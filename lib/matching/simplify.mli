(**
   File: simplify.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Simplify module: the stroke simplifier
                (Ramer-Douglas-Peucker) - reduces a stroke to 5-9 corners, or says why
                it can't.
   Usage: Import: add hack.matching to (libraries ...) in a dune file, then use
          Doodle_matching.Simplify (or Simplify with -open Doodle_matching).
          Build: dune build    Test: dune test
*)

(** Stroke simplifier: reduces a smoothed stroke to 5 to 9 corners.

    Adapted from GIMP's [simplify_subdivide] in [gimpboundary.c]: the
    same cross-product distance test and recursion, but split at the
    farthest point (true Ramer-Douglas-Peucker) instead of GIMP's
    midpoint, with a tolerance relative to the drawing's size.

    Smoothing happens earlier, in {!Capture}. *)

type reason = [ `Too_simple | `Too_complex ]
(** Why a stroke was refused. [main.ml] turns this into the on-screen
    hint, which closes gap G4 in the diagrams. *)

val min_corners : int
(** Fewest corners accepted: [5]. *)

val max_corners : int
(** Most corners accepted: [9]. *)

val eps_fraction : float
(** Starting tolerance as a fraction of the bounding-box diagonal.
    [0.04]. *)

val line_fraction : float
(** A stroke is a line when no point is farther than this fraction of
    the diagonal from the first-to-last chord. [0.08]. *)

val max_tries : int
(** Number of tolerance adjustments before giving up. [5]. *)

val is_line : Geom.pt array -> bool
(**
   [is_line pts] is [true] when the stroke is too close to a straight
   line to match anything distinctive.
   Requires: nothing
   Returns: [true] for fewer than 2 points, a zero-size stroke, or when
            every point lies within [line_fraction *. bbox_diagonal] of
            the first-to-last chord (for a closed stroke, of the first
            point); [false] otherwise
   Raises: nothing
   Example: is_line [|{x=0.;y=0.}; {x=50.;y=1.}; {x=100.;y=0.}|] = true
   Complexity: O(n) time, O(1) space
*)

val rdp : eps:float -> Geom.pt array -> Geom.pt array
(**
   [rdp ~eps pts] is one run of Ramer-Douglas-Peucker with absolute
   tolerance [eps] (pixels). For each range [\[i, j\]] with [a = pts.(i)]
   and [(dx, dy) = pts.(j) - a], the test value for point [p] is
   [|dx *. (a.y -. p.y) -. dy *. (a.x -. p.x)|], the true distance times
   the chord length, so it is compared with [eps *. length] and no square
   root runs inside the loop. When the two ends coincide (a closed
   stroke), plain distance from [a] is used instead. Exposed for tests.
   Requires: [eps >= 0.]
   Returns: the kept points in drawing order, always including the first
            and last; the input unchanged when it has 2 or fewer points
   Raises: nothing
   Example: rdp ~eps:1. [|{x=0.;y=0.};{x=1.;y=0.1};{x=2.;y=0.}|]
            = [|{x=0.;y=0.};{x=2.;y=0.}|]
   Complexity: O(n^2) time worst case, O(n log n) typical; O(n) space
*)

val corners : Geom.pt array -> (Geom.pt array, reason) result
(**
   [corners pts] is the full simplifier:
   + [Error `Too_simple] if fewer than 3 points or {!is_line};
   + [eps = eps_fraction *. bbox_diagonal];
   + run {!rdp}; a closing corner that lands on the first corner is
     dropped (a closed loop has one corner there, not two);
   + over {!max_corners} raises [eps] by 30%, under {!min_corners}
     lowers it by 30%, at most {!max_tries} times;
   + [Ok corners] when the count lands in range, otherwise
     [Error `Too_complex] (still too many) or [Error `Too_simple]
     (still too few).
   Requires: [pts] are smoothed stroke points in drawing order
   Returns: [Ok c] with [min_corners <= Array.length c <= max_corners],
            or the reason for refusal
   Raises: nothing
   Example: corners (a zig-zag "W" with 5 sharp turns) = Ok (5 corners)
   Complexity: O(max_tries * n^2) time worst case, O(n) space
*)
