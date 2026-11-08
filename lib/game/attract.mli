(** Attract: the welcome page's background animation, in which each
    constellation figure draws itself star by star, then fades, and the
    next begins (an arcade "attract mode"). Pure: given the time, it says
    what to draw; [Title_view] draws it.

    PLANNED (welcome page) — interface only; the implementation is a stub.
    See [docs/WELCOME_PLAN.md]. *)

type t
(** Which figure is showing and how far along it is. Abstract. *)

val seconds_per_figure : float
(** Time to draw one figure completely. [3.0]. *)

val hold_seconds : float
(** Time a finished figure stays before fading to the next. [1.5]. *)

val create : Asterism.t array -> t
(**
   [create figures] starts the animation on the first figure, nothing drawn.
   Requires: nothing ([figures] may be empty)
   Returns: the animation
   Raises: nothing
   Example: Attract.current (create [||]) = None
   Complexity: O(1)
*)

val step : float -> t -> t
(**
   [step dt a] advances the animation by [dt] seconds, moving to the next
   figure (wrapping to the first) after drawing plus holding.
   Requires: [dt >= 0.]
   Returns: the advanced animation
   Raises: nothing
   Example: current (step 10. a) is a later figure than current a
   Complexity: O(1)
*)

val current : t -> (Asterism.t * float) option
(**
   [current a] is the figure being drawn and how much of it is drawn.
   Requires: nothing
   Returns: [Some (figure, fraction)] with [fraction] in [0, 1]
            ([1.] while holding), or [None] with no figures
   Raises: nothing
   Example: current (create [| orion |]) = Some (orion, 0.)
   Complexity: O(1)
*)

val alpha : t -> float
(**
   [alpha a] is the figure's opacity: 1 while drawing and holding,
   fading to 0 over the last half second.
   Requires: nothing
   Returns: a value in [0, 1]
   Raises: nothing
   Example: alpha (create [| orion |]) = 1.
   Complexity: O(1)
*)

val visible_path : t -> box:Menu.rect -> Geom.pt array
(**
   [visible_path a ~box] is the drawn part of the current figure in screen
   pixels: its {!Asterism.shape} scaled and centred to fit [box], cut at
   the drawn fraction of its total length (the last point interpolated
   part-way along a segment).
   Requires: nothing
   Returns: the polyline to draw, empty with no figures or at fraction 0
   Raises: nothing
   Example: visible_path (create [| orion |]) ~box = [||]
   Complexity: O(k), k stars in the figure
*)

val star_points : t -> box:Menu.rect -> Geom.pt array
(**
   [star_points a ~box] is every star of the current figure in screen
   pixels, in the same placement as {!visible_path} (drawn as faint dots
   before the line reaches them).
   Requires: nothing
   Returns: one point per star (repeats removed); empty with no figures
   Raises: nothing
   Example: Array.length (star_points (create [| orion |]) ~box) = 6
   Complexity: O(k)
*)
