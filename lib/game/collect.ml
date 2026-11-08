(* Collect mode's state machine. See collect.mli for the contract. *)

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
  dirty : bool;      (* collection changed since the last save request *)
  armed : bool;      (* the button has been up since the mode started *)
  pen_seen : bool;   (* a Pen_down arrived this frame *)
}

let verdict_seconds = 2.5
let diss_seconds = 4.0
let progress_file = "progress.csv"

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
     return { c; r; target; empty capture; live = 0; phase; not dirty; not armed }
*)
let init c r =
  let target = Collection.next_target c in
  { collection = c; roast = r; target; capture = Capture.empty; live = 0.;
    phase = (if target = None then Complete else Prompt); dirty = false; armed = false;
    pen_seen = false }

(**
   [next_round t] moves on to the next uncollected figure with a clean slate.
   Requires: nothing
   Returns: Prompt on the next target, or Complete
   Raises: nothing
   Example: phase (next_round t) = Prompt
   Complexity: O(n)
   Pseudocode:
     target <- Collection.next_target t.collection
     return { t with target; empty capture; live = 0;
                     phase = if target = None then Complete else Prompt }
*)
let next_round t =
  let target = Collection.next_target t.collection in
  { t with target; capture = Capture.empty; live = 0.;
    phase = (if target = None then Complete else Prompt) }

(**
   [pen_down p t] starts or extends the stroke and updates the live score.
   Requires: a target
   Returns: state in Drawing
   Raises: nothing
   Example: phase (pen_down p (init c r)) = Drawing (once armed)
   Complexity: O(Capture.window) + Accuracy.live
   Pseudocode:
     t <- if phase is Verdict then next_round t else t   (skip the rest of the verdict)
     if phase is Complete then t
     capture <- (if phase = Drawing then capture else empty) + p
     live <- Accuracy.live ~target:(shape target) (raw points: smoothing
             would round the corners and cap sharp figures below 90%)
*)
let pen_down p t =
  let t = match t.phase with Verdict _ -> next_round t | _ -> t in
  match (t.phase, t.target) with
  | (Prompt | Drawing), Some f ->
      let capture = Capture.add (if t.phase = Drawing then t.capture else Capture.empty) p in
      let live = Accuracy.live ~target:(Asterism.shape f) (Capture.raw capture) in
      { t with capture; live; phase = Drawing }
  | _ -> t

(**
   [pen_up t] scores the stroke and judges it.
   Requires: nothing
   Returns: Verdict or Dissed (unchanged unless Drawing)
   Raises: nothing
   Example: phase (pen_up drawing_state) = Verdict (...)
   Complexity: Accuracy.score + Judge.judge
   Pseudocode:
     score <- Accuracy.score ~target:(shape target) (raw points)
     (c, r, v) <- Judge.judge collection roast ~target ~score
     phase <- match v with
              | Game_over { line } -> Dissed (line, diss_seconds)
              | v -> Verdict (v, verdict_seconds)
     dirty <- true
*)
let pen_up t =
  match (t.phase, t.target) with
  | Drawing, Some f ->
      let score = Accuracy.score ~target:(Asterism.shape f) (Capture.raw t.capture) in
      let collection, roast, v = Judge.judge t.collection t.roast ~target:f ~score in
      let phase =
        match v with
        | Judge.Game_over { line; _ } -> Dissed (line, diss_seconds)
        | v -> Verdict (v, verdict_seconds)
      in
      { t with collection; roast; phase; live = score; dirty = true }
  | _ -> t

(**
   [apply t cmd] carries out one command.
   Requires: nothing
   Returns: new state
   Raises: nothing
   Example: phase (apply (init c r) (Controls.Pen_down p)) = Drawing (once armed)
   Complexity: see collect.mli
   Pseudocode:
     match phase, cmd with
       | (Dissed _ | Complete), _ -> t
       | _, Pen_down p -> note pen_seen ; if armed then pen_down p t else t
       | _, Pen_up -> if armed then pen_up t else t
       | _, Clear -> drop the stroke ; Prompt (from Drawing or Verdict: next_round)
       | _ -> t
*)
let apply t (cmd : Controls.command) =
  match (t.phase, cmd) with
  | (Dissed _ | Complete), _ -> t
  | _, Pen_down p ->
      let t = { t with pen_seen = true } in
      if t.armed then pen_down p t else t
  | _, Pen_up -> if t.armed then pen_up t else t
  | _, Clear -> next_round t
  | _, (Save_card | Ask_story | Open_menu) -> t

(**
   [tick dt t] counts down timers and arms the pen.
   Requires: dt >= 0
   Returns: advanced state
   Raises: nothing
   Example: phase (tick 10. verdict_state) = Prompt
   Complexity: O(n) on a target change
   Pseudocode:
     armed <- armed or not pen_seen ; pen_seen <- false
     Verdict (v, s) -> if s - dt > 0 then Verdict (v, s - dt) else next_round
     Dissed (l, s)  -> Dissed (l, s - dt)       (wants_quit once s <= 0)
     other -> unchanged
*)
let tick dt t =
  let t = { t with armed = t.armed || not t.pen_seen; pen_seen = false } in
  match t.phase with
  | Verdict (v, s) -> if s -. dt > 0. then { t with phase = Verdict (v, s -. dt) } else next_round t
  | Dissed (line, s) -> { t with phase = Dissed (line, s -. dt) }
  | Prompt | Drawing | Complete -> t

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
