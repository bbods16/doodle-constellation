(**
   File: title_view.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Title_view module: draws the welcome page -
                background, animation, title, menu, help page, reset dialog and
                footer.
   Usage: The contract is in title_view.mli.
          Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(* Drawing of the welcome page. See title_view.mli for the contract. *)

open Raylib

let text_colour = Color.create 200 210 230 255
let dim_colour = Color.create 110 120 140 255
let line_colour = Color.create 120 190 255 255
let panel_colour = Color.create 20 26 52 255
let selected_colour = Color.create 40 60 120 255

(**
   [centred text y size colour] draws [text] centred horizontally.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: centred "Doodle Constellation" 100 56 Color.raywhite
   Complexity: O(length of text)
   Pseudocode:
     draw_text text ((screen width - measure_text text size) / 2) y size colour
*)
let centred text y size colour =
  draw_text text ((get_screen_width () - measure_text text size) / 2) y size colour

(**
   [background ctx] draws the starfield.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: background ctx
   Complexity: O(N)
   Pseudocode:
     Sky.draw (Projection.empty_view (Scene.stars ctx) window size) None
*)
let background ctx =
  Sky.draw
    (Projection.empty_view (Scene.stars ctx) ~width:(get_screen_width ()) ~height:(get_screen_height ()))
    None

(**
   [attract t] draws the self-drawing figure.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: attract t
   Complexity: O(k)
   Pseudocode:
     a <- Title.attract t ; box <- top-left 300 x 220 area
     faint dots at Attract.star_points a ~box
     line through Attract.visible_path a ~box, faded by Attract.alpha a
     figure name under the box
*)
let attract t =
  let a = Title.attract t in
  match Attract.current a with
  | None -> ()
  | Some (f, _) ->
      let box = { Menu.x = 30.; y = 30.; w = 300.; h = 220. } in
      let alpha = Attract.alpha a in
      Array.iter
        (fun p -> draw_circle_v (Sky.to_vector2 p) 4. (fade Color.raywhite (0.6 *. alpha)))
        (Attract.star_points a ~box);
      let path = Attract.visible_path a ~box in
      for i = 1 to Array.length path - 1 do
        draw_line_ex (Sky.to_vector2 path.(i - 1)) (Sky.to_vector2 path.(i)) 2.5
          (fade line_colour alpha)
      done;
      draw_text (Asterism.name f) 40 258 20 (fade text_colour alpha)

(**
   [title t] draws the name and tagline.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: title t shows "Doodle Constellation"
   Complexity: O(1)
   Pseudocode:
     "Doodle Constellation" size 56 centred at height * 0.14
     tagline size 24 underneath, alpha 0.8 + 0.2 sin (2 elapsed)
*)
let title t =
  let y = int_of_float (float_of_int (get_screen_height ()) *. 0.14) in
  centred "Doodle Constellation" y 56 Color.raywhite;
  let pulse = 0.8 +. (0.2 *. sin (2. *. Title.elapsed t)) in
  centred "Draw a shape. Find it in the stars." (y + 70) 24 (fade Color.skyblue pulse)

(**
   [menu_buttons t] draws the current menu.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: menu_buttons t shows "> Collect the constellations" selected
   Complexity: O(n)
   Pseudocode:
     m <- Title.menu t ; rects <- Menu.layout m (window size)
     for each item i with rect r:
       panel: highlighted if i = selected, dim if disabled
       label (with "> " when selected) ; detail line underneath if any
*)
let menu_buttons t =
  let m = Title.menu t in
  let rects = Menu.layout m ~width:(get_screen_width ()) ~height:(get_screen_height ()) in
  List.iteri
    (fun i (item : Title.action Menu.item) ->
      let r = rects.(i) in
      let selected = i = Menu.selected_index m in
      let rect = Rectangle.create r.x r.y r.w r.h in
      draw_rectangle_rounded rect 0.3 8 (fade (if selected then selected_colour else panel_colour) 0.85);
      if selected then draw_rectangle_rounded_lines rect 0.3 8 Color.skyblue;
      let colour = if not item.enabled then dim_colour else if selected then Color.raywhite else text_colour in
      let label = (if selected then "> " else "  ") ^ item.label in
      let x = int_of_float r.x + 20 in
      match item.detail with
      | Some d ->
          draw_text label x (int_of_float r.y + 8) 22 colour;
          draw_text d (x + 26) (int_of_float r.y + 34) 16 (if item.enabled then Color.gold else dim_colour)
      | None -> draw_text label x (int_of_float r.y + 18) 22 colour)
    (Menu.items m)

(**
   [help_page t] draws the rules.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: help_page t
   Complexity: O(lines)
   Pseudocode:
     panel in the middle ; "How to play" heading
     one line per Title.help_lines ; "Press any key to go back"
*)
let help_page (_ : Title.t) =
  let w = get_screen_width () and h = get_screen_height () in
  let n = List.length Title.help_lines in
  let pw = min (w - 80) 900 and ph = 130 + (n * 34) in
  let px = (w - pw) / 2 and py = max 20 ((h - ph) / 2 + 60) in
  draw_rectangle_rounded
    (Rectangle.create (float_of_int px) (float_of_int py) (float_of_int pw) (float_of_int ph))
    0.08 8 (fade panel_colour 0.92);
  centred "How to play" (py + 20) 34 Color.raywhite;
  List.iteri (fun i line -> draw_text line (px + 30) (py + 74 + (i * 34)) 20 text_colour) Title.help_lines;
  centred "Press any key to go back" (py + ph - 34) 18 dim_colour

(**
   [confirm_dialog t] draws the reset confirmation.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: confirm_dialog t
   Complexity: O(1)
   Pseudocode:
     translucent black over the page ; question and warning text
     menu_buttons t (the confirm menu: No, Yes)
*)
let confirm_dialog t =
  let w = get_screen_width () and h = get_screen_height () in
  draw_rectangle 0 0 w h (fade Color.black 0.6);
  let y = int_of_float (float_of_int h *. 0.26) in
  centred "Reset all progress?" y 40 Color.raywhite;
  centred "This deletes your collected constellations and best scores." (y + 56) 20 text_colour;
  menu_buttons t

(**
   [footer ctx] draws hints and engine status.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: footer ctx shows "engine: ready (7 figures)"
   Complexity: O(1)
   Pseudocode:
     left: "Up/Down or mouse to choose - Enter to select - Esc twice to quit"
     right: match Scene.engine ctx with Some m -> "engine: ready (n figures)"
                                      | None -> "engine: not loaded"
*)
let footer ctx =
  let w = get_screen_width () and h = get_screen_height () in
  draw_text "Up/Down or mouse to choose - Enter to select - Esc twice to quit" 20 (h - 30) 16 dim_colour;
  let status =
    match Scene.engine ctx with
    | Some m -> Printf.sprintf "engine: ready (%d figures)" (Array.length (Engine.classes m) - 1)
    | None -> "engine: not loaded"
  in
  draw_text status (w - 20 - measure_text status 16) (h - 30) 16 dim_colour

(**
   [draw ctx t] paints the page.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: O(N + k + n)
   Pseudocode:
     background ; attract ; title
     match page: Main -> menu_buttons | Help -> help_page
                | Confirm_reset -> confirm_dialog (which redraws the No / Yes menu)
     footer
*)
let draw ctx t =
  background ctx;
  attract t;
  title t;
  (match Title.page t with
  | Title.Main -> menu_buttons t
  | Title.Help -> help_page t
  | Title.Confirm_reset -> confirm_dialog t);
  footer ctx
