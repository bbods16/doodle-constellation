# Architecture

**Start here.** The code is split into layers. Each layer is its own
dune library with **one interface file** that lists every module in it,
what each is for, and which layers it may use. To understand a layer,
read that file; to use a module, read its `.mli`. You should never need
to open a `.ml` file to use something.

## The layers

```
 ┌──────────────────────────────────────────────────────────────────┐
 │ 5  app        bin/             raylib window, screens, drawing   │
 ├──────────────────────────────────────────────────────────────────┤
 │ 4  game       lib/game/        screen framework, controls, rules │
 ├────────────────────────────────┬─────────────────────────────────┤
 │ 3  matching   lib/matching/    │ 3b recognition lib/recognition/ │
 │    stroke → star pattern       │    stroke → figure name (model) │
 ├────────────────────────────────┴─────────────────────────────────┤
 │ 2  sky        lib/sky/         star catalogue, visibility        │
 ├──────────────────────────────────────────────────────────────────┤
 │ 1  core       lib/core/        2-D and sky geometry              │
 └──────────────────────────────────────────────────────────────────┘
        a layer may use only the layers below it (dune enforces this)
```

| Layer | Read this interface | Built modules | Planned modules (stubs) | May use |
| --- | --- | --- | --- | --- |
| 1 core | [`lib/core/doodle_core.mli`](lib/core/doodle_core.mli) | `Geom`, `Skyvec` | — | — |
| 2 sky | [`lib/sky/doodle_sky.mli`](lib/sky/doodle_sky.mli) | `Catalogue`, `Visibility`, `Data_dir` | `Asterism` | core |
| 3 matching | [`lib/matching/doodle_matching.mli`](lib/matching/doodle_matching.mli) | `Capture`, `Simplify`, `Index`, `Candidates`, `Fitter` | — | core, sky |
| 3b recognition | [`lib/recognition/doodle_recognition.mli`](lib/recognition/doodle_recognition.mli) | `Engine` | — | core |
| 4 game | [`lib/game/doodle_game.mli`](lib/game/doodle_game.mli) | `Scene`, `Controls`, `Game`, `Projection`, `Morph`, `Narrate` | collect: `Accuracy`, `Collection`, `Roast`, `Judge`, `Collect`; welcome: `Menu`, `Title`, `Attract` | core, sky, matching, recognition |
| 5 app | [`bin/main.mli`](bin/main.mli) | `App`, `Welcome`, `Play`, `Play_view`, `Sky`, `Main` | collect: `Collect_scene`, `Collect_view`; welcome: `Title_view` | every layer + raylib |

Only layer 5 touches raylib. Layers 1–4 are pure OCaml and are unit-tested
without a window (`dune test`).

**Planned modules** have their real `.mli` and a stub `.ml` whose
functions fail with *"not implemented yet (see X.mli)"*. They compile, so
their interfaces are checked, but nothing calls them yet and the
planned screens aren't registered in `main.ml`. Each is marked
`PLANNED` in its `.mli` and in its layer's interface file. Build them
from the plan docs below.

## Docs

| Doc | Read it for |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | this map: layers, data flow, where to change things |
| [README.md](README.md) | build, run, retrain the engine, check the proofs |
| [docs/SCENES.md](docs/SCENES.md) | how to add a screen |
| [docs/PROOFS.md](docs/PROOFS.md) | every Lean theorem explained, mapped to the code |
| [docs/COLLECT_PLAN.md](docs/COLLECT_PLAN.md) | PLANNED collect mode: draw each constellation, live %, insults, 5 strikes |
| [docs/WELCOME_PLAN.md](docs/WELCOME_PLAN.md) | PLANNED welcome page: menu, how to play, reset, background animation |

## One frame, end to end

```
 raylib ─► App.read_input ─► Scene.input
                               │
                               ▼
                      Scene.step (current screen)
                               │  Play.update:
                               │    Controls.read      input  → commands
                               │    Game.apply         command → state
                               │      pen_down  ─► Capture
                               │      pen_up    ─► Engine (guess)
                               │                ─► Simplify → Candidates → Fitter (match)
                               │                ─► Projection, Visibility, Morph
                               │      ask_story ─► Narrate
                               │    Game.tick          advance the morph
                               ▼
                      Scene.draw ─► Play_view.draw ─► Sky (raylib)
                               │
                               ▼
                      App applies effects (screenshots)
```

## Signatures and abstract types

- **`Scene.S`** (`lib/game/scene.mli`) is the module signature every
  screen implements: `name`, `init`, `update`, `draw`. `Welcome` and
  `Play` are the two implementations.
- **Abstract types** hide internals; you build and read them only
  through their functions:
  `Scene.ctx` (`Scene.make_ctx`, `Scene.stars`, `Scene.index`,
  `Scene.engine`, `Scene.location`), `Game.t` (`Game.init`, the step
  functions, and the accessors `Game.stage`, `Game.view`,
  `Game.best_view`, `Game.guess`, `Game.story`, `Game.stroke_length`),
  `Capture.t`, `Index.t`, `Engine.t`, `Morph.t`.
- **Public records** are kept where they're plain data, or where the
  original specification (`lib/doodle-mli.zip`) defines them:
  `Geom.pt`, `Geom.sim`, `Catalogue.star`, `Candidates.hypothesis`,
  `Fitter.fit`, `Projection.view` (= `Sky.view`), `Scene.input`,
  `Game.screen`.

## Where do I change…

| I want to… | Change | Guide |
| --- | --- | --- |
| add a screen (menu, credits, settings…) | a new module in `bin/` implementing `Scene.S`, listed in `bin/main.ml` | [docs/SCENES.md](docs/SCENES.md) |
| change a key | `Controls.bindings` in `lib/game/controls.ml` | |
| change a game rule | one function in `lib/game/game.ml` | |
| restyle one thing on screen | one function in `bin/play_view.ml` | |
| share a new resource with all screens | `Scene.ctx` + `Scene.make_ctx`, filled in `bin/main.ml` | |
| teach the engine a new figure | `data/asterisms.csv`, then `engine/train.py` | [README](README.md) |
| change the matching maths | `lib/matching/` (and check `proofs/`) | [docs/PROOFS.md](docs/PROOFS.md) |
| change where data files are looked for | `lib/sky/data_dir.ml` | [README](README.md) |
| build collect mode | the planned modules listed above, in the plan's order | [docs/COLLECT_PLAN.md](docs/COLLECT_PLAN.md) |
| build the new welcome page | the planned modules listed above, then rewrite `bin/welcome.ml` as glue | [docs/WELCOME_PLAN.md](docs/WELCOME_PLAN.md) |

## Conventions

- Every `.ml` file has an `.mli`. Every function in an `.mli` uses the
  template (`[name args] is…`, Requires, Returns, Raises, Example,
  Complexity); every implementation adds a Pseudocode section.
- `.ocamlformat` keeps those doc comments exactly as written, so
  `dune fmt` won't reflow them.
- Within a layer, modules refer to each other by plain name (`Geom.pt`);
  each layer's `dune` file opens the layers below it, so the same names
  work everywhere.
