# Doodle Constellation

Draw a shape with the mouse; the app finds where that shape sits in the
real night sky, morphs your drawing onto the stars, and tells you when
and where to look for it tonight.

Two independent recognisers run on every stroke:

1. **Geometric matcher** (`lib/`): simplifies the stroke to 5–9 corners,
   looks up every corner triangle in a geometric-hashing index of star
   triangles, then refines each guess with least-squares Procrustes
   fitting. It can find any star pattern, not only named ones.
2. **Recognition engine** (`lib/engine.ml`, `engine/train.py`): a small
   transformer (~100k parameters, the same architecture family as large
   language models) trained from scratch on synthetic hand-drawn strokes.
   It names the constellation figure you drew, or says `none`.

The geometry the matcher and engine depend on is proved in **Lean 4 with
Mathlib** (`proofs/`) and explained in prose in
[docs/PROOFS.md](docs/PROOFS.md).

## CNN strike game (`game/`)

A browser game built on a CNN that recognises line-only constellation drawings.
You get a random constellation (all 88, no repeats) and its shape for a few
seconds, then draw it with lines only, using Apple Pencil, a finger or a mouse.
**Submit** sends a screenshot of the canvas to the model:

- the model names the right constellation: **+1 point**
- it names a different one, or isn't confident (`unknown`): **strike**
- **5 strikes**, or all 88 played: game over. Your score is the number guessed correctly.

```bash
uv venv --python 3.12 .venv-game
uv pip install --python .venv-game -r game/requirements.txt
.venv-game/bin/python game/server.py             # prints a localhost URL and a LAN URL for the iPad
.venv-game/bin/python -m pytest game/test_server.py -q
```

Open the LAN URL in Safari on an iPad on the same wifi to play with Apple Pencil.
The model (`game/model/`) was trained in a separate project. It reaches about 87%
on simulated screenshots, but it hasn't been measured on real player drawings yet.

## Layout

| Path | What it is |
| --- | --- |
| `lib/` | Pure OCaml library: geometry, stroke capture, simplifier, catalogue, triangle index, candidates, fitter, visibility, morph, narration, recognition engine |
| `bin/` | raylib front end (`sky.ml` renderer, `main.ml` app) |
| `test/` | OUnit2 tests, including end-to-end matches and an OCaml-vs-PyTorch agreement test for the engine |
| `engine/train.py` | Synthetic data generator, transformer training and weight export |
| `data/stars.csv` | Sample bright-star catalogue (48 stars; coordinates entered by hand, approximate) |
| `data/asterisms.csv` | Constellation figures the engine learns, as star ids in drawing order |
| `data/engine_weights.txt` | Trained engine weights (plain text) |
| `proofs/` | Lean 4 + Mathlib proofs |
| `docs/PROOFS.md` | Every theorem explained in paragraphs, mapped to the OCaml code |

Every OCaml function is documented with the project template
(`[name args] is…`, Requires, Returns, Raises, Example, Complexity), and
every implementation adds a Pseudocode section.

## Build and run

Requires OCaml 5.2+, dune 3.24+, and for the window app `raylib` and
`ctypes` from opam.

```bash
opam install . --deps-only --with-test
opam install raylib
dune build
dune test
dune exec hack                 # from the repo root, so data/ is found
dune exec hack -- 40.7 -74.0   # latitude, longitude in degrees
```

Without raylib, `dune build` and `dune test` still build and test the
library; only the window app is skipped.

Keys: drag with the left mouse button to draw, **C** clears, **S** saves a
share card, **N** asks for an invented story (needs `ANTHROPIC_API_KEY`
and `curl`).

## Retrain the engine

```bash
py -3 engine/train.py --epochs 20 --per-class 8000
dune test   # checks the OCaml forward pass still matches PyTorch
```

To teach it a new figure, add its stars to `data/stars.csv` and a row to
`data/asterisms.csv`, then retrain.

## Check the proofs

```bash
cd proofs
lake exe cache get   # one-time Mathlib download
lake build
```
