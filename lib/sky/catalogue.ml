(**
   File: catalogue.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Catalogue module: the star catalogue - loads
                data/stars.csv into star records (angles in radians) and labels them.
   Usage: The contract is in catalogue.mli.
          Import: add hack.sky to (libraries ...) in a dune file, then use
          Doodle_sky.Catalogue (or Catalogue with -open Doodle_sky).
          Build: dune build    Test: dune test
*)

(* Star catalogue store. See catalogue.mli for the public contract. *)

type star = {
  id : int;
  name : string;
  ra : float;
  dec : float;
  mag : float;
  con : string;
}

let default_max_mag = 4.5

(**
   [parse_line line] parses one CSV row.
   Requires: nothing
   Returns: [Some star] or [None] for header/blank/malformed rows
   Raises: nothing
   Example: parse_line "2061,Betelgeuse,88.793,7.407,0.50,Ori" = Some {...}
   Complexity: O(L) time and space
   Pseudocode:
     line <- trim line
     fields <- split line on ',' then trim each
     match fields with
       | [id; name; ra; dec; mag; con] ->
           parse id as int, ra/dec/mag as floats ; any failure -> None
           return Some { id; name; ra = rad ra; dec = rad dec; mag; con }
       | _ -> None
*)
let parse_line line =
  match List.map String.trim (String.split_on_char ',' (String.trim line)) with
  | [ id; name; ra; dec; mag; con ] -> (
      match
        ( int_of_string_opt id,
          float_of_string_opt ra,
          float_of_string_opt dec,
          float_of_string_opt mag )
      with
      | Some id, Some ra, Some dec, Some mag ->
          Some { id; name; ra = Geom.rad ra; dec = Geom.rad dec; mag; con }
      | _ -> None)
  | _ -> None

(**
   [load ?max_mag path] reads and filters the catalogue.
   Requires: readable file
   Returns: kept stars in file order
   Raises: [Sys_error] if the file is missing
   Example: load "data/stars.csv" = [| ... |]
   Complexity: O(F) time and space
   Pseudocode:
     text <- read whole file
     for each line: parse_line ; keep Some s when s.mag <= max_mag
     return kept stars as an array, file order
*)
let load ?(max_mag = default_max_mag) path =
  let text = In_channel.with_open_text path In_channel.input_all in
  String.split_on_char '\n' text
  |> List.filter_map (fun l ->
         match parse_line l with
         | Some s when s.mag <= max_mag -> Some s
         | _ -> None)
  |> Array.of_list

(**
   [position s] is the star's sky position.
   Requires: nothing
   Returns: [(s.ra, s.dec)]
   Raises: nothing
   Example: position { s with ra = 1.; dec = 0.5 } = (1., 0.5)
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return (s.ra, s.dec)
*)
let position s = (s.ra, s.dec)

(**
   [label s] is the display label.
   Requires: nothing
   Returns: name, or "HR <id>" when unnamed
   Raises: nothing
   Example: label { s with id = 264; name = "" } = "HR 264"
   Complexity: O(1) time, O(1) space
   Pseudocode:
     if s.name = "" then return "HR " ^ id else return s.name
*)
let label s = if s.name = "" then "HR " ^ string_of_int s.id else s.name
