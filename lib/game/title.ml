(* The welcome page's rules. See title.mli for the contract. *)

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
  last_mouse : Geom.pt option;  (* hover only reselects when the mouse moves *)
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

(**
   [main_items s] is the main menu.
   Requires: nothing
   Returns: five items
   Raises: nothing
   Example: detail of the first item = Some "3 / 7 collected"
   Complexity: O(1)
   Pseudocode:
     [ Collect (enabled when there are figures; detail "k / n collected",
                plus " - avg best x%" once attempted) ;
       Free draw ; How to play ;
       Reset progress (enabled only when something was attempted) ; Quit ]
*)
let main_items s =
  let detail =
    Option.map
      (fun s ->
        Printf.sprintf "%d / %d collected%s" s.collected s.total
          (match s.best_average with
          | Some b -> " - avg best " ^ Accuracy.format b
          | None -> ""))
      s
  in
  let item ?(detail = None) ?(enabled = true) label action = { Menu.label; detail; action; enabled } in
  let has_figures = match s with Some s -> s.total > 0 | None -> false in
  let attempted = match s with Some { best_average = Some _; _ } -> true | _ -> false in
  [ item ~detail ~enabled:has_figures "Collect the constellations" Start_collect;
    item "Free draw" Free_draw;
    item "How to play" How_to_play;
    item ~enabled:attempted "Reset progress" Reset_progress;
    item "Quit" Quit_game ]

(**
   [confirm_menu ()] is the No / Yes menu, No selected first.
   Requires: nothing
   Returns: the menu
   Raises: nothing
   Example: Menu.selected_index (confirm_menu ()) = 0
   Complexity: O(1)
   Pseudocode:
     Menu.create [No -> Confirm_no ; Yes, reset -> Confirm_yes]
*)
let confirm_menu () =
  Menu.create
    [ { Menu.label = "No, keep my progress"; detail = None; action = Confirm_no; enabled = true };
      { Menu.label = "Yes, reset everything"; detail = None; action = Confirm_yes; enabled = true } ]

(**
   [init figures s] opens the main menu.
   Requires: nothing
   Returns: state on Main
   Raises: nothing
   Example: page (init figures None) = Main
   Complexity: O(n)
   Pseudocode:
     return { Main; Menu.create (main_items s); confirm_menu (); s; elapsed = 0;
              Attract.create figures; no mouse yet }
*)
let init figures s =
  { page = Main; main = Menu.create (main_items s); confirm = confirm_menu (); summary = s;
    elapsed = 0.; attract = Attract.create figures; last_mouse = None }

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
   [with_menu t m] stores [m] as the current page's menu.
   Requires: nothing
   Returns: updated state
   Raises: nothing
   Example: menu (with_menu t m) == m
   Complexity: O(1)
   Pseudocode:
     if page = Confirm_reset then { t with confirm = m } else { t with main = m }
*)
let with_menu t m = match t.page with Confirm_reset -> { t with confirm = m } | Main | Help -> { t with main = m }

(**
   [act t a] turns a chosen action into a page change or outcome.
   Requires: nothing
   Returns: new state and outcome
   Raises: nothing
   Example: snd (act t Start_collect) = Go "collect"
   Complexity: O(1)
   Pseudocode:
     Start_collect -> Go collect_scene ; Free_draw -> Go free_draw_scene
     How_to_play -> Help ; Reset_progress -> Confirm_reset (No selected)
     Quit_game -> Quit ; Confirm_yes -> Reset ; Confirm_no -> Main
*)
let act t = function
  | Start_collect -> (t, Go collect_scene)
  | Free_draw -> (t, Go free_draw_scene)
  | How_to_play -> ({ t with page = Help }, Stay)
  | Reset_progress -> ({ t with page = Confirm_reset; confirm = confirm_menu () }, Stay)
  | Quit_game -> (t, Quit)
  | Confirm_yes -> (t, Reset)
  | Confirm_no -> ({ t with page = Main }, Stay)

(**
   [update inp t] is one frame.
   Requires: nothing
   Returns: new state and outcome
   Raises: nothing
   Example: snd (update { inp with keys = [Enter] } (init f s)) = Go "collect"
   Complexity: O(n)
   Pseudocode:
     t <- { t with elapsed += dt; attract = Attract.step dt }
     moved <- mouse differs from last frame ; remember it
     match page with
       | Help -> back to Main on any key or click
       | Main when Escape -> Quit
       | Confirm_reset when Escape -> Main
       | Main | Confirm_reset ->
           cmds <- Menu.read inp (dropping Point unless the mouse moved)
           rects <- Menu.layout (menu t) (window size)
           apply the commands in order; the first chosen action goes to act
*)
let update (inp : Scene.input) t =
  let moved = match t.last_mouse with Some m -> m <> inp.mouse | None -> true in
  let t =
    { t with elapsed = t.elapsed +. inp.dt; attract = Attract.step inp.dt t.attract;
      last_mouse = Some inp.mouse }
  in
  match t.page with
  | Help -> if inp.keys <> [] || inp.mouse_pressed then ({ t with page = Main }, Stay) else (t, Stay)
  | Main when Scene.pressed inp Scene.Escape -> (t, Quit)
  | Confirm_reset when Scene.pressed inp Scene.Escape -> ({ t with page = Main }, Stay)
  | Main | Confirm_reset ->
      let cmds =
        List.filter (function Menu.Point _ -> moved | _ -> true) (Menu.read inp)
      in
      let rects = Menu.layout (menu t) ~width:inp.width ~height:inp.height in
      let rec go m = function
        | [] -> (with_menu t m, Stay)
        | c :: rest -> (
            match Menu.apply m ~rects c with
            | m, Some a -> act (with_menu t m) a
            | m, None -> go m rest)
      in
      go (menu t) cmds

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
let after_reset t =
  let s = Option.map (fun s -> { s with collected = 0; best_average = None }) t.summary in
  { t with page = Main; summary = s; main = Menu.create (main_items s) }

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
