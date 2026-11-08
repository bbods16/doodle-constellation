# Welcome page

**Status: built.** `Menu`, `Attract` and `Title` are implemented and
unit-tested, `Title_view` draws the page, and `bin/welcome.ml` is now
the glue described below. It was checked in the running app: the menu,
How to play, Escape back, and Reset progress (the confirm screen opens
on "No"; "Yes" deletes the progress file). Companion to
[COLLECT_PLAN.md](COLLECT_PLAN.md): the welcome page is the way into
collect mode. This document was the plan; **"As built"** at the end
lists the differences.

## What it does

The current welcome screen only says "click to start". Now that there
are two ways to play, it becomes a real title screen:

- **Main menu**, by keyboard (↑/↓ or W/S, Enter/Space) or mouse (hover
  selects, click chooses):
  1. **Collect the constellations**, with your progress underneath:
     `3 / 7 collected · avg best 71.4%`
  2. **Free draw**: the existing drawing game
  3. **How to play**: the rules
  4. **Reset progress**: dimmed when there's nothing to reset
  5. **Quit**
- **How to play page:** the % score (`0.0%`–`100.0%`, like
  drawtheperfectcircle.com), the 50% pass mark, the site's tiers, and
  the 5-strikes-total rule. Text is built from `Accuracy.pass_mark` and
  `Roast.max_strikes`, so it can't drift out of date.
- **Confirm reset:** "Reset all progress?" with **No** selected by
  default, so an accidental Enter is safe.
- **Background animation:** each constellation figure draws itself star
  by star, holds, fades, then the next begins (an arcade "attract mode").

```
Main ──How to play──► Help ──any key / Esc──► Main
Main ──Reset──► Confirm_reset ──No / Esc──► Main
                            └──Yes──► Reset (delete progress) ──► Main
Main ──Collect──► Go "collect"     Main ──Free draw──► Go "play"     Main ──Quit──► Quit
```

## Modules

| Layer | Module | Job | Uses |
| --- | --- | --- | --- |
| 4 game | [`Menu`](../lib/game/menu.mli) | generic list menu: items (label, detail, enabled), selection that skips disabled items and wraps, keyboard/mouse commands, button layout, hit-testing. Reusable for a pause or settings menu later. | `Scene.input`, `Geom` |
| 4 game | [`Title`](../lib/game/title.mli) | the welcome page's rules: pages, which menu is live, the rules text, and what to do next (`Stay` / `Go scene` / `Quit` / `Reset`) | `Menu`, `Attract`, `Accuracy`, `Roast` |
| 4 game | [`Attract`](../lib/game/attract.mli) | the background animation: which figure, how much is drawn, its fade, and its on-screen path | `Asterism`, `Menu.rect` |
| 5 app | [`Title_view`](../bin/title_view.mli) | drawing, one function per element (background, attract, title, menu buttons, help page, confirm dialog, footer) | raylib, `Sky` |
| 5 app | `Welcome` *(existing, to rewrite)* | becomes glue, shown below | `Title`, `Title_view`, `Collection` |

Like the game screens, all the rules are pure and unit-testable; only
`Title_view` touches raylib, and only the `Welcome` glue touches the disk.

### `Welcome` after the rewrite (glue only)

```ocaml
let init ctx =
  let figures = Scene.figures ctx in
  let progress = Collection.load figures (progress_path ctx) in
  Title.init figures (Some (summary_of progress))

let update ctx inp t =
  match Title.update inp t with
  | t, Title.Stay -> Scene.Continue (t, [])
  | _, Title.Go scene -> Scene.Goto scene
  | _, Title.Quit -> Scene.Quit
  | t, Title.Reset ->
      (try Sys.remove (progress_path ctx) with Sys_error _ -> ());
      Scene.Continue (Title.after_reset t, [])

let draw = Title_view.draw
```

`summary_of` turns a `Collection.t` into `Title.summary` (collected
count, total, and the average best over attempted figures).

## Changes outside the new modules (all done)

Shared with the collect plan; do them once:

1. **`Scene.ctx` gains `figures` and `data_dir`.** See COLLECT_PLAN.md,
   change 1. The welcome page needs the figures for the animation and
   the data folder for the progress file.
2. **Rewrite `bin/welcome.ml`** as the glue above. Its `.mli` stays
   `include Scene.S`, so `main.ml` doesn't change for this step.
3. **Register collect mode** (COLLECT_PLAN.md, change 2). Until then,
   disable the Collect button: create it with `enabled = false`.

## Build order (followed; each step has its tests)

1. **`Menu`:** test that `create` selects the first enabled item; Up/Down
   skip disabled items and wrap; `item_at` hits inside and on edges and
   misses outside; a `Click` on a disabled item chooses nothing; `layout`
   gives one rect per item, all inside the window.
2. **`Attract`:** test that with no figures `current = None` and the paths
   are empty; the fraction runs 0 → 1 over `seconds_per_figure`; it moves
   to the next figure after drawing plus holding and wraps to the first;
   the path at fraction 1 ends at the last star; points stay inside `box`.
3. **`Title`:** drive it with `Scene.idle` inputs. Test that Enter on
   Collect → `Go "collect"`; Free draw → `Go "play"`; How to play → `Help`,
   then any key → `Main`; Reset → `Confirm_reset` with No selected; Esc →
   `Main`; Yes → `Reset`, and `after_reset` → `Main` with 0 collected; Reset
   is disabled when nothing is collected; `help_lines` mentions `50.0%`
   and `5`.
4. **`Title_view`**, then the `Welcome` rewrite. Check by hand: mouse
   hover, clicks, keys, and the animation.

## Decisions

| Question | Built as | Possible change later |
| --- | --- | --- |
| Menu item selected on arrival | Collect the constellations | remember the last choice |
| Free draw mode | kept, as menu item 2 | remove it, collect mode only |
| Confirm before resetting progress | yes, **No** selected by default | reset immediately |
| Background animation | on, cycling all figures | static starfield only |
| Escape on the main menu | quits (now handled by the menu itself, not raylib) | do nothing; quit only via the menu |
| Show your best % per figure on the title screen | only the average, under Collect | a full collection panel on the title screen |

## As built: differences from the plan

1. **Escape is handled by the screens, not raylib.** raylib closed the
   window on Escape before any screen saw it, so "Escape goes back" on
   How to play and the reset confirm couldn't work. `App.run` now turns
   raylib's exit key off: Escape quits from the main menu, goes back from
   How to play and the confirm, and returns to the menu from either game.
2. **Hover only moves the selection when the mouse moves.** Otherwise a
   mouse resting over a button would snap the selection back every frame
   and fight the arrow keys. There's a test for this.
3. **"Reset progress" is enabled once anything was attempted**, not only
   after something is collected, so a run of failed attempts can also be
   wiped.
4. **Plain ASCII on screen** (`>` for the selected item, `[x]` for
   collected). raylib's built-in font has no glyphs for symbols like ✓ or
   ▸ and would draw them as `?`.
5. **`Accuracy.prefix` is shared.** The background animation draws a
   figure part-way using the same function the live score uses, instead
   of a second copy.
