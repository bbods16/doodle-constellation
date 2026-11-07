(** Sky renderer: the only module besides [main.ml] that calls raylib.

    Projects the matched patch of sky stereographically (it keeps small
    shapes recognisable), draws stars, pattern lines, labels and the
    morphing stroke, and saves the share card.

    Orientation matches {!Geom.gnomonic}: the stereographic plane has x
    toward west and y toward north, and {!to_screen} flips y, so the
    screen shows the sky as seen facing it (north up, east left). *)

type view = {
  stars : Catalogue.star array;
  centre : float * float;    (** (ra, dec) at the middle of the screen *)
  px_per_rad : float;        (** zoom *)
  origin : Geom.pt;          (** screen position of [centre] *)
}

val stereographic : centre:float * float -> float * float -> Geom.pt
(**
   [stereographic ~centre (ra, dec)] projects onto the plane tangent at
   [centre]; undefined only at the point opposite [centre].
   Requires: radians; [(ra, dec)] not antipodal to [centre]
   Returns: a plane point in radians-ish units (x west, y north),
            [{x=0.;y=0.}] for [centre] itself
   Raises: nothing (the antipode gives infinities)
   Example: stereographic ~centre:(1., 0.2) (1., 0.2) = {x=0.;y=0.}
   Complexity: O(1) time, O(1) space
*)

val to_screen : view -> float * float -> Geom.pt
(**
   [to_screen v pos] is [origin + px_per_rad * stereographic], with y
   flipped so north is up.
   Requires: radians
   Returns: screen pixels
   Raises: nothing
   Example: to_screen v v.centre = v.origin
   Complexity: O(1) time, O(1) space
*)

val view_for : Catalogue.star array -> Fitter.fit -> width:int -> height:int -> view
(**
   [view_for stars fit ~width ~height] centres on the fit and zooms so
   the matched stars fill about 60% of the shorter side of the window.
   Requires: [fit.stars] non-empty, indices into [stars]
   Returns: a view whose matched stars are centred on screen
   Raises: nothing
   Example: view_for stars fit ~width:1280 ~height:800 = { centre = fit.centre; ... }
   Complexity: O(n) time, O(n) space, n matched stars
*)

val empty_view : Catalogue.star array -> width:int -> height:int -> view
(**
   [empty_view stars ~width ~height] is a wide default view (centred on
   Orion, about 100 degrees across the shorter side) for the blank sky
   before the first match.
   Requires: positive window size
   Returns: a view centred on screen
   Raises: nothing
   Example: (empty_view stars ~width:1280 ~height:800).origin = {x=640.;y=400.}
   Complexity: O(1) time, O(1) space
*)

val star_radius : float -> float
(**
   [star_radius mag] is the dot radius in pixels from magnitude: about
   4.5 for magnitude 0, 1 for magnitude 4.5, linear in between, clamped
   to [1, 6].
   Requires: nothing
   Returns: a radius in [1, 6]
   Raises: nothing
   Example: star_radius 0. = 4.5
   Complexity: O(1) time, O(1) space
*)

val to_vector2 : Geom.pt -> Raylib.Vector2.t
(**
   [to_vector2 p] converts to raylib's vector type.
   Requires: nothing
   Returns: [Vector2.create p.x p.y]
   Raises: nothing
   Example: Vector2.x (to_vector2 {x=1.;y=2.}) = 1.
   Complexity: O(1) time, O(1) space
*)

val draw : view -> Fitter.fit option -> unit
(**
   [draw v fit] draws, inside [begin_drawing]/[end_drawing]: background
   stars with [draw_circle_v], the matched pattern with [draw_line_ex],
   labels with [draw_text]. A [weak] fit is drawn dimmed with the error
   and a hint. Does not clear the background.
   Requires: an open raylib window, inside a drawing block
   Returns: unit
   Raises: nothing
   Example: draw v None draws only the background stars
   Complexity: O(N + n) time, O(1) space
*)

val draw_stroke : Geom.pt array -> unit
(**
   [draw_stroke pts] draws the (morphing) stroke with
   [draw_spline_catmull_rom], which needs at least 4 points; falls back
   to [draw_line_strip] below that (nothing for fewer than 2). Points
   are passed as [CArray.start (CArray.of_list Vector2.t pts)].
   Requires: an open raylib window, inside a drawing block
   Returns: unit
   Raises: nothing
   Example: draw_stroke [||] draws nothing
   Complexity: O(n) time, O(n) space
*)

val draw_info :
  fit:Fitter.fit -> best:(float * float * float) option -> unit
(**
   [draw_info ~fit ~best] writes the fit error, best viewing time
   (local clock) and direction as text in the lower-left corner.
   Requires: an open raylib window, inside a drawing block
   Returns: unit
   Raises: nothing
   Example: draw_info ~fit ~best:None shows only the error line
   Complexity: O(1) time, O(1) space
*)

val save_card : string -> unit
(**
   [save_card path] saves the current frame with [take_screenshot].
   Requires: an open raylib window; call after [end_drawing]
   Returns: unit (raylib writes the file next to the executable's
            working directory)
   Raises: nothing
   Example: save_card "doodle_card.png"
   Complexity: O(W * H) time and space for the frame
*)
