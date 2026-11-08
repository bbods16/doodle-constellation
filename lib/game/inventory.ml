(**
   File: inventory.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Inventory module: unopened cases and unlocked
                insult packs, saved to data/unlocks.csv.
   Usage: The contract is in inventory.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Inventory (or Inventory with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Unopened cases and unlocked packs. See inventory.mli for the contract. *)

type t = { cases : int; packs : string list (* ids, unlock order *) }

let unlocks_file = "unlocks.csv"
let empty = { cases = 0; packs = [] }

(**
   [cases inv] is the case count.
   Requires: nothing
   Returns: inv.cases
   Raises: nothing
   Example: cases empty = 0
   Complexity: O(1)
   Pseudocode:
     return inv.cases
*)
let cases inv = inv.cases

(**
   [add_cases n inv] adds cases.
   Requires: n >= 0
   Returns: updated inventory
   Raises: Invalid_argument if n < 0
   Example: cases (add_cases 2 empty) = 2
   Complexity: O(1)
   Pseudocode:
     if n < 0 then fail ; return { inv with cases = cases + n }
*)
let add_cases n inv =
  if n < 0 then invalid_arg "Inventory.add_cases: negative";
  { inv with cases = inv.cases + n }

(**
   [spend_case inv] uses one case.
   Requires: nothing
   Returns: Some inventory or None
   Raises: nothing
   Example: spend_case empty = None
   Complexity: O(1)
   Pseudocode:
     if cases = 0 then None else Some { inv with cases = cases - 1 }
*)
let spend_case inv = if inv.cases <= 0 then None else Some { inv with cases = inv.cases - 1 }

(**
   [owns inv id] checks a pack.
   Requires: nothing
   Returns: membership
   Raises: nothing
   Example: owns empty "black_hole" = false
   Complexity: O(n)
   Pseudocode:
     return id in inv.packs
*)
let owns inv id = List.mem id inv.packs

(**
   [unlock id inv] adds a pack.
   Requires: nothing
   Returns: updated inventory
   Raises: nothing
   Example: owns (unlock "black_hole" empty) "black_hole" = true
   Complexity: O(n)
   Pseudocode:
     if id is unknown or already owned then inv
     else { inv with packs = packs @ [id] }
*)
let unlock id inv =
  if owns inv id || Insult_pack.find id = None then inv else { inv with packs = inv.packs @ [ id ] }

(**
   [owned_packs inv] lists unlocked packs, rarest first.
   Requires: nothing
   Returns: packs
   Raises: nothing
   Example: owned_packs empty = []
   Complexity: O(n log n)
   Pseudocode:
     map find over packs ; stable sort by descending Rarity.rank
*)
let owned_packs inv =
  List.filter_map Insult_pack.find inv.packs
  |> List.stable_sort (fun (a : Insult_pack.t) (b : Insult_pack.t) ->
         compare (Rarity.rank b.rarity) (Rarity.rank a.rarity))

(**
   [extra_insults inv] gathers insult lines from unlocked packs.
   Requires: nothing
   Returns: the lines
   Raises: nothing
   Example: extra_insults empty = []
   Complexity: O(total lines)
   Pseudocode:
     concat of p.insults over owned packs
*)
let extra_insults inv = List.concat_map (fun (p : Insult_pack.t) -> p.insults) (owned_packs inv)

(**
   [extra_disses inv] gathers final-diss lines from unlocked packs.
   Requires: nothing
   Returns: the lines
   Raises: nothing
   Example: extra_disses empty = []
   Complexity: O(total lines)
   Pseudocode:
     concat of p.final_disses over owned packs
*)
let extra_disses inv =
  List.concat_map (fun (p : Insult_pack.t) -> p.final_disses) (owned_packs inv)

(**
   [save path inv] writes the inventory.
   Requires: writable folder
   Returns: unit
   Raises: Sys_error
   Example: save "data/unlocks.csv" inv
   Complexity: O(n)
   Pseudocode:
     write "cases,<n>" then "pack,<id>" per pack
*)
let save path inv =
  Out_channel.with_open_text path (fun oc ->
      Printf.fprintf oc "cases,%d\n" inv.cases;
      List.iter (fun id -> Printf.fprintf oc "pack,%s\n" id) inv.packs)

(**
   [load path] restores the inventory.
   Requires: nothing
   Returns: inventory, or empty on any problem
   Raises: nothing
   Example: cases (load "missing.csv") = 0
   Complexity: O(F)
   Pseudocode:
     for each line: "cases,<n>" sets the count ; "pack,<id>" unlocks id
     on any read error return empty
*)
let load path =
  try
    In_channel.with_open_text path In_channel.input_all
    |> String.split_on_char '\n'
    |> List.fold_left
         (fun inv line ->
           match String.split_on_char ',' (String.trim line) with
           | [ "cases"; n ] -> (
               match int_of_string_opt n with Some n when n >= 0 -> { inv with cases = n } | _ -> inv)
           | [ "pack"; id ] -> unlock id inv
           | _ -> inv)
         empty
  with Sys_error _ -> empty
