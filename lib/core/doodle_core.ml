(**
   File: doodle_core.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 1 interface (core maths): lists the layer's modules (Geom,
                Skyvec), their roles and the layer's dependency rules.
   Usage: Import: add hack.core to (libraries ...) and (:standard -open Doodle_core)
          to (flags ...) in a dune file.
          Build: dune build
*)

(* Layer 1 interface. See doodle_core.mli. *)

module Geom = Geom
module Skyvec = Skyvec
