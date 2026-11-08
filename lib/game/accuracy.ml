(**
   File: accuracy.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Accuracy module: scores a drawing against a
                figure as a drawtheperfectcircle-style percentage ("87.3%"), with
                tiers, colour and the 50% pass mark.
   Usage: The contract is in accuracy.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Accuracy (or Accuracy with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Drawing accuracy as a percentage. See accuracy.mli for the contract. *)

type tier = Near_perfect | Incredible | Amazing | Great | Collected | Failed

let samples = 64
let tolerance = 0.6
let pass_mark = 50.0

(**
   [arc_length pts] is the total length of a polyline.
   Requires: nothing
   Returns: the sum of segment lengths; 0 for fewer than 2 points
   Raises: nothing
   Example: arc_length [|{x=0.;y=0.}; {x=3.;y=4.}|] = 5.
   Complexity: O(n)
   Pseudocode:
     sum over i of |p.(i) - p.(i-1)|
*)
let arc_length pts =
  let acc = ref 0. in
  for i = 1 to Array.length pts - 1 do
    acc := !acc +. Geom.dist pts.(i) pts.(i - 1)
  done;
  !acc

(**
   [prepare pts] is a shape ready for comparison: resampled to
   {!samples} points by arc length, then normalised.
   Requires: [pts] non-empty
   Returns: {!samples} points, centroid 0, RMS radius 1
   Raises: [Invalid_argument] if [pts] is empty
   Example: Array.length (prepare shape) = 64
   Complexity: O(n + samples)
   Pseudocode:
     return Engine.normalise (Engine.resample samples pts)
*)
let prepare pts = Engine.normalise (Engine.resample samples pts)

(**
   [variants target] is every way the player might draw the figure: both
   directions, every starting star for a closed figure, and the mirror
   image of each.
   Requires: [target] has at least 2 points
   Returns: the variant outlines (at least 4)
   Raises: nothing
   Example: List.length (variants open_figure) = 4
   Complexity: O(k^2)
   Pseudocode:
     closed <- first point = last point
     starts <- if closed then the k-1 rotations of the ring, each closed again
               else [target]
     dirs <- each start and its reverse
     return dirs @ map Geom.mirror_y dirs
*)
let variants target =
  let k = Array.length target in
  let closed = k >= 3 && Geom.dist target.(0) target.(k - 1) < 1e-9 in
  let starts =
    if closed then
      List.init (k - 1) (fun s ->
          let ring = Array.init (k - 1) (fun i -> target.((i + s) mod (k - 1))) in
          Array.append ring [| ring.(0) |])
    else [ target ]
  in
  let rev a = Array.init (Array.length a) (fun i -> a.(Array.length a - 1 - i)) in
  let dirs = List.concat_map (fun v -> [ v; rev v ]) starts in
  dirs @ List.map Geom.mirror_y dirs

(**
   [gap s f] is the RMS distance left after the best similarity maps the
   prepared stroke [s] onto the prepared figure [f].
   Requires: equal lengths
   Returns: a value in [0, 1] (1 = no better than collapsing to a point)
   Raises: nothing
   Example: gap s s = 0.
   Complexity: O(samples)
   Pseudocode:
     match Geom.procrustes s f with
       | Some t -> min 1 (Geom.rms t s f)
       | None -> 1
*)
let gap s f =
  match Geom.procrustes s f with Some t -> Float.min 1. (Geom.rms t s f) | None -> 1.

(**
   [line_gap vs] is how close a plain straight line comes to the figure:
   the smallest {!gap} between a prepared straight segment and any variant.
   Requires: [vs] non-empty
   Returns: a value in [0, 1]; small for nearly straight figures
   Raises: nothing
   Example: line_gap (variants (Asterism.shape cassiopeia)) is about 0.25
   Complexity: O(c * samples)
   Pseudocode:
     line <- prepare [(0, 0); (1, 0)]
     return min over v in vs of gap line (prepare v)
*)
let line_gap vs =
  let line = prepare [| { Geom.x = 0.; y = 0. }; { Geom.x = 1.; y = 0. } |] in
  List.fold_left (fun r v -> Float.min r (gap line (prepare v))) 1. vs

(**
   [zero_point vs] is the gap that scores 0% for this figure: the general
   {!tolerance}, or the straight-line gap if that is smaller, so that a
   straight line never scores above 0% (a shallow figure such as
   Cassiopeia's W would otherwise let a flat line pass).
   Requires: [vs] non-empty
   Returns: a positive value at most [tolerance]
   Raises: nothing
   Example: zero_point (variants (Asterism.shape orion)) = tolerance
   Complexity: O(c * samples)
   Pseudocode:
     return max 1e-6 (min tolerance (line_gap vs))
*)
let zero_point vs = Float.max 1e-6 (Float.min tolerance (line_gap vs))

(**
   [percent ~zero r] turns a gap into a score.
   Requires: [r >= 0.], [zero > 0.]
   Returns: [100 * max 0 (1 - r / zero)]
   Raises: nothing
   Example: percent ~zero:0.6 0. = 100.
   Complexity: O(1)
   Pseudocode:
     return 100 * max 0 (1 - r / zero)
*)
let percent ~zero r = 100. *. Float.max 0. (1. -. (r /. zero))

(**
   [usable stroke] tells whether a stroke has anything to score.
   Requires: nothing
   Returns: at least 2 points and a length above zero
   Raises: nothing
   Example: usable [||] = false
   Complexity: O(n)
   Pseudocode:
     return length >= 2 and arc_length > 1e-9
*)
let usable stroke = Array.length stroke >= 2 && arc_length stroke > 1e-9

(**
   [score ~target stroke] is the final accuracy.
   Requires: see accuracy.mli
   Returns: percentage in [0, 100]
   Raises: nothing
   Example: score ~target:(Asterism.shape orion) (Asterism.shape orion) = 100.
   Complexity: O(c * samples)
   Pseudocode:
     if stroke is not usable then return 0
     s <- prepare stroke ; vs <- variants target
     best_r <- min over v in vs of gap s (prepare v)
     return percent ~zero:(zero_point vs) best_r
*)
let score ~target stroke =
  if (not (usable stroke)) || Array.length target < 2 then 0.
  else
    let s = prepare stroke and vs = variants target in
    percent ~zero:(zero_point vs) (List.fold_left (fun r v -> Float.min r (gap s (prepare v))) 1. vs)

(**
   [prefix pts frac] is the start of a polyline covering [frac] of its length.
   Requires: [pts] has at least 2 points; [0 < frac <= 1]
   Returns: the points up to that length, the last one interpolated
   Raises: nothing
   Example: prefix [|{x=0.;y=0.}; {x=4.;y=0.}|] 0.5 = [|{x=0.;y=0.}; {x=2.;y=0.}|]
   Complexity: O(n)
   Pseudocode:
     want <- frac * arc_length pts ; walked <- 0 ; out <- [p0]
     for each segment (a, b):
       if walked + |b - a| >= want then
         out += lerp a b ((want - walked) / |b - a|) ; stop
       else out += b ; walked += |b - a|
*)
let prefix pts frac =
  let want = frac *. arc_length pts in
  let out = ref [ pts.(0) ] and walked = ref 0. and stop = ref false in
  for i = 1 to Array.length pts - 1 do
    if not !stop then begin
      let a = pts.(i - 1) and b = pts.(i) in
      let len = Geom.dist a b in
      if !walked +. len >= want then begin
        let u = if len > 0. then (want -. !walked) /. len else 0. in
        out := Geom.lerp a b u :: !out;
        stop := true
      end
      else begin
        out := b :: !out;
        walked := !walked +. len
      end
    end
  done;
  Array.of_list (List.rev !out)

(**
   [live ~target partial] is the running score.
   Requires: see accuracy.mli
   Returns: percentage in [0, 100]
   Raises: nothing
   Example: live ~target (first half of a perfect trace) = 100.
   Complexity: O(10 * c * samples)
   Pseudocode:
     if partial is not usable then return 0
     s <- prepare partial ; vs <- variants target
     best_r <- min over v in vs and fractions f in {0.1, 0.2, ..., 1.0}
               of gap s (prepare (prefix v f))
     return percent ~zero:(zero_point vs) best_r
*)
let live ~target partial =
  if (not (usable partial)) || Array.length target < 2 then 0.
  else begin
    let s = prepare partial and vs = variants target in
    let fracs = List.init 10 (fun i -> float_of_int (i + 1) /. 10.) in
    let best =
      List.fold_left
        (fun r v ->
          List.fold_left (fun r f -> Float.min r (gap s (prepare (prefix v f)))) r fracs)
        1. vs
    in
    percent ~zero:(zero_point vs) best
  end

(**
   [format p] is the site-style display.
   Requires: nothing
   Returns: e.g. "87.3%"
   Raises: nothing
   Example: format 87.25 = "87.3%"
   Complexity: O(1)
   Pseudocode:
     return sprintf "%.1f%%" (clamp 0 100 p)
*)
let format p = Printf.sprintf "%.1f%%" (Float.max 0. (Float.min 100. p))

(**
   [format_best b] is the best-score line.
   Requires: nothing
   Returns: "Best: <format b>", 0.0% when none
   Raises: nothing
   Example: format_best None = "Best: 0.0%"
   Complexity: O(1)
   Pseudocode:
     return "Best: " ^ format (b or 0)
*)
let format_best b = "Best: " ^ format (Option.value ~default:0. b)

(**
   [tier p] is the rank band.
   Requires: nothing
   Returns: the band for [p]
   Raises: nothing
   Example: tier 94. = Near_perfect
   Complexity: O(1)
   Pseudocode:
     p >= 94 -> Near_perfect ; >= 90 -> Incredible ; >= 81 -> Amazing
     >= 72 -> Great ; >= pass_mark -> Collected ; else Failed
*)
let tier p =
  if p >= 94. then Near_perfect
  else if p >= 90. then Incredible
  else if p >= 81. then Amazing
  else if p >= 72. then Great
  else if p >= pass_mark then Collected
  else Failed

(**
   [tier_label t] is the band's name.
   Requires: nothing
   Returns: the label
   Raises: nothing
   Example: tier_label Amazing = "Amazing"
   Complexity: O(1)
   Pseudocode:
     one string per constructor
*)
let tier_label = function
  | Near_perfect -> "Near Perfect"
  | Incredible -> "Incredible"
  | Amazing -> "Amazing"
  | Great -> "Great"
  | Collected -> "Collected"
  | Failed -> "Failed"

(**
   [colour p] is the score colour.
   Requires: nothing
   Returns: RGB in [0, 255]
   Raises: nothing
   Example: colour 100. = (60, 220, 90)
   Complexity: O(1)
   Pseudocode:
     red <- (230, 60, 60) ; yellow <- (240, 200, 60) ; green <- (60, 220, 90)
     if p < pass_mark then blend red -> yellow by p / pass_mark
     else blend yellow -> green by (p - pass_mark) / (100 - pass_mark)
*)
let colour p =
  let p = Float.max 0. (Float.min 100. p) in
  let blend (r1, g1, b1) (r2, g2, b2) u =
    let mix a b = int_of_float (Float.round (float_of_int a +. (u *. float_of_int (b - a)))) in
    (mix r1 r2, mix g1 g2, mix b1 b2)
  in
  let red = (230, 60, 60) and yellow = (240, 200, 60) and green = (60, 220, 90) in
  if p < pass_mark then blend red yellow (p /. pass_mark)
  else blend yellow green ((p -. pass_mark) /. (100. -. pass_mark))
