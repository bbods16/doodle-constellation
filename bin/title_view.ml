(* PLANNED (welcome page): stub implementation. The interface in
   title_view.mli is the contract; replace each [todo] with the real code.
   See docs/WELCOME_PLAN.md. *)

let todo what = failwith ("Title_view." ^ what ^ ": not implemented yet (see title_view.mli)")

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
let background (_ : Scene.ctx) : unit = todo "background"

(**
   [attract t] draws the self-drawing figure.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: attract t
   Complexity: O(k)
   Pseudocode:
     a <- Title.attract t ; box <- upper-left third of the window
     faint dots at Attract.star_points a ~box
     line through Attract.visible_path a ~box, faded by Attract.alpha a
     figure name under the box
*)
let attract (_ : Title.t) : unit = todo "attract"

(**
   [title t] draws the name and tagline.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: title t shows "Doodle Constellation"
   Complexity: O(1)
   Pseudocode:
     "Doodle Constellation" size 56 centred at height/5
     tagline size 24 underneath, alpha 0.8 + 0.2 sin (2 elapsed)
*)
let title (_ : Title.t) : unit = todo "title"

(**
   [menu_buttons t] draws the current menu.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: menu_buttons t shows "▸ Collect the constellations" selected
   Complexity: O(n)
   Pseudocode:
     m <- Title.menu t ; rects <- Menu.layout m (window size)
     for each item i with rect r:
       panel: highlighted if i = selected, dim if disabled
       label (with "▸ " when selected) ; detail line underneath if any
*)
let menu_buttons (_ : Title.t) : unit = todo "menu_buttons"

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
let help_page (_ : Title.t) : unit = todo "help_page"

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
let confirm_dialog (_ : Title.t) : unit = todo "confirm_dialog"

(**
   [footer ctx] draws hints and engine status.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: footer ctx shows "engine: ready (7 figures)"
   Complexity: O(1)
   Pseudocode:
     left: "↑↓ / mouse to choose · Enter to select"
     right: match Scene.engine ctx with Some m -> "engine: ready (n figures)"
                                      | None -> "engine: not loaded"
*)
let footer (_ : Scene.ctx) : unit = todo "footer"

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
                | Confirm_reset -> menu_buttons of main, then confirm_dialog
     footer
*)
let draw (ctx : Scene.ctx) (t : Title.t) =
  background ctx;
  attract t;
  title t;
  (match Title.page t with
  | Title.Main -> menu_buttons t
  | Title.Help -> help_page t
  | Title.Confirm_reset -> confirm_dialog t);
  footer ctx
