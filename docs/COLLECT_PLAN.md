# Plan: Collect mode — "collect all the constellations"

**Status:** interfaces designed and type-checked; implementations are
stubs. Every planned module has its real `.mli` in its layer and a
`.ml` whose functions fail with *"not implemented yet (see X.mli)"*. The
build passes and the current app is unchanged (the new screen isn't
registered yet). Each stub's doc comment carries the pseudocode to
implement.

## The game

1. The screen asks for a constellation: **"Draw: Orion"**.
2. You draw it from memory. A big **live percentage** updates as you
   draw, as on [drawtheperfectcircle.com](https://drawtheperfectcircle.com/).
3. On release the drawing is scored against the real figure:
   - **50% or more:** the figure is **collected** (first time), or you see
     **"NEW RECORD!"** or a rank tier if you beat or match your best.
   - **Under 50%:** you get an **insult** and a **strike**.
4. On the **5th strike** you get a **final diss**, it stays up for 4
   seconds, and **the game closes**.
5. Collect every figure to win. Progress and best scores are saved
   between runs.

## Score format (matches the reference site)

| Element | Format | Module |
| --- | --- | --- |
| live and final score | `87.3%`: one decimal, `0.0%`–`100.0%` | `Accuracy.format` |
| best per figure | `Best: 91.2%` (`Best: 0.0%` before any attempt) | `Accuracy.format_best` |
| beat your best | `NEW RECORD!` | `Judge.headline` |
| rank tiers | 94%+ Near Perfect, 90%+ Incredible, 81%+ Amazing, 72%+ Great (the site's table), then 50%+ Collected, below 50% Failed | `Accuracy.tier` |
| colour | red at 0% → yellow at 50% → green at 100% | `Accuracy.colour` |

**Scoring rule** (`Accuracy.score`): resample the stroke and the figure
to 64 points by arc length and normalise both (centroid 0, RMS radius 1),
then align with Procrustes. It tries both drawing directions, every
starting star for closed figures, and the mirror image, and keeps the
smallest RMS gap `r`. The result is `score = 100 · max(0, 1 − r / 0.6)`.
Where you draw, how big, and at what angle never matter. `tolerance = 0.6`
is a first guess, to be tuned so careful drawings land around the site's
typical 50–60%.

## Modules

Each is listed in its layer's interface file (`doodle_sky.mli`,
`doodle_game.mli`) under "PLANNED".

| Layer | Module | Job | Uses |
| --- | --- | --- | --- |
| 2 sky | [`Asterism`](../lib/sky/asterism.mli) | the collectible figures from `data/asterisms.csv`, with each one's ideal shape | `Catalogue`, `Geom`, `Skyvec` |
| 4 game | [`Accuracy`](../lib/game/accuracy.mli) | stroke vs figure → %, format, tiers, colour, pass mark | `Engine.resample/normalise`, `Geom.procrustes` |
| 4 game | [`Collection`](../lib/game/collection.mli) | collected flags and best score per figure; save/load `progress.csv` | `Asterism`, `Accuracy` |
| 4 game | [`Roast`](../lib/game/roast.mli) | strike counter (max 5), insult lines, final diss | `Accuracy.format` |
| 4 game | [`Judge`](../lib/game/judge.mli) | one score → verdict, updating collection and strikes | `Collection`, `Roast`, `Accuracy` |
| 4 game | [`Collect`](../lib/game/collect.mli) | the mode's state machine (Prompt → Drawing → Verdict → … / Dissed → quit / Complete) | all of the above, `Capture`, `Controls` |
| 5 app | [`Collect_scene`](../bin/collect_scene.mli) | the screen (`Scene.S`, name `"collect"`): glue, saving, quitting | `Collect`, `Collection`, `Controls` |
| 5 app | [`Collect_view`](../bin/collect_view.mli) | drawing, one function per element | raylib, `Sky` |

One frame works exactly like the existing game screen:

```
input ─Controls.read─► commands ─Collect.apply (each), Collect.tick─► state
state ─Collect_view.draw─► screen
Collect.take_save_request ─► Collection.save      (after each verdict)
Collect.wants_quit        ─► Scene.Quit           (after the final diss)
```

## Changes needed outside the new modules

These are small, but they touch existing code, so they're listed rather
than made:

1. **`Scene.ctx` gains the figures and the data folder.** Add
   `?figures:Asterism.t array` and `~data_dir:string` to `Scene.make_ctx`,
   with accessors `Scene.figures` and `Scene.data_dir`. `main.ml` loads
   the figures with `Asterism.load` next to the catalogue it already finds
   with `Data_dir`.
2. **Register the screen:** add `(module Collect_scene)` to `scenes` in
   `bin/main.ml`.
3. **Welcome screen:** Enter → `Goto "collect"`, plus a new key (e.g.
   **F**) for free draw → `Goto "play"`, and updated instructions.
4. **`.gitignore`:** add `data/progress.csv` (per-player progress).

## Build order (each step testable on its own)

1. `Asterism.load`: test 7 figures, shapes non-empty, Orion closed,
   Cassiopeia open.
2. `Accuracy`: test a perfect trace = 100.0%; moved, scaled, rotated,
   reversed or mirrored trace = 100.0%; a straight line < 50%; `format`
   rounding and clamping; tier boundaries (94.0 → Near Perfect, 49.9 →
   Failed).
3. `Roast`: test the 5th miss gives `Final_diss` and a 6th raises; same
   seed gives same lines; `insult` fills `{score}`/`{target}`.
4. `Collection`: test collected at exactly 50.0, not at 49.9; `new_best`
   only on improvement; save then load round-trips.
5. `Judge`: test each verdict constructor; a miss also updates the best.
6. `Collect`: drive with `Controls.command`s and `tick`, as the existing
   `Game` tests do: a full win, and 5 misses → `Dissed` → `wants_quit`.
7. `Collect_view` + `Collect_scene`, then the outside changes above.
   Check by hand in the window.

Optional, later: Lean proofs that `Accuracy.score` is always in
[0, 100] and unchanged under moving, scaling and rotating the stroke.
The normalisation half is already proved in `proofs/Proofs/Normalise.lean`.

## Insults

Insults roast the **drawing**, never the person. There are no slurs and
nothing about identity, looks or real-life ability. They are written to
be funny, in the style of a trash-talking arcade game. The pools are
`Roast.insults` (10 lines, can mention the score and the figure) and
`Roast.final_disses` (4 lines). Edit those lists to change the tone.

## Decisions to confirm

| Question | Planned default | Alternative |
| --- | --- | --- |
| ~~Do strikes reset after a good drawing?~~ **Decided:** no. 5 misses in total ends the game; a pass never clears strikes. | — | — |
| How is the target chosen? | first uncollected figure, in file order | random order, or free draw (any figure the matcher finds counts) |
| Pass mark | **50.0%** (your rule) | — |
| Show a faint "ghost" of your best attempt while drawing (as the site does)? | not planned | add `Collect_view.ghost` |
| Does an insult count when the stroke is too short to score? | yes, it scores 0.0% | ignore tiny accidental clicks (e.g. under 20 points) |
