(**
   File: fitter.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Fitter module: snaps corners to stars, refits
                with least squares, scores each candidate and keeps the best match.
   Usage: The contract is in fitter.mli.
          Import: add hack.matching to (libraries ...) in a dune file, then use
          Doodle_matching.Fitter (or Fitter with -open Doodle_matching).
          Build: dune build    Test: dune test
*)

(* Similarity fitter and scorer. See fitter.mli for the public contract. *)

open Geom

type fit = {
  stars : int array;
  sim : Geom.sim;
  centre : float * float;
  rms_deg : float;
  score : float;
  mirrored : bool;
  weak : bool;
}

let accept_limit = 3.0
let snap_radius_deg = 4.0
let passes = 3
let allow_mirror = true
let faint_penalty = 0.25
let unused_bright_penalty = 0.5

(**
   [nearby stars ~centre ~reach] projects every star within the sky
   angle [reach] of [centre] onto its gnomonic plane.
   Requires: [reach] in radians, [0 < reach]
   Returns: array of [(star index, plane point)]
   Raises: nothing
   Example: nearby [||] ~centre:(0., 0.) ~reach:0.1 = [||]
   Complexity: O(N) time, O(N') space
   Pseudocode:
     c <- unit vector of centre
     limit <- cos (min reach (pi/2 - 1e-6))
     for each star i with unit(i) . c >= limit:
       if gnomonic ~centre (position i) = Some p then emit (i, p)
*)
let nearby (stars : Catalogue.star array) ~centre ~reach =
  let c = Skyvec.of_radec centre in
  let limit = cos (Float.min reach ((Float.pi /. 2.) -. 1e-6)) in
  let acc = ref [] in
  for i = Array.length stars - 1 downto 0 do
    let pos = Catalogue.position stars.(i) in
    if Skyvec.dot (Skyvec.of_radec pos) c >= limit then
      match gnomonic ~centre pos with Some p -> acc := (i, p) :: !acc | None -> ()
  done;
  Array.of_list !acc

(**
   [reach_of pts] is a sky angle that safely covers every plane point in
   [pts] plus the snap radius.
   Requires: plane points in radians
   Returns: [atan (max |p|) + rad snap_radius_deg]
   Raises: nothing
   Example: reach_of [|{x=0.;y=0.}|] = rad snap_radius_deg
   Complexity: O(n) time, O(1) space
   Pseudocode:
     r <- max over p of hypot p.x p.y
     return atan r + rad snap_radius_deg   (* gnomonic r = tan(angle) *)
*)
let reach_of pts =
  let r = Array.fold_left (fun m p -> Float.max m (Float.hypot p.x p.y)) 0. pts in
  Float.atan r +. rad snap_radius_deg

(**
   [snap_in cand pts] assigns each point the nearest free candidate star
   within the snap radius.
   Requires: [cand] from {!nearby} on the same plane as [pts]
   Returns: [Some (ids, star_points)] in corner order, or [None]
   Raises: nothing
   Example: snap_in [||] [|{x=0.;y=0.}|] = None
   Complexity: O(n * N') time, O(N' + n) space
   Pseudocode:
     used <- empty set ; r2 <- (rad snap_radius_deg)^2
     for each corner p in order:
       best <- none ; best_d <- r2
       for each (i, q) in cand not in used:          (* running minimum *)
         if dist_sq p q <= best_d then best <- (i, q) ; best_d <- dist_sq p q
       if best = none then return None
       mark best used ; record it
     return Some (ids, points)
*)
let snap_in cand pts =
  let r2 = rad snap_radius_deg ** 2. in
  let used = Hashtbl.create 16 in
  let n = Array.length pts in
  let ids = Array.make n (-1) and qs = Array.make n { x = 0.; y = 0. } in
  let rec go c =
    if c = n then Some (ids, qs)
    else begin
      let p = pts.(c) in
      let best = ref (-1) and best_d = ref r2 and best_q = ref p in
      Array.iter
        (fun (i, q) ->
          if not (Hashtbl.mem used i) then begin
            let d = dist_sq p q in
            if d <= !best_d then begin
              best := i;
              best_d := d;
              best_q := q
            end
          end)
        cand;
      if !best < 0 then None
      else begin
        Hashtbl.replace used !best ();
        ids.(c) <- !best;
        qs.(c) <- !best_q;
        go (c + 1)
      end
    end
  in
  go 0

(**
   [snap stars ~centre pts] gives each corner its nearest free star.
   Requires: plane points of [centre]
   Returns: [Some ids] or [None]
   Raises: nothing
   Example: snap stars ~centre [| projected Dubhe |] = Some [| dubhe_index |]
   Complexity: O(N + n N') time, O(N') space
   Pseudocode:
     cand <- nearby stars ~centre ~reach:(reach_of pts)
     return ids part of snap_in cand pts
*)
let snap stars ~centre pts =
  let cand = nearby stars ~centre ~reach:(reach_of pts) in
  Option.map fst (snap_in cand pts)

(**
   [inside poly p] is the even-odd point-in-polygon test.
   Requires: [poly] has at least 3 vertices (otherwise always false)
   Returns: [true] when [p] lies inside the closed polygon
   Raises: nothing
   Example: inside [|{x=0.;y=0.};{x=2.;y=0.};{x=0.;y=2.}|] {x=0.5;y=0.5} = true
   Complexity: O(n) time, O(1) space
   Pseudocode:
     c <- false ; j <- n - 1
     for i = 0 to n-1:
       if edge (poly.(j), poly.(i)) straddles p.y and p is left of the
          crossing point then c <- not c
       j <- i
     return c
*)
let inside poly p =
  let n = Array.length poly in
  if n < 3 then false
  else begin
    let c = ref false and j = ref (n - 1) in
    for i = 0 to n - 1 do
      let a = poly.(i) and b = poly.(!j) in
      if a.y > p.y <> (b.y > p.y) && p.x < ((b.x -. a.x) *. (p.y -. a.y) /. (b.y -. a.y)) +. a.x
      then c := not !c;
      j := i
    done;
    !c
  end

(**
   [score_of stars cand ids poly rms_deg] adds the brightness penalties
   to the RMS error.
   Requires: [ids] non-empty, [poly] the fitted corners on the plane
   Returns: [rms_deg + faint + unused-bright penalties]
   Raises: nothing
   Example: score_of stars [||] [|bright_star|] poly 1.0 = 1.0
   Complexity: O(n + N') time, O(n) space
   Pseudocode:
     faint <- sum over matched s of max 0 (mag s - 3)
     m_star <- max magnitude among matched stars
     unused <- count of (i, q) in cand with i not matched,
               mag i < m_star and inside poly q
     return rms_deg + faint_penalty * faint + unused_bright_penalty * unused
*)
let score_of (stars : Catalogue.star array) cand ids poly rms_deg =
  let mags = Array.map (fun i -> stars.(i).Catalogue.mag) ids in
  let faint = Array.fold_left (fun acc m -> acc +. Float.max 0. (m -. 3.)) 0. mags in
  let faintest = Array.fold_left Float.max neg_infinity mags in
  let unused =
    Array.fold_left
      (fun acc (i, q) ->
        if (not (Array.mem i ids)) && stars.(i).Catalogue.mag < faintest && inside poly q then
          acc + 1
        else acc)
      0 cand
  in
  rms_deg +. (faint_penalty *. faint) +. (unused_bright_penalty *. float_of_int unused)

(**
   [fit_one stars h] refines and scores one hypothesis.
   Requires: [h] built from [stars]
   Returns: [Some fit] or [None]
   Raises: nothing
   Example: fit_one stars h_for_a_clean_big_dipper = Some { weak = false; ... }
   Complexity: O(passes (N + n N')) time, O(N') space
   Pseudocode:
     sim <- h.sim
     cand <- nearby stars ~centre:h.centre ~reach:(reach_of (apply_all sim drawn))
     repeat passes times:
       (ids, q) <- snap_in cand (apply_all sim drawn)   or return None
       sim <- procrustes drawn q                        or return None
     rms_deg <- deg (rms sim drawn q)
     score <- score_of stars cand ids (apply_all sim drawn) rms_deg
     return Some { ids; sim; centre; rms_deg; score; mirrored = false;
                   weak = rms_deg > accept_limit }
*)
let fit_one stars (h : Candidates.hypothesis) =
  let drawn = h.drawn in
  let cand = nearby stars ~centre:h.centre ~reach:(reach_of (apply_all h.sim drawn)) in
  let rec loop k sim last =
    if k = passes then Option.map (fun (ids, q) -> (sim, ids, q)) last
    else
      match snap_in cand (apply_all sim drawn) with
      | None -> None
      | Some (ids, q) -> (
          match procrustes drawn q with
          | None -> None
          | Some sim' -> loop (k + 1) sim' (Some (Array.copy ids, Array.copy q)))
  in
  match loop 0 h.sim None with
  | None -> None
  | Some (sim, ids, q) ->
      let rms_deg = deg (rms sim drawn q) in
      let score = score_of stars cand ids (apply_all sim drawn) rms_deg in
      Some
        { stars = ids; sim; centre = h.centre; rms_deg; score; mirrored = false;
          weak = rms_deg > accept_limit }

(**
   [mirror_hyp h] is [h] with the drawing reflected and the seed
   transform rebuilt from the reflected seed corners.
   Requires: [h] valid
   Returns: [Some h'], or [None] if the reflected seed is degenerate
   Raises: nothing
   Example: mirror_hyp h = Some { h with drawn = mirror_y h.drawn; sim = ... }
   Complexity: O(n) time and space
   Pseudocode:
     a, b <- drawn seed corners 0 and 1
     a', b' <- apply h.sim a, apply h.sim b      (* the seed stars *)
     m <- mirror_y drawn
     return { h with drawn = m; sim = sim_of_pair m.(c0) m.(c1) a' b' }
*)
let mirror_hyp (h : Candidates.hypothesis) =
  let c0 = h.corners.(0) and c1 = h.corners.(1) in
  let a' = apply h.sim h.drawn.(c0) and b' = apply h.sim h.drawn.(c1) in
  let m = mirror_y h.drawn in
  match sim_of_pair m.(c0) m.(c1) a' b' with
  | exception Invalid_argument _ -> None
  | sim -> Some { h with drawn = m; sim }

(**
   [best stars hs] keeps the lowest-score fit over all hypotheses.
   Requires: hypotheses from [stars]
   Returns: best fit or [None]
   Raises: nothing
   Example: best stars [] = None
   Complexity: O(H passes (N + n N')) time, O(N') space
   Pseudocode:
     best <- None
     for each h in hs:
       consider fit_one stars h
       if allow_mirror then consider (fit_one stars (mirror_hyp h)) with mirrored = true
       where consider f = if f.score < best.score then best <- f
     return best
*)
let best stars hs =
  let keep acc f =
    match (acc, f) with
    | _, None -> acc
    | None, Some _ -> f
    | Some a, Some b -> if b.score < a.score then f else acc
  in
  List.fold_left
    (fun acc h ->
      let acc = keep acc (fit_one stars h) in
      if allow_mirror then
        match mirror_hyp h with
        | None -> acc
        | Some h' -> keep acc (Option.map (fun f -> { f with mirrored = true }) (fit_one stars h'))
      else acc)
    None hs
