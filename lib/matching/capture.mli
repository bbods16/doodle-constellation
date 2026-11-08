(**
   File: capture.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Capture module: stroke capture - drops mouse jitter
                and Gaussian-smooths the samples into a stroke.
   Usage: Import: add hack.matching to (libraries ...) in a dune file, then use
          Doodle_matching.Capture (or Capture with -open Doodle_matching).
          Build: dune build    Test: dune test
*)

(** Stroke capture: movement filter plus Gaussian smoothing.

    Adapted from GIMP's [gimpmotionbuffer.c] (drop moves too small to
    matter) and [gimp_paint_core_smooth_coords] (Gaussian-weighted mean
    of recent points). raylib gives one sample per frame and no
    per-event timestamps, so the weight falls off with distance back
    along the stroke instead of with accumulated velocity.

    [main.ml] reads [get_mouse_position ()] while the left button is
    down and passes each sample to {!add}. *)

type t
(** The stroke so far: raw kept points and their smoothed versions,
    in drawing order. Immutable; {!add} returns a new value. *)

val min_step : float
(** Minimum distance in pixels from the last kept point before a new
    sample is kept. [2.0]. *)

val window : int
(** Number of recent kept points averaged by the smoother. [8]. *)

val sigma : float
(** Gaussian width in pixels, measured along the stroke. [6.0]. *)

val empty : t
(** The stroke with no points. *)

val add : t -> Geom.pt -> t
(**
   [add t p] offers a new mouse sample to the stroke:
   + drops [p] if it is less than {!min_step} from the last kept point;
   + otherwise keeps it and appends its smoothed version, the weighted
     mean of the last {!window} kept points with weight
     [exp (-. d *. d /. (2. *. sigma *. sigma))], where [d] is the
     distance back along the stroke from [p].
   Requires: [p] in screen pixels
   Returns: the updated stroke ([t] itself when [p] is dropped)
   Raises: nothing
   Example: length (add (add empty {x=0.;y=0.}) {x=1.;y=0.}) = 1
   Complexity: O(window) time, O(1) extra space (shares the old stroke)
*)

val stroke : t -> Geom.pt array
(**
   [stroke t] is the smoothed points in drawing order. This is what
   {!Simplify.corners} receives on button release.
   Requires: nothing
   Returns: a fresh array of [length t] points
   Raises: nothing
   Example: stroke (add empty {x=3.;y=4.}) = [|{x=3.;y=4.}|]
   Complexity: O(n) time, O(n) space
*)

val raw : t -> Geom.pt array
(**
   [raw t] is the kept points before smoothing, for debugging and tests.
   Requires: nothing
   Returns: a fresh array of [length t] points in drawing order
   Raises: nothing
   Example: raw (add empty {x=3.;y=4.}) = [|{x=3.;y=4.}|]
   Complexity: O(n) time, O(n) space
*)

val length : t -> int
(**
   [length t] is the number of kept points.
   Requires: nothing
   Returns: a count [>= 0]
   Raises: nothing
   Example: length empty = 0
   Complexity: O(1) time, O(1) space
*)

val is_empty : t -> bool
(**
   [is_empty t] is [length t = 0].
   Requires: nothing
   Returns: [true] for a stroke with no kept points
   Raises: nothing
   Example: is_empty empty = true
   Complexity: O(1) time, O(1) space
*)
