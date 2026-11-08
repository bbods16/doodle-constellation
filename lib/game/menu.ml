(**
   File: menu.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Menu module: a generic keyboard and mouse list
                menu - items, selection, button layout and hit-testing.
   Usage: The contract is in menu.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Menu (or Menu with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Generic keyboard + mouse menu. See menu.mli for the contract. *)

type 'a item = { label : string; detail : string option; action : 'a; enabled : bool }
type 'a t = { items : 'a item array; selected : int }
type command = Up | Down | Choose | Point of Geom.pt | Click of Geom.pt
type rect = { x : float; y : float; w : float; h : float }

let button_w = 460.
let button_h = 58.
let gap = 12.

(**
   [create items] builds the menu.
   Requires: an enabled item
   Returns: first enabled item selected
   Raises: Invalid_argument
   Example: selected_index (create [a; b]) = 0
   Complexity: O(n)
   Pseudocode:
     arr <- array of items ; i <- index of first enabled (fail if none)
     return { items = arr; selected = i }
*)
let create items =
  let arr = Array.of_list items in
  let rec first i =
    if i >= Array.length arr then invalid_arg "Menu.create: no enabled item"
    else if arr.(i).enabled then i
    else first (i + 1)
  in
  { items = arr; selected = first 0 }

(**
   [items m] is the entries.
   Requires: nothing
   Returns: items in order
   Raises: nothing
   Example: List.length (items (create [a; b])) = 2
   Complexity: O(n)
   Pseudocode:
     return list of m.items
*)
let items m = Array.to_list m.items

(**
   [selected_index m] is the selection.
   Requires: nothing
   Returns: m.selected
   Raises: nothing
   Example: selected_index (create [a; b]) = 0
   Complexity: O(1)
   Pseudocode:
     return m.selected
*)
let selected_index m = m.selected

(**
   [read inp] maps input to menu commands.
   Requires: nothing
   Returns: keyboard commands, Point, then Click
   Raises: nothing
   Example: read { idle with keys = [Down] } = [Down; Point origin]
   Complexity: O(k)
   Pseudocode:
     keys: Up | Letter 'w' -> Up ; Down | Letter 's' -> Down ; Enter | Space -> Choose
     then Point inp.mouse ; then Click inp.mouse if inp.mouse_pressed
*)
let read (inp : Scene.input) =
  let key = function
    | Scene.Up | Scene.Letter 'w' -> Some Up
    | Scene.Down | Scene.Letter 's' -> Some Down
    | Scene.Enter | Scene.Space -> Some Choose
    | _ -> None
  in
  List.filter_map key inp.keys
  @ [ Point inp.mouse ]
  @ if inp.mouse_pressed then [ Click inp.mouse ] else []

(**
   [layout m ~width ~height] places the buttons.
   Requires: positive size
   Returns: one rect per item
   Raises: nothing
   Example: Array.length (layout m ~width:1280 ~height:800) = List.length (items m)
   Complexity: O(n)
   Pseudocode:
     total <- n * button_h + (n - 1) * gap
     top <- height * 0.42, moved up if the stack would leave the window
     x <- (width - button_w) / 2
     rect i = { x; y = top + i (button_h + gap); button_w; button_h }
*)
let layout m ~width ~height =
  let n = float_of_int (Array.length m.items) in
  let total = (n *. button_h) +. ((n -. 1.) *. gap) in
  let h = float_of_int height in
  let top = Float.max 10. (Float.min (h *. 0.42) (h -. total -. 50.)) in
  let x = (float_of_int width -. button_w) /. 2. in
  Array.mapi (fun i _ -> { x; y = top +. (float_of_int i *. (button_h +. gap)); w = button_w; h = button_h })
    m.items

(**
   [item_at rects p] hit-tests.
   Requires: nothing
   Returns: Some index or None
   Raises: nothing
   Example: item_at [| { x = 0.; y = 0.; w = 10.; h = 10. } |] { x = 5.; y = 5. } = Some 0
   Complexity: O(n)
   Pseudocode:
     first i with r.x <= p.x <= r.x + r.w and r.y <= p.y <= r.y + r.h
*)
let item_at rects (p : Geom.pt) =
  let rec go i =
    if i >= Array.length rects then None
    else
      let r = rects.(i) in
      if p.x >= r.x && p.x <= r.x +. r.w && p.y >= r.y && p.y <= r.y +. r.h then Some i
      else go (i + 1)
  in
  go 0

(**
   [step m dir] moves the selection to the next enabled item in [dir],
   wrapping around.
   Requires: at least one enabled item
   Returns: the menu with the new selection
   Raises: nothing
   Example: selected_index (step (create [a; b]) 1) = 1
   Complexity: O(n)
   Pseudocode:
     i <- selected ; repeat i <- (i + dir) mod n until items.(i) enabled
*)
let step m dir =
  let n = Array.length m.items in
  let rec go i k =
    if k > n then m.selected
    else
      let i = (((i + dir) mod n) + n) mod n in
      if m.items.(i).enabled then i else go i (k + 1)
  in
  { m with selected = go m.selected 1 }

(**
   [apply m ~rects cmd] handles one command.
   Requires: rects = layout m
   Returns: updated menu and chosen action
   Raises: nothing
   Example: snd (apply m ~rects Choose) = Some selected action
   Complexity: O(n)
   Pseudocode:
     Up / Down -> step to the previous / next enabled item, wrapping
     Point p   -> if item_at p = Some i and i enabled then select i
     Choose    -> (m, Some selected.action)
     Click p   -> if item_at p = Some i and i enabled then (select i, Some action i)
                  else (m, None)
*)
let apply m ~rects cmd =
  let hit p =
    match item_at rects p with Some i when m.items.(i).enabled -> Some i | _ -> None
  in
  match cmd with
  | Up -> (step m (-1), None)
  | Down -> (step m 1, None)
  | Choose -> (m, Some m.items.(m.selected).action)
  | Point p -> ((match hit p with Some i -> { m with selected = i } | None -> m), None)
  | Click p -> (
      match hit p with
      | Some i -> ({ m with selected = i }, Some m.items.(i).action)
      | None -> (m, None))
