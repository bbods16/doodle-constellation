(* PLANNED (collect mode): stub implementation. The interface in
   judge.mli is the contract; replace each [todo] with the real code.
   See docs/COLLECT_PLAN.md. *)

type verdict =
  | Collected_new of { score : float; tier : Accuracy.tier }
  | New_record of { score : float; tier : Accuracy.tier }
  | Passed of { score : float; tier : Accuracy.tier; best : float }
  | Insulted of { score : float; line : string; strikes_left : int }
  | Game_over of { score : float; line : string }

let todo what = failwith ("Judge." ^ what ^ ": not implemented yet (see judge.mli)")

(**
   [judge c r ~target ~score] applies the rules.
   Requires: see judge.mli
   Returns: updated collection, roaster and verdict
   Raises: Invalid_argument
   Example: judge c r ~target:orion ~score:63. gives Collected_new
   Complexity: O(n + L)
   Pseudocode:
     name <- Asterism.name target
     (c, res) <- Collection.record c ~name ~score
     if score >= Accuracy.pass_mark then
       tier <- Accuracy.tier score
       v <- if res.collected_now then Collected_new { score; tier }
            else if res.new_best then New_record { score; tier }
            else Passed { score; tier; best = res.best }
       (c, r, v)
     else
       (r, rv) <- Roast.miss r ~score ~target:name
       v <- match rv with
            | Insult line -> Insulted { score; line; strikes_left = Roast.strikes_left r }
            | Final_diss line -> Game_over { score; line }
       (c, r, v)
*)
let judge (_ : Collection.t) (_ : Roast.t) ~target:(_ : Asterism.t) ~score:(_ : float) :
    Collection.t * Roast.t * verdict =
  todo "judge"

(**
   [headline v] is the verdict's big line.
   Requires: nothing
   Returns: the headline
   Raises: nothing
   Example: headline (New_record { score = 91.; tier = Incredible }) = "NEW RECORD!"
   Complexity: O(1)
   Pseudocode:
     Collected_new -> "Collected!" ; New_record -> "NEW RECORD!"
     Passed { tier } -> Accuracy.tier_label tier
     Insulted { line } | Game_over { line } -> line
*)
let headline = function
  | Collected_new _ -> "Collected!"
  | New_record _ -> "NEW RECORD!"
  | Passed { tier; _ } -> Accuracy.tier_label tier
  | Insulted { line; _ } | Game_over { line; _ } -> line

(**
   [score_of v] is the verdict's score.
   Requires: nothing
   Returns: the score
   Raises: nothing
   Example: score_of (Game_over { score = 12.; line = "..." }) = 12.
   Complexity: O(1)
   Pseudocode:
     return the score field of any constructor
*)
let score_of = function
  | Collected_new { score; _ }
  | New_record { score; _ }
  | Passed { score; _ }
  | Insulted { score; _ }
  | Game_over { score; _ } ->
      score
