(**
   File: doodle_sky.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 2 interface (sky data): lists the layer's modules (Catalogue,
                Visibility, Data_dir, Asterism) and its dependency rules.
   Usage: Import: add hack.sky to (libraries ...) and (:standard -open Doodle_sky) to
          (flags ...) in a dune file.
          Build: dune build
*)

(* Layer 2 interface. See doodle_sky.mli. *)

module Catalogue = Catalogue
module Visibility = Visibility
module Data_dir = Data_dir
module Asterism = Asterism
