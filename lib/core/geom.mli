(** Shared 2-D geometry for Doodle Constellation.

    Every matching module works on {!pt}, a plain record, never on
    raylib's [Vector2.t]. Only [bin/] converts to raylib types, so this
    library can be tested with [dune test] without opening a window.

    Angles are in radians. Sky coordinates are (right ascension,
    declination) pairs in radians.

    Projection-plane orientation: {!gnomonic} returns points in "screen
    orientation" (x grows toward celestial west, y grows toward celestial
    south), which is how the sky looks when you face it with north up and
    east on the left. A drawing in screen pixels (y down) therefore maps
    onto the plane by a proper similarity, with no reflection. *)

(** {1 Types} *)

type pt = { x : float; y : float }
(** A point on the screen (pixels) or on a projection plane (radians). *)

type sim = { s : float; theta : float; tx : float; ty : float }
(** A similarity transform: uniform scale [s], rotation [theta] and
    shift [(tx, ty)].  It maps [p] to [s * R(theta) * p + t], where
    [R(theta) p = (cos theta * p.x - sin theta * p.y,
                   sin theta * p.x + cos theta * p.y)]. *)

val identity : sim
(** [{ s = 1.; theta = 0.; tx = 0.; ty = 0. }], the transform that leaves
    every point where it is. *)

(** {1 Point helpers} *)

val add : pt -> pt -> pt
(**
   [add a b] is the component-wise sum of [a] and [b].
   Requires: nothing
   Returns: [{ x = a.x +. b.x; y = a.y +. b.y }]
   Raises: nothing
   Example: add {x=1.;y=2.} {x=3.;y=4.} = {x=4.;y=6.}
   Complexity: O(1) time, O(1) space
*)

val sub : pt -> pt -> pt
(**
   [sub a b] is the component-wise difference [a - b].
   Requires: nothing
   Returns: the vector pointing from [b] to [a]
   Raises: nothing
   Example: sub {x=3.;y=4.} {x=1.;y=1.} = {x=2.;y=3.}
   Complexity: O(1) time, O(1) space
*)

val scale : float -> pt -> pt
(**
   [scale k p] multiplies both coordinates of [p] by [k].
   Requires: nothing
   Returns: [{ x = k *. p.x; y = k *. p.y }]
   Raises: nothing
   Example: scale 2. {x=1.;y=-3.} = {x=2.;y=-6.}
   Complexity: O(1) time, O(1) space
*)

val rotate : float -> pt -> pt
(**
   [rotate theta p] is [R(theta) p], [p] turned by [theta] radians about
   the origin.
   Requires: nothing
   Returns: [(cos theta * x - sin theta * y, sin theta * x + cos theta * y)]
   Raises: nothing
   Example: rotate (Float.pi /. 2.) {x=1.;y=0.} = {x=0.;y=1.} (to rounding)
   Complexity: O(1) time, O(1) space
*)

val dist : pt -> pt -> float
(**
   [dist a b] is the Euclidean distance between [a] and [b].
   Requires: nothing
   Returns: [sqrt ((a.x - b.x)^2 + (a.y - b.y)^2)], always [>= 0]
   Raises: nothing
   Example: dist {x=0.;y=0.} {x=3.;y=4.} = 5.
   Complexity: O(1) time, O(1) space
*)

val dist_sq : pt -> pt -> float
(**
   [dist_sq a b] is the squared Euclidean distance (no square root), for
   comparisons in tight loops.
   Requires: nothing
   Returns: [(a.x - b.x)^2 + (a.y - b.y)^2]
   Raises: nothing
   Example: dist_sq {x=0.;y=0.} {x=3.;y=4.} = 25.
   Complexity: O(1) time, O(1) space
*)

val lerp : pt -> pt -> float -> pt
(**
   [lerp a b u] is [a + u * (b - a)], linear interpolation.
   Requires: nothing ([u] outside [0, 1] extrapolates)
   Returns: [a] at [u = 0], [b] at [u = 1], the midpoint at [u = 0.5]
   Raises: nothing
   Example: lerp {x=0.;y=0.} {x=10.;y=2.} 0.5 = {x=5.;y=1.}
   Complexity: O(1) time, O(1) space
*)

val centroid : pt array -> pt
(**
   [centroid pts] is the mean of the points.
   Requires: [pts] is non-empty
   Returns: [(sum x / n, sum y / n)]
   Raises: [Invalid_argument] on an empty array
   Example: centroid [|{x=0.;y=0.}; {x=2.;y=4.}|] = {x=1.;y=2.}
   Complexity: O(n) time, O(1) space
*)

val bbox_diagonal : pt array -> float
(**
   [bbox_diagonal pts] is the length of the diagonal of the axis-aligned
   bounding box of [pts], a size measure that ignores point count.
   Requires: nothing
   Returns: [sqrt ((max_x - min_x)^2 + (max_y - min_y)^2)]; [0.] for an
            empty or single-point array
   Raises: nothing
   Example: bbox_diagonal [|{x=0.;y=0.}; {x=3.;y=1.}; {x=1.;y=4.}|] = 5.
   Complexity: O(n) time, O(1) space
*)

val wrap_angle : float -> float
(**
   [wrap_angle a] brings an angle into (-pi, pi], so blending always takes
   the shorter turn.
   Requires: [a] is finite
   Returns: the unique [a'] in (-pi, pi] with [a' = a + 2 k pi]
   Raises: nothing
   Example: wrap_angle (3. *. Float.pi /. 2.) = -. Float.pi /. 2.
   Complexity: O(1) time, O(1) space
*)

(** {1 Similarity transforms} *)

val apply : sim -> pt -> pt
(**
   [apply t p] is [t.s * R(t.theta) * p + (t.tx, t.ty)].
   Requires: nothing
   Returns: the image of [p] under [t]
   Raises: nothing
   Example: apply { s = 2.; theta = 0.; tx = 1.; ty = 0. } {x=1.;y=1.} = {x=3.;y=2.}
   Complexity: O(1) time, O(1) space
*)

val apply_all : sim -> pt array -> pt array
(**
   [apply_all t pts] maps {!apply} [t] over every point.
   Requires: nothing
   Returns: a fresh array, same length and order as [pts]
   Raises: nothing
   Example: apply_all identity [|{x=1.;y=2.}|] = [|{x=1.;y=2.}|]
   Complexity: O(n) time, O(n) space
*)

val sim_of_pair : pt -> pt -> pt -> pt -> sim
(**
   [sim_of_pair a b a' b'] is the similarity that maps [a] to [a'] and
   [b] to [b'] (the two-handle rule of GIMP's Handle Transform tool):
   - [s = |b' - a'| / |b - a|]
   - [theta = atan2 (b' - a') - atan2 (b - a)]
   - [t = a' - s * R(theta) * a]
   Requires: [a <> b] (more than 1e-12 apart)
   Returns: [t] with [apply t a = a'] and [apply t b = b'] (to rounding)
   Raises: [Invalid_argument] when [a] and [b] coincide
   Example: sim_of_pair {x=0.;y=0.} {x=1.;y=0.} {x=0.;y=0.} {x=0.;y=2.}
            = { s = 2.; theta = pi/2; tx = 0.; ty = 0. }
   Complexity: O(1) time, O(1) space
*)

val procrustes : pt array -> pt array -> sim option
(**
   [procrustes p q] is the least-squares similarity mapping [p.(i)] onto
   [q.(i)] for every [i] (closed-form 2-D Procrustes):
   - centre both sets: [p' = p - c_p], [q' = q - c_q]
   - [a = sum (p'x * q'x + p'y * q'y)], [b = sum (p'x * q'y - p'y * q'x)]
   - [theta = atan2 b a], [s = sqrt (a^2 + b^2) / sum |p'|^2]
   - [t = c_q - s * R(theta) * c_p]
   Requires: nothing (bad inputs give [None])
   Returns: [Some t] minimising [sum |apply t p.(i) - q.(i)|^2]; [None]
            when the arrays differ in length, have fewer than 2 points,
            or [sum |p'|^2 < 1e-9] (epsilon test, never exact zero)
   Raises: nothing
   Example: procrustes [|{x=0.;y=0.};{x=1.;y=0.}|] [|{x=5.;y=5.};{x=5.;y=7.}|]
            = Some { s = 2.; theta = pi/2; tx = 5.; ty = 5. }
   Complexity: O(n) time, O(n) space
*)

val rms : sim -> pt array -> pt array -> float
(**
   [rms t p q] is [sqrt (mean |apply t p.(i) - q.(i)|^2)], the
   root-mean-square residual of [t] as a fit from [p] to [q].
   Requires: [p] and [q] have the same, non-zero length
   Returns: the RMS gap in the units of [q]; [0.] for empty input
   Raises: [Invalid_argument] if the lengths differ
   Example: rms identity [|{x=0.;y=0.}|] [|{x=3.;y=4.}|] = 5.
   Complexity: O(n) time, O(1) space
*)

val mirror_y : pt array -> pt array
(**
   [mirror_y pts] reflects every point through the x axis ([y -> -y]),
   for the optional mirror pass in {!Fitter}.
   Requires: nothing
   Returns: a fresh array of the reflected points, same order
   Raises: nothing
   Example: mirror_y [|{x=1.;y=2.}|] = [|{x=1.;y=-2.}|]
   Complexity: O(n) time, O(n) space
*)

(** {1 Sky projections} *)

val gnomonic : centre:float * float -> float * float -> pt option
(**
   [gnomonic ~centre (ra, dec)] projects a sky position onto the plane
   tangent to the sky at [centre]. Straight lines on the sky stay
   straight, so flat-geometry shape keys are valid for small patches.
   The plane is in screen orientation: x toward west, y toward south.
   Requires: all angles in radians
   Returns: [Some p] with [p] in radians on the tangent plane ([centre]
            itself maps to the origin); [None] for positions 90 degrees
            or more from [centre]
   Raises: nothing
   Example: gnomonic ~centre:(0., 0.) (0., 0.) = Some {x=0.;y=0.}
   Complexity: O(1) time, O(1) space
*)

val angular_sep : float * float -> float * float -> float
(**
   [angular_sep (ra1, dec1) (ra2, dec2)] is the great-circle distance
   between two sky positions (haversine formula, stable for tiny angles).
   Requires: all angles in radians
   Returns: the separation in radians, in [0, pi]
   Raises: nothing
   Example: angular_sep (0., 0.) (0., Float.pi /. 2.) = Float.pi /. 2.
   Complexity: O(1) time, O(1) space
*)

val deg : float -> float
(**
   [deg r] converts radians to degrees.
   Requires: nothing
   Returns: [r *. 180. /. pi]
   Raises: nothing
   Example: deg Float.pi = 180.
   Complexity: O(1) time, O(1) space
*)

val rad : float -> float
(**
   [rad d] converts degrees to radians.
   Requires: nothing
   Returns: [d *. pi /. 180.]
   Raises: nothing
   Example: rad 180. = Float.pi
   Complexity: O(1) time, O(1) space
*)
