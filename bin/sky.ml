(* Sky renderer. See sky.mli for the public contract. *)

open Raylib

type view = {
  stars : Catalogue.star array;
  centre : float * float;
  px_per_rad : float;
  origin : Geom.pt;
}

let star_colour = Color.create 230 235 255 255
let line_colour = Color.create 120 190 255 255
let text_colour = Color.create 200 210 230 255

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

(**
   [to_vector2 p] converts to raylib.
   Requires: nothing
   Returns: a Vector2
   Raises: nothing
   Example: Vector2.x (to_vector2 {x=1.;y=2.}) = 1.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return Vector2.create p.x p.y
*)
let to_vector2 (p : Geom.pt) = Vector2.create p.x p.y

(**
   [draw v fit] draws background stars, the pattern and labels.
   Requires: inside a drawing block
   Returns: unit
   Raises: nothing
   Example: draw v None draws only the background stars
   Complexity: O(N + n) time
   Pseudocode:
     alpha <- if fit is weak then 0.4 else 1
     for each star within 80 degrees of v.centre:
       draw_circle_v (to_screen star) (star_radius mag) star colour
     match fit with
       | None -> ()
       | Some f ->
           pts <- to_screen of each matched star, corner order
           draw_line_ex between consecutive pts (faded by alpha)
           draw_text label next to each matched star
           if weak then draw_text the RMS error and a hint
*)
let draw v fit =
  let w = float_of_int (get_screen_width ()) and h = float_of_int (get_screen_height ()) in
  let limit = Geom.rad 80. in
  Array.iter
    (fun (s : Catalogue.star) ->
      let pos = Catalogue.position s in
      if Geom.angular_sep pos v.centre < limit then begin
        let p = to_screen v pos in
        if p.x > -10. && p.x < w +. 10. && p.y > -10. && p.y < h +. 10. then
          draw_circle_v (to_vector2 p) (star_radius s.mag) star_colour
      end)
    v.stars;
  match fit with
  | None -> ()
  | Some (f : Fitter.fit) ->
      let alpha = if f.weak then 0.4 else 1. in
      let pts = Array.map (fun i -> to_screen v (Catalogue.position v.stars.(i))) f.stars in
      for i = 0 to Array.length pts - 2 do
        draw_line_ex (to_vector2 pts.(i)) (to_vector2 pts.(i + 1)) 2.5 (fade line_colour alpha)
      done;
      Array.iteri
        (fun k i ->
          let p = pts.(k) in
          draw_text (Catalogue.label v.stars.(i)) (int_of_float p.x + 8) (int_of_float p.y - 8) 16
            (fade text_colour alpha))
        f.stars;
      if f.weak then
        draw_text
          (Printf.sprintf "Weak match (%.1f deg off) - try a bolder, simpler shape" f.rms_deg)
          20 20 20 Color.gold

(**
   [draw_stroke pts] draws the stroke as a spline or polyline.
   Requires: inside a drawing block
   Returns: unit
   Raises: nothing
   Example: draw_stroke [||] draws nothing
   Complexity: O(n) time, O(n) space
   Pseudocode:
     n <- |pts|
     if n < 2 then return
     arr <- CArray.of_list Vector2.t (map to_vector2 pts)
     if n >= 4 then draw_spline_catmull_rom (CArray.start arr) n 3 colour
     else draw_line_strip (CArray.start arr) n colour
*)
let draw_stroke pts =
  let n = Array.length pts in
  if n >= 2 then begin
    let arr = Ctypes.CArray.of_list Vector2.t (List.map to_vector2 (Array.to_list pts)) in
    if n >= 4 then draw_spline_catmull_rom (Ctypes.CArray.start arr) n 3. Color.skyblue
    else draw_line_strip (Ctypes.CArray.start arr) n Color.skyblue
  end

(**
   [draw_info ~fit ~best] writes the fit summary.
   Requires: inside a drawing block
   Returns: unit
   Raises: nothing
   Example: draw_info ~fit ~best:None shows only the error line
   Complexity: O(1) time, O(1) space
   Pseudocode:
     y <- screen height - 70
     draw_text "Fit error: X.XX deg" at (20, y)
     match best with
       | Some (t, alt, az) ->
           tm <- localtime t
           draw_text "Best view: HH:MM, NN deg up, look <compass az>" at (20, y + 28)
       | None -> ()
*)
let draw_info ~(fit : Fitter.fit) ~best =
  let y = get_screen_height () - 70 in
  draw_text (Printf.sprintf "Fit error: %.2f deg%s" fit.rms_deg (if fit.mirrored then " (mirrored)" else ""))
    20 y 20 text_colour;
  match best with
  | Some (t, alt, az) ->
      let tm = Unix.localtime t in
      draw_text
        (Printf.sprintf "Best view: %02d:%02d, %.0f deg up, look %s" tm.Unix.tm_hour tm.Unix.tm_min
           (Geom.deg alt) (Visibility.compass az))
        20 (y + 28) 20 text_colour
  | None -> ()

(**
   [save_card path] writes a screenshot.
   Requires: an open window
   Returns: unit
   Raises: nothing
   Example: save_card "doodle_card.png"
   Complexity: O(W H)
   Pseudocode:
     take_screenshot path
*)
let save_card path = take_screenshot path
