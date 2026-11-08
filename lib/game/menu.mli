(**
   File: menu.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Menu module: a generic keyboard and mouse list menu -
                items, selection, button layout and hit-testing.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Menu (or Menu with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Menu: a generic, reusable list menu (keyboard and mouse), as pure
    logic: no drawing. Used by the welcome page ({!Title}); reusable for
    a pause or settings menu later.

    Design notes: [docs/WELCOME_PLAN.md].

    The menu is generic in its action type ['a]: the welcome page uses
    {!Title.action}, another screen can use its own. Selection skips
    disabled items and wraps at both ends. *)

type 'a item = {
  label : string;           (** text on the button, e.g. ["Collect the constellations"] *)
  detail : string option;   (** smaller second line, e.g. [Some "3 / 7 collected"] *)
  action : 'a;              (** what choosing the item does *)
  enabled : bool;           (** disabled items are shown dimmed and cannot be chosen *)
}
(** One menu entry. *)

type 'a t
(** The items and which one is selected. Abstract, immutable. *)

type command =
  | Up              (** select the previous enabled item *)
  | Down            (** select the next enabled item *)
  | Choose          (** activate the selected item *)
  | Point of Geom.pt  (** the mouse is over this point (hover selects) *)
  | Click of Geom.pt  (** the mouse was pressed at this point *)
(** Menu input, independent of raylib. *)

type rect = { x : float; y : float; w : float; h : float }
(** A screen rectangle in pixels (top-left corner, width, height). *)

val create : 'a item list -> 'a t
(**
   [create items] is a menu with the first enabled item selected.
   Requires: at least one item is enabled
   Returns: the menu
   Raises: [Invalid_argument] if [items] is empty or none is enabled
   Example: selected_index (create [a; b]) = 0
   Complexity: O(n)
*)

val items : 'a t -> 'a item list
(**
   [items m] is the menu's entries, in order.
   Requires: nothing
   Returns: the items given to {!create}
   Raises: nothing
   Example: List.length (items (create [a; b])) = 2
   Complexity: O(1)
*)

val selected_index : 'a t -> int
(**
   [selected_index m] is the position of the selected item.
   Requires: nothing
   Returns: an index into {!items}, always an enabled item
   Raises: nothing
   Example: selected_index (create [a; b]) = 0
   Complexity: O(1)
*)

val read : Scene.input -> command list
(**
   [read inp] turns a frame of input into menu commands: Up/W, Down/S,
   Enter/Space, the mouse position every frame, and a click when the
   button goes down.
   Requires: nothing
   Returns: the commands, keyboard first, then [Point], then [Click]
   Raises: nothing
   Example: read { idle with keys = [Down] } = [Down; Point origin]
   Complexity: O(k)
*)

val layout : 'a t -> width:int -> height:int -> rect array
(**
   [layout m ~width ~height] places one button per item, stacked and
   centred in the lower half of the window.
   Requires: positive window size
   Returns: one rectangle per item, in order
   Raises: nothing
   Example: Array.length (layout m ~width:1280 ~height:800) = List.length (items m)
   Complexity: O(n)
*)

val item_at : rect array -> Geom.pt -> int option
(**
   [item_at rects p] is the index of the button under [p], if any.
   Requires: nothing
   Returns: [Some i] when [p] is inside [rects.(i)] (edges included)
   Raises: nothing
   Example: item_at [| { x = 0.; y = 0.; w = 10.; h = 10. } |] { x = 5.; y = 5. } = Some 0
   Complexity: O(n)
*)

val apply : 'a t -> rects:rect array -> command -> 'a t * 'a option
(**
   [apply m ~rects cmd] handles one command: [Up]/[Down] move the
   selection, [Point] selects the hovered item, [Choose] and a [Click] on
   an item return its action. Disabled items are never selected or chosen.
   Requires: [rects] is {!layout} of [m]
   Returns: the updated menu, and [Some action] when an item was chosen
   Raises: nothing
   Example: snd (apply m ~rects Choose) = Some (List.nth (items m) (selected_index m)).action
   Complexity: O(n)
*)
