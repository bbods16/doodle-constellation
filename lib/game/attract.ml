(* PLANNED (welcome page): stub implementation. The interface in
   attract.mli is the contract; replace each [todo] with the real code.
   See docs/WELCOME_PLAN.md. *)

type t = { figures : Asterism.t array; index : int; clock : float }

let seconds_per_figure = 3.0
let hold_seconds = 1.5

let todo what = failwith ("Attract." ^ what ^ ": not implemented yet (see attract.mli)")

(**
   [create figures] starts on the first figure.
   Requires: nothing
   Returns: index 0, clock 0
   Raises: nothing
   Example: Attract.current (create [||]) = None
   Complexity: O(1)
   Pseudocode:
     return { figures; index = 0; clock = 0 }
*)
let create figures = { figures; index = 0; clock = 0. }

(**
   [step dt a] advances the animation.
   Requires: dt >= 0
   Returns: advanced state
   Raises: nothing
   Example: current (step 10. a) is a later figure
   Complexity: O(1)
   Pseudocode:
     if no figures then a
     clock <- a.clock + dt ; cycle <- seconds_per_figure + hold_seconds
     while clock >= cycle: clock -= cycle ; index <- (index + 1) mod n
*)
let step (_ : float) (_ : t) : t = todo "step"

(**
   [current a] is the figure and drawn fraction.
   Requires: nothing
   Returns: Some (figure, fraction) or None
   Raises: nothing
   Example: current (create [| orion |]) = Some (orion, 0.)
   Complexity: O(1)
   Pseudocode:
     if no figures then None
     else Some (figures.(index), min 1 (clock / seconds_per_figure))
*)
let current (_ : t) : (Asterism.t * float) option = todo "current"

(**
   [alpha a] is the opacity.
   Requires: nothing
   Returns: value in [0, 1]
   Raises: nothing
   Example: alpha (create [| orion |]) = 1.
   Complexity: O(1)
   Pseudocode:
     left <- seconds_per_figure + hold_seconds - clock
     return min 1 (left / 0.5)
*)
let alpha (_ : t) : float = todo "alpha"

(**
   [visible_path a ~box] is the drawn part, on screen.
   Requires: nothing
   Returns: polyline in pixels
   Raises: nothing
   Example: visible_path (create [| orion |]) ~box = [||]
   Complexity: O(k)
   Pseudocode:
     (f, frac) <- current a (else [||])
     pts <- place (Asterism.shape f) in box: centre on the box centre,
            scale so the shape's bounding box fills 80% of the box
     cut <- frac * total length of pts
     return the points up to [cut], ending with the interpolated point
*)
let visible_path (_ : t) ~box:(_ : Menu.rect) : Geom.pt array = todo "visible_path"

(**
   [star_points a ~box] is the figure's stars on screen.
   Requires: nothing
   Returns: one point per distinct star
   Raises: nothing
   Example: Array.length (star_points (create [| orion |]) ~box) = 6
   Complexity: O(k)
   Pseudocode:
     same placement as visible_path, all points, consecutive or closing
     repeats removed
*)
let star_points (_ : t) ~box:(_ : Menu.rect) : Geom.pt array = todo "star_points"
