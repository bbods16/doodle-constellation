(**
   File: case_opening.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Case_opening module: the case screen's rules -
                open a case, spin the reel, reveal the pack.
   Usage: The contract is in case_opening.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Case_opening (or Case_opening with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* The case screen's rules. See case_opening.mli for the contract. *)

type phase = Idle | Spinning of Case.spin * float | Revealed of Case.spin

type t = {
  inv : Inventory.t;
  phase : phase;
  rng : Random.State.t;
  dirty : bool;         (* inventory changed since the last save request *)
  pressed_here : bool;  (* the mouse went down on this screen (so a release is a click) *)
}

(**
   [init ?seed inv] opens on Idle.
   Requires: nothing
   Returns: the state
   Raises: nothing
   Example: phase (init Inventory.empty) = Idle
   Complexity: O(1)
   Pseudocode:
     rng <- seeded with [seed] if given, else self-initialised
     return { inv; Idle; rng; not dirty; no press yet }
*)
let init ?seed inv =
  let rng =
    match seed with Some s -> Random.State.make [| s |] | None -> Random.State.make_self_init ()
  in
  { inv; phase = Idle; rng; dirty = false; pressed_here = false }

(**
   [open_one t] spends a case and starts the reel, if there is a case.
   Requires: phase = Idle
   Returns: Spinning with the pack unlocked, or t unchanged with no cases
   Raises: nothing
   Example: phase (open_one (init one_case)) = Spinning (_, 0.)
   Complexity: O(reel_length * packs)
   Pseudocode:
     match Inventory.spend_case inv with
       | None -> t
       | Some inv ->
           spin <- Case.open_case rng ~owned:(Inventory.owns inv)
           inv <- Inventory.unlock spin.won.id inv     (no-op for a duplicate)
           { t with inv; phase = Spinning (spin, 0); dirty = true }
*)
let open_one t =
  match Inventory.spend_case t.inv with
  | None -> t
  | Some inv ->
      let spin = Case.open_case t.rng ~owned:(Inventory.owns inv) in
      let inv = Inventory.unlock spin.won.id inv in
      { t with inv; phase = Spinning (spin, 0.); dirty = true }

(**
   [apply t cmd] handles one command.
   Requires: nothing
   Returns: new state
   Raises: nothing
   Example: phase (apply (init one_case) Controls.Dismiss) = Spinning (_, 0.)
   Complexity: see case_opening.mli
   Pseudocode:
     a click is a Pen_up after a Pen_down on this screen (so the click
     that opened the screen from the menu doesn't open a case)
     match phase, cmd with
       | _, Pen_down _ -> pressed_here <- true
       | _, Pen_up when not pressed_here -> t
       | Idle, (Dismiss | Pen_up) -> open_one t          (Pen_up clears pressed_here)
       | Revealed _, (Dismiss | Pen_up) -> Idle
       | _ -> t            (the reel can't be skipped)
*)
let apply t (cmd : Controls.command) =
  let click_or_enter = match cmd with Dismiss -> true | Pen_up -> t.pressed_here | _ -> false in
  let t = match cmd with Pen_down _ -> { t with pressed_here = true } | Pen_up -> { t with pressed_here = false } | _ -> t in
  match t.phase with
  | Idle when click_or_enter -> open_one t
  | Revealed _ when click_or_enter -> { t with phase = Idle }
  | Idle | Spinning _ | Revealed _ -> t

(**
   [tick dt t] advances the reel.
   Requires: dt >= 0
   Returns: advanced state
   Raises: nothing
   Example: phase (tick 10. spinning) = Revealed _
   Complexity: O(1)
   Pseudocode:
     Spinning (s, e) -> if Case.finished (e + dt) then Revealed s else Spinning (s, e + dt)
     other -> unchanged
*)
let tick dt t =
  match t.phase with
  | Spinning (s, e) ->
      let e = e +. dt in
      { t with phase = (if Case.finished e then Revealed s else Spinning (s, e)) }
  | Idle | Revealed _ -> t

(**
   [phase t] is the phase.
   Requires: nothing
   Returns: t.phase
   Raises: nothing
   Example: phase (init Inventory.empty) = Idle
   Complexity: O(1)
   Pseudocode:
     return t.phase
*)
let phase t = t.phase

(**
   [inventory t] is the inventory.
   Requires: nothing
   Returns: t.inv
   Raises: nothing
   Example: Inventory.cases (inventory (init inv)) = Inventory.cases inv
   Complexity: O(1)
   Pseudocode:
     return t.inv
*)
let inventory t = t.inv

(**
   [take_save_request t] returns the inventory to save, once per change.
   Requires: nothing
   Returns: (t with dirty cleared, Some inv if it was dirty)
   Raises: nothing
   Example: snd (take_save_request (init inv)) = None
   Complexity: O(1)
   Pseudocode:
     if dirty then ({ t with dirty = false }, Some inv) else (t, None)
*)
let take_save_request t = if t.dirty then ({ t with dirty = false }, Some t.inv) else (t, None)
