(* PLANNED (welcome page): stub implementation. The interface in
   menu.mli is the contract; replace each [todo] with the real code.
   See docs/WELCOME_PLAN.md. *)

type 'a item = { label : string; detail : string option; action : 'a; enabled : bool }
type 'a t = { items : 'a item array; selected : int }
type command = Up | Down | Choose | Point of Geom.pt | Click of Geom.pt
type rect = { x : float; y : float; w : float; h : float }

let todo what = failwith ("Menu." ^ what ^ ": not implemented yet (see menu.mli)")

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
let create (_ : 'a item list) : 'a t = todo "create"

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
let read (_ : Scene.input) : command list = todo "read"

(**
   [layout m ~width ~height] places the buttons.
   Requires: positive size
   Returns: one rect per item
   Raises: nothing
   Example: Array.length (layout m ~width:1280 ~height:800) = List.length (items m)
   Complexity: O(n)
   Pseudocode:
     w <- 420 ; h <- 56 ; gap <- 14
     top <- height / 2 ; x <- (width - w) / 2
     rect i = { x; y = top + i (h + gap); w; h }
*)
let layout (_ : 'a t) ~width:(_ : int) ~height:(_ : int) : rect array = todo "layout"

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
let item_at (_ : rect array) (_ : Geom.pt) : int option = todo "item_at"

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
let apply (_ : 'a t) ~rects:(_ : rect array) (_ : command) : 'a t * 'a option = todo "apply"
