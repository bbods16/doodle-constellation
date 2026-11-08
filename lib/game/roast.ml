(**
   File: roast.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Roast module: the strike counter, insults for
                drawings under 50%, and the final diss on the 5th strike.
   Usage: The contract is in roast.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Roast (or Roast with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Insults, strikes and the final diss. See roast.mli for the contract. *)

type t = {
  strikes : int;
  seed : int;
  extra_insults : string list; (* from unlocked insult packs *)
  extra_disses : string list;
}

type verdict = Insult of string | Final_diss of string

let max_strikes = 5

let insults =
  [ "{score}? What the fuck was that? The Big Bang was more organised.";
    "That's not {target}. That's what the cat shat across the sky.";
    "{score}. Astronomers will name a black hole after this, because it sucks that hard.";
    "I've seen better constellations floating in a gas station toilet.";
    "{target} called. It says go fuck yourself and leave it out of this.";
    "{score}? Did you draw that with your ass during an earthquake?";
    "Galileo went blind looking at stars. Lucky bastard never saw this shit.";
    "Somewhere a telescope just threw up inside its own lens.";
    "That drawing is a flaming pile of space shit. Random and on fire.";
    "{score}. The Hubble wants a refund, you useless sack of stardust." ]

let final_disses =
  [ "Five strikes. The stars have filed a restraining order. Now fuck off.";
    "That's five. Even Pluto got more respect than this garbage. Game over, dipshit.";
    "Five misses. The universe is expanding just to get the hell away from you. Piss off.";
    "Strike five. Go draw on a fogged-up window, the sky is closed to your dumb ass." ]

(**
   [create ?seed ?extra_insults ?extra_disses ()] starts with no strikes.
   Requires: nothing
   Returns: fresh roaster whose pools are the base lines plus the extras
   Raises: nothing
   Example: strikes (create ()) = 0
   Complexity: O(1)
   Pseudocode:
     return { strikes = 0; seed; extra_insults; extra_disses }   (extras default [])
*)
let create ?(seed = 0) ?(extra_insults = []) ?(extra_disses = []) () =
  { strikes = 0; seed = abs seed; extra_insults; extra_disses }

(**
   [strikes r] is the strike count.
   Requires: nothing
   Returns: r.strikes
   Raises: nothing
   Example: strikes (create ()) = 0
   Complexity: O(1)
   Pseudocode:
     return r.strikes
*)
let strikes r = r.strikes

(**
   [strikes_left r] is the misses left.
   Requires: nothing
   Returns: max_strikes - strikes
   Raises: nothing
   Example: strikes_left (create ()) = 5
   Complexity: O(1)
   Pseudocode:
     return max_strikes - r.strikes
*)
let strikes_left r = max_strikes - r.strikes

(**
   [replace_all s ~sub ~by] replaces every occurrence of [sub] in [s].
   Requires: [sub] non-empty
   Returns: the new string
   Raises: nothing
   Example: replace_all "a{x}b{x}" ~sub:"{x}" ~by:"1" = "a1b1"
   Complexity: O(|s| * |sub|)
   Pseudocode:
     scan left to right; at each match emit [by] and skip [sub], else copy one char
*)
let replace_all s ~sub ~by =
  let n = String.length s and m = String.length sub in
  let b = Buffer.create n in
  let i = ref 0 in
  while !i < n do
    if !i + m <= n && String.sub s !i m = sub then begin
      Buffer.add_string b by;
      i := !i + m
    end
    else begin
      Buffer.add_char b s.[!i];
      incr i
    end
  done;
  Buffer.contents b

(**
   [insult line ~score ~target] fills placeholders.
   Requires: nothing
   Returns: the finished line
   Raises: nothing
   Example: insult "{score} on {target}? Bold." ~score:12.04 ~target:"Leo" = "12.0% on Leo? Bold."
   Complexity: O(L)
   Pseudocode:
     replace every "{score}" with Accuracy.format score
     replace every "{target}" with target
*)
let insult line ~score ~target =
  replace_all
    (replace_all line ~sub:"{score}" ~by:(Accuracy.format score))
    ~sub:"{target}" ~by:target

(**
   [miss r ~score ~target] records a strike and picks a line.
   Requires: strikes left
   Returns: updated roaster and verdict
   Raises: Invalid_argument when strikes are used up
   Example: snd (miss (create ()) ~score:31.4 ~target:"Orion") = Insult "31.4%? ..."
   Complexity: O(L)
   Pseudocode:
     if r.strikes >= max_strikes then fail
     n <- r.strikes + 1
     pick <- (seed + 3 n) mod (length of the pool) (deterministic, varied)
     pools are the base lists plus the unlocked packs' extra lines
     if n = max_strikes then Final_diss (filled line from final_disses @ extra_disses)
     else Insult (filled line from insults @ extra_insults)
     return ({ r with strikes = n }, verdict)
*)
let miss r ~score ~target =
  if r.strikes >= max_strikes then invalid_arg "Roast.miss: no strikes left";
  let n = r.strikes + 1 in
  let pick pool = List.nth pool ((r.seed + (3 * n)) mod List.length pool) in
  let verdict =
    if n = max_strikes then
      Final_diss (insult (pick (final_disses @ r.extra_disses)) ~score ~target)
    else Insult (insult (pick (insults @ r.extra_insults)) ~score ~target)
  in
  ({ r with strikes = n }, verdict)
