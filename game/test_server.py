import base64
from io import BytesIO

import numpy as np
import pytest
from PIL import Image

import server
from server import cnn

ALL = list(cnn.lines()["train"])


def png(img: Image.Image) -> str:
    buf = BytesIO()
    img.convert("RGB").save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def drawing_of(name: str) -> str:
    g = cnn.lines()["train"][name]
    return png(cnn.render_clean(g["stars"], g["edges"]))


def scribble() -> str:
    rng = np.random.default_rng(3)
    return png(cnn.draw(cnn.negative_strokes("graph", rng), rng))


@pytest.fixture()
def client():
    server.GAMES.clear()
    return server.app.test_client()


def new_game(client) -> dict:
    res = client.post("/api/new")
    assert res.status_code == 200
    return res.get_json()


def submit(client, game_id: str, image: str):
    return client.post("/api/submit", json={"game_id": game_id, "image": image})


def test_new_game_starts_clean(client):
    g = new_game(client)
    assert g["target"]["name"] in ALL
    assert g["target"]["edges"] and len(g["target"]["stars"]) >= 2
    assert all(0 <= v <= 1 for p in g["target"]["stars"] for v in p)
    assert (g["score"], g["strikes"], g["remaining"], g["game_over"]) == (0, 0, 88, False)


def test_correct_drawing_scores_a_point(client):
    g = new_game(client)
    res = submit(client, g["game_id"], drawing_of(g["target"]["name"])).get_json()
    assert res["correct"] is True
    assert res["answer"] == g["target"]["name"]
    assert (res["score"], res["strikes"], res["remaining"]) == (1, 0, 87)


def test_wrong_drawing_is_a_strike(client):
    g = new_game(client)
    wrong = next(n for n in ALL if n != g["target"]["name"])
    res = submit(client, g["game_id"], drawing_of(wrong)).get_json()
    assert res["correct"] is False
    assert (res["score"], res["strikes"]) == (0, 1)


def test_unconfident_judge_is_a_strike(client, monkeypatch):
    g = new_game(client)
    monkeypatch.setattr(cnn, "predict_constellation",
                        lambda _: {"name": "unknown", "confidence": 0.2, "top3": [], "unknown_probability": 0.7})
    res = submit(client, g["game_id"], scribble()).get_json()
    assert res["correct"] is False
    assert res["predicted"] == "unknown"
    assert res["strikes"] == 1


def test_five_strikes_end_the_game(client):
    g = new_game(client)
    for _ in range(5):
        res = submit(client, g["game_id"], scribble()).get_json()
    assert res["game_over"] is True and res["strikes"] == 5 and res["target"] is None
    assert len(res["history"]) == 5
    assert submit(client, g["game_id"], scribble()).status_code == 409


def test_all_88_correct_ends_the_game(client, monkeypatch):
    g = new_game(client)
    game = server.GAMES[g["game_id"]]
    monkeypatch.setattr(cnn, "predict_constellation",
                        lambda _: {"name": game.target, "confidence": 1.0, "top3": [], "unknown_probability": 0.0})
    for _ in range(88):
        res = submit(client, g["game_id"], scribble()).get_json()
    assert res["game_over"] is True
    assert (res["score"], res["strikes"], res["remaining"]) == (88, 0, 0)


def test_blank_canvas_is_not_a_strike(client):
    g = new_game(client)
    blank = png(Image.new("RGB", (800, 600), (8, 10, 24)))
    res = submit(client, g["game_id"], blank)
    assert res.status_code == 400
    assert server.GAMES[g["game_id"]].strikes == 0


def test_unknown_game_is_rejected(client):
    assert submit(client, "nope", scribble()).status_code == 404
