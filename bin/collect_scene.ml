(**
   File: collect_scene.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Collect_scene module: the collect-mode screen
                glue - Controls -> Collect -> Collect_view, saving progress after each
                verdict.
   Usage: The contract is in collect_scene.mli.
          Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

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
   [unlocks_path ctx] is where cases and unlocked packs are saved.
   Requires: nothing
   Returns: <data folder>/unlocks.csv
   Raises: nothing
   Example: unlocks_path ctx = "data/unlocks.csv"
   Complexity: O(1)
   Pseudocode:
     return Filename.concat (Scene.data_dir ctx) Inventory.unlocks_file
*)
let unlocks_path ctx = Filename.concat (Scene.data_dir ctx) Inventory.unlocks_file

(**
   [init ctx] enters collect mode with saved progress and unlocked packs.
   Requires: nothing (no figures means the mode opens on Complete)
   Returns: Collect.init of the loaded collection and a fresh roaster whose
            pools include the unlocked insult packs
   Raises: nothing
   Example: Collect.phase (init ctx) = Collect.Prompt
   Complexity: O(n + F)
   Pseudocode:
     c <- Collection.load (Scene.figures ctx) (progress_path ctx)
     inv <- Inventory.load (unlocks_path ctx)
     return Collect.init c (Roast.create ~seed:(current time)
                              ~extra_insults:(lines of unlocked packs)
                              ~extra_disses:(final disses of unlocked packs) ())
*)
let init ctx =
  let c = Collection.load (Scene.figures ctx) (progress_path ctx) in
  let inv = Inventory.load (unlocks_path ctx) in
  Collect.init c
    (Roast.create ~seed:(int_of_float (Unix.time ())) ~extra_insults:(Inventory.extra_insults inv)
       ~extra_disses:(Inventory.extra_disses inv) ())

(**
   [bank_cases ctx n] adds [n] earned cases to the saved inventory.
   Requires: [n >= 0]
   Returns: unit
   Raises: nothing (a failed save is ignored: the cases are just not kept)
   Example: bank_cases ctx 1 adds one case to data/unlocks.csv
   Complexity: O(F)
   Pseudocode:
     if n > 0 then save (add_cases n (load unlocks file)) to the unlocks file
     (load-modify-save, so the case screen's own changes are never overwritten)
*)
let bank_cases ctx n =
  if n > 0 then
    try Inventory.save (unlocks_path ctx) (Inventory.add_cases n (Inventory.load (unlocks_path ctx)))
    with Sys_error _ -> ()

(**
   [update ctx inp t] is one frame of collect mode.
   Requires: nothing
   Returns: Goto "welcome", Goto "cases" after Enter on the win screen,
            Quit after the final diss, else Continue
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
       bank_cases ctx (cases earned this frame, from Collect.take_earned_cases)
       if Collect.wants_quit t then Quit
       else if Collect.wants_cases t then Goto "cases"
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
    let t, earned = Collect.take_earned_cases t in
    bank_cases ctx earned;
    if Collect.wants_quit t then Scene.Quit
    else if Collect.wants_cases t then Scene.Goto Title.cases_scene
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
