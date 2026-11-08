(**
   File: rarity.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Rarity module: the CS2-style rarity tiers of insult
                packs, with CS2's case odds and colours.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Rarity (or Rarity with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Rarity: the CS2-style quality tiers of insult packs, with CS2's
    published case odds and colours.

    {v
    tier              colour   odds
    Mil_spec          blue     79.92%
    Restricted        purple   15.98%
    Classified        pink      3.20%
    Covert            red       0.64%
    Exceedingly_rare  gold      0.26%
    v} *)

type t =
  | Mil_spec          (** most common *)
  | Restricted
  | Classified
  | Covert
  | Exceedingly_rare  (** rarest: the "knife" tier *)
(** A rarity tier, commonest first. *)

val all : t list
(** Every tier, commonest first. *)

val label : t -> string
(**
   [label r] is the tier's display name.
   Requires: nothing
   Returns: ["Mil-Spec"], ["Restricted"], ["Classified"], ["Covert"] or
            ["Exceedingly Rare"]
   Raises: nothing
   Example: label Covert = "Covert"
   Complexity: O(1)
*)

val odds : t -> float
(**
   [odds r] is the chance of rolling this tier from a case.
   Requires: nothing
   Returns: a probability; the five sum to 1
   Raises: nothing
   Example: odds Mil_spec = 0.7992
   Complexity: O(1)
*)

val colour : t -> int * int * int
(**
   [colour r] is the tier's CS2 colour as RGB.
   Requires: nothing
   Returns: components in [0, 255]
   Raises: nothing
   Example: colour Covert = (235, 75, 75)
   Complexity: O(1)
*)

val of_roll : float -> t
(**
   [of_roll u] maps a uniform random number to a tier by the odds above
   (cumulative, commonest first).
   Requires: [0. <= u < 1.] (values outside are clamped)
   Returns: the tier whose odds interval contains [u]
   Raises: nothing
   Example: of_roll 0.5 = Mil_spec    of_roll 0.999 = Exceedingly_rare
   Complexity: O(1)
*)

val rank : t -> int
(**
   [rank r] orders tiers for sorting: 0 for Mil-Spec up to 4 for
   Exceedingly Rare.
   Requires: nothing
   Returns: an integer in [0, 4]
   Raises: nothing
   Example: rank Covert = 3
   Complexity: O(1)
*)
