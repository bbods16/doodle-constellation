import json
import sys
import time
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).parent
DATA = ROOT / "dataset" / "archive" / "Contellations Segmentation"
LINES_PATH = ROOT / "constellation_lines.json"
MODEL_PATH = ROOT / "constellation_model.keras"
NAMES_PATH = ROOT / "class_names.json"
SIZE = 128
INK_DIFF = 40
UNKNOWN = "unknown"
NEG_RATE = 0.12
TRAIN_NEG = ("scribble", "graph", "zigzag", "ellipse", "partial")
HELDOUT_NEG = ("text", "spiral", "grid", "smiley")
BATCH = 32
STEPS = 600
SEED = 0


# ---------- line extraction from the stargazer images ----------

def _ring_kernel(r):
    k = int(r + 4)
    y, x = np.mgrid[-k:k + 1, -k:k + 1]
    ring = (np.abs(np.hypot(x, y) - r) <= 1.25).astype(np.float32)
    return ring / ring.sum()


def _correlate(mask, kernel):
    h, w = mask.shape
    kh, kw = kernel.shape
    shape = (h + kh, w + kw)
    out = np.fft.irfft2(np.fft.rfft2(mask, shape) * np.fft.rfft2(kernel, shape), shape)
    return out[kh // 2:kh // 2 + h, kw // 2:kw // 2 + w]


def find_stars(gray):
    # stars are drawn as fixed-size circles, so a ring template finds them cleanly (real >= 0.9, noise <= 0.5)
    mask = (gray > 80).astype(np.float32)
    inside = np.ones_like(mask)
    scores = {}
    for r in range(8, 40, 2):
        k = _ring_kernel(r)
        # score only the part of the ring inside the frame, so stars cut off by the image edge still count
        scores[r] = _correlate(mask, k) / np.maximum(_correlate(inside, k), 0.5)
    # small radii also fire on the asterisk inside each circle, so the circle size is the largest radius that matches
    r = max(r for r, s in scores.items() if s.max() > 0.9)
    best = np.maximum.reduce([scores[k] for k in (r - 2, r, r + 2) if k in scores])
    stars = []
    flat = np.flatnonzero(best > 0.6)
    for i in flat[np.argsort(best.ravel()[flat])[::-1]]:
        y, x = divmod(int(i), gray.shape[1])
        if all((x - a) ** 2 + (y - b) ** 2 > (1.4 * r) ** 2 for a, b in stars):
            stars.append((x, y))
    return np.array(stars, float), float(r)


def find_edges(gray, stars, r):
    raw = gray > INK_DIFF
    # hand-drawn lines end at the circle edge and don't aim exactly at the centre, so allow a wide corridor
    tol = max(3, int(0.8 * r)) | 1
    dilated = np.asarray(Image.fromarray(raw.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(tol))) > 0
    edges = []
    for i in range(len(stars)):
        for j in range(i + 1, len(stars)):
            a, b = stars[i], stars[j]
            length = np.linalg.norm(b - a)
            if length < 2.3 * r:
                # rings almost touch: connected if ink bridges the midpoint
                mx, my = ((a + b) / 2).round().astype(int)
                if raw[my - 1:my + 2, mx - 1:mx + 2].any():
                    edges.append((i, j))
                continue
            t = np.linspace(1.25 * r / length, 1 - 1.25 * r / length, max(3, int(length - 2.5 * r)))
            pts = a + (b - a) * t[:, None]
            # a line through a third star is really two edges, which that star's own pairs will find;
            # only stars along the middle of the segment count, so a star touching an endpoint doesn't block it
            d = b - a
            proj = ((stars - a) @ d) / length ** 2
            perp = np.abs((stars[:, 0] - a[0]) * d[1] - (stars[:, 1] - a[1]) * d[0]) / length
            through = (proj > 0.1) & (proj < 0.9) & (perp < 1.2 * r)
            through[[i, j]] = False
            if through.any():
                continue
            q = pts.round().astype(int)
            if dilated[q[:, 1], q[:, 0]].mean() > 0.8:
                edges.append((i, j))
    return edges


def _star_mask(size, stars, r):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for x, y in stars:
        draw.ellipse((x - 1.4 * r, y - 1.4 * r, x + 1.4 * r, y + 1.4 * r), fill=255)
    return mask


def coverage_gap(gray, stars, edges, r):
    # share of real line ink (outside star circles) that the extracted edges do not explain
    ink = gray > 60
    size = (gray.shape[1], gray.shape[0])
    stars_only = np.asarray(_star_mask(size, stars, r)) > 0
    covered = _star_mask(size, stars, r)
    draw = ImageDraw.Draw(covered)
    for i, j in edges:
        draw.line((*stars[i], *stars[j]), fill=255, width=max(3, int(0.7 * r)))
    missed = ink & (np.asarray(covered) == 0)
    return float(missed.sum() / max(1, (ink & ~stars_only).sum()))


def _extract_one(path):
    gray = np.asarray(Image.open(path).convert("L"), dtype=np.float32)
    stars, r = find_stars(gray)
    return gray, stars, find_edges(gray, stars, r), r


def _extract_train(json_path):
    label = json.loads(Path(json_path).read_text())["shapes"][0]["label"]
    gray, stars, edges, r = _extract_one(Path(json_path).with_suffix(".jpg"))
    return label, {"stars": stars.round(1).tolist(), "edges": edges, "source": Path(json_path).stem,
                   "gap": round(coverage_gap(gray, stars, edges, r), 4)}


def extract_lines():
    with Pool() as pool:
        train = dict(pool.map(_extract_train, [str(p) for p in DATA.glob("train/*.json")]))
    challenge = []
    for f in sorted(DATA.glob("test/*.json")):
        gray, stars, edges, r = _extract_one(f.with_suffix(".jpg"))
        for shape in json.loads(f.read_text())["shapes"]:
            mask = Image.new("L", (gray.shape[1], gray.shape[0]), 0)
            ImageDraw.Draw(mask).polygon([tuple(p) for p in shape["points"]], fill=255)
            keep = [k for k, (x, y) in enumerate(stars) if mask.getpixel((int(x), int(y)))]
            index = {old: new for new, old in enumerate(keep)}
            challenge.append({
                "label": shape["label"], "source": f.stem,
                "stars": stars[keep].round(1).tolist(),
                "edges": [(index[i], index[j]) for i, j in edges if i in index and j in index],
            })
    LINES_PATH.write_text(json.dumps({"train": dict(sorted(train.items())), "challenge": challenge}, ensure_ascii=False))
    for label, g in sorted(train.items(), key=lambda kv: -kv[1]["gap"])[:12]:
        print(f"{g['gap']:.2%} uncovered  {len(g['stars'])} stars {len(g['edges'])} edges  {g['source']}  {label}")
    for c in challenge:
        print(f"challenge {c['source']}: {c['label']}  {len(c['stars'])} stars {len(c['edges'])} edges")


_LINES = None


def lines():
    global _LINES
    if _LINES is None:
        _LINES = json.loads(LINES_PATH.read_text())
    return _LINES


# ---------- preprocessing shared by training and the game ----------

def preprocess(img, size=SIZE):
    a = np.asarray(img.convert("L"), dtype=np.float32)
    # background is whatever colour dominates the border, so light-on-dark and dark-on-light both work
    border = np.concatenate([a[:2].ravel(), a[-2:].ravel(), a[:, :2].ravel(), a[:, -2:].ravel()])
    ink = np.abs(a - np.median(border)) > INK_DIFF
    ys, xs = np.nonzero(ink)
    if len(xs) < 5:
        return np.zeros((size, size, 1), np.float32)
    # percentiles keep a few stray specks from blowing up the crop
    x0, x1 = np.percentile(xs, [0.2, 99.8])
    y0, y1 = np.percentile(ys, [0.2, 99.8])
    half = max(x1 - x0, y1 - y0) * 0.55 + 1
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    box = tuple(int(round(v)) for v in (cx - half, cy - half, cx + half, cy + half))
    crop = Image.fromarray(ink.astype(np.uint8) * 255).crop(box).resize((size, size), Image.BOX)
    # area-averaged downscale makes thin strokes faint, so boost them to full brightness and give a minimum width
    boosted = np.minimum(np.asarray(crop, np.float32) * 3, 255).astype(np.uint8)
    out = Image.fromarray(boosted).filter(ImageFilter.MaxFilter(3))
    return np.asarray(out, np.float32)[..., None] / 255.0


# ---------- synthetic apple pencil drawings ----------

def _wobble(p, q, rng, amount):
    t = np.linspace(0, 1, 16)[:, None]
    d = q - p
    length = np.linalg.norm(d) + 1e-9
    normal = np.array([-d[1], d[0]]) / length
    f, phase = rng.uniform(0.5, 2.0), rng.uniform(0, 2 * np.pi)
    offset = amount * length * np.sin(np.pi * f * t + phase) * np.sin(np.pi * t)
    return p + d * t + normal * offset


def _edge_strokes(points, edges, rng):
    strokes = []
    for i, j in edges:
        p, q = points[i], points[j]
        d = q - p
        # players stop short of or overshoot the vertex
        p = p - d * rng.uniform(-0.05, 0.04)
        q = q + d * rng.uniform(-0.05, 0.04)
        line = _wobble(p, q, rng, rng.uniform(0, 0.03))
        if rng.random() < 0.15:
            cut = rng.integers(3, 13)
            strokes += [line[:cut], line[cut + 1:]]
        else:
            strokes.append(line)
    return strokes


def _affine(points, rng):
    theta = rng.uniform(0, 2 * np.pi)
    rot = np.array([[np.cos(theta), -np.sin(theta)], [np.sin(theta), np.cos(theta)]])
    shape = np.array([[rng.uniform(0.85, 1.15), np.tan(np.radians(rng.uniform(-10, 10)))], [0, rng.uniform(0.85, 1.15)]])
    return points @ (rot @ shape).T


def constellation_strokes(stars, edges, rng):
    p = np.array(stars, float)
    p = (p - p.mean(0)) / (np.ptp(p, 0).max() + 1e-9)
    p = _affine(p, rng) + rng.normal(0, 0.015, p.shape)
    return _edge_strokes(p, edges, rng)


def draw(strokes, rng):
    pts = np.concatenate(strokes)
    lo, hi = pts.min(0), pts.max(0)
    extent = max((hi - lo).max(), 1e-6)
    w = int(rng.integers(160, 1400))
    h = int(w * rng.uniform(0.6, 1.6))
    scale = rng.uniform(0.3, 0.9) * min(w, h) / extent
    span = (hi - lo) * scale
    origin = np.array([rng.uniform(0, w - span[0]), rng.uniform(0, h - span[1])])
    light = rng.random() < 0.25
    bg = rng.uniform(190, 255) if light else rng.uniform(0, 60)
    fg = rng.uniform(0, 100) if light else rng.uniform(110, 255)
    img = Image.new("L", (w, h), int(bg))
    pen = ImageDraw.Draw(img)
    width = max(1, int(round(rng.uniform(0.004, 0.03) * min(w, h))))
    for s in strokes:
        pen.line([tuple(v) for v in (s - lo) * scale + origin], fill=int(fg), width=width, joint="curve")
    if rng.random() < 0.5:
        img = img.filter(ImageFilter.GaussianBlur(rng.uniform(0.3, 1.0)))
    if rng.random() < 0.3:
        noise = rng.normal(0, rng.uniform(1, 6), (h, w))
        img = Image.fromarray(np.clip(np.asarray(img, np.float32) + noise, 0, 255).astype(np.uint8))
    return img


def _random_walk(rng, n):
    angle = np.cumsum(rng.normal(0, 0.6, n)) + rng.uniform(0, 2 * np.pi)
    return np.cumsum(np.stack([np.cos(angle), np.sin(angle)], 1), 0)


def negative_strokes(kind, rng):
    if kind == "scribble":
        return [_random_walk(rng, int(rng.integers(20, 60))) for _ in range(rng.integers(1, 4))]
    if kind == "graph":
        p = rng.uniform(0, 1, (int(rng.integers(4, 13)), 2))
        edges = [(k, int(rng.integers(0, k))) for k in range(1, len(p))]
        return _edge_strokes(p, edges, rng)
    if kind == "zigzag":
        n = int(rng.integers(4, 11))
        p = np.stack([np.arange(n), rng.uniform(0.5, 2, n) * (np.arange(n) % 2)], 1)
        return [_affine(p, rng)]
    if kind == "ellipse":
        out = []
        for _ in range(rng.integers(1, 3)):
            t = np.linspace(0, rng.uniform(1.2, 2) * np.pi, 40)
            out.append(_affine(np.stack([np.cos(t), rng.uniform(0.4, 1) * np.sin(t)], 1) + rng.uniform(-1, 1, 2), rng))
        return out
    if kind == "partial":
        big = [g for g in lines()["train"].values() if len(g["edges"]) >= 5]
        g = big[rng.integers(len(big))]
        keep = rng.choice(len(g["edges"]), max(1, int(len(g["edges"]) * rng.uniform(0.2, 0.4))), replace=False)
        return constellation_strokes(g["stars"], [g["edges"][k] for k in keep], rng)
    if kind == "spiral":
        t = np.linspace(0, rng.uniform(4, 8) * np.pi, 80)
        return [_affine(np.stack([t * np.cos(t), t * np.sin(t)], 1), rng)]
    if kind == "grid":
        n, m = rng.integers(2, 5), rng.integers(2, 5)
        rows = [np.array([[0, k], [m, k]], float) for k in range(n)]
        cols = [np.array([[k, -0.5], [k, n - 0.5]], float) for k in range(m)]
        return [_wobble(s[0], s[1], rng, 0.02) for s in _split_affine(rows + cols, rng)]
    if kind == "smiley":
        t = np.linspace(0, 2 * np.pi, 40)
        face = np.stack([np.cos(t), np.sin(t)], 1)
        eyes = [face * 0.12 + [-0.35, 0.3], face * 0.12 + [0.35, 0.3]]
        u = np.linspace(-2.5, -0.6, 20)
        mouth = np.stack([0.5 * np.cos(u), 0.5 * np.sin(u)], 1)
        return _split_affine([face, *eyes, mouth], rng)
    raise ValueError(kind)


def _split_affine(strokes, rng):
    sizes = np.cumsum([len(s) for s in strokes])[:-1]
    return np.split(_affine(np.concatenate(strokes), rng), sizes)


def draw_text(rng):
    letters = "ABCDEFGHJKLMNPQRSTUVWXYZabdefghkmnpqrstuwxyz0123456789"
    text = "".join(rng.choice(list(letters), int(rng.integers(1, 5))))
    w = int(rng.integers(200, 1000))
    light = rng.random() < 0.25
    img = Image.new("L", (w, w), 230 if light else 15)
    font = ImageFont.load_default(size=int(w * rng.uniform(0.15, 0.4)))
    ImageDraw.Draw(img).text((w * 0.1, w * 0.3), text, fill=20 if light else 230, font=font)
    return img.rotate(rng.uniform(0, 360), fillcolor=230 if light else 15)


def sample(seed, size, neg_kinds, neg_rate):
    rng = np.random.default_rng(seed)
    names = list(lines()["train"])
    if rng.random() < neg_rate:
        kind = neg_kinds[rng.integers(len(neg_kinds))]
        img = draw_text(rng) if kind == "text" else draw(negative_strokes(kind, rng), rng)
        label = len(names)
    else:
        label = int(rng.integers(len(names)))
        g = lines()["train"][names[label]]
        img = draw(constellation_strokes(g["stars"], g["edges"], rng), rng)
    return (preprocess(img, size)[..., 0] * 255).astype(np.uint8), label


def _batch(args):
    start, count, size, neg_kinds, neg_rate = args
    xs, ys = zip(*(sample(s, size, neg_kinds, neg_rate) for s in range(start, start + count)))
    return np.stack(xs), np.array(ys)


def make_set(pool, start, count, size, neg_kinds, neg_rate):
    chunks = [(s, min(256, start + count - s), size, neg_kinds, neg_rate) for s in range(start, start + count, 256)]
    parts = pool.map(_batch, chunks)
    return np.concatenate([p[0] for p in parts])[..., None], np.concatenate([p[1] for p in parts])


def render_clean(stars, edges, canvas=800):
    # straight, evenly lit lines with no augmentation: how a tidy player drawing looks
    p = np.array(stars, float)
    p = (p - p.min(0)) / (np.ptp(p, 0).max() + 1e-9) * canvas * 0.8 + canvas * 0.1
    img = Image.new("L", (canvas, canvas), 10)
    pen = ImageDraw.Draw(img)
    for i, j in edges:
        pen.line((*p[i], *p[j]), fill=235, width=5)
    return img


# ---------- model ----------

def build_model(num_classes, size=SIZE, dropout=0.4, l2=0.0):
    import tensorflow as tf
    reg = tf.keras.regularizers.l2(l2) if l2 else None
    # strided stem: full-resolution convs were most of the compute, and line drawings don't need them
    model = tf.keras.Sequential([
        tf.keras.Input((size, size, 1)),
        tf.keras.layers.Conv2D(32, 5, strides=2, padding="same", use_bias=False, kernel_regularizer=reg),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.ReLU(),
    ])
    for filters in (64, 128, 256):
        for _ in range(2):
            model.add(tf.keras.layers.Conv2D(filters, 3, padding="same", use_bias=False, kernel_regularizer=reg))
            model.add(tf.keras.layers.BatchNormalization())
            model.add(tf.keras.layers.ReLU())
        model.add(tf.keras.layers.MaxPooling2D())
    model.add(tf.keras.layers.GlobalAveragePooling2D())
    model.add(tf.keras.layers.Dropout(dropout))
    model.add(tf.keras.layers.Dense(num_classes, activation="softmax", kernel_regularizer=reg))
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    return model


def decide(probs, threshold):
    # the last class is "unknown"; reject when it wins or the best constellation is not confident enough
    best = probs[:, :-1].argmax(1)
    conf = probs[:, :-1].max(1)
    accepted = (probs.argmax(1) != probs.shape[1] - 1) & (conf >= threshold)
    return best, conf, accepted


def pick_threshold(probs, labels):
    unknown = probs.shape[1] - 1
    valid = labels != unknown
    best = (0.0, 0.0)
    for t in np.arange(0.0, 0.96, 0.01):
        pred, _, ok = decide(probs, t)
        good = (ok[valid] & (pred[valid] == labels[valid])).mean()
        rejected = (~ok[~valid]).mean()
        score = (good + rejected) / 2
        if score > best[0] + 1e-9:
            best = (score, float(t))
    return best[1]


def train(size=SIZE, dropout=0.4, l2=0.0, epochs=60, out=MODEL_PATH):
    import tensorflow as tf
    tf.keras.utils.set_random_seed(SEED)
    print("GPUs:", tf.config.list_physical_devices("GPU"))
    names = list(lines()["train"]) + [UNKNOWN]
    n = len(names)
    pool = Pool()
    # val/test use their own seed ranges, so no generated image appears twice; positives still share source drawings
    x_val, y_val = make_set(pool, 1_000_000, 88 * 40 + 600, size, TRAIN_NEG, 600 / (88 * 40 + 600))
    x_test, y_test = make_set(pool, 2_000_000, 88 * 40 + 600, size, TRAIN_NEG, 600 / (88 * 40 + 600))
    x_held, y_held = make_set(pool, 3_000_000, 800, size, HELDOUT_NEG, 1.0)
    print(f"val {len(x_val)} / test {len(x_test)} / held-out negatives {len(x_held)}")

    def batches():
        start = 10_000_000
        jobs = ((start + k * BATCH, BATCH, size, TRAIN_NEG, NEG_RATE) for k in range(10 ** 9))
        for x, y in pool.imap(_batch, jobs, chunksize=4):
            yield x[..., None].astype(np.float32) / 255.0, y

    spec = (tf.TensorSpec((None, size, size, 1), tf.float32), tf.TensorSpec((None,), tf.int64))
    train_ds = tf.data.Dataset.from_generator(batches, output_signature=spec).prefetch(8)
    model = build_model(n, size, dropout, l2)
    print(f"params {model.count_params():,}  size {size}  dropout {dropout}  l2 {l2}")
    model.fit(
        train_ds,
        steps_per_epoch=STEPS,
        validation_data=(x_val / 255.0, y_val),
        epochs=epochs,
        callbacks=[
            tf.keras.callbacks.ModelCheckpoint(out, monitor="val_accuracy", save_best_only=True),
            tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=3),
            tf.keras.callbacks.EarlyStopping(monitor="val_accuracy", patience=8, restore_best_weights=True),
        ],
        verbose=2,
    )
    pool.terminate()
    model = tf.keras.models.load_model(out)
    report = evaluate_model(model, names, size, x_val, y_val, x_test, y_test, x_held)
    meta = {"classes": names, "threshold": report["threshold"], "size": size, "report": report}
    names_path = NAMES_PATH if Path(out) == MODEL_PATH else Path(out).with_suffix(".json")
    names_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print(json.dumps(report, indent=2))


def evaluate_model(model, names, size, x_val, y_val, x_test, y_test, x_held):
    unknown = len(names) - 1
    p_val = model.predict(x_val / 255.0, verbose=0)
    threshold = pick_threshold(p_val, y_val)
    report = {"threshold": threshold, "params": model.count_params()}
    for name, x, y in (("val", x_val, y_val), ("test", x_test, y_test)):
        probs = model.predict(x / 255.0, verbose=0)
        pred, _, ok = decide(probs, threshold)
        valid = y != unknown
        report[f"{name}_top1"] = round(float((pred[valid] == y[valid]).mean()), 4)
        report[f"{name}_accepted_correct"] = round(float((ok[valid] & (pred[valid] == y[valid])).mean()), 4)
        report[f"{name}_neg_rejected"] = round(float((~ok[~valid]).mean()), 4)
    _, _, ok = decide(model.predict(x_held / 255.0, verbose=0), threshold)
    report["heldout_neg_rejected"] = round(float((~ok).mean()), 4)

    clean = np.stack([preprocess(render_clean(g["stars"], g["edges"]), size) for g in lines()["train"].values()])
    pred, _, ok = decide(model.predict(clean, verbose=0), threshold)
    report["clean_train_drawings_top1"] = round(float((pred == np.arange(len(clean))).mean()), 4)

    challenge = lines()["challenge"]
    xc = np.stack([preprocess(render_clean(c["stars"], c["edges"]), size) for c in challenge])
    yc = np.array([names.index(c["label"]) for c in challenge])
    pred, conf, ok = decide(model.predict(xc, verbose=0), threshold)
    report["challenge_lines_top1"] = f"{int((pred == yc).sum())}/{len(yc)}"
    report["challenge_lines_accepted_correct"] = f"{int((ok & (pred == yc)).sum())}/{len(yc)}"
    report["challenge_detail"] = [f"{names[t].split(' – ')[0]} -> {names[p].split(' – ')[0]} {c:.2f}{'' if a else ' (rejected)'}"
                                  for t, p, c, a in zip(yc, pred, conf, ok)]

    one = clean[:1]
    model.predict(one, verbose=0)
    start = time.perf_counter()
    for _ in range(20):
        model(one, training=False)
    report["latency_ms"] = round((time.perf_counter() - start) / 20 * 1000, 1)
    return report


# ---------- game interface ----------

_MODEL = None
_META = None


def _load():
    global _MODEL, _META
    if _MODEL is None:
        import tensorflow as tf
        _MODEL = tf.keras.models.load_model(MODEL_PATH)
        _META = json.loads(NAMES_PATH.read_text())
    return _MODEL, _META


def predict_constellation(image_path, canvas_box=None):
    # ui text or buttons in the image get treated as strokes, so send the canvas only or pass its (left, top, right, bottom)
    model, meta = _load()
    img = Image.open(image_path)
    if canvas_box:
        img = img.crop(canvas_box)
    x = preprocess(img, meta["size"])[None]
    probs = model(x, training=False).numpy()
    best, conf, ok = decide(probs, meta["threshold"])
    order = np.argsort(probs[0, :-1])[::-1][:3]
    top3 = [(meta["classes"][k], round(float(probs[0, k]), 4)) for k in order]
    name = meta["classes"][int(best[0])] if ok[0] else UNKNOWN
    return {"name": name, "confidence": round(float(conf[0]), 4), "top3": top3,
            "unknown_probability": round(float(probs[0, -1]), 4)}


def evaluate_folder(folder):
    # folder layout: <folder>/<constellation name or "unknown">/<drawing>.png
    _, meta = _load()
    short = {c.split(" – ")[0].lower(): c for c in meta["classes"]}
    total = correct = 0
    for sub in sorted(Path(folder).iterdir()):
        if not sub.is_dir():
            continue
        truth = short.get(sub.name.lower().split(" – ")[0])
        if truth is None:
            print(f"skipping {sub.name}: not a known constellation")
            continue
        for f in sorted(sub.iterdir()):
            if f.suffix.lower() not in (".png", ".jpg", ".jpeg"):
                continue
            result = predict_constellation(f)
            total += 1
            if result["name"] == truth:
                correct += 1
            else:
                print(f"wrong: {sub.name}/{f.name} -> {result['name']} ({result['confidence']:.2f}), top3 {result['top3']}")
    print(f"accuracy {correct}/{total} = {correct / max(1, total):.1%}")


def _arg(flag, default, cast):
    return cast(sys.argv[sys.argv.index(flag) + 1]) if flag in sys.argv else default


if __name__ == "__main__":
    command = sys.argv[1:2]
    if command == ["extract"]:
        extract_lines()
    elif command == ["train"]:
        train(size=_arg("--size", SIZE, int), dropout=_arg("--dropout", 0.4, float), l2=_arg("--l2", 0.0, float),
              epochs=_arg("--epochs", 60, int), out=Path(_arg("--out", MODEL_PATH, str)))
    elif command == ["evaluate"] and len(sys.argv) == 3:
        evaluate_folder(sys.argv[2])
    elif command == ["predict"] and len(sys.argv) == 3:
        print(json.dumps(predict_constellation(sys.argv[2]), indent=2, ensure_ascii=False))
    else:
        print("usage: python constellation_cnn.py extract | train [--size N] [--dropout X] [--l2 X] [--epochs N] [--out PATH]"
              " | evaluate <folder> | predict <image_path>")
