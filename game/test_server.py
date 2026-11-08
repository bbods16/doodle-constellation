import base64
from io import BytesIO

import numpy as np
import pytest
from PIL import Image

import server
from server import cnn

ALL = list(cnn.lines()["train"])
ANDROMEDA = ALL[0]


def png(img: Image.Image) -> str:
    buf = BytesIO()
    img.convert("RGB").save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def drawing_of(name: str) -> str:
    g = cnn.lines()["train"][name]
    return png(cnn.render_clean(g["stars"], g["edges"]))


def scribble() -> str:
    rng = np.random.default_rng(3)
    return png(cnn.draw(cnn.negative_strokes("scribble", rng), rng))


@pytest.fixture()
def client(tmp_path, monkeypatch):
    server.GAMES.clear()
    monkeypatch.setattr(server, "DRAWINGS_DIR", tmp_path / "drawings")
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
    assert (g["points"], g["round"], g["rounds"], g["game_over"]) == (0, 1, 10, False)


def test_correct_drawing_scores_high(client):
    g = new_game(client)
    # pin the target: a few constellations score lower even when drawn perfectly
    server.GAMES[g["game_id"]].deck[0] = ANDROMEDA
    res = submit(client, g["game_id"], drawing_of(ANDROMEDA)).get_json()
    assert res["answer"] == ANDROMEDA
    assert res["points_earned"] >= 90
    assert res["points"] == res["points_earned"]
    assert res["round"] == 2


def test_wrong_drawing_scores_low(client):
    g = new_game(client)
    wrong = next(n for n in ALL if n != g["target"]["name"])
    res = submit(client, g["game_id"], drawing_of(wrong)).get_json()
    assert res["points_earned"] < 20


def test_ten_rounds_end_the_game_and_total_adds_up(client):
    g = new_game(client)
    earned = []
    for _ in range(10):
        res = submit(client, g["game_id"], scribble()).get_json()
        earned.append(res["points_earned"])
    assert res["game_over"] is True and res["target"] is None
    assert res["points"] == sum(earned)
    assert [h["points"] for h in res["history"]] == earned
    assert submit(client, g["game_id"], scribble()).status_code == 409


def test_each_submit_saves_the_drawing(client):
    g = new_game(client)
    name = g["target"]["name"]
    submit(client, g["game_id"], drawing_of(name))
    saved = list((server.DRAWINGS_DIR / server.short(name)).glob("*.png"))
    assert len(saved) == 1
    assert Image.open(saved[0]).size == (800, 800)


def test_blank_canvas_uses_no_round(client):
    g = new_game(client)
    blank = png(Image.new("RGB", (800, 600), (8, 10, 24)))
    res = submit(client, g["game_id"], blank)
    assert res.status_code == 400
    assert server.GAMES[g["game_id"]].index == 0
    assert not server.DRAWINGS_DIR.exists()


def test_unknown_game_is_rejected(client):
    assert submit(client, "nope", scribble()).status_code == 404


def test_every_constellation_has_at_least_two_facts():
    from facts import FACTS
    assert set(FACTS) == {server.short(n) for n in ALL}
    for name, facts in FACTS.items():
        assert len(facts) >= 2, name
        assert all(f.strip() for f in facts), name
        assert len(set(facts)) == len(facts), name


def test_submit_returns_a_fact_about_the_target(client):
    from facts import FACTS
    g = new_game(client)
    res = submit(client, g["game_id"], drawing_of(g["target"]["name"])).get_json()
    assert res["fact"] in FACTS[server.short(res["answer"])]
