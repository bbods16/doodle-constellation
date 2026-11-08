(** Collect_view: draws collect mode, one function per element, in the
    style of drawtheperfectcircle.com.

    PLANNED (collect mode) — interface only; the implementation is a stub.
    See [docs/COLLECT_PLAN.md].

    {v
     ┌────────────────────────────────────────────────────────────────┐
     │ Draw: Orion                              3 / 7 collected  ● ●○○○│  target_prompt, progress, strikes
     │                                                                │
     │                          87.3%                                 │  big_percentage (live, coloured)
     │                       Best: 91.2%                              │  best_line
     │                       NEW RECORD!                              │  headline (verdict)
     │                    ~~~ the stroke ~~~                          │  stroke
     │                                                                │
     │ [✓ Big Dipper 91.2%] [✓ Cassiopeia 64.0%] [  Orion  —  ] ...   │  shelf
     └────────────────────────────────────────────────────────────────┘
    v}
    Under 50% the headline is the insult (red, large). On the fifth
    strike {!diss_screen} replaces everything until the game closes. *)

val draw : Scene.ctx -> Collect.t -> unit
(**
   [draw ctx t] paints every element back to front: {!stroke},
   {!target_prompt}, {!progress}, {!strikes}, {!big_percentage},
   {!best_line}, {!headline}, {!shelf}; or only {!diss_screen} /
   {!complete_screen} in those phases.
   Requires: inside the loop's drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: O(s + n), s stroke points, n figures
*)

val target_prompt : Collect.t -> unit
(**
   [target_prompt t] draws ["Draw: <figure>"] at the top left.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: target_prompt t shows "Draw: Orion"
   Complexity: O(1)
*)

val progress : Collect.t -> unit
(**
   [progress t] draws {!Collection.progress_label} at the top right.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: progress t shows "3 / 7 collected"
   Complexity: O(n)
*)

val strikes : Collect.t -> unit
(**
   [strikes t] draws {!Roast.max_strikes} markers, filled for each strike.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: strikes t shows two filled and three empty markers
   Complexity: O(1)
*)

val big_percentage : Collect.t -> unit
(**
   [big_percentage t] draws the score huge and centred, as on the site:
   the live score while drawing, the final score during a verdict, in
   {!Accuracy.colour}, formatted with {!Accuracy.format}.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: big_percentage t shows "87.3%" in green
   Complexity: O(1)
*)

val best_line : Collect.t -> unit
(**
   [best_line t] draws ["Best: 91.2%"] for the current figure under the
   big number ({!Accuracy.format_best}).
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: best_line t shows "Best: 0.0%" before any attempt
   Complexity: O(n)
*)

val headline : Collect.t -> unit
(**
   [headline t] draws the verdict line during [Verdict]:
   ["Collected!"], ["NEW RECORD!"], the tier label, or the insult with
   ["k strikes left"] ({!Judge.headline}).
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: headline t shows "NEW RECORD!"
   Complexity: O(L)
*)

val stroke : Collect.t -> unit
(**
   [stroke t] draws the player's stroke ({!Sky.draw_stroke}), tinted with
   the live score's colour.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: stroke t
   Complexity: O(s)
*)

val shelf : Collect.t -> unit
(**
   [shelf t] draws the collection along the bottom: one tile per figure,
   ticked and showing its best score once collected, dim otherwise.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: shelf t shows "✓ Big Dipper 91.2%" for a collected figure
   Complexity: O(n)
*)

val diss_screen : string -> float -> unit
(**
   [diss_screen line seconds_left] draws the final diss full screen, with
   a closing countdown.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: diss_screen "Five strikes. ..." 3.2 shows "Closing in 4..."
   Complexity: O(L)
*)

val complete_screen : Collect.t -> unit
(**
   [complete_screen t] draws the win screen: every figure with its best
   score, and the average.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: complete_screen t shows "All 7 constellations collected!"
   Complexity: O(n)
*)
