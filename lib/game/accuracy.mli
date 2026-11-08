(** Accuracy: how closely a drawing matches a constellation figure, as a
    percentage in the style of drawtheperfectcircle.com.

    PLANNED (collect mode) — interface only; the implementation is a stub.
    See [docs/COLLECT_PLAN.md].

    {2 Display, matching the reference site}
    - One decimal place and a percent sign: ["87.3%"], from ["0.0%"] to
      ["100.0%"] ({!format}).
    - Shown live while drawing ({!live}) and as a final score on release
      ({!score}).
    - ["Best: 87.3%"] per figure ({!format_best}) and ["NEW RECORD!"] when
      it improves (decided by {!Collection}).
    - Rank tiers from the site's table ({!tier}): 94%+ Near Perfect,
      90%+ Incredible, 81%+ Amazing, 72%+ Great. This game adds 50%+
      Collected (the pass mark) and below 50% Failed.

    {2 Scoring rule}
    The stroke and the figure's {!Asterism.shape} are each resampled to
    {!samples} points by arc length and normalised (centroid 0, RMS
    radius 1, as {!Engine.normalise}). The stroke is then aligned to the
    figure with {!Geom.procrustes}, trying both drawing directions, every
    starting star for closed figures, and the mirror image. With [r] the
    smallest RMS gap left after alignment:

    {v score = 100 * max 0 (1 - r / tolerance) v}

    So a perfect trace scores 100.0%, and a gap of [tolerance] (in units
    of the figure's RMS radius) or more scores 0.0%. Position, size and
    rotation never matter. *)

type tier =
  | Near_perfect  (** 94% and up *)
  | Incredible    (** 90% to 94% *)
  | Amazing       (** 81% to 90% *)
  | Great         (** 72% to 81% *)
  | Collected     (** 50% to 72%: passes, figure collected *)
  | Failed        (** under 50%: a strike and an insult *)
(** Rank bands; the first four follow the reference site. *)

val samples : int
(** Points each shape is resampled to before comparing. [64]. *)

val tolerance : float
(** RMS gap, in figure radii, that scores 0%. [0.6]. To be tuned so an
    average careful drawing lands in the site's typical 50–60% band. *)

val pass_mark : float
(** Lowest score that collects a figure. [50.0]. *)

val score : target:Geom.pt array -> Geom.pt array -> float
(**
   [score ~target stroke] is the accuracy of a finished stroke against a
   figure outline, using the rule above.
   Requires: [target] has at least 2 points ({!Asterism.shape})
   Returns: a percentage in [0., 100.]; [0.] for an empty or zero-length
            stroke
   Raises: nothing
   Example: score ~target:(Asterism.shape orion) (Asterism.shape orion) = 100.
   Complexity: O(c * samples), c = alignments tried (at most 4 * stars)
*)

val live : target:Geom.pt array -> Geom.pt array -> float
(**
   [live ~target partial] is the running score while the stroke is still
   being drawn: the partial stroke is compared with the stretch of the
   figure it most likely covers so far (the prefix of the same arc-length
   fraction, best direction and start).
   Requires: [target] has at least 2 points
   Returns: a percentage in [0., 100.]; [0.] until the stroke has length
   Raises: nothing
   Example: live ~target (first half of a perfect trace) = 100.
   Complexity: same as {!score}
*)

val format : float -> string
(**
   [format p] is the site-style display: one decimal and a percent sign,
   clamped to [0, 100].
   Requires: nothing
   Returns: e.g. ["87.3%"]
   Raises: nothing
   Example: format 87.25 = "87.3%"   format (-3.) = "0.0%"
   Complexity: O(1)
*)

val format_best : float option -> string
(**
   [format_best b] is the best-score line.
   Requires: nothing
   Returns: ["Best: 87.3%"], or ["Best: 0.0%"] when there is none yet
   Raises: nothing
   Example: format_best None = "Best: 0.0%"
   Complexity: O(1)
*)

val tier : float -> tier
(**
   [tier p] is the rank band for a score.
   Requires: nothing
   Returns: the band containing [p] (bounds inclusive at the bottom)
   Raises: nothing
   Example: tier 94. = Near_perfect   tier 49.9 = Failed
   Complexity: O(1)
*)

val tier_label : tier -> string
(**
   [tier_label t] is the band's on-screen name.
   Requires: nothing
   Returns: ["Near Perfect"], ["Incredible"], ["Amazing"], ["Great"],
            ["Collected"] or ["Failed"]
   Raises: nothing
   Example: tier_label Amazing = "Amazing"
   Complexity: O(1)
*)

val colour : float -> int * int * int
(**
   [colour p] is the score's display colour as RGB: red at 0%, yellow at
   the pass mark, green at 100%, blended in between.
   Requires: nothing
   Returns: three components in [0, 255]
   Raises: nothing
   Example: colour 100. = (60, 220, 90)
   Complexity: O(1)
*)
