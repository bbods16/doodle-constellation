(**
   File: case.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Case module: rolling a case (rarity, then a pack) and
                the CS2-style reel animation.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Case (or Case with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Case: rolling a case and the CS2-style reel animation, as pure
    functions of a random state and the time.

    Opening a case picks a rarity by {!Rarity.of_roll}, then a pack of
    that rarity, preferring one the player doesn't own yet (so duplicates
    only appear once a whole tier is collected). The reel is a long strip
    of random packs with the winner placed near the end; it scrolls fast
    and eases to a stop with the winner under the centre marker. *)

type spin = {
  reel : Insult_pack.t array;  (** the strip of items shown scrolling past *)
  winner_index : int;          (** where the winner sits in [reel] *)
  won : Insult_pack.t;         (** the pack this case gives *)
  duplicate : bool;            (** [true] if the player already owned it *)
}
(** One opened case. *)

val reel_length : int
(** Items on the reel. [56]. *)

val winner_slot : int
(** Index of the winner on the reel. [48]. *)

val spin_seconds : float
(** How long the reel takes to stop. [6.0]. *)

val roll : Random.State.t -> owned:(string -> bool) -> Insult_pack.t * bool
(**
   [roll rng ~owned] picks the pack a case gives.
   Requires: nothing
   Returns: [(pack, duplicate)]: the rarity follows {!Rarity.odds}; within
            it, an unowned pack is chosen if any remain, otherwise a random
            pack of that rarity with [duplicate = true]
   Raises: nothing
   Example: roll rng ~owned:(fun _ -> false) gives a pack with duplicate = false
   Complexity: O(n)
*)

val open_case : Random.State.t -> owned:(string -> bool) -> spin
(**
   [open_case rng ~owned] rolls the winner with {!roll} and builds the reel
   around it: {!reel_length} items, each drawn by rarity odds, with the
   winner at {!winner_slot}.
   Requires: nothing
   Returns: the spin
   Raises: nothing
   Example: let s = open_case rng ~owned in s.reel.(s.winner_index) == s.won
   Complexity: O(reel_length * n)
*)

val position : float -> float
(**
   [position elapsed] is how far the reel has scrolled, in items, after
   [elapsed] seconds: an ease-out curve from 0 to {!winner_slot}, so it
   starts fast and settles with the winner centred.
   Requires: nothing
   Returns: a value in [0, winner_slot]; [winner_slot] from
            {!spin_seconds} on
   Raises: nothing
   Example: position 0. = 0.    position spin_seconds = 48.
   Complexity: O(1)
*)

val finished : float -> bool
(**
   [finished elapsed] tells whether the reel has stopped.
   Requires: nothing
   Returns: [elapsed >= spin_seconds]
   Raises: nothing
   Example: finished 6.0 = true
   Complexity: O(1)
*)
