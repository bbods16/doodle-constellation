(* PLANNED (collect mode): stub implementation. The interface in
   roast.mli is the contract; replace each [todo] with the real code.
   See docs/COLLECT_PLAN.md. *)

type t = { strikes : int; seed : int }
type verdict = Insult of string | Final_diss of string

let max_strikes = 5

let insults =
  [ "{score}? Even the Big Bang was more organised.";
    "That's not {target}. That's what the cat dragged across the sky.";
    "{score}. Astronomers will name a new black hole after this: it absorbs all talent.";
    "I've seen better constellations in a bowl of alphabet soup.";
    "{target} called. It wants a restraining order.";
    "{score}? Did you draw that during an earthquake?";
    "Galileo went blind looking at stars. Lucky him, he never saw this.";
    "Somewhere a telescope just closed its lens in shame.";
    "That drawing has the structure of a meteor shower. Random and on fire.";
    "{score}. The Hubble telescope is asking for a refund." ]

let final_disses =
  [ "Five strikes. The stars have filed a restraining order. Goodbye.";
    "That's five. Even Pluto got more respect than these drawings. Game over.";
    "Five misses. The universe is expanding just to get away from you. Bye.";
    "Strike five. Go draw on a fogged-up window, the sky is closed to you." ]

let todo what = failwith ("Roast." ^ what ^ ": not implemented yet (see roast.mli)")

(**
   [create ?seed ()] starts with no strikes.
   Requires: nothing
   Returns: fresh roaster
   Raises: nothing
   Example: strikes (create ()) = 0
   Complexity: O(1)
   Pseudocode:
     return { strikes = 0; seed }
*)
let create ?(seed = 0) () = { strikes = 0; seed }

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
let insult (_ : string) ~score:(_ : float) ~target:(_ : string) : string = todo "insult"

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
     pick <- (seed + n) mod (length of the pool) (deterministic order)
     if n = max_strikes then Final_diss (insult final_disses.(pick) ...)
     else Insult (insult insults.(pick) ...)
     return ({ r with strikes = n }, verdict)
*)
let miss (_ : t) ~score:(_ : float) ~target:(_ : string) : t * verdict = todo "miss"
