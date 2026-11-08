(* PLANNED (welcome page): stub implementation. The interface in
   title.mli is the contract; replace each [todo] with the real code.
   See docs/WELCOME_PLAN.md. *)

type action =
  | Start_collect
  | Free_draw
  | How_to_play
  | Reset_progress
  | Quit_game
  | Confirm_yes
  | Confirm_no

type page = Main | Help | Confirm_reset
type summary = { collected : int; total : int; best_average : float option }
type outcome = Stay | Go of string | Quit | Reset

type t = {
  page : page;
  main : action Menu.t;
  confirm : action Menu.t;
  summary : summary option;
  elapsed : float;
  attract : Attract.t;
}

let collect_scene = "collect"
let free_draw_scene = "play"

let help_lines =
  [ "Draw the constellation named at the top, from memory.";
    Printf.sprintf "Your drawing is scored like drawtheperfectcircle.com: %s to %s."
      (Accuracy.format 0.) (Accuracy.format 100.);
    Printf.sprintf "Score %s or more to collect a constellation." (Accuracy.format Accuracy.pass_mark);
    "94%+ Near Perfect   90%+ Incredible   81%+ Amazing   72%+ Great";
    Printf.sprintf "Under %s earns a strike, and an insult." (Accuracy.format Accuracy.pass_mark);
    Printf.sprintf "%d strikes in total and the game closes." Roast.max_strikes;
    "Collect every constellation to win. Progress is saved." ]

let todo what = failwith ("Title." ^ what ^ ": not implemented yet (see title.mli)")

(**
   [main_items s] is the main menu.
   Requires: nothing
   Returns: five items
   Raises: nothing
   Example: detail of the first item = Some "3 / 7 collected"
   Complexity: O(1)
   Pseudocode:
     [ Collect (detail "k / n collected" from s) ; Free draw ; How to play ;
       Reset progress (enabled only when s has collected > 0) ; Quit ]
*)
let main_items (_ : summary option) : action Menu.item list = todo "main_items"

(**
   [init figures s] opens the main menu.
   Requires: nothing
   Returns: state on Main
   Raises: nothing
   Example: page (init figures None) = Main
   Complexity: O(n)
   Pseudocode:
     main <- Menu.create (main_items s)
     confirm <- Menu.create [No (Confirm_no); Yes, reset (Confirm_yes)]   (No first)
     return { Main; main; confirm; s; elapsed = 0; Attract.create figures }
*)
let init (_ : Asterism.t array) (_ : summary option) : t = todo "init"

(**
   [update inp t] is one frame.
   Requires: nothing
   Returns: new state and outcome
   Raises: nothing
   Example: snd (update { inp with keys = [Enter] } (init f s)) = Go "collect"
   Complexity: O(n)
   Pseudocode:
     t <- { t with elapsed += dt; attract = Attract.step dt }
     match page with
       | Help -> if any key or click then (page Main, Stay) else (t, Stay)
       | Main | Confirm_reset ->
           if Escape and page = Confirm_reset then (page Main, Stay)
           cmds <- Menu.read inp ; rects <- Menu.layout menu (inp size)
           fold Menu.apply over cmds, stop at the first chosen action
           Start_collect  -> Go collect_scene
           Free_draw      -> Go free_draw_scene
           How_to_play    -> page Help, Stay
           Reset_progress -> page Confirm_reset, Stay
           Quit_game      -> Quit
           Confirm_yes    -> Reset
           Confirm_no     -> page Main, Stay
*)
let update (_ : Scene.input) (_ : t) : t * outcome = todo "update"

(**
   [after_reset t] clears the summary after a reset.
   Requires: Reset handled
   Returns: Main page, zero progress
   Raises: nothing
   Example: page (after_reset t) = Main
   Complexity: O(1)
   Pseudocode:
     s <- summary with collected = 0, best_average = None
     return { t with page = Main; summary = s; main = Menu.create (main_items s) }
*)
let after_reset (_ : t) : t = todo "after_reset"

(**
   [page t] is the page.
   Requires: nothing
   Returns: t.page
   Raises: nothing
   Example: page (init figures None) = Main
   Complexity: O(1)
   Pseudocode:
     return t.page
*)
let page t = t.page

(**
   [menu t] is the current page's menu.
   Requires: nothing
   Returns: confirm menu on Confirm_reset, else main
   Raises: nothing
   Example: List.length (Menu.items (menu (init f None))) = 5
   Complexity: O(1)
   Pseudocode:
     if page = Confirm_reset then t.confirm else t.main
*)
let menu t = match t.page with Confirm_reset -> t.confirm | Main | Help -> t.main

(**
   [summary t] is the progress summary.
   Requires: nothing
   Returns: t.summary
   Raises: nothing
   Example: summary (init f None) = None
   Complexity: O(1)
   Pseudocode:
     return t.summary
*)
let summary t = t.summary

(**
   [elapsed t] is time on the page.
   Requires: nothing
   Returns: t.elapsed
   Raises: nothing
   Example: elapsed (init f None) = 0.
   Complexity: O(1)
   Pseudocode:
     return t.elapsed
*)
let elapsed t = t.elapsed

(**
   [attract t] is the animation.
   Requires: nothing
   Returns: t.attract
   Raises: nothing
   Example: Attract.current (attract (init [||] None)) = None
   Complexity: O(1)
   Pseudocode:
     return t.attract
*)
let attract t = t.attract
