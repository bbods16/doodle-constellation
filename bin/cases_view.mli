(**
   File: cases_view.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Cases_view module: draws the case screen CS2-style -
                the scrolling reel, the reveal and the pack shelf.
   Usage: Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(** Cases_view: draws the case screen ({!Case_opening.t}), CS2 style.

    {v
     ┌──────────────────────────────────────────────────────────────┐
     │ CONSTELLATION CASE                               3 cases      │  header
     │                              ▼                               │
     │  ┌──────┐┌──────┐┌──────┐┌──────┐┌──────┐┌──────┐┌──────┐    │  reel: cards slide left,
     │  │Mission││Cloudy││Event ││Super-││Gift  ││Astro ││Night │    │  slowing to a stop with the
     │  │Control││Night ││Horizn││nova  ││Shop  ││101   ││Shift │    │  winner under the marker;
     │  ▔▔blue▔▔▔▔blue▔▔▔▔purple▔▔▔pink▔▔▔blue▔▔▔▔blue▔▔▔▔▔red▔▔    │  colour bar = rarity
     │                              ▲                               │
     │            NEW PACK: Event Horizon (Restricted)              │  reveal
     │     "That Orion has the gravitational pull of zero viewers." │  sample insult
     │                                                              │
     │ [x] Astronomy 101  [ ] Cloudy Night  [x] Event Horizon ...   │  shelf: all packs
     │ Enter / click: open a case        M / Esc: back to the menu   │  footer
     └──────────────────────────────────────────────────────────────┘
    v} *)

val draw : Scene.ctx -> Case_opening.t -> unit
(**
   [draw ctx t] paints the screen for the current phase: {!header}, then
   {!reel} (spinning or stopped) and {!reveal}, or the idle prompt, then
   {!shelf} and {!footer}.
   Requires: inside the loop's drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: O(reel_length + packs)
*)

val header : Case_opening.t -> unit
(**
   [header t] draws the title and the number of unopened cases.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: header t shows "CONSTELLATION CASE" and "3 cases"
   Complexity: O(1)
*)

val reel : Case.spin -> float -> unit
(**
   [reel spin elapsed] draws the strip of item cards scrolled by
   {!Case.position} [elapsed], each with its rarity colour bar, and the
   gold centre marker.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: reel spin 6.0 draws the winner centred under the marker
   Complexity: O(visible cards)
*)

val reveal : Case.spin -> unit
(**
   [reveal spin] announces the pack: ["NEW PACK"] or ["DUPLICATE"], its
   name and rarity in the rarity colour, how many insults it adds, a
   sample line, and ["Press Enter to continue"].
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: reveal spin shows "NEW PACK: Event Horizon"
   Complexity: O(L)
*)

val idle_prompt : Case_opening.t -> unit
(**
   [idle_prompt t] tells the player how to open a case, or how to earn
   one when they have none.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: idle_prompt t shows "Press Enter or click to open a case"
   Complexity: O(1)
*)

val shelf : Case_opening.t -> unit
(**
   [shelf t] draws every pack as a tile: owned ones bright with ["[x]"],
   locked ones dim, each underlined in its rarity colour.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: shelf t shows "[x] Event Horizon" in purple
   Complexity: O(packs)
*)

val footer : unit -> unit
(**
   [footer ()] draws the key hints.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: footer () shows "Enter / click: open a case    M / Esc: back to the menu"
   Complexity: O(1)
*)
