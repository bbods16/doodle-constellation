(** Sky-to-screen projection: the pure maths behind the renderer.

    Split out of [bin/sky.ml] so the game logic ({!Game}) can place stars
    on screen without depending on raylib. [Sky] re-exports everything
    here, so its interface is unchanged.

    The stereographic plane has x toward west and y toward north;
    {!to_screen} flips y, so the screen shows the sky as seen facing it
    (north up, east left), matching {!Geom.gnomonic}. *)

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
   Returns: a plane point (x west, y north); the origin for [centre]
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
   [view_for stars fit ~width ~height] centres on the fit and zooms so the
   matched stars fill about 60% of the shorter side of the window.
   Requires: [fit.stars] non-empty, indices into [stars]
   Returns: a view whose matched stars are centred on screen
   Raises: nothing
   Example: (view_for stars fit ~width:1280 ~height:800).centre = fit.centre
   Complexity: O(n) time, O(n) space, n matched stars
*)

val empty_view : Catalogue.star array -> width:int -> height:int -> view
(**
   [empty_view stars ~width ~height] is a wide default view (centred on
   Orion, about 100 degrees across the shorter side).
   Requires: positive window size
   Returns: a view centred on screen
   Raises: nothing
   Example: (empty_view stars ~width:1280 ~height:800).origin = {x=640.;y=400.}
   Complexity: O(1) time, O(1) space
*)

val star_radius : float -> float
(**
   [star_radius mag] is the dot radius in pixels from magnitude: about
   4.5 for magnitude 0, 1 for magnitude 4.5, clamped to [1, 6].
   Requires: nothing
   Returns: a radius in [1, 6]
   Raises: nothing
   Example: star_radius 0. = 4.5
   Complexity: O(1) time, O(1) space
*)
