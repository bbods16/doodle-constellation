(* The welcome page as a screen: glue between Title, Title_view and the
   saved progress. See welcome.mli for the contract. *)

type t = Title.t

let name = "welcome"

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
   [summary_of c] is the progress line shown under the Collect button.
   Requires: nothing
   Returns: [None] when there are no figures; otherwise collected count,
            total, and the mean best score over attempted figures
   Raises: nothing
   Example: summary_of (Collection.create figures) = Some { collected = 0; total = 7; best_average = None }
   Complexity: O(n)
   Pseudocode:
     if total c = 0 then None
     bests <- best score of each attempted figure
     Some { collected_count c; total c; mean bests (None if no attempts) }
*)
let summary_of c =
  if Collection.total c = 0 then None
  else begin
    let bests =
      Array.to_list (Collection.figures c)
      |> List.filter_map (fun f -> Collection.best c (Asterism.name f))
    in
    let best_average =
      if bests = [] then None
      else Some (List.fold_left ( +. ) 0. bests /. float_of_int (List.length bests))
    in
    Some { Title.collected = Collection.collected_count c; total = Collection.total c; best_average }
  end

(**
   [init ctx] opens the welcome page with the saved progress.
   Requires: nothing
   Returns: Title.init on the figures and their progress summary
   Raises: nothing
   Example: Title.page (init ctx) = Title.Main
   Complexity: O(n + F)
   Pseudocode:
     figures <- Scene.figures ctx
     return Title.init figures (summary_of (Collection.load figures (progress_path ctx)))
*)
let init ctx =
  let figures = Scene.figures ctx in
  Title.init figures (summary_of (Collection.load figures (progress_path ctx)))

(**
   [update ctx inp t] is one frame of the welcome page.
   Requires: nothing
   Returns: Continue, Goto a scene, or Quit, as Title decides
   Raises: nothing
   Example: update ctx { inp with keys = [Enter] } t = Goto "collect"
   Complexity: Title.update
   Pseudocode:
     match Title.update inp t with
       | t, Stay -> Continue (t, [])
       | _, Go scene -> Goto scene
       | _, Quit -> Quit
       | t, Reset -> delete the progress file ; Continue (Title.after_reset t, [])
*)
let update ctx (inp : Scene.input) t =
  match Title.update inp t with
  | t, Title.Stay -> Scene.Continue (t, [])
  | _, Title.Go scene -> Scene.Goto scene
  | _, Title.Quit -> Scene.Quit
  | t, Title.Reset ->
      (try Sys.remove (progress_path ctx) with Sys_error _ -> ());
      Scene.Continue (Title.after_reset t, [])

(**
   [draw ctx t] hands the state to the view.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: see Title_view.draw
   Pseudocode:
     Title_view.draw ctx t
*)
let draw = Title_view.draw
