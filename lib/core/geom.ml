(**
   File: geom.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Geom module: 2-D geometry - points, similarity
                transforms, Procrustes fitting, the tangent-plane (gnomonic) sky
                projection and angle helpers.
   Usage: The contract is in geom.mli.
          Import: add hack.core to (libraries ...) in a dune file, then use
          Doodle_core.Geom (or Geom with -open Doodle_core).
          Build: dune build    Test: dune test
*)

(* Shared 2-D geometry. See geom.mli for the public contract. *)

type pt = { x : float; y : float }
type sim = { s : float; theta : float; tx : float; ty : float }

let identity = { s = 1.; theta = 0.; tx = 0.; ty = 0. }
let pi = Float.pi
let two_pi = 2. *. Float.pi

(**
   [add a b] is the component-wise sum of [a] and [b].
   Requires: nothing
   Returns: [{ x = a.x +. b.x; y = a.y +. b.y }]
   Raises: nothing
   Example: add {x=1.;y=2.} {x=3.;y=4.} = {x=4.;y=6.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return (a.x + b.x, a.y + b.y)
*)
let add a b = { x = a.x +. b.x; y = a.y +. b.y }

(**
   [sub a b] is the component-wise difference [a - b].
   Requires: nothing
   Returns: the vector pointing from [b] to [a]
   Raises: nothing
   Example: sub {x=3.;y=4.} {x=1.;y=1.} = {x=2.;y=3.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return (a.x - b.x, a.y - b.y)
*)
let sub a b = { x = a.x -. b.x; y = a.y -. b.y }

(**
   [scale k p] multiplies both coordinates of [p] by [k].
   Requires: nothing
   Returns: [{ x = k *. p.x; y = k *. p.y }]
   Raises: nothing
   Example: scale 2. {x=1.;y=-3.} = {x=2.;y=-6.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return (k * p.x, k * p.y)
*)
let scale k p = { x = k *. p.x; y = k *. p.y }

(**
   [rotate theta p] is [R(theta) p].
   Requires: nothing
   Returns: [p] turned [theta] radians counter-clockwise (in a y-up frame)
   Raises: nothing
   Example: rotate (Float.pi /. 2.) {x=1.;y=0.} = {x=0.;y=1.} (to rounding)
   Complexity: O(1) time, O(1) space
   Pseudocode:
     c <- cos theta ; s <- sin theta
     return (c * p.x - s * p.y, s * p.x + c * p.y)
*)
let rotate theta p =
  let c = cos theta and s = sin theta in
  { x = (c *. p.x) -. (s *. p.y); y = (s *. p.x) +. (c *. p.y) }

(**
   [dist_sq a b] is the squared Euclidean distance.
   Requires: nothing
   Returns: [(a.x - b.x)^2 + (a.y - b.y)^2]
   Raises: nothing
   Example: dist_sq {x=0.;y=0.} {x=3.;y=4.} = 25.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     dx <- a.x - b.x ; dy <- a.y - b.y
     return dx*dx + dy*dy
*)
let dist_sq a b =
  let dx = a.x -. b.x and dy = a.y -. b.y in
  (dx *. dx) +. (dy *. dy)

(**
   [dist a b] is the Euclidean distance.
   Requires: nothing
   Returns: [sqrt (dist_sq a b)]
   Raises: nothing
   Example: dist {x=0.;y=0.} {x=3.;y=4.} = 5.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return sqrt (dist_sq a b)
*)
let dist a b = sqrt (dist_sq a b)

(**
   [lerp a b u] is [a + u * (b - a)].
   Requires: nothing
   Returns: [a] at [u = 0], [b] at [u = 1]
   Raises: nothing
   Example: lerp {x=0.;y=0.} {x=10.;y=2.} 0.5 = {x=5.;y=1.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return (a.x + u * (b.x - a.x), a.y + u * (b.y - a.y))
*)
let lerp a b u = { x = a.x +. (u *. (b.x -. a.x)); y = a.y +. (u *. (b.y -. a.y)) }

(**
   [centroid pts] is the mean of the points.
   Requires: [pts] non-empty
   Returns: the average point
   Raises: [Invalid_argument] on an empty array
   Example: centroid [|{x=0.;y=0.}; {x=2.;y=4.}|] = {x=1.;y=2.}
   Complexity: O(n) time, O(1) space
   Pseudocode:
     if n = 0 then fail
     sx, sy <- 0
     for each p in pts: sx += p.x ; sy += p.y
     return (sx / n, sy / n)
*)
let centroid pts =
  let n = Array.length pts in
  if n = 0 then invalid_arg "Geom.centroid: empty array";
  let sx = ref 0. and sy = ref 0. in
  Array.iter
    (fun p ->
      sx := !sx +. p.x;
      sy := !sy +. p.y)
    pts;
  let fn = float_of_int n in
  { x = !sx /. fn; y = !sy /. fn }

(**
   [bbox_diagonal pts] is the diagonal length of the bounding box.
   Requires: nothing
   Returns: the diagonal; [0.] for fewer than 2 points
   Raises: nothing
   Example: bbox_diagonal [|{x=0.;y=0.}; {x=3.;y=1.}; {x=1.;y=4.}|] = 5.
   Complexity: O(n) time, O(1) space
   Pseudocode:
     if empty then return 0
     track min_x, max_x, min_y, max_y over all points
     return hypot (max_x - min_x) (max_y - min_y)
*)
let bbox_diagonal pts =
  if Array.length pts = 0 then 0.
  else begin
    let p0 = pts.(0) in
    let minx = ref p0.x and maxx = ref p0.x in
    let miny = ref p0.y and maxy = ref p0.y in
    Array.iter
      (fun p ->
        if p.x < !minx then minx := p.x;
        if p.x > !maxx then maxx := p.x;
        if p.y < !miny then miny := p.y;
        if p.y > !maxy then maxy := p.y)
      pts;
    Float.hypot (!maxx -. !minx) (!maxy -. !miny)
  end

(**
   [wrap_angle a] brings an angle into (-pi, pi].
   Requires: [a] finite
   Returns: the equivalent angle in (-pi, pi]
   Raises: nothing
   Example: wrap_angle (3. *. Float.pi /. 2.) = -. Float.pi /. 2.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     r <- (a + pi) mod 2pi        (* in (-2pi, 2pi) *)
     if r < 0 then r <- r + 2pi   (* now in [0, 2pi) *)
     r <- r - pi                  (* now in [-pi, pi) *)
     if r <= -pi then return pi else return r
*)
let wrap_angle a =
  let r = Float.rem (a +. pi) two_pi in
  let r = if r < 0. then r +. two_pi else r in
  let r = r -. pi in
  if r <= -.pi then pi else r

(**
   [apply t p] is [t.s * R(t.theta) * p + (t.tx, t.ty)].
   Requires: nothing
   Returns: the image of [p] under [t]
   Raises: nothing
   Example: apply { s = 2.; theta = 0.; tx = 1.; ty = 0. } {x=1.;y=1.} = {x=3.;y=2.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     q <- rotate t.theta p
     return (t.s * q.x + t.tx, t.s * q.y + t.ty)
*)
let apply t p =
  let q = rotate t.theta p in
  { x = (t.s *. q.x) +. t.tx; y = (t.s *. q.y) +. t.ty }

(**
   [apply_all t pts] applies [t] to every point.
   Requires: nothing
   Returns: a fresh array of images, same order
   Raises: nothing
   Example: apply_all identity [|{x=1.;y=2.}|] = [|{x=1.;y=2.}|]
   Complexity: O(n) time, O(n) space
   Pseudocode:
     return map (apply t) pts
*)
let apply_all t pts = Array.map (apply t) pts

(**
   [sim_of_pair a b a' b'] maps [a] to [a'] and [b] to [b'].
   Requires: [a] and [b] distinct
   Returns: the unique similarity with those two correspondences
   Raises: [Invalid_argument] when [a] and [b] coincide
   Example: sim_of_pair {x=0.;y=0.} {x=1.;y=0.} {x=0.;y=0.} {x=0.;y=2.}
            = { s = 2.; theta = pi/2; tx = 0.; ty = 0. }
   Complexity: O(1) time, O(1) space
   Pseudocode:
     v <- b - a ; v' <- b' - a'
     if |v| < 1e-12 then fail
     s <- |v'| / |v|
     theta <- atan2 v'.y v'.x - atan2 v.y v.x
     t <- a' - s * R(theta) * a
     return { s; theta; t }
*)
let sim_of_pair a b a' b' =
  let v = sub b a and v' = sub b' a' in
  let len = Float.hypot v.x v.y in
  if len < 1e-12 then invalid_arg "Geom.sim_of_pair: a and b coincide";
  let s = Float.hypot v'.x v'.y /. len in
  let theta = wrap_angle (Float.atan2 v'.y v'.x -. Float.atan2 v.y v.x) in
  let ra = scale s (rotate theta a) in
  { s; theta; tx = a'.x -. ra.x; ty = a'.y -. ra.y }

(**
   [procrustes p q] is the least-squares similarity mapping [p] onto [q].
   Requires: nothing
   Returns: [Some t], or [None] for mismatched lengths, fewer than 2
            points, or a degenerate (collapsed) source set
   Raises: nothing
   Example: procrustes [|{x=0.;y=0.};{x=1.;y=0.}|] [|{x=5.;y=5.};{x=5.;y=7.}|]
            = Some { s = 2.; theta = pi/2; tx = 5.; ty = 5. }
   Complexity: O(n) time, O(n) space
   Pseudocode:
     if |p| <> |q| or |p| < 2 then return None
     cp <- centroid p ; cq <- centroid q
     a, b, norm <- 0
     for i: p' <- p.(i) - cp ; q' <- q.(i) - cq
            a += p'.x q'.x + p'.y q'.y
            b += p'.x q'.y - p'.y q'.x
            norm += |p'|^2
     if norm < 1e-9 then return None
     theta <- atan2 b a ; s <- sqrt (a^2 + b^2) / norm
     t <- cq - s * R(theta) * cp
     return Some { s; theta; t }
*)
let procrustes p q =
  let n = Array.length p in
  if n <> Array.length q || n < 2 then None
  else begin
    let cp = centroid p and cq = centroid q in
    let a = ref 0. and b = ref 0. and norm = ref 0. in
    for i = 0 to n - 1 do
      let p' = sub p.(i) cp and q' = sub q.(i) cq in
      a := !a +. (p'.x *. q'.x) +. (p'.y *. q'.y);
      b := !b +. (p'.x *. q'.y) -. (p'.y *. q'.x);
      norm := !norm +. (p'.x *. p'.x) +. (p'.y *. p'.y)
    done;
    if !norm < 1e-9 then None
    else begin
      let theta = Float.atan2 !b !a in
      let s = Float.hypot !a !b /. !norm in
      let rc = scale s (rotate theta cp) in
      Some { s; theta; tx = cq.x -. rc.x; ty = cq.y -. rc.y }
    end
  end

(**
   [rms t p q] is the root-mean-square residual of [t] from [p] to [q].
   Requires: equal lengths
   Returns: [sqrt (mean |apply t p.(i) - q.(i)|^2)]; [0.] when empty
   Raises: [Invalid_argument] if the lengths differ
   Example: rms identity [|{x=0.;y=0.}|] [|{x=3.;y=4.}|] = 5.
   Complexity: O(n) time, O(1) space
   Pseudocode:
     if |p| <> |q| then fail
     if |p| = 0 then return 0
     acc <- sum over i of dist_sq (apply t p.(i)) q.(i)
     return sqrt (acc / n)
*)
let rms t p q =
  let n = Array.length p in
  if n <> Array.length q then invalid_arg "Geom.rms: length mismatch";
  if n = 0 then 0.
  else begin
    let acc = ref 0. in
    for i = 0 to n - 1 do
      acc := !acc +. dist_sq (apply t p.(i)) q.(i)
    done;
    sqrt (!acc /. float_of_int n)
  end

(**
   [mirror_y pts] reflects every point through the x axis.
   Requires: nothing
   Returns: fresh array with [y] negated
   Raises: nothing
   Example: mirror_y [|{x=1.;y=2.}|] = [|{x=1.;y=-2.}|]
   Complexity: O(n) time, O(n) space
   Pseudocode:
     return map (fun p -> (p.x, -p.y)) pts
*)
let mirror_y pts = Array.map (fun p -> { p with y = -.p.y }) pts

(**
   [gnomonic ~centre (ra, dec)] is the tangent-plane projection.
   Requires: radians
   Returns: [Some p] (x toward west, y toward south), or [None] when the
            position is 90 degrees or more from [centre]
   Raises: nothing
   Example: gnomonic ~centre:(0., 0.) (0., 0.) = Some {x=0.;y=0.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     (ra0, dec0) <- centre ; dra <- ra - ra0
     cos_c <- sin dec0 sin dec + cos dec0 cos dec cos dra
     if cos_c <= 1e-9 then return None          (* on/behind the limb *)
     east  <- cos dec sin dra / cos_c
     north <- (cos dec0 sin dec - sin dec0 cos dec cos dra) / cos_c
     return Some (-east, -north)                (* screen orientation *)
*)
let gnomonic ~centre:(ra0, dec0) (ra, dec) =
  let dra = ra -. ra0 in
  let cos_c = (sin dec0 *. sin dec) +. (cos dec0 *. cos dec *. cos dra) in
  if cos_c <= 1e-9 then None
  else
    let east = cos dec *. sin dra /. cos_c in
    let north = ((cos dec0 *. sin dec) -. (sin dec0 *. cos dec *. cos dra)) /. cos_c in
    Some { x = -.east; y = -.north }

(**
   [angular_sep a b] is the great-circle distance (haversine).
   Requires: radians
   Returns: separation in [0, pi]
   Raises: nothing
   Example: angular_sep (0., 0.) (0., Float.pi /. 2.) = Float.pi /. 2.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     h <- sin^2 ((dec2 - dec1) / 2) + cos dec1 cos dec2 sin^2 ((ra2 - ra1) / 2)
     return 2 asin (sqrt (clamp h to [0, 1]))
*)
let angular_sep (ra1, dec1) (ra2, dec2) =
  let sd = sin ((dec2 -. dec1) /. 2.) and sr = sin ((ra2 -. ra1) /. 2.) in
  let h = (sd *. sd) +. (cos dec1 *. cos dec2 *. sr *. sr) in
  let h = Float.min 1. (Float.max 0. h) in
  2. *. Float.asin (sqrt h)

(**
   [deg r] converts radians to degrees.
   Requires: nothing
   Returns: [r * 180 / pi]
   Raises: nothing
   Example: deg Float.pi = 180.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return r * 180 / pi
*)
let deg r = r *. 180. /. pi

(**
   [rad d] converts degrees to radians.
   Requires: nothing
   Returns: [d * pi / 180]
   Raises: nothing
   Example: rad 180. = Float.pi
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return d * pi / 180
*)
let rad d = d *. pi /. 180.
