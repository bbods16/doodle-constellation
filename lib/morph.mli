(** Morph animation: slides, turns and scales the drawing onto the stars.

    Interpolates the transform, not the points, the way GIMP's
    [gimp_tool_polygon_fit_segment] moves a whole point list with one
    transform. Pure OCaml; {!Sky} does the drawing. *)

type t
(** An animation in progress: the start centroid [c0], the end transform
    [T1] and the raw progress [u]. Immutable. *)

val duration : float
(** Seconds from start to finish. [1.5]. *)

val ease : float -> float
(**
   [ease u] is smoothstep: [u *. u *. (3. -. 2. *. u)].
   Requires: [u] in [0, 1] (values outside are clamped first)
   Returns: a value in [0, 1] with zero slope at both ends
   Raises: nothing
   Example: ease 0.5 = 0.5
   Complexity: O(1) time, O(1) space
*)

val start : drawn:Geom.pt array -> target:Geom.pt array -> t
(**
   [start ~drawn ~target] fits the end transform with {!Geom.procrustes}
   from the drawn corners to the matched stars' screen positions (falls
   back to {!Geom.identity} if that fails), and records [c0], the
   centroid of [drawn]. Progress starts at 0.
   Requires: [drawn] non-empty
   Returns: a fresh animation
   Raises: [Invalid_argument] if [drawn] is empty
   Example: progress (start ~drawn ~target) = 0.
   Complexity: O(n) time, O(n) space
*)

val step : t -> float -> t
(**
   [step t dt] advances progress by [dt /. duration], capped at 1.
   Pass [get_frame_time ()].
   Requires: [dt >= 0.]
   Returns: the advanced animation
   Raises: nothing
   Example: progress (step (start ~drawn ~target) 0.75) = 0.5
   Complexity: O(1) time, O(1) space
*)

val progress : t -> float
(**
   [progress t] is the raw progress [u].
   Requires: nothing
   Returns: a value in [0, 1]
   Raises: nothing
   Example: progress (start ~drawn ~target) = 0.
   Complexity: O(1) time, O(1) space
*)

val finished : t -> bool
(**
   [finished t] is [progress t >= 1.].
   Requires: nothing
   Returns: whether the animation is complete
   Raises: nothing
   Example: finished (step (start ~drawn ~target) 10.) = true
   Complexity: O(1) time, O(1) space
*)

val current_sim : t -> Geom.sim
(**
   [current_sim t] is the blended transform at eased progress [e]:
   scale [s1 ** e], angle [e *. wrap_angle theta1], and the centroid
   moved in a straight line from [c0] to [T1 c0].
   Requires: nothing
   Returns: {!Geom.identity} at [e = 0] and [T1] at [e = 1]
   Raises: nothing
   Example: current_sim (start ~drawn ~target) = Geom.identity
   Complexity: O(1) time, O(1) space
*)

val current : t -> Geom.pt array -> Geom.pt array
(**
   [current t pts] applies {!current_sim} to any point list, normally
   every smoothed stroke point:
   [p -> c(e) + s(e) * R(theta(e)) * (p - c0)].
   Requires: nothing
   Returns: a fresh array, same order
   Raises: nothing
   Example: current (start ~drawn ~target) pts = pts
   Complexity: O(n) time, O(n) space
*)

val end_sim : t -> Geom.sim
(**
   [end_sim t] is the final transform [T1].
   Requires: nothing
   Returns: the Procrustes fit (or identity) chosen by {!start}
   Raises: nothing
   Example: end_sim (start ~drawn:p ~target:p) = Geom.identity (to rounding)
   Complexity: O(1) time, O(1) space
*)
