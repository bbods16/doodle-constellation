import base64
import random
import socket
import sys
import uuid
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory
from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE / "model"))
import constellation_cnn as cnn  # noqa: E402

MAX_STRIKES = 5
PORT = 8000

app = Flask(__name__, static_folder=str(HERE / "static"), static_url_path="/static")


@dataclass
class Game:
    deck: list[str]
    index: int = 0
    score: int = 0
    strikes: int = 0
    history: list[dict] = field(default_factory=list)

    @property
    def over(self) -> bool:
        return self.strikes >= MAX_STRIKES or self.index >= len(self.deck)

    @property
    def target(self) -> str | None:
        return None if self.over else self.deck[self.index]


GAMES: dict[str, Game] = {}


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


def state(game_id: str, game: Game) -> dict:
    return {
        "game_id": game_id,
        "score": game.score,
        "strikes": game.strikes,
        "max_strikes": MAX_STRIKES,
        "remaining": len(game.deck) - game.index,
        "total": len(game.deck),
        "game_over": game.over,
        "target": preview(game.target) if game.target else None,
        "history": game.history if game.over else [],
    }


def decode(data_url: str) -> Image.Image:
    return Image.open(BytesIO(base64.b64decode(data_url.split(",", 1)[-1])))


@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.post("/api/new")
def new_game():
    deck = list(cnn.lines()["train"])
    random.shuffle(deck)
    game_id = uuid.uuid4().hex
    GAMES[game_id] = Game(deck)
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
        img = decode(body.get("image", ""))
        img.load()
    except Exception:
        return jsonify(error="could not read the drawing"), 400
    # a blank canvas is a misclick, not a guess
    if cnn.preprocess(img).max() == 0:
        return jsonify(error="draw something first"), 400

    buf = BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    result = cnn.predict_constellation(buf)
    target = game.target
    correct = result["name"] == target
    if correct:
        game.score += 1
    else:
        game.strikes += 1
    game.history.append({"target": target, "predicted": result["name"], "correct": correct})
    game.index += 1
    return jsonify({
        "correct": correct,
        "answer": target,
        "predicted": result["name"],
        "confidence": result["confidence"],
        "top3": result["top3"],
        **state(body["game_id"], game),
    })


def lan_address() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


if __name__ == "__main__":
    # load the model now so the first submit isn't slow
    cnn.predict_constellation(BytesIO(base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==")))
    print(f"play on this computer: http://localhost:{PORT}")
    print(f"play on the ipad (same wifi): http://{lan_address()}:{PORT}")
    app.run(host="0.0.0.0", port=PORT, threaded=False)
