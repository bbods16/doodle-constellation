(* Drawing of collect mode. See collect_view.mli for the contract. *)

open Raylib

let text_colour = Color.create 200 210 230 255
let dim_colour = Color.create 110 120 140 255
let red = Color.create 235 70 70 255

(**
   [rgb (r, g, b)] is an opaque raylib colour.
   Requires: components in [0, 255]
   Returns: the colour
   Raises: nothing
   Example: rgb (Accuracy.colour 100.)
   Complexity: O(1)
   Pseudocode:
     Color.create r g b 255
*)
let rgb (r, g, b) = Color.create r g b 255

(**
   [centred text y size colour] draws [text] centred horizontally.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: centred "87.3%" 300 96 green
   Complexity: O(length of text)
   Pseudocode:
     draw_text text ((screen width - measure_text text size) / 2) y size colour
*)
let centred text y size colour =
  draw_text text ((get_screen_width () - measure_text text size) / 2) y size colour

(**
   [wrap text size max_w] splits [text] into lines no wider than [max_w]
   pixels at font [size], breaking between words.
   Requires: [max_w > 0]
   Returns: the lines (a single over-long word gets its own line)
   Raises: nothing
   Example: wrap "a b c" 20 10000 = ["a b c"]
   Complexity: O(words * line length)
   Pseudocode:
     for each word: if line ^ " " ^ word fits then append, else start a new line
*)
let wrap text size max_w =
  let words = List.filter (( <> ) "") (String.split_on_char ' ' text) in
  let lines, last =
    List.fold_left
      (fun (lines, cur) w ->
        let cand = if cur = "" then w else cur ^ " " ^ w in
        if cur <> "" && measure_text cand size > max_w then (cur :: lines, w) else (lines, cand))
      ([], "") words
  in
  List.rev (if last = "" then lines else last :: lines)

(**
   [centred_block text y size colour] draws wrapped, centred lines from [y].
   Requires: inside the drawing block
   Returns: the y just below the last line
   Raises: nothing
   Example: centred_block insult 420 28 red
   Complexity: O(length of text)
   Pseudocode:
     for each line of wrap text size (width - 80): centred line y ; y += size + 8
*)
let centred_block text y size colour =
  List.fold_left
    (fun y line ->
      centred line y size colour;
      y + size + 8)
    y
    (wrap text size (get_screen_width () - 80))

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
let target_prompt t =
  match Collect.target t with
  | Some f -> draw_text ("Draw: " ^ Asterism.name f) 24 20 36 Color.raywhite
  | None -> ()

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
let progress t =
  let s = Collection.progress_label (Collect.collection t) in
  draw_text s (get_screen_width () - 24 - measure_text s 22) 22 22 text_colour

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
let strikes t =
  let n = Roast.strikes (Collect.roast t) in
  let right = get_screen_width () - 34 in
  for i = 1 to Roast.max_strikes do
    let x = right - ((Roast.max_strikes - i) * 26) in
    if i <= n then draw_circle x 66 9. red else draw_circle_lines x 66 9. dim_colour
  done

(**
   [shown_score t] is the number on screen: the verdict's score, or the live score.
   Requires: nothing
   Returns: a percentage
   Raises: nothing
   Example: shown_score (Collect.init c r) = 0.
   Complexity: O(1)
   Pseudocode:
     Verdict (v, _) -> Judge.score_of v ; otherwise Collect.live_score t
*)
let shown_score t =
  match Collect.phase t with Collect.Verdict (v, _) -> Judge.score_of v | _ -> Collect.live_score t

(**
   [big_percentage t] draws the big centred score.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: big_percentage t shows "87.3%" in green
   Complexity: O(1)
   Pseudocode:
     p <- shown_score t
     draw Accuracy.format p, size 96, centred, colour Accuracy.colour p
     (dimmed while waiting for the first stroke)
*)
let big_percentage t =
  let p = shown_score t in
  let colour = if Collect.phase t = Collect.Prompt then dim_colour else rgb (Accuracy.colour p) in
  centred (Accuracy.format p) (get_screen_height () / 5) 96 colour

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
let best_line t =
  match Collect.target t with
  | Some f ->
      let b = Collection.best (Collect.collection t) (Asterism.name f) in
      centred (Accuracy.format_best b) ((get_screen_height () / 5) + 104) 24 text_colour
  | None -> ()

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
           Judge.headline v in red (wrapped), then "<strikes_left> strikes left"
       | Verdict (v, _) -> Judge.headline v in the score colour
       | Prompt -> "Start drawing" hint
       | _ -> ()
*)
let headline t =
  let y = (get_screen_height () / 5) + 150 in
  match Collect.phase t with
  | Collect.Verdict ((Judge.Insulted { strikes_left; _ } as v), _) ->
      let y = centred_block (Judge.headline v) y 28 red in
      centred
        (Printf.sprintf "%d strike%s left" strikes_left (if strikes_left = 1 then "" else "s"))
        (y + 6) 20 text_colour
  | Collect.Verdict (v, _) -> centred (Judge.headline v) y 40 (rgb (Accuracy.colour (Judge.score_of v)))
  | Collect.Prompt -> centred "Draw it from memory - click and drag" y 22 dim_colour
  | Collect.Drawing | Collect.Dissed _ | Collect.Complete -> ()

(**
   [stroke t] draws the stroke, tinted by the score.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: stroke t
   Complexity: O(s)
   Pseudocode:
     pts <- Collect.stroke t ; n <- |pts| ; if n < 2 then return
     colour <- Accuracy.colour (shown_score t)
     Catmull-Rom spline when n >= 4, else a line strip
*)
let stroke t =
  let pts = Collect.stroke t in
  let n = Array.length pts in
  if n >= 2 then begin
    let colour = rgb (Accuracy.colour (shown_score t)) in
    let arr = Ctypes.CArray.of_list Vector2.t (List.map Sky.to_vector2 (Array.to_list pts)) in
    if n >= 4 then draw_spline_catmull_rom (Ctypes.CArray.start arr) n 4. colour
    else draw_line_strip (Ctypes.CArray.start arr) n colour
  end

(**
   [shelf t] draws the collection tiles.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: shelf t shows "[x] Big Dipper 91.2%"
   Complexity: O(n)
   Pseudocode:
     tile width <- (screen width - 40) / n ; for each figure, left to right:
       collected -> bright "[x] <name> <best %>" ; else dim "[ ] <name>"
       the current target's tile is outlined
*)
let shelf t =
  let c = Collect.collection t in
  let figs = Collection.figures c in
  let n = Array.length figs in
  if n > 0 then begin
    let w = get_screen_width () and h = get_screen_height () in
    let tile = (w - 40) / n and y = h - 64 in
    Array.iteri
      (fun i f ->
        let name = Asterism.name f in
        let x = 20 + (i * tile) in
        let got = Collection.is_collected c name in
        let current = Option.map Asterism.name (Collect.target t) = Some name in
        draw_rectangle (x + 3) y (tile - 6) 48 (fade (if got then Color.darkgreen else Color.darkgray) 0.35);
        if current then draw_rectangle_lines (x + 3) y (tile - 6) 48 Color.gold;
        draw_text ((if got then "[x] " else "[ ] ") ^ name) (x + 10) (y + 6) 16
          (if got then Color.raywhite else dim_colour);
        match Collection.best c name with
        | Some b -> draw_text (Accuracy.format b) (x + 10) (y + 26) 16 (rgb (Accuracy.colour b))
        | None -> ())
      figs
  end

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
let diss_screen line seconds_left =
  let h = get_screen_height () in
  centred "GAME OVER" (h / 4) 64 red;
  let y = centred_block line ((h / 4) + 110) 34 Color.raywhite in
  centred
    (Printf.sprintf "Closing in %d..." (max 1 (int_of_float (Float.ceil seconds_left))))
    (y + 30) 22 dim_colour

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
let complete_screen t =
  let c = Collect.collection t in
  let figs = Collection.figures c in
  let h = get_screen_height () in
  centred (Printf.sprintf "All %d constellations collected!" (Array.length figs)) (h / 6) 48 Color.gold;
  let bests =
    Array.to_list figs |> List.filter_map (fun f -> Collection.best c (Asterism.name f))
  in
  Array.iteri
    (fun i f ->
      let b = Collection.best c (Asterism.name f) in
      centred
        (Printf.sprintf "%s   %s" (Asterism.name f) (Accuracy.format (Option.value ~default:0. b)))
        ((h / 6) + 90 + (i * 30)) 22
        (rgb (Accuracy.colour (Option.value ~default:0. b))))
    figs;
  if bests <> [] then begin
    let avg = List.fold_left ( +. ) 0. bests /. float_of_int (List.length bests) in
    centred ("Average best: " ^ Accuracy.format avg) ((h / 6) + 110 + (Array.length figs * 30)) 26
      Color.raywhite
  end;
  centred "Press M to return to the menu" (h - 60) 20 dim_colour

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
let draw (_ : Scene.ctx) t =
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
