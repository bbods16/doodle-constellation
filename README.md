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

## Layout

**New to the code? Read [ARCHITECTURE.md](ARCHITECTURE.md) first.** The
library is split into layers, each with one interface file.

| Path | What it is |
| --- | --- |
| `lib/core/` | Layer 1: geometry (`Geom`, `Skyvec`) |
| `lib/sky/` | Layer 2: star catalogue and visibility (`Catalogue`, `Visibility`) |
| `lib/matching/` | Layer 3: stroke → star pattern (`Capture`, `Simplify`, `Index`, `Candidates`, `Fitter`) |
| `lib/recognition/` | Layer 3b: trained recognition engine (`Engine`) |
| `lib/game/` | Layer 4: screen framework and game rules (`Scene`, `Controls`, `Game`, `Projection`, `Morph`, `Narrate`) |
| `bin/` | Layer 5: raylib app (`App` loop, `Welcome` and `Play` screens, `Play_view`, `Sky` renderer, `Main`) |
| `test/` | OUnit2 tests, including end-to-end matches and an OCaml-vs-PyTorch agreement test for the engine |
| `engine/train.py` | Synthetic data generator, transformer training and weight export |
| `data/stars.csv` | Sample bright-star catalogue (48 stars; coordinates entered by hand, approximate) |
| `data/asterisms.csv` | Constellation figures the engine learns, as star ids in drawing order |
| `data/engine_weights.txt` | Trained engine weights (plain text) |
| `proofs/` | Lean 4 + Mathlib proofs |
| `docs/PROOFS.md` | Every theorem explained in paragraphs, mapped to the OCaml code |

| `docs/SCENES.md` | How to add a screen |

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

The app opens on a welcome screen; click or press Enter to start. In the
game, drag with the left mouse button to draw, **C** clears, **S** saves a
share card, **N** asks for an invented story (needs `ANTHROPIC_API_KEY`
and `curl`), and **M** returns to the welcome screen.

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
