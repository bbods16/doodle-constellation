(**
   File: projection.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Projection module: sky-to-screen maths -
                stereographic projection and framing a match on screen.
   Usage: The contract is in projection.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Projection (or Projection with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Sky-to-screen projection. See projection.mli for the public contract. *)

type view = {
  stars : Catalogue.star array;
  centre : float * float;
  px_per_rad : float;
  origin : Geom.pt;
}

(**
   [stereographic ~centre (ra, dec)] is the stereographic projection.
   Requires: radians, not antipodal
   Returns: plane point, x west, y north
   Raises: nothing
   Example: stereographic ~centre:(1., 0.2) (1., 0.2) = {x=0.;y=0.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     (ra0, dec0) <- centre ; dra <- ra - ra0
     cos_c <- sin dec0 sin dec + cos dec0 cos dec cos dra
     k <- 2 / (1 + cos_c)
     east  <- k cos dec sin dra
     north <- k (cos dec0 sin dec - sin dec0 cos dec cos dra)
     return (-east, north)
*)
let stereographic ~centre:(ra0, dec0) (ra, dec) =
  let dra = ra -. ra0 in
  let cos_c = (sin dec0 *. sin dec) +. (cos dec0 *. cos dec *. cos dra) in
  let k = 2. /. (1. +. cos_c) in
  let east = k *. cos dec *. sin dra in
  let north = k *. ((cos dec0 *. sin dec) -. (sin dec0 *. cos dec *. cos dra)) in
  { Geom.x = -.east; y = north }

(**
   [to_screen v pos] maps a sky position to pixels.
   Requires: radians
   Returns: screen point
   Raises: nothing
   Example: to_screen v v.centre = v.origin
   Complexity: O(1) time, O(1) space
   Pseudocode:
     q <- stereographic ~centre:v.centre pos
     return (origin.x + px * q.x, origin.y - px * q.y)
*)
let to_screen v pos =
  let q = stereographic ~centre:v.centre pos in
  { Geom.x = v.origin.x +. (v.px_per_rad *. q.x); y = v.origin.y -. (v.px_per_rad *. q.y) }

(**
   [view_for stars fit ~width ~height] frames the matched stars.
   Requires: non-empty [fit.stars]
   Returns: a centred, zoomed view
   Raises: nothing
   Example: view_for stars fit ~width:1280 ~height:800 = { centre = fit.centre; ... }
   Complexity: O(n) time, O(n) space
   Pseudocode:
     q <- stereographic ~centre:fit.centre of each matched star
     span <- max (bbox width, bbox height) of q, at least 1e-4
     px <- 0.6 * min width height / span
     mid <- bbox centre of q
     origin <- screen centre - px * (mid.x, -mid.y)   (* centres the bbox *)
     return { stars; centre = fit.centre; px_per_rad = px; origin }
*)
let view_for stars (fit : Fitter.fit) ~width ~height =
  let qs =
    Array.map (fun i -> stereographic ~centre:fit.centre (Catalogue.position stars.(i))) fit.stars
  in
  let fold f init = Array.fold_left f init qs in
  let minx = fold (fun m q -> Float.min m q.Geom.x) infinity
  and maxx = fold (fun m q -> Float.max m q.Geom.x) neg_infinity
  and miny = fold (fun m q -> Float.min m q.Geom.y) infinity
  and maxy = fold (fun m q -> Float.max m q.Geom.y) neg_infinity in
  let span = Float.max 1e-4 (Float.max (maxx -. minx) (maxy -. miny)) in
  let short = float_of_int (min width height) in
  let px = 0.6 *. short /. span in
  let midx = (minx +. maxx) /. 2. and midy = (miny +. maxy) /. 2. in
  let origin =
    { Geom.x = (float_of_int width /. 2.) -. (px *. midx);
      y = (float_of_int height /. 2.) +. (px *. midy) }
  in
  { stars; centre = fit.centre; px_per_rad = px; origin }

(**
   [empty_view stars ~width ~height] is the wide starting view.
   Requires: positive size
   Returns: view centred on Orion
   Raises: nothing
   Example: (empty_view stars ~width:1280 ~height:800).origin = {x=640.;y=400.}
   Complexity: O(1) time, O(1) space
   Pseudocode:
     centre <- (rad 84, rad 0)
     px <- min width height / (2 tan (rad 50 / 2) * 2)  (* ~100 degrees across *)
     return { stars; centre; px_per_rad = px; origin = screen centre }
*)
let empty_view stars ~width ~height =
  let short = float_of_int (min width height) in
  (* stereographic radius of a point 50 degrees out is 2 tan 25 *)
  let px = short /. (2. *. 2. *. tan (Geom.rad 25.)) in
  { stars; centre = (Geom.rad 84., 0.); px_per_rad = px;
    origin = { Geom.x = float_of_int width /. 2.; y = float_of_int height /. 2. } }

(**
   [star_radius mag] is the dot size from brightness.
   Requires: nothing
   Returns: radius in [1, 6]
   Raises: nothing
   Example: star_radius 0. = 4.5
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return clamp 1 6 (4.5 - mag * 3.5 / 4.5)
*)
let star_radius mag = Float.max 1. (Float.min 6. (4.5 -. (mag *. 3.5 /. 4.5)))
