(**
   File: doodle_recognition.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 3b interface (recognition): lists the Engine module and the
                layer's dependency rules.
   Usage: Import: add hack.recognition to (libraries ...) and
          (:standard -open Doodle_recognition) to (flags ...) in a dune file.
          Build: dune build
*)

(* Layer 3b interface. See doodle_recognition.mli. *)

module Engine = Engine
