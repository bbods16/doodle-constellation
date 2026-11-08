(* Unit vectors on the celestial sphere. See skyvec.mli. *)

type v = { vx : float; vy : float; vz : float }

(**
   [of_radec (ra, dec)] is the unit vector toward [(ra, dec)].
   Requires: radians
   Returns: the Cartesian unit vector
   Raises: nothing
   Example: of_radec (0., 0.) = { vx = 1.; vy = 0.; vz = 0. }
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return (cos dec cos ra, cos dec sin ra, sin dec)
*)
let of_radec (ra, dec) =
  let cd = cos dec in
  { vx = cd *. cos ra; vy = cd *. sin ra; vz = sin dec }

(**
   [dot a b] is the scalar product.
   Requires: nothing
   Returns: [a.vx b.vx + a.vy b.vy + a.vz b.vz]
   Raises: nothing
   Example: dot (of_radec (0., 0.)) (of_radec (0., 0.)) = 1.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return a.vx*b.vx + a.vy*b.vy + a.vz*b.vz
*)
let dot a b = (a.vx *. b.vx) +. (a.vy *. b.vy) +. (a.vz *. b.vz)

(**
   [centre ps] is the direction of the mean unit vector.
   Requires: non-empty, non-cancelling
   Returns: [(ra, dec)], [ra] in [0, 2 pi)
   Raises: [Invalid_argument] on empty input or a zero mean
   Example: centre [(0., 0.1); (0., -0.1)] = (0., 0.)
   Complexity: O(n) time, O(1) space
   Pseudocode:
     if ps = [] then fail
     m <- sum of of_radec p over ps
     if |m| < 1e-12 then fail
     ra <- atan2 m.vy m.vx, shifted into [0, 2pi)
     dec <- atan2 m.vz (hypot m.vx m.vy)
     return (ra, dec)
*)
let centre ps =
  if ps = [] then invalid_arg "Skyvec.centre: empty";
  let sx, sy, sz =
    List.fold_left
      (fun (sx, sy, sz) p ->
        let u = of_radec p in
        (sx +. u.vx, sy +. u.vy, sz +. u.vz))
      (0., 0., 0.) ps
  in
  let rho = Float.hypot sx sy in
  if Float.hypot rho sz < 1e-12 then invalid_arg "Skyvec.centre: zero mean";
  let ra = Float.atan2 sy sx in
  let ra = if ra < 0. then ra +. (2. *. Float.pi) else ra in
  (ra, Float.atan2 sz rho)
