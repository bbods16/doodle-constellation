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
      └──────────┘   │ verdict_seconds pass, or a click │
                     └───────────────────────────────────┤
                         Game_over verdict               ▼
      ┌──────────┐ diss_seconds pass   ┌──────────────────┐
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
  | Dissed of string * float           (** final diss shown; seconds until quit *)
  | Complete                           (** every figure collected *)
(** Where the mode is. *)

type t
(** The whole mode state: collection, strikes, current target, the stroke
    and its live score, and the phase. Abstract. *)

val verdict_seconds : float
(** How long a verdict stays up before the next prompt. [2.5]. *)

val diss_seconds : float
(** How long the final diss stays up before the game closes. [4.0]. *)

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
   skipping the rest of a [Verdict]) and updates the live score;
   [Pen_up] scores the stroke ({!Accuracy.score}), runs {!Judge.judge}
   and enters [Verdict] (or [Dissed] on [Game_over]); [Clear] drops the
   stroke and returns to [Prompt]. Other commands leave [t] unchanged.
   Ignored entirely in [Dissed] and [Complete]. Pen commands are also
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
   [tick dt t] counts down the timers: when a [Verdict] runs out the next
   prompt appears (or [Complete]); when [Dissed] runs out, {!wants_quit}
   becomes true.
   Requires: [dt >= 0.]
   Returns: the advanced state
   Raises: nothing
   Example: phase (tick 10. verdict_state) = Prompt
   Complexity: O(n) when moving to the next target, else O(1)
*)

val wants_quit : t -> bool
(**
   [wants_quit t] tells the screen to close the game: the final diss has
   been on screen for {!diss_seconds}.
   Requires: nothing
   Returns: [true] only after the fifth strike's countdown
   Raises: nothing
   Example: wants_quit (init c r) = false
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
