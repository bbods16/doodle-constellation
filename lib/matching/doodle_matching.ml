(**
   File: doodle_matching.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 3 interface (matching): lists the stroke-to-stars pipeline
                modules and the layer's dependency rules.
   Usage: Import: add hack.matching to (libraries ...) and
          (:standard -open Doodle_matching) to (flags ...) in a dune file.
          Build: dune build
*)

(* Layer 3 interface. See doodle_matching.mli. *)

module Capture = Capture
module Simplify = Simplify
module Index = Index
module Candidates = Candidates
module Fitter = Fitter
