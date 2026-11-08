(**
   File: collect.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Collect module: collect mode's state machine -
                prompt, draw with a live score, verdict, next figure, win or quit.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Collect (or Collect with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Collect: the "collect all the constellations" game mode, as pure
    state and rules (no raylib). [bin/collect_scene.ml] wires it to the
    screen exactly the way [Play] wires {!Game}.

    Design notes: [docs/COLLECT_PLAN.md].

    {2 Flow}
    {v
      ┌──────────┐ pen down ┌──────────┐ pen up ┌──────────────┐
      │ Prompt   ├─────────►│ Drawing  ├───────►│ Verdict      │
      │ "Draw:   │          │ live %   │ score, │ % + headline │
      │  Orion"  │◄──┐      └──────────┘ judge  └──────┬───────┘
      └──────────┘   │ pass: 2.5 s / click; insult: Enter│
                     └───────────────────────────────────┤
                         Game_over verdict               ▼
      ┌──────────┐    Enter pressed    ┌──────────────────┐
      │ (quit)   │◄────────────────────┤ Dissed           │
      └──────────┘                     │ final diss line  │
                                       └──────────────────┘
      when every figure is collected: Complete (win screen)
    v}

    One frame = {!apply} each {!Controls.command}, then {!tick}. *)

type phase =
  | Prompt                             (** showing which figure to draw *)
  | Drawing                            (** pen down; live score updating *)
  | Verdict of Judge.verdict * float   (** result shown; seconds left on screen *)
  | Dissed of string                   (** final diss shown; waits for Enter, then quits *)
  | Complete                           (** every figure collected *)
(** Where the mode is. *)

type t
(** The whole mode state: collection, strikes, current target, the stroke
    and its live score, and the phase. Abstract. *)

val verdict_seconds : float
(** How long a passing verdict ("Collected!", "NEW RECORD!", a tier)
    stays up before the next prompt. [2.5]. An insult has no timer: it
    stays until the player presses Enter (see {!apply}). *)

val waiting_for_enter : t -> bool
(**
   [waiting_for_enter t] tells whether an insult or the final diss is on
   screen waiting for the player to press Enter.
   Requires: nothing
   Returns: [true] while the phase is [Verdict (Insulted _, _)] or
            [Dissed _] (until Enter has been pressed)
   Raises: nothing
   Example: waiting_for_enter (init c r) = false
   Complexity: O(1)
*)

val progress_file : string
(** Where progress is saved, next to the catalogue: ["progress.csv"]. *)

val init : Collection.t -> Roast.t -> t
(**
   [init c r] starts the mode on the next uncollected figure.
   Requires: nothing
   Returns: state in [Prompt], or [Complete] if [c] is already complete
   Raises: nothing
   Example: phase (init (Collection.create figures) (Roast.create ())) = Prompt
   Complexity: O(n)
*)

val apply : t -> Controls.command -> t
(**
   [apply t cmd] carries out one command:
   [Pen_down p] starts or extends the stroke (leaving [Prompt], or
   skipping the rest of a passing [Verdict]) and updates the live score;
   [Pen_up] scores the stroke ({!Accuracy.score}), runs {!Judge.judge}
   and enters [Verdict] (or [Dissed] on [Game_over]); [Clear] drops the
   stroke and returns to [Prompt]. Other commands leave [t] unchanged.
   While an insult is showing ({!waiting_for_enter}), only [Dismiss]
   (Enter) does anything: it moves on to the next prompt; drawing and
   clearing are ignored so the insult can't be skipped by accident.
   On the final diss ([Dissed]) likewise only [Dismiss] (Enter) does
   anything: it ends the game ({!wants_quit}). In [Complete] only
   [Dismiss] (Enter) does anything: it asks for the case screen
   ({!wants_cases}), so the cases earned can be opened. Pen commands are also
   ignored until the button has been up for one frame after the mode
   starts, so the click that opened collect mode can't start a stroke
   (and an instant 0% strike).
   Requires: nothing
   Returns: the new state
   Raises: nothing
   Example: phase (apply (init c r) (Controls.Pen_down p)) = Drawing
   Complexity: O(1) per sample plus {!Accuracy.live}; one {!Accuracy.score} on release
*)

val tick : float -> t -> t
(**
   [tick dt t] counts down the timers: when a passing [Verdict] runs out
   the next prompt appears (or [Complete]). Insults and the final diss
   have no timer: they wait for Enter.
   Requires: [dt >= 0.]
   Returns: the advanced state
   Raises: nothing
   Example: phase (tick 10. verdict_state) = Prompt
   Complexity: O(n) when moving to the next target, else O(1)
*)

val wants_quit : t -> bool
(**
   [wants_quit t] tells the screen to close the game: the player has
   pressed Enter on the final diss.
   Requires: nothing
   Returns: [true] only after Enter on the fifth strike's final diss
   Raises: nothing
   Example: wants_quit (init c r) = false
   Complexity: O(1)
*)

val wants_cases : t -> bool
(**
   [wants_cases t] tells the screen to open the case screen: the player
   has pressed Enter on the win screen ([Complete]). Winning never closes
   the game.
   Requires: nothing
   Returns: [true] only after Enter in [Complete]
   Raises: nothing
   Example: wants_cases (apply complete_state Controls.Dismiss) = true
   Complexity: O(1)
*)

(** {1 Accessors (for the view)} *)

val phase : t -> phase
(**
   [phase t] is where the mode is.
   Requires: nothing
   Returns: the phase
   Raises: nothing
   Example: phase (init c r) = Prompt
   Complexity: O(1)
*)

val target : t -> Asterism.t option
(**
   [target t] is the figure to draw now.
   Requires: nothing
   Returns: [Some figure], or [None] when [Complete]
   Raises: nothing
   Example: Option.map Asterism.name (target (init c r)) = Some "Big Dipper"
   Complexity: O(1)
*)

val stroke : t -> Geom.pt array
(**
   [stroke t] is the current drawing, smoothed, in screen pixels.
   Requires: nothing
   Returns: points in drawing order (empty in [Prompt])
   Raises: nothing
   Example: stroke (init c r) = [||]
   Complexity: O(s)
*)

val live_score : t -> float
(**
   [live_score t] is the running percentage while drawing (the big number).
   Requires: nothing
   Returns: a percentage in [0, 100]; [0.] before drawing starts
   Raises: nothing
   Example: live_score (init c r) = 0.
   Complexity: O(1)
*)

val collection : t -> Collection.t
(**
   [collection t] is the progress so far (for the shelf and "3 / 7 collected").
   Requires: nothing
   Returns: the collection
   Raises: nothing
   Example: Collection.collected_count (collection (init c r)) = 0
   Complexity: O(1)
*)

val roast : t -> Roast.t
(**
   [roast t] is the strike state (for "strikes left").
   Requires: nothing
   Returns: the roaster
   Raises: nothing
   Example: Roast.strikes (roast (init c r)) = 0
   Complexity: O(1)
*)

val earns_case : Judge.verdict -> bool
(**
   [earns_case v] tells whether a verdict rewards a case for the case
   screen ({!Case_opening}): collecting a constellation for the first
   time, or setting a new record on one.
   Requires: nothing
   Returns: [true] for [Collected_new] and [New_record]
   Raises: nothing
   Example: earns_case (Judge.New_record { score = 91.; tier = Accuracy.Incredible }) = true
   Complexity: O(1)
*)

val take_earned_cases : t -> t * int
(**
   [take_earned_cases t] hands the screen the cases earned since the last
   call (see {!earns_case}), so it can add them to the saved
   {!Inventory}; the count is reset.
   Requires: nothing
   Returns: the state with the count reset, and the number of cases earned
   Raises: nothing
   Example: snd (take_earned_cases (init c r)) = 0
   Complexity: O(1)
*)

val take_save_request : t -> t * Collection.t option
(**
   [take_save_request t] hands the screen a collection to save when it
   changed since the last call (after each verdict), so the pure rules
   never touch the disk themselves.
   Requires: nothing
   Returns: the state with the request cleared, and [Some c] to save or [None]
   Raises: nothing
   Example: snd (take_save_request (init c r)) = None
   Complexity: O(1)
*)
