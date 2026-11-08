(**
   File: controls.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Controls module: maps one frame of input to game
                commands; the only place key bindings live.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Controls (or Controls with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Controls: turns one frame of raw {!Scene.input} into game commands.

    This is the only place that knows which key does what, so changing a
    binding (or adding a gamepad later) never touches the game logic.
    Pure OCaml, unit-tested. *)

type command =
  | Pen_down of Geom.pt  (** left button held at this screen position *)
  | Pen_up               (** left button released *)
  | Clear                (** wipe the sky and start over *)
  | Save_card            (** save the current frame as a share card *)
  | Ask_story            (** request an invented story for the match *)
  | Open_menu            (** go back to the welcome screen *)
  | Dismiss              (** acknowledge a message that waits for the player (Enter) *)
(** Everything the player can ask the game to do. *)

val bindings : (Scene.key * command) list
(** Key bindings: [C] clear, [S] save card, [N] story, [M] or Escape: menu,
    Enter: dismiss (collect mode's insults wait for it). *)

val read : Scene.input -> command list
(**
   [read inp] lists this frame's commands: [Pen_down] while the button is
   held, [Pen_up] on release, then one command per bound key pressed, in
   {!bindings} order.
   Requires: nothing
   Returns: the commands, possibly empty
   Raises: nothing
   Example: read { idle with mouse_down = true; mouse = p } = [Pen_down p]
   Complexity: O(k * b) time, k keys pressed, b bindings; O(k) space
*)
