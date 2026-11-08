(**
   File: collect.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Collect module: collect mode's state machine -
                prompt, draw with a live score, verdict, next figure, win or quit.
   Usage: The contract is in collect.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Collect (or Collect with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Collect mode's state machine. See collect.mli for the contract. *)

type phase =
  | Prompt
  | Drawing
  | Verdict of Judge.verdict * float
  | Dissed of string
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
  quit : bool;       (* Enter was pressed on the final diss *)
  to_cases : bool;   (* Enter was pressed on the win screen *)
  earned : int;      (* cases earned since the last take_earned_cases *)
}

let verdict_seconds = 2.5
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
     return { c; r; target; empty capture; live = 0; phase; not dirty; not armed;
              not quitting; not leaving for the cases; earned = 0 }
*)
let init c r =
  let target = Collection.next_target c in
  { collection = c; roast = r; target; capture = Capture.empty; live = 0.;
    phase = (if target = None then Complete else Prompt); dirty = false; armed = false;
    pen_seen = false; quit = false; to_cases = false; earned = 0 }

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
              | Game_over { line } -> Dissed line   (* no timer: waits for Enter *)
              | Insulted _ -> Verdict (v, 0)   (* no timer: waits for Enter *)
              | v -> Verdict (v, verdict_seconds)
     dirty <- true
     earned <- earned + (1 if v is Collected_new or New_record)   (a case reward)
*)
let pen_up t =
  match (t.phase, t.target) with
  | Drawing, Some f ->
      let score = Accuracy.score ~target:(Asterism.shape f) (Capture.raw t.capture) in
      let collection, roast, v = Judge.judge t.collection t.roast ~target:f ~score in
      let phase =
        match v with
        | Judge.Game_over { line; _ } -> Dissed line
        | Judge.Insulted _ -> Verdict (v, 0.) (* no timer: waits for Enter *)
        | v -> Verdict (v, verdict_seconds)
      in
      let reward = match v with Judge.Collected_new _ | Judge.New_record _ -> 1 | _ -> 0 in
      { t with collection; roast; phase; live = score; dirty = true; earned = t.earned + reward }
  | _ -> t

(**
   [earns_case v] tells whether a verdict rewards a case.
   Requires: nothing
   Returns: true for Collected_new and New_record
   Raises: nothing
   Example: earns_case (Judge.New_record { score = 91.; tier = Incredible }) = true
   Complexity: O(1)
   Pseudocode:
     match v with Collected_new _ | New_record _ -> true | _ -> false
*)
let earns_case (v : Judge.verdict) =
  match v with Judge.Collected_new _ | Judge.New_record _ -> true | _ -> false

(**
   [take_earned_cases t] hands over the cases earned since the last call.
   Requires: nothing
   Returns: (t with the count reset, the count)
   Raises: nothing
   Example: snd (take_earned_cases (init c r)) = 0
   Complexity: O(1)
   Pseudocode:
     return ({ t with earned = 0 }, t.earned)
*)
let take_earned_cases t = ({ t with earned = 0 }, t.earned)

(**
   [apply t cmd] carries out one command.
   Requires: nothing
   Returns: new state
   Raises: nothing
   Example: phase (apply (init c r) (Controls.Pen_down p)) = Drawing (once armed)
   Complexity: see collect.mli
   Pseudocode:
     match phase, cmd with
       | Dissed _, Dismiss -> quit <- true                (Enter ends the game)
       | Complete, Dismiss -> to_cases <- true            (Enter opens the cases)
       | (Dissed _ | Complete), _ -> t
       | insult showing, Dismiss -> next_round t          (Enter moves on)
       | insult showing, Pen_down _ -> note pen_seen only  (can't skip by drawing)
       | insult showing, _ -> t
       | _, Pen_down p -> note pen_seen ; if armed then pen_down p t else t
       | _, Pen_up -> if armed then pen_up t else t
       | _, Clear -> drop the stroke ; Prompt (from Drawing or Verdict: next_round)
       | _ -> t
*)
let apply t (cmd : Controls.command) =
  match (t.phase, cmd) with
  | Dissed _, Dismiss -> { t with quit = true }
  | Complete, Dismiss -> { t with to_cases = true }
  | (Dissed _ | Complete), _ -> t
  | Verdict (Judge.Insulted _, _), Dismiss -> next_round t
  | Verdict (Judge.Insulted _, _), Pen_down _ -> { t with pen_seen = true }
  | Verdict (Judge.Insulted _, _), _ -> t
  | _, Pen_down p ->
      let t = { t with pen_seen = true } in
      if t.armed then pen_down p t else t
  | _, Pen_up -> if t.armed then pen_up t else t
  | _, Clear -> next_round t
  | _, (Save_card | Ask_story | Open_menu | Dismiss) -> t

(**
   [tick dt t] counts down timers and arms the pen.
   Requires: dt >= 0
   Returns: advanced state
   Raises: nothing
   Example: phase (tick 10. verdict_state) = Prompt
   Complexity: O(n) on a target change
   Pseudocode:
     armed <- armed or not pen_seen ; pen_seen <- false
     Verdict (Insulted _, _) | Dissed _ -> unchanged (no timer: waits for Enter)
     Verdict (v, s) -> if s - dt > 0 then Verdict (v, s - dt) else next_round
     other -> unchanged
*)
let tick dt t =
  let t = { t with armed = t.armed || not t.pen_seen; pen_seen = false } in
  match t.phase with
  | Verdict (Judge.Insulted _, _) | Dissed _ -> t
  | Verdict (v, s) -> if s -. dt > 0. then { t with phase = Verdict (v, s -. dt) } else next_round t
  | Prompt | Drawing | Complete -> t

(**
   [waiting_for_enter t] tells whether an insult or the final diss is
   waiting for Enter.
   Requires: nothing
   Returns: true in Verdict (Insulted _, _), and in Dissed _ until Enter
   Raises: nothing
   Example: waiting_for_enter (init c r) = false
   Complexity: O(1)
   Pseudocode:
     match phase with
       | Verdict (Insulted _, _) -> true
       | Dissed _ -> not quit
       | _ -> false
*)
let waiting_for_enter t =
  match t.phase with
  | Verdict (Judge.Insulted _, _) -> true
  | Dissed _ -> not t.quit
  | Prompt | Drawing | Verdict _ | Complete -> false

(**
   [wants_quit t] is true once Enter was pressed on the final diss.
   Requires: nothing
   Returns: t.quit
   Raises: nothing
   Example: wants_quit (init c r) = false
   Complexity: O(1)
   Pseudocode:
     return t.quit
*)
let wants_quit t = t.quit

(**
   [wants_cases t] is true once Enter was pressed on the win screen.
   Requires: nothing
   Returns: t.to_cases
   Raises: nothing
   Example: wants_cases (init c r) = false
   Complexity: O(1)
   Pseudocode:
     return t.to_cases
*)
let wants_cases t = t.to_cases

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
