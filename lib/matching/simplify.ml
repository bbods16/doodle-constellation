(* Stroke simplifier. See simplify.mli for the public contract. *)

open Geom

type reason = [ `Too_simple | `Too_complex ]

let min_corners = 5
let max_corners = 9
let eps_fraction = 0.04
let line_fraction = 0.08
let max_tries = 5

(**
   [max_offset pts] is the largest distance of any point from the chord
   joining the first and last points (from the first point when the
   chord has zero length).
   Requires: [Array.length pts >= 1]
   Returns: the maximum offset in the units of [pts]
   Raises: nothing
   Example: max_offset [|{x=0.;y=0.}; {x=5.;y=3.}; {x=10.;y=0.}|] = 3.
   Complexity: O(n) time, O(1) space
   Pseudocode:
     a <- first ; d <- last - a ; len <- |d|
     best <- 0
     for each p:
       off <- if len < 1e-9 then |p - a|
              else |d.x (a.y - p.y) - d.y (a.x - p.x)| / len
       best <- max best off
     return best
*)
let max_offset pts =
  let n = Array.length pts in
  let a = pts.(0) in
  let d = sub pts.(n - 1) a in
  let len = Float.hypot d.x d.y in
  let best = ref 0. in
  Array.iter
    (fun p ->
      let off =
        if len < 1e-9 then dist p a
        else Float.abs ((d.x *. (a.y -. p.y)) -. (d.y *. (a.x -. p.x))) /. len
      in
      if off > !best then best := off)
    pts;
  !best

(**
   [is_line pts] tells whether the stroke is (nearly) a straight line.
   Requires: nothing
   Returns: [true] when there is nothing distinctive to match
   Raises: nothing
   Example: is_line [|{x=0.;y=0.}; {x=50.;y=1.}; {x=100.;y=0.}|] = true
   Complexity: O(n) time, O(1) space
   Pseudocode:
     if n < 2 then return true
     diag <- bbox_diagonal pts
     if diag < 1e-9 then return true
     return max_offset pts < line_fraction * diag
*)
let is_line pts =
  if Array.length pts < 2 then true
  else
    let diag = bbox_diagonal pts in
    if diag < 1e-9 then true else max_offset pts < line_fraction *. diag

(**
   [rdp ~eps pts] runs Ramer-Douglas-Peucker with absolute tolerance.
   Requires: [eps >= 0.]
   Returns: kept points in order, first and last always included
   Raises: nothing
   Example: rdp ~eps:1. [|{x=0.;y=0.};{x=1.;y=0.1};{x=2.;y=0.}|]
            = [|{x=0.;y=0.};{x=2.;y=0.}|]
   Complexity: O(n^2) worst, O(n log n) typical time; O(n) space
   Pseudocode:
     if n <= 2 then return pts
     keep <- bool array, keep.(0) <- keep.(n-1) <- true
     subdivide i j:
       if j <= i + 1 then return
       a <- pts.(i) ; d <- pts.(j) - a ; len <- |d|
       find k in (i, j) maximising
         v(k) = if len < 1e-9 then |pts.(k) - a|
                else |d.x (a.y - p.y) - d.y (a.x - p.x)|
       limit <- if len < 1e-9 then eps else eps * len
       if v(k) > limit then keep.(k) <- true ; subdivide i k ; subdivide k j
     subdivide 0 (n-1)
     return the points whose keep flag is set, in order
*)
let rdp ~eps pts =
  let n = Array.length pts in
  if n <= 2 then Array.copy pts
  else begin
    let keep = Array.make n false in
    keep.(0) <- true;
    keep.(n - 1) <- true;
    let rec subdivide i j =
      if j > i + 1 then begin
        let a = pts.(i) in
        let d = sub pts.(j) a in
        let len = Float.hypot d.x d.y in
        let closed = len < 1e-9 in
        let best = ref (-1.) and best_k = ref (-1) in
        for k = i + 1 to j - 1 do
          let p = pts.(k) in
          let v =
            if closed then dist p a
            else Float.abs ((d.x *. (a.y -. p.y)) -. (d.y *. (a.x -. p.x)))
          in
          if v > !best then begin
            best := v;
            best_k := k
          end
        done;
        let limit = if closed then eps else eps *. len in
        if !best > limit then begin
          keep.(!best_k) <- true;
          subdivide i !best_k;
          subdivide !best_k j
        end
      end
    in
    subdivide 0 (n - 1);
    let out = ref [] in
    for k = n - 1 downto 0 do
      if keep.(k) then out := pts.(k) :: !out
    done;
    Array.of_list !out
  end

(**
   [drop_closing ~eps c] removes the last corner when it sits within
   [eps] of the first, so a closed loop is not counted twice.
   Requires: nothing
   Returns: [c] or [c] without its final element
   Raises: nothing
   Example: drop_closing ~eps:1. [|a; b; c; a|] = [|a; b; c|]
   Complexity: O(n) time, O(n) space
   Pseudocode:
     if n >= 2 and |c.(n-1) - c.(0)| <= eps then return c.(0 .. n-2)
     else return c
*)
let drop_closing ~eps c =
  let n = Array.length c in
  if n >= 2 && dist c.(n - 1) c.(0) <= eps then Array.sub c 0 (n - 1) else c

(**
   [corners pts] reduces a stroke to between 5 and 9 corners.
   Requires: smoothed stroke points in drawing order
   Returns: [Ok corners] or [Error reason]
   Raises: nothing
   Example: corners (a zig-zag "W" with 5 sharp turns) = Ok (5 corners)
   Complexity: O(max_tries * n^2) time worst case, O(n) space
   Pseudocode:
     if n < 3 or is_line pts then return Error Too_simple
     eps <- eps_fraction * bbox_diagonal pts
     repeat with tries = 0, 1, ...:
       c <- drop_closing (rdp ~eps pts)
       if min_corners <= |c| <= max_corners then return Ok c
       if tries = max_tries then
         return Error (if |c| > max_corners then Too_complex else Too_simple)
       eps <- eps * (if |c| > max_corners then 1.3 else 0.7)
*)
let corners pts : (pt array, reason) result =
  if Array.length pts < 3 || is_line pts then Error `Too_simple
  else begin
    let rec go eps tries =
      let c = drop_closing ~eps (rdp ~eps pts) in
      let k = Array.length c in
      if k >= min_corners && k <= max_corners then Ok c
      else if tries >= max_tries then
        Error (if k > max_corners then `Too_complex else `Too_simple)
      else go (eps *. if k > max_corners then 1.3 else 0.7) (tries + 1)
    in
    go (eps_fraction *. bbox_diagonal pts) 0
  end
