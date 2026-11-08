(**
   File: fitter.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Fitter module: snaps corners to stars, refits with
                least squares, scores each candidate and keeps the best match.
   Usage: Import: add hack.matching to (libraries ...) in a dune file, then use
          Doodle_matching.Fitter (or Fitter with -open Doodle_matching).
          Build: dune build    Test: dune test
*)

(** Similarity fitter and scorer.

    Tests each hypothesis against every corner: snap each corner to the
    nearest unused star within a radius (running minimum, as in GIMP's
    [gimp_image_snap_point]), refit with {!Geom.procrustes}, repeat,
    then score. Least-squares Procrustes is new code; GIMP only solves
    exact 4-point transforms. *)

type fit = {
  stars : int array;       (** one star index per corner, in corner order *)
  sim : Geom.sim;          (** screen pixels onto the gnomonic plane *)
  centre : float * float;  (** (ra, dec) of that plane *)
  rms_deg : float;         (** root-mean-square corner-to-star gap, degrees *)
  score : float;           (** [rms_deg] plus penalties; lower is better *)
  mirrored : bool;         (** [true] if the reflected drawing fitted better *)
  weak : bool;             (** [rms_deg > accept_limit] *)
}

val accept_limit : float
(** Largest RMS error, in degrees, that counts as a good match. The
    fitter owns this rule, which closes gap G3. [3.0]. *)

val snap_radius_deg : float
(** A corner only snaps to a star within this distance. [4.0]. *)

val passes : int
(** Snap-and-refit rounds per hypothesis. [3]. *)

val allow_mirror : bool
(** Also try the drawing reflected with {!Geom.mirror_y}. [true]. *)

val faint_penalty : float
(** Added per magnitude fainter than 3.0, summed over matched stars.
    [0.25] (degrees of score per magnitude). *)

val unused_bright_penalty : float
(** Added per star brighter than the faintest matched star that lies
    inside the shape but was not used. [0.5]. *)

val snap :
  Catalogue.star array -> centre:float * float -> Geom.pt array ->
  int array option
(**
   [snap stars ~centre pts] gives, for each projected corner, the
   nearest star within {!snap_radius_deg} not already taken by an
   earlier corner. Corners are handled in order; each keeps a running
   minimum over the candidate stars.
   Requires: [pts] are on the gnomonic plane of [centre] (radians)
   Returns: [Some ids] with one distinct star index per corner, in
            corner order; [None] if any corner has no free star in range
   Raises: nothing
   Example: snap stars ~centre [| projected Dubhe; projected Merak |]
            = Some [| dubhe_index; merak_index |]
   Complexity: O(N + n * N') time, O(N') space; N stars, N' stars near
               the patch, n corners
*)

val fit_one : Catalogue.star array -> Candidates.hypothesis -> fit option
(**
   [fit_one stars h] refines one hypothesis: {!passes} rounds of {!snap}
   then {!Geom.procrustes}, then scores the result.
   Requires: [h] was produced from the same [stars]
   Returns: [Some fit] with [mirrored = false]; [None] if snapping fails
            or Procrustes rejects a degenerate set
   Raises: nothing
   Example: fit_one stars h_for_a_clean_big_dipper = Some { rms_deg ~ 0.; weak = false; ... }
   Complexity: O(passes * (N + n * N')) time, O(N') space
*)

val best : Catalogue.star array -> Candidates.hypothesis list -> fit option
(**
   [best stars hs] runs {!fit_one} on every hypothesis (and on the
   mirrored drawing when {!allow_mirror}) and keeps the lowest [score].
   The mirrored attempt reflects [drawn] with {!Geom.mirror_y} and
   reseeds the transform from the reflected seed corners, which suits
   star triangles that are the mirror image of the drawn one.
   Requires: hypotheses produced from the same [stars]
   Returns: the best fit; [None] only when no hypothesis could be fitted
            at all; a poor fit is returned with [weak = true]
   Raises: nothing
   Example: best stars [] = None
   Complexity: O(H * passes * (N + n * N')) time, O(N') space,
               H hypotheses
*)
