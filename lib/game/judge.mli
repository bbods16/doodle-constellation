(** Judge: turns one finished drawing's score into a verdict, updating
    the collection and the strike count.

    Design notes: [docs/COLLECT_PLAN.md].

    {v
    score >= 50% ─► Collection.record ─► Collected_new | New_record | Passed
    score <  50% ─► Roast.miss        ─► Insulted (strikes 1-4)
                                       └► Game_over (strike 5: final diss, then quit)
    v}

    Pure: no drawing and no clock, so every rule is unit-tested. *)

type verdict =
  | Collected_new of { score : float; tier : Accuracy.tier }
      (** first time this figure reached the pass mark *)
  | New_record of { score : float; tier : Accuracy.tier }
      (** already collected, and this beat its best ("NEW RECORD!") *)
  | Passed of { score : float; tier : Accuracy.tier; best : float }
      (** at least the pass mark, but no new record *)
  | Insulted of { score : float; line : string; strikes_left : int }
      (** under the pass mark: a strike and an insult *)
  | Game_over of { score : float; line : string }
      (** under the pass mark on the last strike: final diss, then quit *)
(** The outcome of one drawing. *)

val judge :
  Collection.t -> Roast.t -> target:Asterism.t -> score:float ->
  Collection.t * Roast.t * verdict
(**
   [judge c r ~target ~score] applies the rules to one finished drawing
   of [target].
   Requires: [target] is in [c]; [Roast.strikes_left r > 0]
   Returns: the updated collection and roaster, and the verdict. Scores
            at or above {!Accuracy.pass_mark} are recorded in [c] and
            leave [r] unchanged; lower scores add a strike to [r] (and
            are still recorded as an attempt, for the best score)
   Raises: [Invalid_argument] if [target] is not in [c] or no strikes are left
   Example: let (_, _, v) = judge c r ~target:orion ~score:63. in
            v = Collected_new { score = 63.; tier = Collected }
   Complexity: O(n + L), n figures, L insult length
*)

val headline : verdict -> string
(**
   [headline v] is the big line shown with the verdict.
   Requires: nothing
   Returns: ["Collected!"], ["NEW RECORD!"], the tier label
            ({!Accuracy.tier_label}), the insult, or the final diss
   Raises: nothing
   Example: headline (New_record { score = 91.; tier = Incredible }) = "NEW RECORD!"
   Complexity: O(1)
*)

val score_of : verdict -> float
(**
   [score_of v] is the score the verdict was given for.
   Requires: nothing
   Returns: the score carried by [v]
   Raises: nothing
   Example: score_of (Game_over { score = 12.; line = "..." }) = 12.
   Complexity: O(1)
*)
