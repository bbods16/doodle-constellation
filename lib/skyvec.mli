(** Internal helper (not part of the zip's interfaces): unit vectors on
    the celestial sphere, used by {!Index}, {!Candidates} and {!Fitter}
    for fast separation tests and for the centre of a group of stars. *)

type v = { vx : float; vy : float; vz : float }
(** A unit vector in equatorial Cartesian coordinates. *)

val of_radec : float * float -> v
(**
   [of_radec (ra, dec)] is the unit vector pointing at that position.
   Requires: radians
   Returns: [(cos dec cos ra, cos dec sin ra, sin dec)]
   Raises: nothing
   Example: of_radec (0., 0.) = { vx = 1.; vy = 0.; vz = 0. }
   Complexity: O(1) time, O(1) space
*)

val dot : v -> v -> float
(**
   [dot a b] is the scalar product, the cosine of the angle between two
   unit vectors.
   Requires: nothing
   Returns: a value in [-1, 1] for unit vectors
   Raises: nothing
   Example: dot (of_radec (0., 0.)) (of_radec (0., 0.)) = 1.
   Complexity: O(1) time, O(1) space
*)

val centre : (float * float) list -> float * float
(**
   [centre ps] is the direction of the mean of the unit vectors of [ps],
   the natural "centroid" of a small group of sky positions.
   Requires: [ps] non-empty and not spread evenly around the sphere
   Returns: [(ra, dec)] in radians, [ra] in [0, 2 pi)
   Raises: [Invalid_argument] if [ps] is empty or the mean vector is zero
   Example: centre [(0., 0.1); (0., -0.1)] = (0., 0.)
   Complexity: O(n) time, O(1) space
*)
