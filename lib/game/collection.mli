(** Collection: which constellation figures the player has collected, and
    their best score for each.

    Design notes: [docs/COLLECT_PLAN.md].

    A figure is collected the first time it scores at least
    {!Accuracy.pass_mark}. Best scores keep improving after that (the
    site's per-shape "Best" and "NEW RECORD!"). Progress is saved to a
    small text file so it survives restarts, like the site's local
    records. Immutable: every change returns a new value. *)

type t
(** The figures in play, which are collected, and each one's best score.
    Abstract. *)

type record_result = {
  collected_now : bool;  (** this score collected the figure for the first time *)
  new_best : bool;       (** this score beat the previous best ("NEW RECORD!") *)
  best : float;          (** the figure's best score after this attempt *)
}
(** What one scored attempt changed. *)

val create : Asterism.t array -> t
(**
   [create figures] is a fresh collection: nothing collected, no scores.
   Requires: figure names are distinct
   Returns: the collection, figures in the given order
   Raises: [Invalid_argument] on a duplicate figure name
   Example: collected_count (create figures) = 0
   Complexity: O(n^2) in the (small) number of figures
*)

val next_target : t -> Asterism.t option
(**
   [next_target c] is the figure to ask for next: the first uncollected
   figure in order.
   Requires: nothing
   Returns: [Some figure], or [None] once everything is collected
   Raises: nothing
   Example: Option.map Asterism.name (next_target (create figures)) = Some "Big Dipper"
   Complexity: O(n)
*)

val record : t -> name:string -> score:float -> t * record_result
(**
   [record c ~name ~score] notes one attempt at a figure.
   Requires: [name] is a figure in [c]
   Returns: the updated collection and what changed
   Raises: [Invalid_argument] for an unknown figure name
   Example: snd (record (create figures) ~name:"Orion" ~score:63.)
            = { collected_now = true; new_best = true; best = 63. }
   Complexity: O(n)
*)

val best : t -> string -> float option
(**
   [best c name] is the figure's best score so far.
   Requires: nothing
   Returns: [Some p], or [None] if never attempted (or unknown)
   Raises: nothing
   Example: best (create figures) "Orion" = None
   Complexity: O(n)
*)

val is_collected : t -> string -> bool
(**
   [is_collected c name] tells whether the figure has been collected.
   Requires: nothing
   Returns: [true] once it has scored at least the pass mark
   Raises: nothing
   Example: is_collected (create figures) "Orion" = false
   Complexity: O(n)
*)

val figures : t -> Asterism.t array
(**
   [figures c] is every figure in play, in order (for the collection shelf).
   Requires: nothing
   Returns: a fresh array
   Raises: nothing
   Example: Array.length (figures (create f)) = Array.length f
   Complexity: O(n)
*)

val collected_count : t -> int
(**
   [collected_count c] is how many figures are collected.
   Requires: nothing
   Returns: between 0 and {!total}
   Raises: nothing
   Example: collected_count (create figures) = 0
   Complexity: O(n)
*)

val total : t -> int
(**
   [total c] is how many figures are in play.
   Requires: nothing
   Returns: the number of figures
   Raises: nothing
   Example: total (create figures) = 7
   Complexity: O(1)
*)

val is_complete : t -> bool
(**
   [is_complete c] tells whether every figure is collected (the game is won).
   Requires: nothing
   Returns: [collected_count c = total c]
   Raises: nothing
   Example: is_complete (create figures) = false
   Complexity: O(n)
*)

val progress_label : t -> string
(**
   [progress_label c] is the on-screen counter.
   Requires: nothing
   Returns: e.g. ["3 / 7 collected"]
   Raises: nothing
   Example: progress_label (create figures) = "0 / 7 collected"
   Complexity: O(n)
*)

val save : string -> t -> unit
(**
   [save path c] writes progress (one [name,collected,best] line per
   figure) so it survives restarts.
   Requires: the folder of [path] exists and is writable
   Returns: unit
   Raises: [Sys_error] if the file cannot be written
   Example: save "data/progress.csv" c
   Complexity: O(n)
*)

val load : Asterism.t array -> string -> t
(**
   [load figures path] restores saved progress onto the current figures.
   Lines for figures no longer present are ignored; new figures start
   uncollected.
   Requires: nothing
   Returns: the restored collection, or [create figures] if the file is
            missing or unreadable
   Raises: nothing
   Example: collected_count (load figures "missing.csv") = 0
   Complexity: O(n + F), F = file size
*)
