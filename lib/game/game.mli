(** Game: the drawing game's rules as pure functions, no raylib.

    One frame of the game is: {!apply} each {!Controls.command}, then
    {!tick}. Each step of that is its own small function below, and each
    delegates the real work to an outside module:

    {v
    command        step here        outside module doing the work
    -------------  ---------------  ------------------------------------
    Pen_down p     pen_down         Capture   (filter + smooth samples)
    Pen_up         pen_up
                     recognise      Engine    (name the figure)
                     match_stroke   Simplify, Candidates, Fitter
                     begin_morph    Projection, Visibility, Morph
    (every frame)  tick             Morph     (advance the animation)
    Clear          clear
    Ask_story      ask_story        Narrate   (story in the background)
    v}

    [Save_card] and [Open_menu] are screen-level, handled by [bin/play.ml]. *)

type stage =
  | Drawing                                          (** waiting for or capturing a stroke *)
  | Hint of string                                   (** stroke refused; the reason to show *)
  | Morphing of Morph.t * Geom.pt array * Fitter.fit (** animation, stroke, match *)
  | Showing of Geom.pt array * Fitter.fit            (** final stroke on the stars, match *)
(** Where the game is. *)

type t
(** The whole game state (abstract): the stroke being drawn, the stage,
    the sky framing, the best viewing time, the engine's guess and the
    story slot. Change it only through the steps below; read it through
    the accessors at the end of this file. *)

type screen = {
  width : int;   (** window width in pixels *)
  height : int;  (** window height in pixels *)
  now : float;   (** current Unix time, for the best-viewing calculation *)
}
(** Facts about the outside world that the rules need. *)

val init : unit -> t
(**
   [init ()] is a blank sky waiting for a stroke.
   Requires: nothing
   Returns: state in [Drawing] with nothing captured, and a fresh story slot
   Raises: nothing
   Example: (init ()).stage = Drawing
   Complexity: O(1) time, O(1) space
*)

val apply : Scene.ctx -> screen -> t -> Controls.command -> t
(**
   [apply ctx screen t cmd] carries out one command by calling the
   matching step below. [Save_card] and [Open_menu] leave [t] unchanged.
   Requires: nothing
   Returns: the new state
   Raises: nothing
   Example: (apply ctx screen (init ()) Controls.Clear).stage = Drawing
   Complexity: that of the step called
*)

val pen_down : Geom.pt -> t -> t
(**
   [pen_down p t] adds a mouse sample to the stroke, starting a new
   stroke if the last one had already finished.
   Requires: [p] in screen pixels
   Returns: state in [Drawing] with [p] offered to {!Capture.add}
   Raises: nothing
   Example: Capture.length (pen_down p (init ())).capture = 1
   Complexity: O(Capture.window) time, O(1) extra space
*)

val pen_up : Scene.ctx -> screen -> t -> t
(**
   [pen_up ctx screen t] finishes the stroke: {!recognise} it, then
   {!match_stroke} it, then either show the refusal or {!begin_morph}.
   Does nothing if no stroke was captured.
   Requires: nothing
   Returns: state in [Hint] or [Morphing], with [guess] set
   Raises: nothing
   Example: (pen_up ctx screen t).stage = Morphing (...) for a Big Dipper drawing
   Complexity: dominated by {!match_stroke}
*)

val recognise : Scene.ctx -> Geom.pt array -> (string * float) option
(**
   [recognise ctx stroke] asks the recognition engine for its best guess.
   Requires: [stroke] non-empty
   Returns: [Some (class, probability)], or [None] when no engine is loaded
   Raises: nothing
   Example: recognise ctx dipper_stroke = Some ("Big Dipper", 0.99)
   Complexity: one {!Engine.classify} forward pass
*)

val match_stroke : Scene.ctx -> Geom.pt array -> (Geom.pt array * Fitter.fit, string) result
(**
   [match_stroke ctx stroke] finds the stroke in the sky:
   {!Simplify.corners}, then {!Candidates.generate}, then {!Fitter.best}.
   Requires: nothing
   Returns: [Ok (corners, fit)], or [Error hint] explaining the refusal
   Raises: nothing
   Example: match_stroke ctx straight_line = Error "Too simple - ..."
   Complexity: see {!Candidates.generate} and {!Fitter.best}
*)

val begin_morph :
  Scene.ctx -> screen -> corners:Geom.pt array -> stroke:Geom.pt array -> Fitter.fit -> t -> t
(**
   [begin_morph ctx screen ~corners ~stroke fit t] frames the match with
   {!Projection.view_for}, finds the best viewing time with
   {!Visibility.best_view}, and starts {!Morph} from the drawing to the
   stars' screen positions. A mirrored fit animates from the reflected
   drawing.
   Requires: [corners] non-empty and matching [fit.stars] in order
   Returns: state in [Morphing] with [view] and [best] set
   Raises: nothing
   Example: (begin_morph ctx screen ~corners ~stroke fit t).stage = Morphing (...)
   Complexity: O(n + s) time and space, n corners, s stroke points
*)

val tick : float -> t -> t
(**
   [tick dt t] advances the morph by [dt] seconds; when it finishes the
   game moves to [Showing]. Other stages are unchanged.
   Requires: [dt >= 0.]
   Returns: the advanced state
   Raises: nothing
   Example: (tick 10. morphing).stage = Showing (...)
   Complexity: O(1), or O(s) on the frame the morph finishes
*)

val clear : t -> t
(**
   [clear t] wipes the sky and starts over (a late story is ignored
   because the story slot is replaced).
   Requires: nothing
   Returns: [init ()]
   Raises: nothing
   Example: (clear t).stage = Drawing
   Complexity: O(1)
*)

val ask_story : Scene.ctx -> t -> t
(**
   [ask_story ctx t] starts an invented story about the current match in
   the background ({!Narrate.story_async}); it appears in [t.story] later.
   Does nothing without a match.
   Requires: nothing
   Returns: [t] unchanged (the story arrives through [t.story])
   Raises: nothing
   Example: ask_story ctx (init ()) == init state
   Complexity: O(n) to collect star labels; the request runs elsewhere
*)

val hint_of : Simplify.reason -> string
(**
   [hint_of reason] is the on-screen explanation for a refused stroke.
   Requires: nothing
   Returns: a short instruction
   Raises: nothing
   Example: hint_of `Too_simple = "Too simple - add a few sharp corners (5 to 9)"
   Complexity: O(1)
*)

val mirror_about_centroid : Geom.pt array -> Geom.pt array -> Geom.pt array
(**
   [mirror_about_centroid c pts] reflects [pts] top-to-bottom about the
   centroid of [c].
   Requires: [c] non-empty
   Returns: reflected copy of [pts]
   Raises: [Invalid_argument] if [c] is empty
   Example: mirror_about_centroid [|{x=0.;y=0.};{x=0.;y=2.}|] [|{x=0.;y=0.}|] = [|{x=0.;y=2.}|]
   Complexity: O(n) time, O(n) space
*)

val visible_stroke : t -> Geom.pt array
(**
   [visible_stroke t] is the stroke to draw right now: the live stroke
   while drawing, the morphing stroke during the animation, the final one
   afterwards.
   Requires: nothing
   Returns: screen points in drawing order
   Raises: nothing
   Example: visible_stroke (init ()) = [||]
   Complexity: O(s) time and space
*)

val current_fit : t -> Fitter.fit option
(**
   [current_fit t] is the match being animated or shown, if any.
   Requires: nothing
   Returns: [Some fit] in [Morphing] and [Showing], else [None]
   Raises: nothing
   Example: current_fit (init ()) = None
   Complexity: O(1)
*)

(** {1 Accessors} *)

val stage : t -> stage
(**
   [stage t] is where the game is.
   Requires: nothing
   Returns: the current stage
   Raises: nothing
   Example: stage (init ()) = Drawing
   Complexity: O(1)
*)

val view : t -> Projection.view option
(**
   [view t] is the sky framing for the current match.
   Requires: nothing
   Returns: [Some view] after a match, [None] for the default wide view
   Raises: nothing
   Example: view (init ()) = None
   Complexity: O(1)
*)

val best_view : t -> (float * float * float) option
(**
   [best_view t] is the best time to see the match: (Unix time,
   altitude, azimuth), angles in radians.
   Requires: nothing
   Returns: [Some _] after a match, else [None]
   Raises: nothing
   Example: best_view (init ()) = None
   Complexity: O(1)
*)

val guess : t -> (string * float) option
(**
   [guess t] is the recognition engine's top class and probability for
   the last stroke.
   Requires: nothing
   Returns: [Some (class, p)] after a stroke when an engine is loaded
   Raises: nothing
   Example: guess (init ()) = None
   Complexity: O(1)
*)

val story : t -> string option
(**
   [story t] is the invented story, once it has arrived from {!Narrate}.
   Requires: nothing
   Returns: [Some text] or [None]
   Raises: nothing
   Example: story (init ()) = None
   Complexity: O(1)
*)

val stroke_length : t -> int
(**
   [stroke_length t] is the number of points kept in the stroke being drawn.
   Requires: nothing
   Returns: a count [>= 0]
   Raises: nothing
   Example: stroke_length (init ()) = 0
   Complexity: O(1)
*)
