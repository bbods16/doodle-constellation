(* Drawing of the game state. See play_view.mli for the public contract. *)

open Raylib

let card_path = "doodle_card.png"

(**
   [right_aligned text y size colour] draws [text] 20 px from the right edge.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: right_aligned "hi" 20 20 Color.white
   Complexity: O(length of text)
   Pseudocode:
     x <- screen width - 20 - measure_text text size
     draw_text text x y size colour
*)
let right_aligned text y size colour =
  draw_text text (get_screen_width () - 20 - measure_text text size) y size colour

(**
   [sky ctx g] draws the stars and the match.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: sky ctx (Game.init ()) draws the default wide view
   Complexity: O(N)
   Pseudocode:
     view <- g.view, or Projection.empty_view for the window size
     Sky.draw view (Game.current_fit g)
*)
let sky (ctx : Scene.ctx) (g : Game.t) =
  let view =
    match Game.view g with
    | Some v -> v
    | None -> Projection.empty_view (Scene.stars ctx) ~width:(get_screen_width ()) ~height:(get_screen_height ())
  in
  Sky.draw view (Game.current_fit g)

(**
   [stroke g] draws the stroke as it currently looks.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: stroke (Game.init ()) draws nothing
   Complexity: O(s)
   Pseudocode:
     Sky.draw_stroke (Game.visible_stroke g)
*)
let stroke g = Sky.draw_stroke (Game.visible_stroke g)

(**
   [status g] draws the prompt or the refusal reason.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: status (Game.init ()) shows "Draw a shape with 5 to 9 corners"
   Complexity: O(1)
   Pseudocode:
     Drawing  -> prompt in light grey
     Hint msg -> msg in gold
     otherwise nothing
*)
let status (g : Game.t) =
  match Game.stage g with
  | Drawing -> draw_text "Draw a shape with 5 to 9 corners" 20 20 20 Color.lightgray
  | Hint msg -> draw_text msg 20 20 20 Color.gold
  | Morphing _ | Showing _ -> ()

(**
   [fit_info g] draws the fit summary after the morph.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: fit_info (Game.init ()) draws nothing
   Complexity: O(1)
   Pseudocode:
     if stage = Showing (_, f) then Sky.draw_info ~fit:f ~best:(Game.best_view g)
*)
let fit_info (g : Game.t) =
  match Game.stage g with
  | Showing (_, f) -> Sky.draw_info ~fit:f ~best:(Game.best_view g)
  | Drawing | Hint _ | Morphing _ -> ()

(**
   [engine_badge g] draws the engine's guess.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: engine_badge g shows "Engine: Big Dipper (99%)"
   Complexity: O(1)
   Pseudocode:
     match Game.guess g with
       | None -> ()
       | Some ("none", _) -> "Engine: no known figure"
       | Some (cls, p) -> "Engine: <cls> (<p as %>)"
     right-aligned at the top in sky blue
*)
let engine_badge (g : Game.t) =
  match Game.guess g with
  | None -> ()
  | Some (cls, p) ->
      let label =
        if cls = Engine.none_label then "Engine: no known figure"
        else Printf.sprintf "Engine: %s (%.0f%%)" cls (100. *. p)
      in
      right_aligned label 20 20 Color.skyblue

(**
   [story g] draws the story once it has arrived.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: story (Game.init ()) draws nothing
   Complexity: O(length of the story)
   Pseudocode:
     match Game.story g with
       | Some s -> draw s, then Narrate.fiction_label underneath
       | None -> ()
*)
let story (g : Game.t) =
  match Game.story g with
  | Some s ->
      draw_text s 20 60 18 Color.raywhite;
      draw_text Narrate.fiction_label 20 84 14 Color.gray
  | None -> ()

(**
   [help ()] draws the key reminder.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: help () shows "C clear   S save   N story   M menu"
   Complexity: O(b)
   Pseudocode:
     for each (Letter k, command) in Controls.bindings: "<K> <word for command>"
     join with three spaces ; right-aligned at the bottom in grey
*)
let help () =
  let word = function
    | Controls.Clear -> "clear"
    | Save_card -> "save"
    | Ask_story -> "story"
    | Open_menu -> "menu"
    | Pen_down _ | Pen_up -> ""
  in
  let entry (k, c) =
    match k with
    | Scene.Letter ch -> Printf.sprintf "%c %s" (Char.uppercase_ascii ch) (word c)
    | _ -> word c
  in
  let letters = List.filter (function Scene.Letter _, _ -> true | _ -> false) Controls.bindings in
  let text = String.concat "   " (List.map entry letters) in
  right_aligned text (get_screen_height () - 30) 16 Color.gray

(**
   [draw ctx g] paints all layers back to front.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx (Game.init ()) shows the blank sky and the prompt
   Complexity: O(N + s)
   Pseudocode:
     sky ; stroke ; status ; fit_info ; engine_badge ; story ; help
*)
let draw ctx g =
  sky ctx g;
  stroke g;
  status g;
  fit_info g;
  engine_badge g;
  story g;
  help ()
