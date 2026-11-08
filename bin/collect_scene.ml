(* Collect mode as a screen: glue between Controls, Collect, Collect_view
   and the progress file. See collect_scene.mli for the contract. *)

type t = Collect.t

let name = "collect"

(**
   [progress_path ctx] is where collect mode saves progress.
   Requires: nothing
   Returns: <data folder>/progress.csv
   Raises: nothing
   Example: progress_path ctx = "data/progress.csv"
   Complexity: O(1)
   Pseudocode:
     return Filename.concat (Scene.data_dir ctx) Collect.progress_file
*)
let progress_path ctx = Filename.concat (Scene.data_dir ctx) Collect.progress_file

(**
   [init ctx] enters collect mode with saved progress.
   Requires: nothing (no figures means the mode opens on Complete)
   Returns: Collect.init of the loaded collection and a fresh roaster
   Raises: nothing
   Example: Collect.phase (init ctx) = Collect.Prompt
   Complexity: O(n + F)
   Pseudocode:
     c <- Collection.load (Scene.figures ctx) (progress_path ctx)
     return Collect.init c (Roast.create ~seed:(current time) ())
*)
let init ctx =
  let c = Collection.load (Scene.figures ctx) (progress_path ctx) in
  Collect.init c (Roast.create ~seed:(int_of_float (Unix.time ())) ())

(**
   [update ctx inp t] is one frame of collect mode.
   Requires: nothing
   Returns: Goto "welcome", Quit after the final diss, else Continue
   Raises: nothing (a failed save is ignored: progress just isn't kept)
   Example: update ctx { inp with keys = [Letter 'm'] } t = Goto "welcome"
   Complexity: per frame, Collect.apply / tick
   Pseudocode:
     cmds <- Controls.read inp
     if Open_menu in cmds then Goto "welcome"
     else
       t <- fold Collect.apply t cmds |> Collect.tick inp.dt
       (t, save) <- Collect.take_save_request t
       if save = Some c then Collection.save (progress_path ctx) c
       if Collect.wants_quit t then Quit
       else Continue (t, [Screenshot] if Save_card in cmds)
*)
let update ctx (inp : Scene.input) t =
  let cmds = Controls.read inp in
  if List.mem Controls.Open_menu cmds then Scene.Goto "welcome"
  else begin
    let t = List.fold_left Collect.apply t cmds |> Collect.tick inp.dt in
    let t, save = Collect.take_save_request t in
    (match save with
    | Some c -> ( try Collection.save (progress_path ctx) c with Sys_error _ -> ())
    | None -> ());
    if Collect.wants_quit t then Scene.Quit
    else
      Scene.Continue
        (t, if List.mem Controls.Save_card cmds then [ Scene.Screenshot "doodle_card.png" ] else [])
  end

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
