(* PLANNED (collect mode): stub implementation. The interface in
   collection.mli is the contract; replace each [todo] with the real code.
   See docs/COLLECT_PLAN.md. *)

type entry = { figure : Asterism.t; collected : bool; best : float option }
type t = entry array
type record_result = { collected_now : bool; new_best : bool; best : float }

let todo what = failwith ("Collection." ^ what ^ ": not implemented yet (see collection.mli)")

(**
   [create figures] is a fresh collection.
   Requires: distinct names
   Returns: nothing collected
   Raises: Invalid_argument on a duplicate name
   Example: collected_count (create figures) = 0
   Complexity: O(n^2)
   Pseudocode:
     check names distinct ; map each figure to { figure; collected = false; best = None }
*)
let create (_ : Asterism.t array) : t = todo "create"

(**
   [next_target c] is the first uncollected figure.
   Requires: nothing
   Returns: Some figure or None
   Raises: nothing
   Example: Option.map Asterism.name (next_target (create figures)) = Some "Big Dipper"
   Complexity: O(n)
   Pseudocode:
     first entry with collected = false, mapped to its figure
*)
let next_target (_ : t) : Asterism.t option = todo "next_target"

(**
   [record c ~name ~score] notes one attempt.
   Requires: known name
   Returns: updated collection and changes
   Raises: Invalid_argument for an unknown name
   Example: snd (record (create figures) ~name:"Orion" ~score:63.) = { true; true; 63. }
   Complexity: O(n)
   Pseudocode:
     e <- entry named [name] (else fail)
     new_best <- e.best = None or score > e.best
     collected_now <- not e.collected and score >= Accuracy.pass_mark
     e' <- { e with collected = e.collected || collected_now;
                    best = max e.best score }
     return (c with e replaced by e', { collected_now; new_best; best = e'.best })
*)
let record (_ : t) ~name:(_ : string) ~score:(_ : float) : t * record_result = todo "record"

(**
   [best c name] is the best score.
   Requires: nothing
   Returns: Some p or None
   Raises: nothing
   Example: best (create figures) "Orion" = None
   Complexity: O(n)
   Pseudocode:
     the entry's best, or None if not found
*)
let best (_ : t) (_ : string) : float option = todo "best"

(**
   [is_collected c name] tells whether it is collected.
   Requires: nothing
   Returns: the entry's flag, false if unknown
   Raises: nothing
   Example: is_collected (create figures) "Orion" = false
   Complexity: O(n)
   Pseudocode:
     the entry's collected flag, or false
*)
let is_collected (_ : t) (_ : string) : bool = todo "is_collected"

(**
   [figures c] is every figure in order.
   Requires: nothing
   Returns: fresh array
   Raises: nothing
   Example: Array.length (figures (create f)) = Array.length f
   Complexity: O(n)
   Pseudocode:
     map (fun e -> e.figure) c
*)
let figures (c : t) = Array.map (fun e -> e.figure) c

(**
   [collected_count c] counts collected figures.
   Requires: nothing
   Returns: the count
   Raises: nothing
   Example: collected_count (create figures) = 0
   Complexity: O(n)
   Pseudocode:
     count entries with collected = true
*)
let collected_count (c : t) = Array.fold_left (fun n e -> if e.collected then n + 1 else n) 0 c

(**
   [total c] is the number of figures.
   Requires: nothing
   Returns: Array.length c
   Raises: nothing
   Example: total (create figures) = 7
   Complexity: O(1)
   Pseudocode:
     return length c
*)
let total (c : t) = Array.length c

(**
   [is_complete c] tells whether all are collected.
   Requires: nothing
   Returns: collected_count = total
   Raises: nothing
   Example: is_complete (create figures) = false
   Complexity: O(n)
   Pseudocode:
     return collected_count c = total c
*)
let is_complete c = collected_count c = total c

(**
   [progress_label c] is the counter text.
   Requires: nothing
   Returns: "k / n collected"
   Raises: nothing
   Example: progress_label (create figures) = "0 / 7 collected"
   Complexity: O(n)
   Pseudocode:
     sprintf "%d / %d collected" (collected_count c) (total c)
*)
let progress_label c = Printf.sprintf "%d / %d collected" (collected_count c) (total c)

(**
   [save path c] writes progress.
   Requires: writable folder
   Returns: unit
   Raises: Sys_error
   Example: save "data/progress.csv" c
   Complexity: O(n)
   Pseudocode:
     write "name,collected,best" then one line per entry
*)
let save (_ : string) (_ : t) : unit = todo "save"

(**
   [load figures path] restores progress.
   Requires: nothing
   Returns: restored collection, or fresh on any problem
   Raises: nothing
   Example: collected_count (load figures "missing.csv") = 0
   Complexity: O(n + F)
   Pseudocode:
     c <- create figures
     try read lines; for each "name,collected,best" whose name is in c,
       set that entry's collected and best
     with any error -> c
*)
let load (_ : Asterism.t array) (_ : string) : t = todo "load"
