(* Welcome screen scene. See welcome.mli for the public contract. *)

open Raylib

type t = { elapsed : float }  (* seconds on this screen, for the pulse *)

let name = "welcome"

(**
   [init ctx] starts the screen's clock.
   Requires: nothing
   Returns: [{ elapsed = 0. }]
   Raises: nothing
   Example: (init ctx).elapsed = 0.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return { elapsed = 0 }
*)
let init (_ : Scene.ctx) = { elapsed = 0. }

(**
   [update ctx inp t] waits for the player to start.
   Requires: nothing
   Returns: [Goto "play"] on a click, Enter or Space; [Quit] on Q;
            otherwise [Continue] with the clock advanced
   Raises: nothing
   Example: update ctx { inp with keys = [Enter] } t = Goto "play"
   Complexity: O(k) time, k = keys pressed this frame
   Pseudocode:
     if mouse pressed or Enter or Space then Goto "play"
     else if Q then Quit
     else Continue ({ elapsed = elapsed + dt }, [])
*)
let update (_ : Scene.ctx) (inp : Scene.input) t =
  if inp.mouse_pressed || Scene.pressed inp Scene.Enter || Scene.pressed inp Scene.Space then
    Scene.Goto "play"
  else if Scene.pressed inp (Scene.Letter 'q') then Scene.Quit
  else Scene.Continue ({ elapsed = t.elapsed +. inp.dt }, [])

(**
   [centred text y size colour] draws [text] centred horizontally.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: centred "Hello" 100 20 Color.white
   Complexity: O(length of text)
   Pseudocode:
     x <- (screen width - measure_text text size) / 2
     draw_text text x y size colour
*)
let centred text y size colour =
  draw_text text ((get_screen_width () - measure_text text size) / 2) y size colour

(**
   [draw ctx t] draws the starfield, title, instructions and a pulsing
   start prompt.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx (init ctx)
   Complexity: O(N) for the background stars
   Pseudocode:
     draw the catalogue with the default wide view
     title and subtitle centred in the upper third
     three instruction lines
     prompt with alpha 0.55 + 0.45 sin (3 elapsed)
     engine status: "ready (n figures)" or "not loaded"
*)
let draw (ctx : Scene.ctx) t =
  let w = get_screen_width () and h = get_screen_height () in
  Sky.draw (Sky.empty_view (Scene.stars ctx) ~width:w ~height:h) None;
  let top = h / 4 in
  centred "Doodle Constellation" top 56 Color.raywhite;
  centred "Draw a shape. Find it in the stars." (top + 70) 24 Color.skyblue;
  centred "Drag with the mouse to draw a shape with 5 to 9 corners." (top + 140) 20 Color.lightgray;
  centred "Your drawing is matched to real stars and morphed onto them." (top + 168) 20
    Color.lightgray;
  centred "C clear    S save card    N story    M back here" (top + 196) 20 Color.lightgray;
  let alpha = 0.55 +. (0.45 *. sin (3. *. t.elapsed)) in
  centred "Click or press Enter to start" (top + 270) 28 (fade Color.gold alpha);
  let status =
    match Scene.engine ctx with
    | Some m ->
        Printf.sprintf "Recognition engine ready (%d figures)" (Array.length (Engine.classes m) - 1)
    | None -> "Recognition engine not loaded (data/engine_weights.txt missing)"
  in
  centred status (h - 40) 16 Color.gray
