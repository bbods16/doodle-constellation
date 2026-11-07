"""Train the Doodle Constellation recognition engine.

A small transformer (the same architecture family as large language
models, scaled down to ~100k parameters) reads a hand-drawn stroke as a
sequence of 32 point tokens and names the constellation figure it
resembles, or "none".

There is no real drawing data, so every training example is synthetic:
each figure in data/asterisms.csv is projected from the star catalogue,
then redrawn the way a person might draw it (wobbly corners, random
rotation and size, either direction, mirrored, rounded corners, uneven
speed). The "none" class is random scribbles, loops and lines.

Outputs (read by lib/engine.ml):
  data/engine_weights.txt   model weights in a plain text format
  data/engine_testvec.txt   raw strokes + expected logits, for the
                            OCaml/PyTorch agreement test

Usage (from the hack/ folder):  py -3 engine/train.py [--epochs 25]

Every function below uses the project's documentation template, with a
Pseudocode section, matching the OCaml sources.
"""

from __future__ import annotations

import argparse
import csv
import math
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

ROOT = Path(__file__).resolve().parent.parent
N_POINTS = 32          # tokens per stroke (lib/engine.ml: n_points)
D_MODEL = 64
N_HEADS = 4
N_LAYERS = 3
D_FF = 128
NONE_LABEL = "none"


# --------------------------------------------------------------------------
# Data
# --------------------------------------------------------------------------

def load_catalogue(path: Path) -> dict[int, tuple[float, float]]:
    """
    [load_catalogue path] reads the star CSV into a map id -> (ra, dec).
    Requires: header id,name,ra_deg,dec_deg,mag,con
    Returns: dict from HR id to (ra, dec) in radians
    Raises: FileNotFoundError if the file is missing
    Example: load_catalogue(ROOT/"data/stars.csv")[4301] == (2.896..., 1.0778...)
    Complexity: O(F) time and space, F = file size
    Pseudocode:
      for each data row: out[id] <- (rad ra_deg, rad dec_deg)
    """
    out = {}
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            out[int(row["id"])] = (math.radians(float(row["ra_deg"])),
                                   math.radians(float(row["dec_deg"])))
    return out


def load_asterisms(path: Path) -> list[tuple[str, str, list[int]]]:
    """
    [load_asterisms path] reads the figure definitions.
    Requires: header name,con,stars with space-separated HR ids
    Returns: list of (name, constellation, star ids in drawing order)
    Raises: FileNotFoundError if the file is missing
    Example: load_asterisms(...)[1] == ("Cassiopeia", "Cas", [21, 168, 264, 403, 542])
    Complexity: O(F) time and space
    Pseudocode:
      for each row: (name, con, map int (split stars))
    """
    with open(path, newline="") as f:
        return [(r["name"], r["con"], [int(s) for s in r["stars"].split()])
                for r in csv.DictReader(f)]


def gnomonic(centre: tuple[float, float], pos: tuple[float, float]) -> tuple[float, float]:
    """
    [gnomonic centre pos] is Geom.gnomonic: tangent-plane projection in
    screen orientation (x toward west, y toward south).
    Requires: radians, pos less than 90 degrees from centre
    Returns: (x, y) on the plane
    Raises: ValueError when pos is on or behind the limb
    Example: gnomonic((0, 0), (0, 0)) == (0.0, 0.0)
    Complexity: O(1) time, O(1) space
    Pseudocode:
      cos_c <- sin dec0 sin dec + cos dec0 cos dec cos dra
      east <- cos dec sin dra / cos_c
      north <- (cos dec0 sin dec - sin dec0 cos dec cos dra) / cos_c
      return (-east, -north)
    """
    ra0, dec0 = centre
    ra, dec = pos
    dra = ra - ra0
    cos_c = math.sin(dec0) * math.sin(dec) + math.cos(dec0) * math.cos(dec) * math.cos(dra)
    if cos_c <= 1e-9:
        raise ValueError("behind the limb")
    east = math.cos(dec) * math.sin(dra) / cos_c
    north = (math.cos(dec0) * math.sin(dec) - math.sin(dec0) * math.cos(dec) * math.cos(dra)) / cos_c
    return (-east, -north)


def sky_centre(ps: list[tuple[float, float]]) -> tuple[float, float]:
    """
    [sky_centre ps] is Skyvec.centre: direction of the mean unit vector.
    Requires: non-empty, non-cancelling positions
    Returns: (ra, dec) in radians
    Raises: nothing
    Example: sky_centre([(0, 0.1), (0, -0.1)]) == (0.0, 0.0)
    Complexity: O(n) time, O(1) space
    Pseudocode:
      m <- sum of (cos dec cos ra, cos dec sin ra, sin dec)
      return (atan2 m.y m.x, atan2 m.z (hypot m.x m.y))
    """
    x = sum(math.cos(d) * math.cos(r) for r, d in ps)
    y = sum(math.cos(d) * math.sin(r) for r, d in ps)
    z = sum(math.sin(d) for r, d in ps)
    return (math.atan2(y, x), math.atan2(z, math.hypot(x, y)))


def figure_vertices(cat, ids: list[int]) -> np.ndarray:
    """
    [figure_vertices cat ids] projects a figure's stars around their
    centre and normalises them (centroid 0, RMS radius 1).
    Requires: every id in cat
    Returns: (k, 2) float array in drawing order
    Raises: KeyError for an unknown id
    Example: figure_vertices(cat, [21, 168, 264, 403, 542]).shape == (5, 2)
    Complexity: O(k) time and space
    Pseudocode:
      c <- sky_centre of the stars ; v <- gnomonic c of each star
      return normalise v
    """
    pos = [cat[i] for i in ids]
    c = sky_centre(pos)
    return normalise(np.array([gnomonic(c, p) for p in pos], dtype=np.float64))


# --------------------------------------------------------------------------
# Preprocessing (mirrored exactly by lib/engine.ml)
# --------------------------------------------------------------------------

def resample(pts: np.ndarray, n: int = N_POINTS) -> np.ndarray:
    """
    [resample pts n] places n points evenly by arc length along the
    polyline pts (first and last points kept).
    Requires: at least 1 point
    Returns: (n, 2) array
    Raises: nothing
    Example: resample(np.array([[0, 0], [3, 0]]), 4) == [[0,0],[1,0],[2,0],[3,0]]
    Complexity: O(m + n) time, O(m + n) space, m input points
    Pseudocode:
      cum.(0) <- 0 ; cum.(i) <- cum.(i-1) + |p.(i) - p.(i-1)|
      if m = 1 or total < 1e-12 then return n copies of p.(0)
      j <- 0
      for k = 0 to n-1:
        t <- k * total / (n-1)
        while j < m-2 and cum.(j+1) < t: j <- j+1
        seg <- cum.(j+1) - cum.(j)
        u <- if seg > 0 then clamp 0 1 ((t - cum.(j)) / seg) else 0
        out.(k) <- p.(j) + u (p.(j+1) - p.(j))
    """
    m = len(pts)
    cum = [0.0]
    for i in range(1, m):
        cum.append(cum[-1] + math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]))
    total = cum[-1]
    if m == 1 or total < 1e-12:
        return np.repeat(np.asarray(pts[:1], dtype=np.float64), n, axis=0)
    out = np.zeros((n, 2))
    j = 0
    for k in range(n):
        t = k * total / (n - 1)
        while j < m - 2 and cum[j + 1] < t:
            j += 1
        seg = cum[j + 1] - cum[j]
        u = min(1.0, max(0.0, (t - cum[j]) / seg)) if seg > 0 else 0.0
        out[k, 0] = pts[j][0] + u * (pts[j + 1][0] - pts[j][0])
        out[k, 1] = pts[j][1] + u * (pts[j + 1][1] - pts[j][1])
    return out


def normalise(pts: np.ndarray) -> np.ndarray:
    """
    [normalise pts] removes position and size: subtract the centroid,
    divide by the RMS distance from it.
    Requires: at least 1 point
    Returns: array of the same shape with centroid 0 and RMS radius 1
             (unchanged scale when the points all coincide)
    Raises: nothing
    Example: normalise(np.array([[0, 0], [2, 0]])) == [[-1, 0], [1, 0]]
    Complexity: O(n) time and space
    Pseudocode:
      c <- mean pts ; q <- pts - c
      r <- sqrt (mean |q|^2) ; if r < 1e-12 then r <- 1
      return q / r
    """
    q = pts - pts.mean(axis=0)
    r = math.sqrt(float((q ** 2).sum(axis=1).mean()))
    return q / (r if r >= 1e-12 else 1.0)


def preprocess(stroke: np.ndarray) -> np.ndarray:
    """
    [preprocess stroke] is the model input: normalise (resample stroke).
    Requires: at least 1 point
    Returns: (N_POINTS, 2) float32 array
    Raises: nothing
    Example: preprocess(some_stroke).shape == (32, 2)
    Complexity: O(m + N_POINTS) time and space
    Pseudocode:
      return normalise (resample stroke N_POINTS)
    """
    return normalise(resample(stroke)).astype(np.float32)


# --------------------------------------------------------------------------
# Synthetic drawings
# --------------------------------------------------------------------------

def draw_like_a_person(verts: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """
    [draw_like_a_person verts rng] turns ideal figure vertices into a
    plausible hand-drawn stroke in screen pixels.
    Requires: (k, 2) normalised vertices, k >= 2
    Returns: (m, 2) stroke points, m roughly 40 to 200
    Raises: nothing
    Example: draw_like_a_person(figure, rng).shape[1] == 2
    Complexity: O(m) time and space
    Pseudocode:
      closed <- first vertex = last vertex
      if closed and coin: start the loop at a random vertex
      if coin: reverse direction ; if coin: mirror (y -> -y)
      jitter every vertex by N(0, sigma_v), sigma_v ~ U(0.02, 0.12)
      (keep a closed loop nearly closed)
      rotate by U(0, 2pi), scale by U(60, 400) pixels
      walk each segment in steps with uneven speed, add pen noise
      smooth with a short moving average (rounded corners)
    """
    v = verts.copy()
    closed = np.allclose(v[0], v[-1])
    if closed and rng.random() < 0.5:
        s = int(rng.integers(0, len(v) - 1))
        ring = np.roll(v[:-1], -s, axis=0)
        v = np.vstack([ring, ring[:1]])
    if rng.random() < 0.5:
        v = v[::-1].copy()
    if rng.random() < 0.5:
        v[:, 1] = -v[:, 1]
    sigma_v = rng.uniform(0.02, 0.12)
    v = v + rng.normal(0, sigma_v, v.shape)
    if closed:
        v[-1] = v[0] + rng.normal(0, 0.02, 2)
    th = rng.uniform(0, 2 * math.pi)
    rot = np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]])
    v = (v @ rot.T) * rng.uniform(60, 400)
    total = sum(np.linalg.norm(v[i + 1] - v[i]) for i in range(len(v) - 1))
    step = total / rng.uniform(40, 200)
    pts = [v[0]]
    for i in range(len(v) - 1):
        a, b = v[i], v[i + 1]
        n = max(1, int(np.linalg.norm(b - a) / (step * rng.uniform(0.6, 1.6))))
        for k in range(1, n + 1):
            pts.append(a + (b - a) * (k / n))
    pts = np.array(pts)
    pts = pts + rng.normal(0, rng.uniform(0, 0.01) * total / len(v), pts.shape)
    w = int(rng.choice([1, 1, 3, 5]))
    if w > 1 and len(pts) > w:
        ker = np.ones(w) / w
        sm = np.stack([np.convolve(pts[:, d], ker, mode="valid") for d in range(2)], axis=1)
        pts = np.vstack([pts[:1], sm, pts[-1:]])
    return pts


def scribble(rng: np.random.Generator) -> np.ndarray:
    """
    [scribble rng] is a stroke that is not any figure: a random polyline,
    a random walk, a straight line or a circle-ish loop.
    Requires: nothing
    Returns: (m, 2) stroke points
    Raises: nothing
    Example: scribble(rng).ndim == 2
    Complexity: O(m) time and space
    Pseudocode:
      kind <- random choice
      polyline: 3..9 uniform random vertices, drawn like a person
      walk: cumulative sum of random steps
      line: two endpoints, drawn like a person
      loop: points on a noisy circle of random extent
    """
    kind = rng.integers(0, 4)
    if kind == 0:
        k = int(rng.integers(3, 10))
        return draw_like_a_person(normalise(rng.uniform(-1, 1, (k, 2))), rng)
    if kind == 1:
        return np.cumsum(rng.normal(0, 1, (int(rng.integers(30, 150)), 2)), axis=0)
    if kind == 2:
        return draw_like_a_person(normalise(rng.uniform(-1, 1, (2, 2))), rng)
    t = np.linspace(0, rng.uniform(1.5, 2.2) * math.pi, int(rng.integers(30, 120)))
    r = 1 + rng.normal(0, 0.05, t.shape)
    return np.stack([r * np.cos(t), r * np.sin(t)], axis=1) * 100


def make_dataset(figures, n_per_class: int, seed: int):
    """
    [make_dataset figures n_per_class seed] builds a balanced synthetic
    dataset: n_per_class drawings of each figure plus n_per_class
    scribbles labelled "none" (the last class).
    Requires: figures non-empty
    Returns: (X, y, raw) with X (n, N_POINTS, 2) float32, y (n,) int64,
             raw the unprocessed strokes
    Raises: nothing
    Example: make_dataset(figs, 10, 0)[0].shape == (10 * (len(figs) + 1), 32, 2)
    Complexity: O(n * m) time and space
    Pseudocode:
      for each class c (figures, then none), n_per_class times:
        stroke <- draw_like_a_person figure_c   (or scribble for none)
        X += preprocess stroke ; y += c ; raw += stroke
    """
    rng = np.random.default_rng(seed)
    xs, ys, raw = [], [], []
    for c, verts in enumerate(figures + [None]):
        for _ in range(n_per_class):
            s = scribble(rng) if verts is None else draw_like_a_person(verts, rng)
            xs.append(preprocess(s))
            ys.append(c)
            raw.append(s)
    return np.stack(xs), np.array(ys, dtype=np.int64), raw


# --------------------------------------------------------------------------
# Model
# --------------------------------------------------------------------------

class Block(nn.Module):
    """One pre-norm transformer block: x + Attn(LN x), then x + MLP(LN x)."""

    def __init__(self):
        """
        [Block()] allocates one transformer block's weights.
        Requires: nothing
        Returns: a module with ln1, q, k, v, o, ln2, ff1, ff2
        Raises: nothing
        Example: Block()(torch.zeros(1, 33, 64)).shape == (1, 33, 64)
        Complexity: O(D_MODEL * D_FF) space
        Pseudocode:
          layer norms and linear maps with the sizes from the constants
        """
        super().__init__()
        self.ln1 = nn.LayerNorm(D_MODEL)
        self.q = nn.Linear(D_MODEL, D_MODEL)
        self.k = nn.Linear(D_MODEL, D_MODEL)
        self.v = nn.Linear(D_MODEL, D_MODEL)
        self.o = nn.Linear(D_MODEL, D_MODEL)
        self.ln2 = nn.LayerNorm(D_MODEL)
        self.ff1 = nn.Linear(D_MODEL, D_FF)
        self.ff2 = nn.Linear(D_FF, D_MODEL)

    def forward(self, x):
        """
        [forward x] applies the block.
        Requires: x of shape (batch, tokens, D_MODEL)
        Returns: same shape
        Raises: nothing
        Example: Block()(torch.zeros(1, 33, 64)).shape == (1, 33, 64)
        Complexity: O(T^2 D + T D D_FF) time per sequence, T tokens
        Pseudocode:
          h <- LN1 x ; split q, k, v into N_HEADS heads of size hd
          a <- softmax (q k^T / sqrt hd) v, heads concatenated
          x <- x + O a
          x <- x + FF2 (GELU (FF1 (LN2 x)))
        """
        b, t, d = x.shape
        hd = d // N_HEADS
        h = self.ln1(x)
        q = self.q(h).view(b, t, N_HEADS, hd).transpose(1, 2)
        k = self.k(h).view(b, t, N_HEADS, hd).transpose(1, 2)
        v = self.v(h).view(b, t, N_HEADS, hd).transpose(1, 2)
        att = torch.softmax(q @ k.transpose(-1, -2) / math.sqrt(hd), dim=-1)
        a = (att @ v).transpose(1, 2).reshape(b, t, d)
        x = x + self.o(a)
        return x + self.ff2(F.gelu(self.ff1(self.ln2(x))))


class Engine(nn.Module):
    """Point-token transformer classifier: [CLS] + 32 stroke points -> class."""

    def __init__(self, n_classes: int):
        """
        [Engine n_classes] allocates the whole model.
        Requires: n_classes >= 2
        Returns: module with inp, cls, pos, blocks, ln_f, head
        Raises: nothing
        Example: Engine(8)(torch.zeros(1, 32, 2)).shape == (1, 8)
        Complexity: about 100k parameters
        Pseudocode:
          inp: 2 -> D_MODEL ; cls: 1 learned token ; pos: N_POINTS + 1 learned
          N_LAYERS blocks ; final layer norm ; head: D_MODEL -> n_classes
        """
        super().__init__()
        self.inp = nn.Linear(2, D_MODEL)
        self.cls = nn.Parameter(torch.zeros(1, 1, D_MODEL))
        self.pos = nn.Parameter(torch.randn(1, N_POINTS + 1, D_MODEL) * 0.02)
        self.blocks = nn.ModuleList([Block() for _ in range(N_LAYERS)])
        self.ln_f = nn.LayerNorm(D_MODEL)
        self.head = nn.Linear(D_MODEL, n_classes)

    def forward(self, x):
        """
        [forward x] maps preprocessed strokes to class logits.
        Requires: x of shape (batch, N_POINTS, 2)
        Returns: (batch, n_classes) logits
        Raises: nothing
        Example: Engine(8)(torch.zeros(1, 32, 2)).shape == (1, 8)
        Complexity: O(N_LAYERS * (T^2 D + T D D_FF)) per sequence
        Pseudocode:
          h <- [cls ; inp x] + pos
          for each block: h <- block h
          return head (LN_f h.(0))       (* the CLS token *)
        """
        h = torch.cat([self.cls.expand(x.shape[0], -1, -1), self.inp(x)], dim=1) + self.pos
        for blk in self.blocks:
            h = blk(h)
        return self.head(self.ln_f(h[:, 0]))


# --------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------

def write_weights(model: Engine, classes: list[str], path: Path) -> None:
    """
    [write_weights model classes path] saves the model for lib/engine.ml.
    Requires: a trained Engine
    Returns: None; writes the text file
    Raises: OSError on write failure
    Example: write_weights(model, ["Big Dipper", ..., "none"], ROOT/"data/engine_weights.txt")
    Complexity: O(P) time and space, P parameters
    Pseudocode:
      write "doodle-engine 1"
      write "config n_points d_model n_heads n_layers d_ff n_classes"
      write "classes" then one class name per line
      for each tensor in state_dict order:
        write "tensor <name> <ndims> <dims...>" then all values on one line
    """
    with open(path, "w", newline="\n") as f:
        f.write("doodle-engine 1\n")
        f.write(f"config {N_POINTS} {D_MODEL} {N_HEADS} {N_LAYERS} {D_FF} {len(classes)}\n")
        f.write("classes\n")
        for c in classes:
            f.write(c + "\n")
        for name, t in model.state_dict().items():
            a = t.detach().cpu().numpy().astype(np.float64)
            f.write(f"tensor {name} {a.ndim} {' '.join(str(d) for d in a.shape)}\n")
            f.write(" ".join(f"{x:.9g}" for x in a.ravel()) + "\n")


def write_testvec(model: Engine, raws: list[np.ndarray], path: Path) -> None:
    """
    [write_testvec model raws path] saves raw strokes and the logits
    PyTorch computes for them, so OCaml can check it agrees.
    Requires: a trained Engine in eval mode
    Returns: None; writes the text file
    Raises: OSError on write failure
    Example: write_testvec(model, raws[:4], ROOT/"data/engine_testvec.txt")
    Complexity: O(sum of stroke lengths + forward passes)
    Pseudocode:
      for each raw stroke:
        write "stroke <m>" then 2m coordinates
        write "logits <C>" then model (preprocess stroke)
    """
    with open(path, "w", newline="\n") as f, torch.no_grad():
        for s in raws:
            logits = model(torch.from_numpy(preprocess(s))[None])[0].numpy()
            f.write(f"stroke {len(s)}\n" + " ".join(f"{x:.17g}" for x in s.ravel()) + "\n")
            f.write(f"logits {len(logits)}\n" + " ".join(f"{x:.9g}" for x in logits) + "\n")


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main() -> None:
    """
    [main ()] generates data, trains, evaluates and exports.
    Requires: data/stars.csv and data/asterisms.csv
    Returns: None
    Raises: FileNotFoundError if the data files are missing
    Example: py -3 engine/train.py --epochs 25
    Complexity: O(epochs * dataset) time
    Pseudocode:
      figures <- figure_vertices of each asterism ; classes <- names + none
      train <- make_dataset figures 12000 seed 1 ; val <- make_dataset figures 1000 seed 2
      AdamW (lr 3e-3, weight decay 0.01), cosine schedule, label smoothing 0.05
      for each epoch: shuffle, minibatches of 256, step ; report val accuracy
      print the per-class confusion matrix on val
      write_weights ; write_testvec on 6 val strokes
    """
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=25)
    ap.add_argument("--per-class", type=int, default=12000)
    args = ap.parse_args()
    torch.manual_seed(0)
    torch.set_num_threads(max(1, torch.get_num_threads()))

    cat = load_catalogue(ROOT / "data" / "stars.csv")
    asts = load_asterisms(ROOT / "data" / "asterisms.csv")
    figures = [figure_vertices(cat, ids) for _, _, ids in asts]
    classes = [name for name, _, _ in asts] + [NONE_LABEL]

    t0 = time.time()
    xtr, ytr, _ = make_dataset(figures, args.per_class, seed=1)
    xva, yva, rva = make_dataset(figures, 1000, seed=2)
    print(f"data: {len(xtr)} train, {len(xva)} val, {time.time() - t0:.0f}s", flush=True)

    model = Engine(len(classes))
    print(f"parameters: {sum(p.numel() for p in model.parameters())}", flush=True)
    opt = torch.optim.AdamW(model.parameters(), lr=3e-3, weight_decay=0.01)
    steps = args.epochs * math.ceil(len(xtr) / 256)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=3e-3, total_steps=steps, pct_start=0.1)
    xtr_t, ytr_t = torch.from_numpy(xtr), torch.from_numpy(ytr)
    xva_t, yva_t = torch.from_numpy(xva), torch.from_numpy(yva)

    for ep in range(args.epochs):
        model.train()
        perm = torch.randperm(len(xtr_t))
        tot = 0.0
        for i in range(0, len(perm), 256):
            idx = perm[i:i + 256]
            loss = F.cross_entropy(model(xtr_t[idx]), ytr_t[idx], label_smoothing=0.05)
            opt.zero_grad()
            loss.backward()
            opt.step()
            sched.step()
            tot += loss.item() * len(idx)
        model.eval()
        with torch.no_grad():
            acc = (model(xva_t).argmax(1) == yva_t).float().mean().item()
        print(f"epoch {ep + 1:2d}  loss {tot / len(perm):.4f}  val acc {acc:.4f}  "
              f"{time.time() - t0:.0f}s", flush=True)

    with torch.no_grad():
        pred = model(xva_t).argmax(1).numpy()
    print("confusion (rows = truth):")
    for c, name in enumerate(classes):
        row = [int(((yva == c) & (pred == k)).sum()) for k in range(len(classes))]
        print(f"  {name:16s} {row}")

    write_weights(model, classes, ROOT / "data" / "engine_weights.txt")
    pick = [int(np.where(yva == c)[0][0]) for c in range(0, len(classes), max(1, len(classes) // 6))]
    write_testvec(model, [rva[i] for i in pick], ROOT / "data" / "engine_testvec.txt")
    print("wrote data/engine_weights.txt and data/engine_testvec.txt")


if __name__ == "__main__":
    main()
