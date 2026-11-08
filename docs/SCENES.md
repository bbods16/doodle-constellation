# Adding screens (scenes)

The app is a set of independent **scenes**: `welcome`, `play`, and any
you add. The game loop (`bin/app.ml`) knows nothing about any particular
screen; it only runs whatever scene is current.

```
          bin/main.ml                    bin/app.ml (the loop, every frame)
   load ctx, list the scenes  ──►   read_input ─► Scene.step ─► draw ─► effects
                                                     │
               lib/game/scene.ml (pure, tested)      ▼
                  registry: "welcome" ─► Welcome   update returns
                            "play"    ─► Play      Continue / Goto "name" / Quit
```

## The pieces

| Module | Role |
| --- | --- |
| `lib/game/scene.ml` | The `Scene.S` interface, input and context types, registry and `step`. Pure OCaml, no raylib, unit-tested. |
| `bin/app.ml` | The loop: opens the window, turns raylib input into `Scene.input`, steps the current scene, clears, draws, applies effects. |
| `bin/main.ml` | Loads shared resources into `Scene.ctx` and lists the scenes. |
| `bin/welcome.ml` | The welcome page: glue over `Title` (rules) and `Title_view` (drawing). For a minimal scene, see the credits example below. |
| `bin/collect_scene.ml` | Collect mode: glue over `Collect` (rules) and `Collect_view` (drawing). |
| `bin/play.ml` | The drawing game scene: about 20 lines of glue, shown below. |
| `lib/game/controls.ml` | Raw input → `Controls.command` list. The only place key bindings live. Pure, tested. |
| `lib/game/game.ml` | The game's rules: one small function per command (`pen_down`, `pen_up` → `recognise` / `match_stroke` / `begin_morph`, `tick`, `clear`, `ask_story`), each delegating to the matching library module. Pure, tested. |
| `lib/game/projection.ml` | Sky-to-screen maths (moved out of the renderer so `Game` needs no raylib). |
| `bin/play_view.ml` | Draws a `Game.t`, one function per layer (`sky`, `stroke`, `status`, `fit_info`, `engine_badge`, `story`, `help`). |

## How the game scene is wired

Every step of a frame is a call into a separate module:

```
input ──Controls.read──► commands ──Game.apply (each) ─► Game.tick ──► state
state ──Play_view.draw──► screen
```

```ocaml
(* bin/play.ml, in full apart from comments *)
let update ctx inp g =
  let cmds = Controls.read inp in
  if List.mem Controls.Open_menu cmds then Scene.Goto "welcome"
  else
    let g = List.fold_left (Game.apply ctx (screen_of inp)) g cmds |> Game.tick inp.dt in
    Scene.Continue (g, effects_of cmds)

let draw = Play_view.draw
```

To change a key, edit `Controls.bindings`. To change a rule, edit one
function in `Game`. To restyle one on-screen element, edit one function
in `Play_view`. None of these touch the loop.

## What a scene looks like

```ocaml
(* bin/credits.ml *)
open Raylib

type t = { elapsed : float }

let name = "credits"                       (* unique; other scenes Goto it by this *)

let init (_ : Scene.ctx) = { elapsed = 0. }  (* fresh state each time it's entered *)

let update (_ : Scene.ctx) (inp : Scene.input) t =
  if Scene.pressed inp Scene.Enter then Scene.Goto "welcome"
  else Scene.Continue ({ elapsed = t.elapsed +. inp.dt }, [])

let draw (_ : Scene.ctx) _t =                (* the background is already cleared *)
  draw_text "Made with OCaml, raylib and Lean" 40 40 24 Color.raywhite
```

and its interface, `bin/credits.mli`:

```ocaml
include Scene.S
```

Then add it to the list in `bin/main.ml`:

```ocaml
let scenes : (module Scene.S) list = [ (module Welcome); (module Play); (module Credits) ]
```

That's all. `bin/dune` builds every module in the folder, so there's
nothing else to register. To show it, return `Scene.Goto "credits"` from
any other scene's `update`.

## Rules of the road

- **`update` decides, `draw` only draws.** `update` gets this frame's
  `Scene.input` and returns `Continue (state, effects)`, `Goto name` or
  `Quit`. Keep raylib calls out of `update`, so its logic can be tested
  with `Scene.idle` (see the router tests in `test/test_hack.ml`).
- **Scenes don't import each other.** Switch screens by name with `Goto`.
  The target starts from its own `init`, so state is never shared by
  accident.
- **Shared resources live in `Scene.ctx`** (abstract; read it with `Scene.stars`, `Scene.index`, `Scene.engine`, `Scene.location`): the star catalogue, triangle
  index, recognition engine (if loaded), and observer location. To share
  something new, add a field plus an accessor in `lib/game/scene.ml`, extend `Scene.make_ctx`, and fill it in `load_ctx` in
  `main.ml`.
- **Side effects go through `effects`.** Return
  `[Scene.Screenshot "file.png"]` and the loop saves the frame after it is
  drawn. New effect kinds go in `Scene.side_effect` and `App.apply_effect`.
- **Keys:** scenes see `Scene.key` values (`Enter`, `Space`, `Escape`,
  `Backspace`, `Tab`, arrows, `Letter 'a'..'z'`, `Digit 0..9`). To expose
  another raylib key, extend `Scene.key` and `App.key_map`. Escape is
  not a raylib exit key here: each screen decides what it does (the menu
  quits, the games go back to the menu).
- **Starting screen:** `~first:"welcome"` in `main.ml`.
