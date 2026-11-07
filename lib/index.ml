(* Invariant index. See index.mli for the public contract. *)

open Geom

type key = int * int * int
type triple = int * int * int

type t = { stars : Catalogue.star array; table : (key, triple list) Hashtbl.t; count : int }

let ratio_bins = 40
let angle_bins = 36
let max_sep_deg = 25.

(**
   [bin x n] maps [x] in [0, 1] to a bin in [0, n-1].
   Requires: [n >= 1]
   Returns: [floor (x * n)] clamped to [0, n-1]
   Raises: nothing
   Example: bin 1.0 40 = 39
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return clamp 0 (n-1) (floor (x * n))
*)
let bin x n = max 0 (min (n - 1) (int_of_float (Float.floor (x *. float_of_int n))))

(**
   [key a b c] is the binned shape key and canonical permutation.
   Requires: a proper triangle
   Returns: [(key, perm)]
   Raises: [Invalid_argument] for degenerate triangles
   Example: key {x=0.;y=0.} {x=4.;y=0.} {x=0.;y=3.} = ((24, 32, 18), [|1; 2; 0|])
   Complexity: O(1) time, O(1) space
   Pseudocode:
     v <- [|a; b; c|]
     opp.(i) <- length of the side opposite vertex i
                (opp.(0) = |b-c|, opp.(1) = |a-c|, opp.(2) = |a-b|)
     perm <- [0;1;2] sorted by opp ascending (ties by index, stable)
     ls, lm, ll <- opp.(perm.(0)), opp.(perm.(1)), opp.(perm.(2))
     if ll < 1e-12 or |(b-a) x (c-a)| < 1e-9 * ll^2 then fail
     angle <- acos (clamp ((ls^2 + lm^2 - ll^2) / (2 ls lm)))  (* law of cosines *)
     return ((bin (ls/ll) ratio_bins, bin (lm/ll) ratio_bins,
              bin (angle/pi) angle_bins), perm)
*)
let key a b c =
  let opp = [| dist b c; dist a c; dist a b |] in
  let perm = [| 0; 1; 2 |] in
  Array.stable_sort (fun i j -> compare opp.(i) opp.(j)) perm;
  let ls = opp.(perm.(0)) and lm = opp.(perm.(1)) and ll = opp.(perm.(2)) in
  let ab = sub b a and ac = sub c a in
  let cross = Float.abs ((ab.x *. ac.y) -. (ab.y *. ac.x)) in
  if ll < 1e-12 || cross < 1e-9 *. ll *. ll then invalid_arg "Index.key: degenerate triangle";
  let cosang = ((ls *. ls) +. (lm *. lm) -. (ll *. ll)) /. (2. *. ls *. lm) in
  let angle = Float.acos (Float.max (-1.) (Float.min 1. cosang)) in
  ( (bin (ls /. ll) ratio_bins, bin (lm /. ll) ratio_bins, bin (angle /. Float.pi) angle_bins),
    perm )

(**
   [neighbours k] is [k] and its clamped +-1 neighbours.
   Requires: valid key
   Returns: distinct keys including [k]
   Raises: nothing
   Example: List.length (neighbours (10, 10, 10)) = 27
   Complexity: O(1) time, O(1) space
   Pseudocode:
     for d1, d2, d3 in {-1, 0, 1}^3:
       emit (clamp r1+d1, clamp r2+d2, clamp a+d3)
     return emitted keys without duplicates
*)
let neighbours (r1, r2, a) =
  let clamp n v = max 0 (min (n - 1) v) in
  let ds = [ -1; 0; 1 ] in
  List.concat_map
    (fun d1 ->
      List.concat_map
        (fun d2 ->
          List.map
            (fun d3 ->
              (clamp ratio_bins (r1 + d1), clamp ratio_bins (r2 + d2), clamp angle_bins (a + d3)))
            ds)
        ds)
    ds
  |> List.sort_uniq compare

(**
   [build stars] files every small star triangle under its key.
   Requires: radians
   Returns: the index
   Raises: nothing
   Example: size (build [||]) = 0
   Complexity: O(N m^2) time, O(T) space
   Pseudocode:
     u.(i) <- unit vector of star i ; limit <- cos (rad max_sep_deg)
     near.(i) <- [ j > i such that u.(i) . u.(j) >= limit ]
     for i, for j in near.(i), for k in near.(i) with k > j:
       if u.(j) . u.(k) >= limit then
         centre <- Skyvec.centre of the three positions
         project the three with gnomonic ~centre (skip if any is None)
         (key, perm) <- key p0 p1 p2          (skip if degenerate)
         ids <- [|i; j; k|]
         add (ids.(perm.(0)), ids.(perm.(1)), ids.(perm.(2))) under key
     return { stars; table; count }
*)
let build stars =
  let n = Array.length stars in
  let u = Array.map (fun s -> Skyvec.of_radec (Catalogue.position s)) stars in
  let limit = cos (rad max_sep_deg) in
  let near =
    Array.init n (fun i ->
        let acc = ref [] in
        for j = n - 1 downto i + 1 do
          if Skyvec.dot u.(i) u.(j) >= limit then acc := j :: !acc
        done;
        Array.of_list !acc)
  in
  let table = Hashtbl.create 4096 in
  let count = ref 0 in
  for i = 0 to n - 1 do
    let ni = near.(i) in
    let m = Array.length ni in
    for jj = 0 to m - 1 do
      let j = ni.(jj) in
      for kk = jj + 1 to m - 1 do
        let k = ni.(kk) in
        if Skyvec.dot u.(j) u.(k) >= limit then begin
          let pos = [ Catalogue.position stars.(i); Catalogue.position stars.(j);
                      Catalogue.position stars.(k) ] in
          match Skyvec.centre pos with
          | exception Invalid_argument _ -> ()
          | centre -> (
              match List.map (gnomonic ~centre) pos with
              | [ Some p0; Some p1; Some p2 ] -> (
                  match key p0 p1 p2 with
                  | exception Invalid_argument _ -> ()
                  | k', perm ->
                      let ids = [| i; j; k |] in
                      let tr = (ids.(perm.(0)), ids.(perm.(1)), ids.(perm.(2))) in
                      let prev = Option.value ~default:[] (Hashtbl.find_opt table k') in
                      Hashtbl.replace table k' (tr :: prev);
                      incr count)
              | _ -> ())
        end
      done
    done
  done;
  { stars; table; count = !count }

(**
   [stars t] is the catalogue behind the index.
   Requires: nothing
   Returns: [t.stars]
   Raises: nothing
   Example: stars (build s) == s
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return t.stars
*)
let stars t = t.stars

(**
   [find t k] is the triples under exactly [k].
   Requires: nothing
   Returns: stored list or []
   Raises: nothing
   Example: find (build [||]) (0, 0, 0) = []
   Complexity: O(1) expected time
   Pseudocode:
     return table[k] or [] if absent
*)
let find t k = Option.value ~default:[] (Hashtbl.find_opt t.table k)

(**
   [find_near t k] is the triples under [k] or any neighbour.
   Requires: nothing
   Returns: concatenated results
   Raises: nothing
   Example: find_near (build [||]) (0, 0, 0) = []
   Complexity: O(27 + r) time and space
   Pseudocode:
     return concat (map (find t) (neighbours k))
*)
let find_near t k = List.concat_map (find t) (neighbours k)

(**
   [size t] is the number of stored triples.
   Requires: nothing
   Returns: [t.count]
   Raises: nothing
   Example: size (build [||]) = 0
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return t.count
*)
let size t = t.count
