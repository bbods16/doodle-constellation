(** Title_view: draws the welcome page ({!Title.t}), one function per
    element.

    PLANNED (welcome page) — interface only; the implementation is a stub.
    See [docs/WELCOME_PLAN.md].

    {v
     ┌──────────────────────────────────────────────────────────────┐
     │  · ·    ·        (starfield)          ·      ·   ·           │  background
     │          ✦───✦                                               │  attract (figure drawing
     │         ╱     ╲   Orion                                      │   itself, fading)
     │               DOODLE CONSTELLATION                           │  title
     │          Draw a shape. Find it in the stars.                 │
     │        ┌────────────────────────────────────┐                │
     │        │ ▸ Collect the constellations        │                │  menu_buttons
     │        │     3 / 7 collected · avg best 71.4% │                │   (selected = highlighted,
     │        ├────────────────────────────────────┤                │    detail line under label,
     │        │   Free draw                          │                │    disabled = dimmed)
     │        │   How to play                        │                │
     │        │   Reset progress                     │                │
     │        │   Quit                               │                │
     │        └────────────────────────────────────┘                │
     │  ↑↓ / mouse to choose · Enter to select      engine: ready   │  footer
     └──────────────────────────────────────────────────────────────┘
    v}
    The Help page replaces the menu with {!help_page}; Confirm_reset
    draws {!confirm_dialog} over a dimmed main page. *)

val draw : Scene.ctx -> Title.t -> unit
(**
   [draw ctx t] paints the page: {!background}, {!attract}, {!title},
   then {!menu_buttons}, {!help_page} or {!confirm_dialog} for the
   current page, then {!footer}.
   Requires: inside the loop's drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx t
   Complexity: O(N + k + n), N stars, k figure stars, n menu items
*)

val background : Scene.ctx -> unit
(**
   [background ctx] draws the starfield (the default wide sky view).
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: background ctx
   Complexity: O(N)
*)

val attract : Title.t -> unit
(**
   [attract t] draws the figure drawing itself in the upper-left area:
   faint star dots, the drawn part of the line, and the figure's name,
   all faded by {!Attract.alpha}.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: attract t
   Complexity: O(k)
*)

val title : Title.t -> unit
(**
   [title t] draws the game name and tagline, centred, with a gentle
   pulse from {!Title.elapsed}.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: title t shows "Doodle Constellation"
   Complexity: O(1)
*)

val menu_buttons : Title.t -> unit
(**
   [menu_buttons t] draws the current menu at {!Menu.layout}: one button
   per item, the selected one highlighted with a marker, the detail line
   under its label, disabled items dimmed.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: menu_buttons t shows "▸ Collect the constellations" selected
   Complexity: O(n)
*)

val help_page : Title.t -> unit
(**
   [help_page t] draws "How to play": {!Title.help_lines} in a centred
   panel, and "Press any key to go back".
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: help_page t
   Complexity: O(lines)
*)

val confirm_dialog : Title.t -> unit
(**
   [confirm_dialog t] dims the page and draws "Reset all progress?
   This deletes your collected constellations and best scores." with the
   No / Yes buttons ({!menu_buttons} of the confirm menu).
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: confirm_dialog t
   Complexity: O(1)
*)

val footer : Scene.ctx -> unit
(**
   [footer ctx] draws the key hints at the bottom left and the
   recognition engine's status at the bottom right.
   Requires: inside the drawing block
   Returns: unit
   Raises: nothing
   Example: footer ctx shows "engine: ready (7 figures)"
   Complexity: O(1)
*)
