(**
   File: catalogue.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Catalogue module: the star catalogue - loads
                data/stars.csv into star records (angles in radians) and labels them.
   Usage: Import: add hack.sky to (libraries ...) in a dune file, then use
          Doodle_sky.Catalogue (or Catalogue with -open Doodle_sky).
          Build: dune build    Test: dune test
*)

(** Star catalogue store: the bright stars the matcher may use.

    Loaded once at startup from a CSV file with the header
    [id,name,ra_deg,dec_deg,mag,con]. No GIMP counterpart. *)

type star = {
  id : int;
  name : string;  (** proper name, or [""] when the star has none *)
  ra : float;     (** right ascension, radians *)
  dec : float;    (** declination, radians *)
  mag : float;    (** apparent magnitude; smaller is brighter *)
  con : string;   (** three-letter constellation abbreviation, e.g. ["Ori"] *)
}

val default_max_mag : float
(** Brightness cut: [4.5]. Fainter stars are hard to find from a city. *)

val parse_line : string -> star option
(**
   [parse_line line] parses one CSV row (degrees in the file, radians in
   the record). Surrounding whitespace and a trailing ['\r'] are ignored.
   Requires: nothing
   Returns: [Some star], or [None] for the header, blank lines and
            malformed rows (wrong field count, non-numeric values)
   Raises: nothing
   Example: parse_line "2061,Betelgeuse,88.793,7.407,0.50,Ori"
            = Some { id = 2061; name = "Betelgeuse"; ra = 1.5497...;
                     dec = 0.1293...; mag = 0.5; con = "Ori" }
   Complexity: O(L) time and space, L = line length
*)

val load : ?max_mag:float -> string -> star array
(**
   [load ?max_mag path] reads the file with [In_channel], keeps stars
   with [mag <= max_mag] (default {!default_max_mag}), and returns them
   in file order. Array indices are the star indices used everywhere
   else.
   Requires: [path] names a readable CSV in the format above
   Returns: the kept stars in file order
   Raises: [Sys_error] if the file is missing
   Example: load "data/stars.csv" = [| { id = 21; name = "Caph"; ... }; ... |]
   Complexity: O(F) time and space, F = file size
*)

val position : star -> float * float
(**
   [position s] is [(s.ra, s.dec)].
   Requires: nothing
   Returns: the sky position in radians
   Raises: nothing
   Example: position { s with ra = 1.; dec = 0.5 } = (1., 0.5)
   Complexity: O(1) time, O(1) space
*)

val label : star -> string
(**
   [label s] is the name if there is one, otherwise ["HR " ^ string_of_int id].
   Requires: nothing
   Returns: a display label
   Raises: nothing
   Example: label { s with id = 264; name = "" } = "HR 264"
   Complexity: O(1) time, O(1) space (plus the label string)
*)
