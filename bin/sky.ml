(**
   File: sky.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Sky module: the raylib renderer - stars, matched
                patterns and labels, strokes, fit info and screenshots.
   Usage: The contract is in sky.mli.
          Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(* Sky renderer. See sky.mli for the public contract. *)

open Raylib

(* The projection maths lives in lib/projection.ml (pure, testable);
   it is re-exported here so this module's interface is unchanged. *)
type view = Projection.view = {
  stars : Catalogue.star array;
  centre : float * float;
  px_per_rad : float;
  origin : Geom.pt;
}

let stereographic = Projection.stereographic
let to_screen = Projection.to_screen
let view_for = Projection.view_for
let empty_view = Projection.empty_view
let star_radius = Projection.star_radius
let star_colour = Color.create 230 235 255 255
let line_colour = Color.create 120 190 255 255
let text_colour = Color.create 200 210 230 255

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
          draw_text
            (Catalogue.label v.stars.(i))
            (int_of_float p.x + 8)
            (int_of_float p.y - 8)
            16 (fade text_colour alpha))
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
  draw_text
    (Printf.sprintf "Fit error: %.2f deg%s" fit.rms_deg
       (if fit.mirrored then " (mirrored)" else ""))
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
