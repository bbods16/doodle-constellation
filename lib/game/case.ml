(**
   File: case.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Case module: rolling a case (rarity, then a
                pack) and the CS2-style reel animation.
   Usage: The contract is in case.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Case (or Case with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Case rolls and the reel animation. See case.mli for the contract. *)

type spin = { reel : Insult_pack.t array; winner_index : int; won : Insult_pack.t; duplicate : bool }

let reel_length = 56
let winner_slot = 48
let spin_seconds = 6.0

(**
   [pick rng l] is a uniformly random element of a non-empty list.
   Requires: [l] non-empty
   Returns: an element
   Raises: Invalid_argument on an empty list
   Example: pick rng [x] = x
   Complexity: O(n)
   Pseudocode:
     return List.nth l (random int below length)
*)
let pick rng l =
  match l with
  | [] -> invalid_arg "Case.pick: empty"
  | _ -> List.nth l (Random.State.int rng (List.length l))

(**
   [random_pack rng] is a pack drawn by rarity odds, ignoring ownership
   (filler for the reel).
   Requires: nothing
   Returns: a pack
   Raises: nothing
   Example: random_pack rng is usually a Mil-Spec pack
   Complexity: O(n)
   Pseudocode:
     r <- Rarity.of_roll (uniform) ; return pick rng (Insult_pack.of_rarity r)
*)
let random_pack rng = pick rng (Insult_pack.of_rarity (Rarity.of_roll (Random.State.float rng 1.)))

(**
   [roll rng ~owned] picks the case's pack.
   Requires: nothing
   Returns: (pack, duplicate)
   Raises: nothing
   Example: roll rng ~owned:(fun _ -> false) has duplicate = false
   Complexity: O(n)
   Pseudocode:
     tier <- Rarity.of_roll (uniform)
     fresh <- packs of tier not owned
     if fresh <> [] then (pick fresh, false) else (pick (packs of tier), true)
*)
let roll rng ~owned =
  let tier = Insult_pack.of_rarity (Rarity.of_roll (Random.State.float rng 1.)) in
  match List.filter (fun (p : Insult_pack.t) -> not (owned p.id)) tier with
  | [] -> (pick rng tier, true)
  | fresh -> (pick rng fresh, false)

(**
   [open_case rng ~owned] rolls the winner and builds the reel.
   Requires: nothing
   Returns: the spin
   Raises: nothing
   Example: let s = open_case rng ~owned in s.reel.(s.winner_index) == s.won
   Complexity: O(reel_length * n)
   Pseudocode:
     (won, duplicate) <- roll rng ~owned
     reel <- reel_length random packs ; reel.(winner_slot) <- won
     return { reel; winner_index = winner_slot; won; duplicate }
*)
let open_case rng ~owned =
  let won, duplicate = roll rng ~owned in
  let reel = Array.init reel_length (fun _ -> random_pack rng) in
  reel.(winner_slot) <- won;
  { reel; winner_index = winner_slot; won; duplicate }

(**
   [position elapsed] is the reel offset in items.
   Requires: nothing
   Returns: value in [0, winner_slot]
   Raises: nothing
   Example: position spin_seconds = 48.
   Complexity: O(1)
   Pseudocode:
     u <- clamp 0 1 (elapsed / spin_seconds)
     return winner_slot * (1 - (1 - u)^4)        (* fast start, long slow stop *)
*)
let position elapsed =
  let u = Float.max 0. (Float.min 1. (elapsed /. spin_seconds)) in
  float_of_int winner_slot *. (1. -. ((1. -. u) ** 4.))

(**
   [finished elapsed] tells whether the reel stopped.
   Requires: nothing
   Returns: elapsed >= spin_seconds
   Raises: nothing
   Example: finished 6.0 = true
   Complexity: O(1)
   Pseudocode:
     return elapsed >= spin_seconds
*)
let finished elapsed = elapsed >= spin_seconds
