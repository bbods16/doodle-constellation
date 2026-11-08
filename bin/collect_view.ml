(* PLANNED (collect mode): stub implementation. The interface in
   collect_view.mli is the contract; replace each [todo] with the real
   code. See docs/COLLECT_PLAN.md. *)

let todo what = failwith ("Collect_view." ^ what ^ ": not implemented yet (see collect_view.mli)")

(**
   [target_prompt t] draws "Draw: <figure>".
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: target_prompt t shows "Draw: Orion"
   Complexity: O(1)
   Pseudocode:
     match Collect.target t with Some f -> draw_text ("Draw: " ^ name f) top-left | None -> ()
*)
let target_prompt (_ : Collect.t) : unit = todo "target_prompt"

(**
   [progress t] draws "k / n collected".
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: progress t shows "3 / 7 collected"
   Complexity: O(n)
   Pseudocode:
     right-aligned draw_text (Collection.progress_label (Collect.collection t))
*)
let progress (_ : Collect.t) : unit = todo "progress"

(**
   [strikes t] draws the strike markers.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: strikes t shows two filled and three empty markers
   Complexity: O(1)
   Pseudocode:
     for i in 1..max_strikes: filled red circle if i <= strikes else outline
*)
let strikes (_ : Collect.t) : unit = todo "strikes"

(**
   [big_percentage t] draws the big centred score.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: big_percentage t shows "87.3%" in green
   Complexity: O(1)
   Pseudocode:
     p <- match phase with Verdict (v, _) -> Judge.score_of v | _ -> Collect.live_score t
     draw Accuracy.format p, size 96, centred, colour Accuracy.colour p
*)
let big_percentage (_ : Collect.t) : unit = todo "big_percentage"

(**
   [best_line t] draws "Best: x%".
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: best_line t shows "Best: 0.0%" before any attempt
   Complexity: O(n)
   Pseudocode:
     b <- Collection.best (collection t) (name of target)
     draw Accuracy.format_best b centred under the big number
*)
let best_line (_ : Collect.t) : unit = todo "best_line"

(**
   [headline t] draws the verdict line.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: headline t shows "NEW RECORD!"
   Complexity: O(L)
   Pseudocode:
     match phase with
       | Verdict (Insulted { strikes_left; _ } as v, _) ->
           Judge.headline v in red, then "<strikes_left> strikes left"
       | Verdict (v, _) -> Judge.headline v in the score colour
       | _ -> ()
*)
let headline (_ : Collect.t) : unit = todo "headline"

(**
   [stroke t] draws the stroke.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: stroke t
   Complexity: O(s)
   Pseudocode:
     Sky.draw_stroke (Collect.stroke t)   (tint: Accuracy.colour live_score)
*)
let stroke (_ : Collect.t) : unit = todo "stroke"

(**
   [shelf t] draws the collection tiles.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: shelf t shows "✓ Big Dipper 91.2%"
   Complexity: O(n)
   Pseudocode:
     for each figure in Collection.figures, left to right along the bottom:
       collected -> bright tile "✓ <name> <best %>" ; else dim tile "<name>"
*)
let shelf (_ : Collect.t) : unit = todo "shelf"

(**
   [diss_screen line seconds_left] draws the final diss.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: diss_screen "Five strikes. ..." 3.2 shows "Closing in 4..."
   Complexity: O(L)
   Pseudocode:
     large red [line], wrapped and centred
     "Closing in <ceil seconds_left>..." underneath
*)
let diss_screen (_ : string) (_ : float) : unit = todo "diss_screen"

(**
   [complete_screen t] draws the win screen.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: complete_screen t shows "All 7 constellations collected!"
   Complexity: O(n)
   Pseudocode:
     title "All <n> constellations collected!"
     one line per figure with its best % ; average best underneath
*)
let complete_screen (_ : Collect.t) : unit = todo "complete_screen"

(**
   [draw ctx t] paints the screen for the current phase.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: O(s + n)
   Pseudocode:
     match Collect.phase t with
       | Dissed (line, s) -> diss_screen line s
       | Complete -> complete_screen t
       | _ -> stroke ; target_prompt ; progress ; strikes ;
              big_percentage ; best_line ; headline ; shelf
*)
let draw (_ : Scene.ctx) (t : Collect.t) =
  match Collect.phase t with
  | Collect.Dissed (line, s) -> diss_screen line s
  | Collect.Complete -> complete_screen t
  | Collect.Prompt | Collect.Drawing | Collect.Verdict _ ->
      stroke t;
      target_prompt t;
      progress t;
      strikes t;
      big_percentage t;
      best_line t;
      headline t;
      shelf t
