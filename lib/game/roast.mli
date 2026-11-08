(** Roast: insults for drawings under 50%, and the final diss that ends
    the game.

    PLANNED (collect mode) — interface only; the implementation is a stub.
    See [docs/COLLECT_PLAN.md].

    Every finished drawing that scores below {!Accuracy.pass_mark} is a
    strike and earns an insult. On strike {!max_strikes} the player gets
    a final diss and the game closes. Strikes count over the whole
    session: 5 misses in total ends the game, and a good drawing never
    clears a strike (decided; see the plan doc).

    The lines are playful trash talk aimed at the drawing, never at who
    the player is: no slurs, nothing about identity, appearance or
    real-life ability. Each line may contain [{score}] and [{target}],
    filled in by {!insult}. Choosing a line is deterministic for a given
    seed, so tests can check exact output. *)

type t
(** Strike count and the line picker's state. Abstract, immutable. *)

type verdict =
  | Insult of string      (** a strike, with the line to show; the game goes on *)
  | Final_diss of string  (** the last strike; show this, then close the game *)
(** What happens after a drawing under the pass mark. *)

val max_strikes : int
(** Strikes allowed before the game closes. [5]. *)

val insults : string list
(** The pool of insult lines (with [{score}] / [{target}] placeholders),
    e.g. ["{score}? Even the Big Bang was more organised."]. *)

val final_disses : string list
(** The pool of closing lines shown on the last strike, e.g.
    ["Five strikes. The stars have filed a restraining order. Goodbye."]. *)

val create : ?seed:int -> unit -> t
(**
   [create ?seed ()] starts a session with no strikes.
   Requires: nothing
   Returns: a fresh roaster; [seed] (default 0) fixes the order of lines
   Raises: nothing
   Example: strikes (create ()) = 0
   Complexity: O(1)
*)

val strikes : t -> int
(**
   [strikes r] is how many strikes the player has.
   Requires: nothing
   Returns: between 0 and {!max_strikes}
   Raises: nothing
   Example: strikes (create ()) = 0
   Complexity: O(1)
*)

val strikes_left : t -> int
(**
   [strikes_left r] is how many more misses the player can afford.
   Requires: nothing
   Returns: [max_strikes - strikes r]
   Raises: nothing
   Example: strikes_left (create ()) = 5
   Complexity: O(1)
*)

val miss : t -> score:float -> target:string -> t * verdict
(**
   [miss r ~score ~target] records a strike for a drawing of [target] that
   scored [score], and picks what to say.
   Requires: [score < Accuracy.pass_mark]; fewer than {!max_strikes} strikes
   Returns: the updated roaster and [Insult line] for strikes 1 to 4, or
            [Final_diss line] for strike {!max_strikes}
   Raises: [Invalid_argument] if the strikes are already used up
   Example: snd (miss (create ()) ~score:31.4 ~target:"Orion") = Insult "31.4%? ..."
   Complexity: O(L), L = length of the chosen line
*)

val insult : string -> score:float -> target:string -> string
(**
   [insult line ~score ~target] fills a line's placeholders: [{score}]
   becomes {!Accuracy.format} [score], [{target}] the figure's name.
   Requires: nothing
   Returns: the finished line
   Raises: nothing
   Example: insult "{score} on {target}? Bold." ~score:12.04 ~target:"Leo" = "12.0% on Leo? Bold."
   Complexity: O(L)
*)
