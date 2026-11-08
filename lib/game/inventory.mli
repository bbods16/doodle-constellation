(**
   File: inventory.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Inventory module: unopened cases and unlocked insult
                packs, saved to data/unlocks.csv.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Inventory (or Inventory with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Inventory: unopened cases and unlocked insult packs.

    Earned in collect mode (one case per newly collected constellation
    and per new record), spent on the case screen. Saved to
    [data/unlocks.csv] between runs, like {!Collection}'s progress.
    Immutable: every change returns a new value. *)

type t
(** Case count and the ids of unlocked packs. Abstract. *)

val unlocks_file : string
(** Save file name, next to the catalogue: ["unlocks.csv"]. *)

val empty : t
(** No cases, no packs. *)

val cases : t -> int
(**
   [cases inv] is how many unopened cases the player has.
   Requires: nothing
   Returns: a count [>= 0]
   Raises: nothing
   Example: cases empty = 0
   Complexity: O(1)
*)

val add_cases : int -> t -> t
(**
   [add_cases n inv] gives the player [n] more cases.
   Requires: [n >= 0]
   Returns: the updated inventory
   Raises: [Invalid_argument] if [n < 0]
   Example: cases (add_cases 2 empty) = 2
   Complexity: O(1)
*)

val spend_case : t -> t option
(**
   [spend_case inv] uses up one case.
   Requires: nothing
   Returns: [Some inv'] with one case fewer, or [None] with no cases left
   Raises: nothing
   Example: spend_case empty = None
   Complexity: O(1)
*)

val owns : t -> string -> bool
(**
   [owns inv id] tells whether the pack with this id is unlocked.
   Requires: nothing
   Returns: [true] once unlocked
   Raises: nothing
   Example: owns empty "black_hole" = false
   Complexity: O(n), n packs owned
*)

val unlock : string -> t -> t
(**
   [unlock id inv] adds a pack (unknown ids and duplicates are ignored).
   Requires: nothing
   Returns: the updated inventory
   Raises: nothing
   Example: owns (unlock "black_hole" empty) "black_hole" = true
   Complexity: O(n)
*)

val owned_packs : t -> Insult_pack.t list
(**
   [owned_packs inv] is every unlocked pack, rarest first.
   Requires: nothing
   Returns: the packs
   Raises: nothing
   Example: owned_packs empty = []
   Complexity: O(n log n)
*)

val extra_insults : t -> string list
(**
   [extra_insults inv] is every insult line from unlocked packs, to add
   to {!Roast.insults}.
   Requires: nothing
   Returns: the lines (empty when nothing is unlocked)
   Raises: nothing
   Example: extra_insults empty = []
   Complexity: O(total lines)
*)

val extra_disses : t -> string list
(**
   [extra_disses inv] is every final-diss line from unlocked packs, to
   add to {!Roast.final_disses}.
   Requires: nothing
   Returns: the lines
   Raises: nothing
   Example: extra_disses empty = []
   Complexity: O(total lines)
*)

val save : string -> t -> unit
(**
   [save path inv] writes the inventory: a ["cases,<n>"] line, then one
   ["pack,<id>"] line per unlocked pack.
   Requires: the folder exists and is writable
   Returns: unit
   Raises: [Sys_error] if the file cannot be written
   Example: save "data/unlocks.csv" inv
   Complexity: O(n)
*)

val load : string -> t
(**
   [load path] restores a saved inventory; unknown pack ids are dropped.
   Requires: nothing
   Returns: the inventory, or {!empty} if the file is missing or unreadable
   Raises: nothing
   Example: cases (load "missing.csv") = 0
   Complexity: O(F)
*)
