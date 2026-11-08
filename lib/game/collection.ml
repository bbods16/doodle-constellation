(**
   File: collection.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Collection module: collect-mode progress - which
                figures are collected and each one's best score, saved to
                data/progress.csv.
   Usage: The contract is in collection.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Collection (or Collection with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Collected figures and best scores. See collection.mli for the contract. *)

type entry = { figure : Asterism.t; collected : bool; best : float option }
type t = entry array
type record_result = { collected_now : bool; new_best : bool; best : float }

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
let create figures =
  let names = Array.map Asterism.name figures in
  Array.iteri
    (fun i n ->
      for j = 0 to i - 1 do
        if names.(j) = n then invalid_arg ("Collection.create: duplicate figure " ^ n)
      done)
    names;
  Array.map (fun figure -> { figure; collected = false; best = None }) figures

(**
   [find c name] is the position of the named figure.
   Requires: nothing
   Returns: Some index or None
   Raises: nothing
   Example: find (create figures) "Orion" = Some 2
   Complexity: O(n)
   Pseudocode:
     first i with name of c.(i) = name
*)
let find (c : t) name =
  let rec go i =
    if i >= Array.length c then None
    else if Asterism.name c.(i).figure = name then Some i
    else go (i + 1)
  in
  go 0

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
let next_target (c : t) =
  Array.to_list c |> List.find_opt (fun e -> not e.collected) |> Option.map (fun e -> e.figure)

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
     e' <- { e with collected = e.collected || collected_now; best = max e.best score }
     return (c with e replaced by e', { collected_now; new_best; best = e'.best })
*)
let record (c : t) ~name ~score =
  match find c name with
  | None -> invalid_arg ("Collection.record: unknown figure " ^ name)
  | Some i ->
      let e = c.(i) in
      let new_best = match e.best with None -> true | Some b -> score > b in
      let collected_now = (not e.collected) && score >= Accuracy.pass_mark in
      let best = match e.best with None -> score | Some b -> Float.max b score in
      let c' = Array.copy c in
      c'.(i) <- { e with collected = e.collected || collected_now; best = Some best };
      (c', { collected_now; new_best; best })

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
let best (c : t) name = Option.bind (find c name) (fun i -> c.(i).best)

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
let is_collected (c : t) name = match find c name with Some i -> c.(i).collected | None -> false

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
     (best printed with 17 significant digits, empty when None)
*)
let save path (c : t) =
  Out_channel.with_open_text path (fun oc ->
      output_string oc "name,collected,best\n";
      Array.iter
        (fun e ->
          Printf.fprintf oc "%s,%b,%s\n" (Asterism.name e.figure) e.collected
            (match e.best with Some b -> Printf.sprintf "%.17g" b | None -> ""))
        c)

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
let load figures path =
  let c = create figures in
  try
    let lines = In_channel.with_open_text path In_channel.input_all |> String.split_on_char '\n' in
    List.iter
      (fun line ->
        match String.split_on_char ',' (String.trim line) with
        | [ name; collected; best ] -> (
            match (find c name, bool_of_string_opt collected) with
            | Some i, Some col -> c.(i) <- { (c.(i)) with collected = col; best = float_of_string_opt best }
            | _ -> ())
        | _ -> ())
      lines;
    c
  with Sys_error _ | Failure _ -> create figures
