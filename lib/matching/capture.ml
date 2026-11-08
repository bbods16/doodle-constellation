(* Stroke capture. See capture.mli for the public contract. *)

open Geom

(* Both lists are newest-first so [add] is O(window). *)
type t = { raw_rev : pt list; smooth_rev : pt list; n : int }

let min_step = 2.0
let window = 8
let sigma = 6.0
let empty = { raw_rev = []; smooth_rev = []; n = 0 }

(**
   [smooth recent] is the Gaussian-weighted mean of the newest kept
   points, weighted by distance back along the stroke from the newest.
   Requires: [recent] non-empty, newest first
   Returns: the smoothed position of the newest point
   Raises: nothing
   Example: smooth [{x=5.;y=5.}] = {x=5.;y=5.}
   Complexity: O(window) time, O(1) space
   Pseudocode:
     d <- 0 ; prev <- newest ; sw, sx, sy <- 0
     for the first [window] points q of recent:
       d <- d + |q - prev| ; prev <- q
       w <- exp (-d^2 / (2 sigma^2))
       sw += w ; sx += w q.x ; sy += w q.y
     return (sx / sw, sy / sw)
*)
let smooth recent =
  let two_s2 = 2. *. sigma *. sigma in
  let rec go pts k prev d sw sx sy =
    match pts with
    | q :: rest when k < window ->
        let d = d +. dist q prev in
        let w = exp (-.(d *. d) /. two_s2) in
        go rest (k + 1) q d (sw +. w) (sx +. (w *. q.x)) (sy +. (w *. q.y))
    | _ -> { x = sx /. sw; y = sy /. sw }
  in
  match recent with
  | [] -> invalid_arg "Capture.smooth: empty"
  | p :: _ -> go recent 0 p 0. 0. 0. 0.

(**
   [add t p] offers a new sample to the stroke.
   Requires: screen pixels
   Returns: the updated stroke, or [t] when [p] is too close
   Raises: nothing
   Example: length (add (add empty {x=0.;y=0.}) {x=1.;y=0.}) = 1
   Complexity: O(window) time, O(1) extra space
   Pseudocode:
     match last kept point:
       | Some q when |p - q| < min_step -> return t
       | _ -> raw' <- p :: raw
              return { raw'; smooth = smooth raw' :: smooth; n + 1 }
*)
let add t p =
  match t.raw_rev with
  | q :: _ when dist p q < min_step -> t
  | _ ->
      let raw_rev = p :: t.raw_rev in
      { raw_rev; smooth_rev = smooth raw_rev :: t.smooth_rev; n = t.n + 1 }

(**
   [stroke t] is the smoothed points in drawing order.
   Requires: nothing
   Returns: fresh array, oldest first
   Raises: nothing
   Example: stroke (add empty {x=3.;y=4.}) = [|{x=3.;y=4.}|]
   Complexity: O(n) time, O(n) space
   Pseudocode:
     return array_of (reverse smooth_rev)
*)
let stroke t = Array.of_list (List.rev t.smooth_rev)

(**
   [raw t] is the kept, unsmoothed points in drawing order.
   Requires: nothing
   Returns: fresh array, oldest first
   Raises: nothing
   Example: raw (add empty {x=3.;y=4.}) = [|{x=3.;y=4.}|]
   Complexity: O(n) time, O(n) space
   Pseudocode:
     return array_of (reverse raw_rev)
*)
let raw t = Array.of_list (List.rev t.raw_rev)

(**
   [length t] is the number of kept points.
   Requires: nothing
   Returns: the stored count
   Raises: nothing
   Example: length empty = 0
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return t.n
*)
let length t = t.n

(**
   [is_empty t] is [length t = 0].
   Requires: nothing
   Returns: whether no point was kept
   Raises: nothing
   Example: is_empty empty = true
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return t.n = 0
*)
let is_empty t = t.n = 0
