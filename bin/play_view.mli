(**
   File: play_view.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Play_view module: draws the free-draw game, one
                function per screen element.
   Usage: Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(** Play_view: draws a {!Game.t}, one small function per layer.

    {!draw} paints the layers back to front; each layer reads the game
    state and hands the actual drawing to {!Sky} or raylib's text calls.
    To restyle or move one element, change only its function. *)

val card_path : string
(** Where [Save_card] writes the screenshot: ["doodle_card.png"]. *)

val draw : Scene.ctx -> Game.t -> unit
(**
   [draw ctx g] paints every layer in order: {!sky}, {!stroke},
   {!status}, {!fit_info}, {!engine_badge}, {!story}, {!help}.
   Requires: inside the loop's drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx (Game.init ()) shows the blank sky and the prompt
   Complexity: O(N + s), N stars, s stroke points
*)

val sky : Scene.ctx -> Game.t -> unit
(**
   [sky ctx g] draws the stars and, when there is a match, its pattern
   lines and labels ({!Sky.draw}).
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: sky ctx (Game.init ()) draws the default wide view
   Complexity: O(N)
*)

val stroke : Game.t -> unit
(**
   [stroke g] draws the player's stroke as it currently looks: live,
   morphing, or settled on the stars ({!Sky.draw_stroke}).
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: stroke (Game.init ()) draws nothing
   Complexity: O(s)
*)

val status : Game.t -> unit
(**
   [status g] draws the top-left line: the drawing prompt, or the reason
   a stroke was refused.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: status (Game.init ()) shows "Draw a shape with 5 to 9 corners"
   Complexity: O(1)
*)

val fit_info : Game.t -> unit
(**
   [fit_info g] draws the fit error and best viewing time once the morph
   has finished ({!Sky.draw_info}).
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: fit_info (Game.init ()) draws nothing
   Complexity: O(1)
*)

val engine_badge : Game.t -> unit
(**
   [engine_badge g] draws the recognition engine's guess at the top right.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: engine_badge g shows "Engine: Big Dipper (99%)"
   Complexity: O(1)
*)

val story : Game.t -> unit
(**
   [story g] draws the invented story, with its fiction label, once it
   has arrived.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: story (Game.init ()) draws nothing
   Complexity: O(length of the story)
*)

val help : unit -> unit
(**
   [help ()] draws the key reminder at the bottom right, built from
   {!Controls.bindings}.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: help () shows "C clear   S save   N story   M menu"
   Complexity: O(b), b bindings
*)
