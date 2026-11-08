(**
   File: insult_pack.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Insult_pack module: the catalogue of unlockable
                insult packs that cases drop, each with a rarity and extra insults.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Insult_pack (or Insult_pack with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Insult_pack: the unlockable packs of extra insults that cases drop.

    Each pack has a rarity ({!Rarity}) and adds its lines to collect
    mode's pool once unlocked (see {!Inventory.extra_insults}). Lines use
    the same [{score}] and [{target}] placeholders as {!Roast.insults}.
    Rarer packs also add final disses for the 5th strike.

    Like the base insults, every line roasts the drawing, never the
    player: no slurs, nothing about identity, appearance or real-life
    ability. *)

type t = {
  id : string;                 (** stable key used in the save file, e.g. ["black_hole"] *)
  name : string;               (** display name, e.g. ["Event Horizon"] *)
  rarity : Rarity.t;           (** how rare the pack is in a case *)
  insults : string list;       (** lines added to the insult pool *)
  final_disses : string list;  (** lines added to the final-diss pool (may be empty) *)
}
(** One pack. Plain data. *)

val all : t list
(** Every pack, commonest rarity first. 9 packs: 4 Mil-Spec,
    2 Restricted, 1 Classified, 1 Covert, 1 Exceedingly Rare. *)

val find : string -> t option
(**
   [find id] is the pack with this id.
   Requires: nothing
   Returns: [Some pack] or [None] for an unknown id
   Raises: nothing
   Example: Option.map (fun p -> p.name) (find "black_hole") = Some "Event Horizon"
   Complexity: O(n)
*)

val of_rarity : Rarity.t -> t list
(**
   [of_rarity r] is every pack of this tier, in catalogue order.
   Requires: nothing
   Returns: the packs (every tier has at least one)
   Raises: nothing
   Example: List.length (of_rarity Rarity.Mil_spec) = 4
   Complexity: O(n)
*)
