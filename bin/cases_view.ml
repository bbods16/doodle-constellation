(**
   File: cases_view.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Cases_view module: draws the case screen
                CS2-style - the scrolling reel, the reveal and the pack shelf.
   Usage: The contract is in cases_view.mli.
          Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(* Drawing of the case screen. See cases_view.mli for the contract. *)

open Raylib

let text_colour = Color.create 200 210 230 255
let dim_colour = Color.create 110 120 140 255
let card_colour = Color.create 24 30 56 255
let card_w = 190
let card_h = 120
let card_gap = 10

(**
   [rgb (r, g, b)] is an opaque raylib colour.
   Requires: components in [0, 255]
   Returns: the colour
   Raises: nothing
   Example: rgb (Rarity.colour Rarity.Covert)
   Complexity: O(1)
   Pseudocode:
     Color.create r g b 255
*)
let rgb (r, g, b) = Color.create r g b 255

(**
   [centred text y size colour] draws text centred horizontally.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: centred "NEW PACK" 400 40 Color.gold
   Complexity: O(length of text)
   Pseudocode:
     draw_text text ((screen width - measure_text text size) / 2) y size colour
*)
let centred text y size colour =
  draw_text text ((get_screen_width () - measure_text text size) / 2) y size colour

(**
   [fit text size max_w] shortens [text] with "..." until it fits [max_w] pixels.
   Requires: [max_w > 0]
   Returns: the text, possibly shortened
   Raises: nothing
   Example: fit "Observatory Night Shift" 18 170 = "Observatory Nig..."
   Complexity: O(n^2) in the text length (short strings)
   Pseudocode:
     while measure_text text size > max_w: drop the last character, add "..."
*)
let fit text size max_w =
  let rec go s =
    if measure_text s size <= max_w || String.length s <= 3 then s
    else go (String.sub s 0 (String.length s - 4) ^ "...")
  in
  go text

(**
   [reel_y ()] is the top of the reel band.
   Requires: an open window
   Returns: pixels from the top
   Raises: nothing
   Example: reel_y () = 200 for an 800-pixel window
   Complexity: O(1)
   Pseudocode:
     return screen height / 4
*)
let reel_y () = get_screen_height () / 4

(**
   [header t] draws the title and case count.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: header t shows "CONSTELLATION CASE" and "3 cases"
   Complexity: O(1)
   Pseudocode:
     "CONSTELLATION CASE" top-left ; "<n> cases" top-right
*)
let header t =
  draw_text "CONSTELLATION CASE" 24 20 36 Color.raywhite;
  let n = Inventory.cases (Case_opening.inventory t) in
  let s = Printf.sprintf "%d case%s" n (if n = 1 then "" else "s") in
  draw_text s (get_screen_width () - 24 - measure_text s 28) 24 28 Color.gold

(**
   [reel spin elapsed] draws the scrolling strip and the marker.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: reel spin 6.0 draws the winner centred under the marker
   Complexity: O(visible cards)
   Pseudocode:
     pos <- Case.position elapsed ; step <- card_w + card_gap
     for each item i: x <- centre - card_w / 2 + (i - pos) * step
       if on screen: card background, pack name, rarity bar (rarity colour)
     dark band edges ; gold marker line and triangles at the centre
*)
let reel (spin : Case.spin) elapsed =
  let w = get_screen_width () and y = reel_y () in
  let pos = Case.position elapsed and step = card_w + card_gap in
  let centre = w / 2 in
  draw_rectangle 0 (y - 14) w (card_h + 28) (fade Color.black 0.45);
  Array.iteri
    (fun i (p : Insult_pack.t) ->
      let x = centre - (card_w / 2) + int_of_float ((float_of_int i -. pos) *. float_of_int step) in
      if x > -card_w && x < w then begin
        let colour = rgb (Rarity.colour p.rarity) in
        draw_rectangle x y card_w card_h card_colour;
        draw_rectangle x (y + card_h - 10) card_w 10 colour;
        draw_rectangle_lines x y card_w card_h (fade colour 0.6);
        draw_text (fit p.name 18 (card_w - 20)) (x + 10) (y + 18) 18 Color.raywhite;
        draw_text (Rarity.label p.rarity) (x + 10) (y + 48) 16 colour;
        draw_text (Printf.sprintf "+%d insults" (List.length p.insults)) (x + 10) (y + 74) 14 dim_colour
      end)
    spin.reel;
  draw_rectangle (centre - 2) (y - 18) 4 (card_h + 36) Color.gold;
  draw_triangle
    (Vector2.create (float_of_int (centre - 12)) (float_of_int (y - 22)))
    (Vector2.create (float_of_int centre) (float_of_int (y - 6)))
    (Vector2.create (float_of_int (centre + 12)) (float_of_int (y - 22)))
    Color.gold

(**
   [reveal spin] announces what the case gave.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: reveal spin shows "NEW PACK: Event Horizon"
   Complexity: O(L)
   Pseudocode:
     colour <- rarity colour of the pack
     "NEW PACK: <name>" (or "DUPLICATE: <name>") ; rarity label
     "+5 insults added to collect mode" (or "already owned") ; a sample line
     pulsing "Press Enter to continue"
*)
let reveal (spin : Case.spin) =
  let p = spin.won in
  let colour = rgb (Rarity.colour p.rarity) in
  let y = reel_y () + card_h + 50 in
  centred ((if spin.duplicate then "DUPLICATE: " else "NEW PACK: ") ^ p.name) y 40 colour;
  centred (Rarity.label p.rarity) (y + 50) 24 colour;
  let added =
    if spin.duplicate then "You already own this pack."
    else
      Printf.sprintf "+%d insults%s added to collect mode" (List.length p.insults)
        (match p.final_disses with [] -> "" | l -> Printf.sprintf " and %d final diss" (List.length l))
  in
  centred added (y + 90) 20 text_colour;
  (match p.insults with
  | line :: _ -> centred ("\"" ^ Roast.insult line ~score:23.4 ~target:"Orion" ^ "\"") (y + 126) 18 dim_colour
  | [] -> ());
  let pulse = 0.55 +. (0.45 *. sin (3. *. get_time ())) in
  centred "Press Enter to continue" (y + 170) 22 (fade Color.raywhite pulse)

(**
   [idle_prompt t] explains how to open or earn cases.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: idle_prompt t shows "Press Enter or click to open a case"
   Complexity: O(1)
   Pseudocode:
     if cases > 0 then pulsing "Press Enter or click to open a case"
     else "No cases yet" and how to earn them
*)
let idle_prompt t =
  let y = reel_y () + 40 in
  if Inventory.cases (Case_opening.inventory t) > 0 then begin
    let pulse = 0.55 +. (0.45 *. sin (3. *. get_time ())) in
    centred "Press Enter or click to open a case" y 32 (fade Color.gold pulse);
    centred "Each case unlocks an insult pack for collect mode." (y + 50) 20 text_colour
  end
  else begin
    centred "No cases yet" y 32 Color.raywhite;
    centred "Earn one by collecting a new constellation or setting a new record." (y + 50) 20
      text_colour
  end

(**
   [shelf t] draws every pack as a tile.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: shelf t shows "[x] Event Horizon" in purple
   Complexity: O(packs)
   Pseudocode:
     three columns of tiles at the bottom ; owned: "[x] name" bright,
     locked: "[ ] name" dim ; a bar in the rarity colour under each
*)
let shelf t =
  let inv = Case_opening.inventory t in
  let w = get_screen_width () and h = get_screen_height () in
  let cols = 3 and tile_h = 34 in
  let tile_w = (w - 60) / cols in
  let top = h - 60 - (3 * (tile_h + 8)) in
  draw_text
    (Printf.sprintf "Insult packs: %d / %d" (List.length (Inventory.owned_packs inv))
       (List.length Insult_pack.all))
    24 (top - 30) 20 text_colour;
  List.iteri
    (fun i (p : Insult_pack.t) ->
      let x = 30 + (i mod cols * tile_w) and y = top + (i / cols * (tile_h + 8)) in
      let owned = Inventory.owns inv p.id in
      let colour = rgb (Rarity.colour p.rarity) in
      draw_rectangle x y (tile_w - 10) tile_h (fade card_colour (if owned then 0.95 else 0.5));
      draw_rectangle x (y + tile_h - 4) (tile_w - 10) 4 (fade colour (if owned then 1. else 0.35));
      draw_text
        ((if owned then "[x] " else "[ ] ") ^ fit p.name 18 (tile_w - 60))
        (x + 10) (y + 8) 18
        (if owned then Color.raywhite else dim_colour))
    Insult_pack.all

(**
   [footer ()] draws the key hints.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: footer () shows the hints
   Complexity: O(1)
   Pseudocode:
     bottom-left grey text
*)
let footer () =
  draw_text "Enter / click: open a case    M / Esc: back to the menu" 24
    (get_screen_height () - 34) 16 dim_colour

(**
   [draw ctx t] paints the screen.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: O(reel_length + packs)
   Pseudocode:
     header
     match phase: Idle -> idle_prompt | Spinning (s, e) -> reel s e
                | Revealed s -> reel s spin_seconds ; reveal s
     shelf (not while spinning or revealing) ; footer
*)
let draw (_ : Scene.ctx) t =
  header t;
  (match Case_opening.phase t with
  | Case_opening.Idle ->
      idle_prompt t;
      shelf t
  | Case_opening.Spinning (s, e) -> reel s e
  | Case_opening.Revealed s ->
      reel s Case.spin_seconds;
      reveal s);
  footer ()
