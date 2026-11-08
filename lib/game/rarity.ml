(**
   File: rarity.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Rarity module: the CS2-style rarity tiers of
                insult packs, with CS2's case odds and colours.
   Usage: The contract is in rarity.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Rarity (or Rarity with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* CS2-style rarity tiers. See rarity.mli for the contract. *)

type t = Mil_spec | Restricted | Classified | Covert | Exceedingly_rare

let all = [ Mil_spec; Restricted; Classified; Covert; Exceedingly_rare ]

(**
   [label r] is the display name.
   Requires: nothing
   Returns: the tier's name
   Raises: nothing
   Example: label Covert = "Covert"
   Complexity: O(1)
   Pseudocode:
     one string per constructor
*)
let label = function
  | Mil_spec -> "Mil-Spec"
  | Restricted -> "Restricted"
  | Classified -> "Classified"
  | Covert -> "Covert"
  | Exceedingly_rare -> "Exceedingly Rare"

(**
   [odds r] is the tier's probability.
   Requires: nothing
   Returns: CS2's published case odds
   Raises: nothing
   Example: odds Mil_spec = 0.7992
   Complexity: O(1)
   Pseudocode:
     0.7992 ; 0.1598 ; 0.0320 ; 0.0064 ; 0.0026
*)
let odds = function
  | Mil_spec -> 0.7992
  | Restricted -> 0.1598
  | Classified -> 0.0320
  | Covert -> 0.0064
  | Exceedingly_rare -> 0.0026

(**
   [colour r] is the tier's colour.
   Requires: nothing
   Returns: RGB
   Raises: nothing
   Example: colour Covert = (235, 75, 75)
   Complexity: O(1)
   Pseudocode:
     blue ; purple ; pink ; red ; gold
*)
let colour = function
  | Mil_spec -> (75, 105, 255)
  | Restricted -> (136, 71, 255)
  | Classified -> (211, 46, 230)
  | Covert -> (235, 75, 75)
  | Exceedingly_rare -> (255, 215, 0)

(**
   [of_roll u] picks the tier for a uniform roll.
   Requires: nothing (clamped to [0, 1))
   Returns: the tier
   Raises: nothing
   Example: of_roll 0.5 = Mil_spec
   Complexity: O(1)
   Pseudocode:
     acc <- 0
     for r in all (commonest first): acc += odds r ; if u < acc then return r
     return Exceedingly_rare            (rounding at the top end)
*)
let of_roll u =
  let u = Float.max 0. (Float.min 0.999999 u) in
  let rec go acc = function
    | [] -> Exceedingly_rare
    | r :: rest ->
        let acc = acc +. odds r in
        if u < acc then r else go acc rest
  in
  go 0. all

(**
   [rank r] is the sort order.
   Requires: nothing
   Returns: 0 .. 4
   Raises: nothing
   Example: rank Covert = 3
   Complexity: O(1)
   Pseudocode:
     position in [all]
*)
let rank = function
  | Mil_spec -> 0
  | Restricted -> 1
  | Classified -> 2
  | Covert -> 3
  | Exceedingly_rare -> 4
