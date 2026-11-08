(**
   File: asterism.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Asterism module: the collectible constellation
                figures from data/asterisms.csv, each with its stars in drawing order
                and its ideal outline.
   Usage: The contract is in asterism.mli.
          Import: add hack.sky to (libraries ...) in a dune file, then use
          Doodle_sky.Asterism (or Asterism with -open Doodle_sky).
          Build: dune build    Test: dune test
*)

(* The collectible constellation figures. See asterism.mli for the contract. *)

type t = {
  name : string;
  con : string;
  stars : int array;       (* catalogue indices, drawing order *)
  shape : Geom.pt array;   (* gnomonic outline, same order *)
}

(**
   [parse_row by_id line] reads one ["name,con,ids"] row.
   Requires: [by_id] maps HR ids to catalogue indices
   Returns: [Some (name, con, indices)], or [None] for the header and blank lines
   Raises: [Failure] naming the figure and id when an id is unknown or not a number
   Example: parse_row by_id "Leo,Leo,3982 4057" = Some ("Leo", "Leo", [|i; j|])
   Complexity: O(L)
   Pseudocode:
     match split line on ',' (trimmed) with
       | [name; con; ids] when name <> "name" ->
           indices <- map (lookup by_id, else fail) (non-empty tokens of ids)
           Some (name, con, indices)
       | _ -> None
*)
let parse_row by_id line =
  match List.map String.trim (String.split_on_char ',' (String.trim line)) with
  | [ name; con; ids ] when name <> "name" && name <> "" ->
      let index tok =
        match Option.bind (int_of_string_opt tok) (Hashtbl.find_opt by_id) with
        | Some i -> i
        | None -> failwith (Printf.sprintf "Asterism.load: %s uses unknown star id %s" name tok)
      in
      let toks = List.filter (( <> ) "") (String.split_on_char ' ' ids) in
      Some (name, con, Array.of_list (List.map index toks))
  | _ -> None

(**
   [outline stars idx] projects the figure's stars around their centre.
   Requires: [idx] non-empty and within 90 degrees of their centre
   Returns: one plane point per index, screen orientation
   Raises: [Failure] if a star cannot be projected
   Example: Array.length (outline stars [|a; b|]) = 2
   Complexity: O(k)
   Pseudocode:
     centre <- Skyvec.centre of the positions
     return map (Geom.gnomonic ~centre) positions (fail on None)
*)
let outline (stars : Catalogue.star array) idx =
  let pos = Array.map (fun i -> Catalogue.position stars.(i)) idx in
  let centre = Skyvec.centre (Array.to_list pos) in
  Array.map
    (fun p ->
      match Geom.gnomonic ~centre p with
      | Some q -> q
      | None -> failwith "Asterism.load: figure spans more than 90 degrees")
    pos

(**
   [load stars path] reads and resolves the figure file.
   Requires: see asterism.mli
   Returns: figures in file order
   Raises: Sys_error, Failure
   Example: Array.length (load stars "data/asterisms.csv") = 7
   Complexity: O(F + N)
   Pseudocode:
     by_id <- table from HR id to catalogue index
     for each data line "name,con,ids":
       idx <- map (lookup by_id) (split ids)   (fail on unknown id)
       shape <- outline stars idx
       emit { name; con; stars = idx; shape }
*)
let load (stars : Catalogue.star array) path =
  let by_id = Hashtbl.create (Array.length stars) in
  Array.iteri (fun i (s : Catalogue.star) -> Hashtbl.replace by_id s.id i) stars;
  In_channel.with_open_text path In_channel.input_all
  |> String.split_on_char '\n'
  |> List.filter_map (parse_row by_id)
  |> List.filter_map (fun (name, con, idx) ->
         if Array.length idx < 2 then None
         else Some { name; con; stars = idx; shape = outline stars idx })
  |> Array.of_list

(**
   [name f] is the display name.
   Requires: nothing
   Returns: [f.name]
   Raises: nothing
   Example: name big_dipper = "Big Dipper"
   Complexity: O(1)
   Pseudocode:
     return f.name
*)
let name f = f.name

(**
   [constellation f] is the constellation abbreviation.
   Requires: nothing
   Returns: [f.con]
   Raises: nothing
   Example: constellation big_dipper = "UMa"
   Complexity: O(1)
   Pseudocode:
     return f.con
*)
let constellation f = f.con

(**
   [star_indices f] is the stars in drawing order.
   Requires: nothing
   Returns: a copy of [f.stars]
   Raises: nothing
   Example: Array.length (star_indices big_dipper) = 8
   Complexity: O(k)
   Pseudocode:
     return copy f.stars
*)
let star_indices f = Array.copy f.stars

(**
   [shape f] is the ideal outline.
   Requires: nothing
   Returns: a copy of [f.shape]
   Raises: nothing
   Example: Array.length (shape orion) = 7
   Complexity: O(k)
   Pseudocode:
     return copy f.shape
*)
let shape f = Array.copy f.shape

(**
   [is_closed f] tells whether the figure is a loop.
   Requires: nothing
   Returns: first star index = last star index
   Raises: nothing
   Example: is_closed cassiopeia = false
   Complexity: O(1)
   Pseudocode:
     return k >= 2 and stars.(0) = stars.(k-1)
*)
let is_closed f =
  let k = Array.length f.stars in
  k >= 2 && f.stars.(0) = f.stars.(k - 1)
