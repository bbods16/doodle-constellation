(**
   File: controls.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Controls module: maps one frame of input to game
                commands; the only place key bindings live.
   Usage: The contract is in controls.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Controls (or Controls with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Input-to-command mapping. See controls.mli for the public contract. *)

type command = Pen_down of Geom.pt | Pen_up | Clear | Save_card | Ask_story | Open_menu | Dismiss

let bindings =
  [ (Scene.Letter 'c', Clear); (Scene.Letter 's', Save_card); (Scene.Letter 'n', Ask_story);
    (Scene.Letter 'm', Open_menu); (Scene.Escape, Open_menu); (Scene.Enter, Dismiss) ]

(**
   [read inp] turns one frame of input into commands.
   Requires: nothing
   Returns: pen commands first, then key commands in binding order
   Raises: nothing
   Example: read { idle with mouse_down = true; mouse = p } = [Pen_down p]
   Complexity: O(k * b) time, O(k) space
   Pseudocode:
     pen <- [Pen_down mouse] if the button is held, then [Pen_up] if released
     keys <- for each (key, command) in bindings: command if key was pressed
     return pen @ keys
*)
let read (inp : Scene.input) =
  let pen =
    (if inp.mouse_down then [ Pen_down inp.mouse ] else [])
    @ if inp.mouse_released then [ Pen_up ] else []
  in
  pen @ List.filter_map (fun (k, c) -> if Scene.pressed inp k then Some c else None) bindings
