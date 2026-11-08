import base64
import random
import socket
import sys
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from io import BytesIO
from pathlib import Path

import numpy as np
from flask import Flask, jsonify, request, send_from_directory
from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE / "model"))
import constellation_cnn as cnn  # noqa: E402
from facts import FACTS  # noqa: E402

ROUNDS = 10
# >1 softens the model's confidence; tested 1.5-3 and it only lowered good drawings' scores without giving wrong ones credit
SCORE_TEMPERATURE = 1.0
DRAWINGS_DIR = HERE / "drawings"
PORT = 8000

app = Flask(__name__, static_folder=str(HERE / "static"), static_url_path="/static")


@dataclass
class Game:
    deck: list[str]
    index: int = 0
    points: int = 0
    history: list[dict] = field(default_factory=list)

    @property
    def over(self) -> bool:
        return self.index >= len(self.deck)

    @property
    def target(self) -> str | None:
        return None if self.over else self.deck[self.index]


GAMES: dict[str, Game] = {}


def short(name: str) -> str:
    return name.split(" – ")[0]


def preview(name: str) -> dict:
    graph = cnn.lines()["train"][name]
    pts = graph["stars"]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    span = max(max(xs) - min(xs), max(ys) - min(ys)) or 1.0
    # centre the shape in a unit square so the browser can scale it to any canvas
    ox = min(xs) - (span - (max(xs) - min(xs))) / 2
    oy = min(ys) - (span - (max(ys) - min(ys))) / 2
    stars = [[(x - ox) / span, (y - oy) / span] for x, y in pts]
    return {"name": name, "stars": stars, "edges": graph["edges"]}


def judge(img: Image.Image, target: str) -> dict:
    model, meta = cnn._load()
    probs = model(cnn.preprocess(img, meta["size"])[None], training=False).numpy()
    best, conf, accepted = cnn.decide(probs, meta["threshold"])
    constellations = probs[0, :-1]
    soft = constellations ** (1 / SCORE_TEMPERATURE)
    soft /= soft.sum()
    top = np.argsort(soft)[::-1][:3]
    return {
        "target_confidence": float(soft[meta["classes"].index(target)]),
        "predicted": meta["classes"][int(best[0])] if accepted[0] else cnn.UNKNOWN,
        "top3": [(meta["classes"][k], round(float(soft[k]), 4)) for k in top],
    }


def state(game_id: str, game: Game) -> dict:
    return {
        "game_id": game_id,
        "points": game.points,
        "round": min(game.index + 1, len(game.deck)),
        "rounds": len(game.deck),
        "game_over": game.over,
        "target": preview(game.target) if game.target else None,
        "history": game.history if game.over else [],
    }


def save_drawing(img: Image.Image, target: str, points: int) -> Path:
    # same layout constellation_cnn.py evaluate reads: <folder>/<constellation>/<drawing>.png
    folder = DRAWINGS_DIR / short(target)
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{datetime.now():%Y%m%d-%H%M%S-%f}_{points}.png"
    img.save(path)
    return path


@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.post("/api/new")
def new_game():
    game_id = uuid.uuid4().hex
    GAMES[game_id] = Game(random.sample(list(cnn.lines()["train"]), ROUNDS))
    return jsonify(state(game_id, GAMES[game_id]))


@app.post("/api/submit")
def submit():
    body = request.get_json(silent=True) or {}
    game = GAMES.get(body.get("game_id", ""))
    if game is None:
        return jsonify(error="unknown game"), 404
    if game.over:
        return jsonify(error="game is over"), 409
    try:
        img = Image.open(BytesIO(base64.b64decode(body.get("image", "").split(",", 1)[-1])))
        img.load()
    except Exception:
        return jsonify(error="could not read the drawing"), 400
    # a blank canvas is a misclick, not a guess
    if cnn.preprocess(img).max() == 0:
        return jsonify(error="draw something first"), 400

    target = game.target
    result = judge(img, target)
    earned = round(100 * result["target_confidence"])
    save_drawing(img, target, earned)
    game.points += earned
    game.history.append({"target": target, "points": earned, "predicted": result["predicted"]})
    game.index += 1
    fact = random.choice(FACTS[short(target)])
    return jsonify({"answer": target, "points_earned": earned, "fact": fact, **result, **state(body["game_id"], game)})


def lan_address() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


if __name__ == "__main__":
    # load the model now so the first submit isn't slow
    cnn._load()
    print(f"play on this computer: http://localhost:{PORT}")
    print(f"play on the ipad (same wifi): http://{lan_address()}:{PORT}")
    print(f"drawings are saved to {DRAWINGS_DIR}")
    app.run(host="0.0.0.0", port=PORT, threaded=False)
