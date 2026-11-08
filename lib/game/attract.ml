(* Welcome-page background animation. See attract.mli for the contract. *)

type t = { figures : Asterism.t array; index : int; clock : float }

let seconds_per_figure = 3.0
let hold_seconds = 1.5
let fade_seconds = 0.5

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
   Complexity: O(1) amortised
   Pseudocode:
     if no figures then a
     clock <- a.clock + dt ; cycle <- seconds_per_figure + hold_seconds
     while clock >= cycle: clock -= cycle ; index <- (index + 1) mod n
*)
let step dt a =
  let n = Array.length a.figures in
  if n = 0 then a
  else begin
    let cycle = seconds_per_figure +. hold_seconds in
    let clock = a.clock +. dt in
    let laps = int_of_float (Float.floor (clock /. cycle)) in
    { a with index = (a.index + laps) mod n; clock = clock -. (float_of_int laps *. cycle) }
  end

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
let current a =
  if Array.length a.figures = 0 then None
  else Some (a.figures.(a.index), Float.min 1. (a.clock /. seconds_per_figure))

(**
   [alpha a] is the opacity.
   Requires: nothing
   Returns: value in [0, 1]
   Raises: nothing
   Example: alpha (create [| orion |]) = 1.
   Complexity: O(1)
   Pseudocode:
     left <- seconds_per_figure + hold_seconds - clock
     return clamp 0 1 (left / fade_seconds)
*)
let alpha a =
  let left = seconds_per_figure +. hold_seconds -. a.clock in
  Float.max 0. (Float.min 1. (left /. fade_seconds))

(**
   [place shape box] fits a shape into a box, centred, filling 80% of it.
   Requires: [shape] non-empty
   Returns: the shape in screen pixels
   Raises: nothing
   Example: place [|{x=0.;y=0.}|] box = [| centre of box |]
   Complexity: O(k)
   Pseudocode:
     bounding box of shape ; k <- 0.8 * min (box.w / bw) (box.h / bh)
     map p -> box centre + k (p - shape bbox centre)
*)
let place (shape : Geom.pt array) (box : Menu.rect) =
  let fold f init = Array.fold_left f init shape in
  let minx = fold (fun m (p : Geom.pt) -> Float.min m p.x) infinity
  and maxx = fold (fun m (p : Geom.pt) -> Float.max m p.x) neg_infinity
  and miny = fold (fun m (p : Geom.pt) -> Float.min m p.y) infinity
  and maxy = fold (fun m (p : Geom.pt) -> Float.max m p.y) neg_infinity in
  let bw = Float.max 1e-9 (maxx -. minx) and bh = Float.max 1e-9 (maxy -. miny) in
  let k = 0.8 *. Float.min (box.w /. bw) (box.h /. bh) in
  let cx = (minx +. maxx) /. 2. and cy = (miny +. maxy) /. 2. in
  let bx = box.x +. (box.w /. 2.) and by = box.y +. (box.h /. 2.) in
  Array.map (fun (p : Geom.pt) -> { Geom.x = bx +. (k *. (p.x -. cx)); y = by +. (k *. (p.y -. cy)) }) shape

(**
   [visible_path a ~box] is the drawn part, on screen.
   Requires: nothing
   Returns: polyline in pixels
   Raises: nothing
   Example: visible_path (create [| orion |]) ~box = [||]
   Complexity: O(k)
   Pseudocode:
     (f, frac) <- current a (else [||]) ; if frac <= 0 then [||]
     pts <- place (Asterism.shape f) box
     return the prefix of pts covering frac of its length
*)
let visible_path a ~box =
  match current a with
  | None -> [||]
  | Some (_, frac) when frac <= 0. -> [||]
  | Some (f, frac) -> Accuracy.prefix (place (Asterism.shape f) box) frac

(**
   [star_points a ~box] is the figure's stars on screen.
   Requires: nothing
   Returns: one point per distinct star
   Raises: nothing
   Example: Array.length (star_points (create [| orion |]) ~box) = 6
   Complexity: O(k^2)
   Pseudocode:
     pts <- place (Asterism.shape f) box
     keep each point whose star index has not appeared before
*)
let star_points a ~box =
  match current a with
  | None -> [||]
  | Some (f, _) ->
      let pts = place (Asterism.shape f) box and ids = Asterism.star_indices f in
      let seen = Hashtbl.create 8 in
      Array.to_list (Array.mapi (fun i p -> (ids.(i), p)) pts)
      |> List.filter_map (fun (id, p) ->
             if Hashtbl.mem seen id then None
             else begin
               Hashtbl.add seen id ();
               Some p
             end)
      |> Array.of_list
