# Doodle Constellation

Two ways to play:

- **Collect the constellations:** the game names a constellation, you
  draw it from memory, and a live percentage scores your drawing (in the
  style of drawtheperfectcircle.com). 50% or more collects it. Under 50%
  earns an insult and a strike; 5 strikes and the game closes. Collect
  all 7 to win; progress and best scores are saved.
- **Free draw:** draw any shape and the app finds where it sits in the
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

## Layout

**New to the code? Read [ARCHITECTURE.md](ARCHITECTURE.md) first.** The
library is split into layers, each with one interface file.

| Path | What it is |
| --- | --- |
| `lib/core/` | Layer 1: geometry (`Geom`, `Skyvec`) |
| `lib/sky/` | Layer 2: star catalogue, visibility, data-folder lookup, collectible figures (`Catalogue`, `Visibility`, `Data_dir`, `Asterism`) |
| `lib/matching/` | Layer 3: stroke → star pattern (`Capture`, `Simplify`, `Index`, `Candidates`, `Fitter`) |
| `lib/recognition/` | Layer 3b: trained recognition engine (`Engine`) |
| `lib/game/` | Layer 4: screen framework (`Scene`, `Controls`), free draw (`Game`, `Projection`, `Morph`, `Narrate`), collect mode (`Accuracy`, `Collection`, `Roast`, `Judge`, `Collect`), welcome page (`Menu`, `Title`, `Attract`) |
| `bin/` | Layer 5: raylib app (`App` loop, screens `Welcome` + `Title_view`, `Play` + `Play_view`, `Collect_scene` + `Collect_view`, `Sky` renderer, `Main`) |
| `test/` | OUnit2 tests, including end-to-end matches and an OCaml-vs-PyTorch agreement test for the engine |
| `engine/train.py` | Synthetic data generator, transformer training and weight export |
| `data/stars.csv` | Sample bright-star catalogue (48 stars; coordinates entered by hand, approximate) |
| `data/asterisms.csv` | Constellation figures: what the engine learns and, once built, what collect mode asks for |
| `data/engine_weights.txt` | Trained engine weights (plain text) |
| `proofs/` | Lean 4 + Mathlib proofs |
| `docs/PROOFS.md` | Every theorem explained in paragraphs, mapped to the OCaml code |
| `docs/SCENES.md` | How to add a screen |
| `docs/COLLECT_PLAN.md` | Collect mode design: scoring, verdicts, insults, strikes |
| `docs/WELCOME_PLAN.md` | Welcome page design: menu, how to play, reset, animation |

Every OCaml function is documented with the project template
(`[name args] is…`, Requires, Returns, Raises, Example, Complexity), and
every implementation adds a Pseudocode section. `.ocamlformat` keeps
those comments exactly as written, so `dune fmt` won't reflow them.

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

The app finds `data/stars.csv` on its own: it looks in the current folder
and its parents, then next to the executable and its parents, so it works
from anywhere inside the repo (including `bin/`, or by running
`_build/default/bin/main.exe` directly). To use data elsewhere, pass the
file (`hack path/to/stars.csv`) or set `DOODLE_DATA` to the folder that
contains `stars.csv`. If nothing is found, it prints every place it
looked.

The app opens on the welcome menu (arrow keys or W/S and Enter, or the
mouse): **Collect the constellations**, **Free draw**, **How to play**,
**Reset progress**, **Quit**. Escape quits from the menu.

In both games, drag with the left mouse button to draw, **C** clears,
**S** saves a share card, and **M** or **Escape** returns to the menu. In
free draw, **N** asks for an invented story (needs `ANTHROPIC_API_KEY`
and `curl`). Collect-mode progress is saved to `data/progress.csv` (not
committed; Reset progress deletes it).

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
