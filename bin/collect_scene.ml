(* PLANNED (collect mode): stub implementation. The interface in
   collect_scene.mli is the contract; replace each [todo] with the real
   code, then add (module Collect_scene) to [scenes] in main.ml.
   See docs/COLLECT_PLAN.md. *)

type t = Collect.t

let name = "collect"

let todo what = failwith ("Collect_scene." ^ what ^ ": not implemented yet (see collect_scene.mli)")

(**
   [init ctx] enters collect mode with saved progress.
   Requires: the context carries the figures and data folder (see the
             Scene.ctx change in docs/COLLECT_PLAN.md)
   Returns: Collect.init of the loaded collection and a fresh roaster
   Raises: nothing
   Example: Collect.phase (init ctx) = Collect.Prompt
   Complexity: O(n + F)
   Pseudocode:
     figures <- Scene.figures ctx
     c <- Collection.load figures (data folder / Collect.progress_file)
     return Collect.init c (Roast.create ~seed:(time-based) ())
*)
let init (_ : Scene.ctx) : t = todo "init"

(**
   [update ctx inp t] is one frame of collect mode.
   Requires: nothing
   Returns: Goto "welcome", Quit after the final diss, else Continue
   Raises: Sys_error only if saving progress fails
   Example: update ctx { inp with keys = [Letter 'm'] } t = Goto "welcome"
   Complexity: per frame, Collect.apply / tick
   Pseudocode:
     cmds <- Controls.read inp
     if Open_menu in cmds then Goto "welcome"
     else
       t <- fold Collect.apply t cmds |> Collect.tick inp.dt
       (t, save) <- Collect.take_save_request t
       if save = Some c then Collection.save (data folder / progress_file) c
       if Collect.wants_quit t then Quit
       else Continue (t, [Screenshot] if Save_card in cmds)
*)
let update (_ : Scene.ctx) (_ : Scene.input) (_ : t) : t Scene.outcome = todo "update"

(**
   [draw ctx t] hands the state to the view.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: see Collect_view.draw
   Pseudocode:
     Collect_view.draw ctx t
*)
let draw = Collect_view.draw
