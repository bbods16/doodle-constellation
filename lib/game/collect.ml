(* PLANNED (collect mode): stub implementation. The interface in
   collect.mli is the contract; replace each [todo] with the real code.
   See docs/COLLECT_PLAN.md. *)

type phase =
  | Prompt
  | Drawing
  | Verdict of Judge.verdict * float
  | Dissed of string * float
  | Complete

type t = {
  collection : Collection.t;
  roast : Roast.t;
  target : Asterism.t option;
  capture : Capture.t;
  live : float;
  phase : phase;
  dirty : bool;            (* collection changed since the last save request *)
}

let verdict_seconds = 2.5
let diss_seconds = 4.0
let progress_file = "progress.csv"

let todo what = failwith ("Collect." ^ what ^ ": not implemented yet (see collect.mli)")

(**
   [init c r] starts on the next uncollected figure.
   Requires: nothing
   Returns: Prompt, or Complete
   Raises: nothing
   Example: phase (init (Collection.create figures) (Roast.create ())) = Prompt
   Complexity: O(n)
   Pseudocode:
     target <- Collection.next_target c
     phase <- if target = None then Complete else Prompt
     return { c; r; target; empty capture; live = 0; phase; dirty = false }
*)
let init (_ : Collection.t) (_ : Roast.t) : t = todo "init"

(**
   [apply t cmd] carries out one command.
   Requires: nothing
   Returns: new state
   Raises: nothing
   Example: phase (apply (init c r) (Controls.Pen_down p)) = Drawing
   Complexity: see collect.mli
   Pseudocode:
     match phase, cmd with
       | (Dissed _ | Complete), _ -> t
       | (Prompt | Verdict _ | Drawing), Pen_down p ->
           capture <- (if phase = Drawing then capture else empty) + p
           live <- Accuracy.live ~target:(shape target) (stroke)
           phase <- Drawing
       | Drawing, Pen_up ->
           score <- Accuracy.score ~target:(shape target) (stroke)
           (c, r, v) <- Judge.judge collection roast ~target ~score
           phase <- match v with
                    | Game_over { line } -> Dissed (line, diss_seconds)
                    | v -> Verdict (v, verdict_seconds)
           dirty <- true
       | _, Clear -> drop the stroke ; phase <- Prompt
       | _ -> t
*)
let apply (_ : t) (_ : Controls.command) : t = todo "apply"

(**
   [tick dt t] counts down timers.
   Requires: dt >= 0
   Returns: advanced state
   Raises: nothing
   Example: phase (tick 10. verdict_state) = Prompt
   Complexity: O(n) on a target change
   Pseudocode:
     Verdict (v, s) -> if s - dt > 0 then Verdict (v, s - dt)
                       else target <- Collection.next_target collection
                            phase <- if target = None then Complete else Prompt
                            clear the stroke
     Dissed (l, s)  -> Dissed (l, s - dt)       (wants_quit once s <= 0)
     other -> unchanged
*)
let tick (_ : float) (_ : t) : t = todo "tick"

(**
   [wants_quit t] is true once the diss countdown ends.
   Requires: nothing
   Returns: phase = Dissed (_, s) with s <= 0
   Raises: nothing
   Example: wants_quit (init c r) = false
   Complexity: O(1)
   Pseudocode:
     match phase with Dissed (_, s) -> s <= 0 | _ -> false
*)
let wants_quit t = match t.phase with Dissed (_, s) -> s <= 0. | _ -> false

(**
   [phase t] is the phase.
   Requires: nothing
   Returns: t.phase
   Raises: nothing
   Example: phase (init c r) = Prompt
   Complexity: O(1)
   Pseudocode:
     return t.phase
*)
let phase t = t.phase

(**
   [target t] is the figure to draw.
   Requires: nothing
   Returns: t.target
   Raises: nothing
   Example: Option.map Asterism.name (target (init c r)) = Some "Big Dipper"
   Complexity: O(1)
   Pseudocode:
     return t.target
*)
let target t = t.target

(**
   [stroke t] is the current drawing.
   Requires: nothing
   Returns: Capture.stroke t.capture
   Raises: nothing
   Example: stroke (init c r) = [||]
   Complexity: O(s)
   Pseudocode:
     return Capture.stroke t.capture
*)
let stroke t = Capture.stroke t.capture

(**
   [live_score t] is the running percentage.
   Requires: nothing
   Returns: t.live
   Raises: nothing
   Example: live_score (init c r) = 0.
   Complexity: O(1)
   Pseudocode:
     return t.live
*)
let live_score t = t.live

(**
   [collection t] is the progress.
   Requires: nothing
   Returns: t.collection
   Raises: nothing
   Example: Collection.collected_count (collection (init c r)) = 0
   Complexity: O(1)
   Pseudocode:
     return t.collection
*)
let collection t = t.collection

(**
   [roast t] is the strike state.
   Requires: nothing
   Returns: t.roast
   Raises: nothing
   Example: Roast.strikes (roast (init c r)) = 0
   Complexity: O(1)
   Pseudocode:
     return t.roast
*)
let roast t = t.roast

(**
   [take_save_request t] returns progress to save, once per change.
   Requires: nothing
   Returns: (t with dirty cleared, Some collection if it was dirty)
   Raises: nothing
   Example: snd (take_save_request (init c r)) = None
   Complexity: O(1)
   Pseudocode:
     if t.dirty then ({ t with dirty = false }, Some t.collection) else (t, None)
*)
let take_save_request t =
  if t.dirty then ({ t with dirty = false }, Some t.collection) else (t, None)
