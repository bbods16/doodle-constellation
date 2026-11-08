(**
   File: cases_scene.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Cases_scene module: the case screen glue -
                Controls -> Case_opening -> Cases_view, saving the inventory after
                each case.
   Usage: The contract is in cases_scene.mli.
          Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(* The case screen: glue between Controls, Case_opening, Cases_view and the
   unlocks file. See cases_scene.mli for the contract. *)

type t = Case_opening.t

let name = "cases"

(**
   [unlocks_path ctx] is where the inventory is saved.
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
   [init ctx] opens the case screen with the saved inventory.
   Requires: nothing
   Returns: Case_opening.init of the loaded inventory
   Raises: nothing
   Example: Case_opening.phase (init ctx) = Case_opening.Idle
   Complexity: O(F)
   Pseudocode:
     return Case_opening.init (Inventory.load (unlocks_path ctx))
*)
let init ctx = Case_opening.init (Inventory.load (unlocks_path ctx))

(**
   [update ctx inp t] is one frame of the case screen.
   Requires: nothing
   Returns: Goto "welcome" on M / Escape, else Continue
   Raises: nothing (a failed save is ignored)
   Example: update ctx { inp with keys = [Escape] } t = Goto "welcome"
   Complexity: per frame, Case_opening.apply / tick
   Pseudocode:
     cmds <- Controls.read inp
     if Open_menu in cmds then Goto "welcome"
     else
       t <- fold Case_opening.apply t cmds |> Case_opening.tick inp.dt
       (t, save) <- Case_opening.take_save_request t
       if save = Some inv then Inventory.save (unlocks_path ctx) inv
       Continue (t, [])
*)
let update ctx (inp : Scene.input) t =
  let cmds = Controls.read inp in
  if List.mem Controls.Open_menu cmds then Scene.Goto "welcome"
  else begin
    let t = List.fold_left Case_opening.apply t cmds |> Case_opening.tick inp.dt in
    let t, save = Case_opening.take_save_request t in
    (match save with
    | Some inv -> ( try Inventory.save (unlocks_path ctx) inv with Sys_error _ -> ())
    | None -> ());
    Scene.Continue (t, [])
  end

(**
   [draw ctx t] hands the state to the view.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: see Cases_view.draw
   Pseudocode:
     Cases_view.draw ctx t
*)
let draw = Cases_view.draw
