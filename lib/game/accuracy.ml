(* PLANNED (collect mode): stub implementation. The interface in
   accuracy.mli is the contract; replace each [todo] with the real code.
   See docs/COLLECT_PLAN.md. *)

type tier = Near_perfect | Incredible | Amazing | Great | Collected | Failed

let samples = 64
let tolerance = 0.6
let pass_mark = 50.0

let todo what = failwith ("Accuracy." ^ what ^ ": not implemented yet (see accuracy.mli)")

(**
   [score ~target stroke] is the final accuracy.
   Requires: see accuracy.mli
   Returns: percentage in [0, 100]
   Raises: nothing
   Example: score ~target:(Asterism.shape orion) (Asterism.shape orion) = 100.
   Complexity: O(c * samples)
   Pseudocode:
     if stroke has no length then return 0
     s <- Engine.normalise (Engine.resample samples stroke)
     best_r <- infinity
     for each variant v of target (both directions; every start if closed;
                                   and each of those mirrored):
       f <- Engine.normalise (Engine.resample samples v)
       match Geom.procrustes s f with
         | Some t -> best_r <- min best_r (Geom.rms t s f)
         | None -> ()
     return 100 * max 0 (1 - best_r / tolerance)
*)
let score ~target:(_ : Geom.pt array) (_ : Geom.pt array) : float = todo "score"

(**
   [live ~target partial] is the running score.
   Requires: see accuracy.mli
   Returns: percentage in [0, 100]
   Raises: nothing
   Example: live ~target (first half of a perfect trace) = 100.
   Complexity: O(c * samples)
   Pseudocode:
     frac <- length partial / (expected full length), capped at 1
             (expected length: the figure's perimeter scaled by the
              partial's own size estimate)
     for each target variant: compare partial with the variant's prefix
     covering [frac] of its arc length, as in score
     return the best percentage
*)
let live ~target:(_ : Geom.pt array) (_ : Geom.pt array) : float = todo "live"

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
let colour _ : int * int * int = todo "colour"
