(**
   File: case_opening.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Case_opening module: the case screen's rules - open a
                case, spin the reel, reveal the pack.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Case_opening (or Case_opening with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Case_opening: the case screen's rules, pure (no drawing, no disk).
    [bin/cases_scene.ml] wires it to the screen like the other modes.

    {v
      ┌───────────┐ Enter / click, ┌────────────┐ reel stops  ┌────────────┐
      │ Idle      │ a case is spent│ Spinning   │ (6 s, can't │ Revealed   │
      │ "N cases" ├───────────────►│ reel moves ├────────────►│ pack +     │
      │ packs     │                └────────────┘   skip)     │ rarity     │
      └─────▲─────┘                                           └─────┬──────┘
            └────────────────── Enter / click ──────────────────────┘
    v}

    The pack is unlocked the moment the case is opened (before the reel
    stops), so leaving mid-spin never loses it. *)

type phase =
  | Idle                          (** showing cases left and owned packs *)
  | Spinning of Case.spin * float (** the reel, and seconds since it started *)
  | Revealed of Case.spin         (** the reel stopped; showing what was won *)
(** Where the screen is. *)

type t
(** Inventory, phase, random state and whether the inventory changed. *)

val init : ?seed:int -> Inventory.t -> t
(**
   [init ?seed inv] opens the case screen on [Idle].
   Requires: nothing
   Returns: the state; [seed] fixes the rolls (for tests)
   Raises: nothing
   Example: phase (init Inventory.empty) = Idle
   Complexity: O(1)
*)

val apply : t -> Controls.command -> t
(**
   [apply t cmd] handles one command: on [Idle], [Dismiss] (Enter) or
   [Pen_up] (a click) spends a case, rolls it ({!Case.open_case}),
   unlocks the pack and starts [Spinning]; with no cases it does nothing.
   On [Revealed] the same commands return to [Idle]. Everything else,
   and anything during [Spinning], is ignored. A [Pen_up] only counts as
   a click if the button also went down on this screen ([Pen_down]), so
   the click that opened the screen from the menu doesn't open a case.
   Requires: nothing
   Returns: the new state
   Raises: nothing
   Example: phase (apply (init (Inventory.add_cases 1 Inventory.empty)) Controls.Dismiss)
            = Spinning (_, 0.)
   Complexity: O(reel_length * packs) when opening, else O(1)
*)

val tick : float -> t -> t
(**
   [tick dt t] advances the reel; when it stops the phase becomes [Revealed].
   Requires: [dt >= 0.]
   Returns: the advanced state
   Raises: nothing
   Example: phase (tick 10. spinning) = Revealed _
   Complexity: O(1)
*)

val phase : t -> phase
(**
   [phase t] is where the screen is.
   Requires: nothing
   Returns: the phase
   Raises: nothing
   Example: phase (init Inventory.empty) = Idle
   Complexity: O(1)
*)

val inventory : t -> Inventory.t
(**
   [inventory t] is the current inventory (cases left, packs owned).
   Requires: nothing
   Returns: the inventory
   Raises: nothing
   Example: Inventory.cases (inventory (init inv)) = Inventory.cases inv
   Complexity: O(1)
*)

val take_save_request : t -> t * Inventory.t option
(**
   [take_save_request t] hands the screen the inventory to save once per
   change (after each case opened), so these rules never touch the disk.
   Requires: nothing
   Returns: the state with the request cleared, and [Some inv] or [None]
   Raises: nothing
   Example: snd (take_save_request (init inv)) = None
   Complexity: O(1)
*)
