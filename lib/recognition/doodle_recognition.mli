(**
   File: doodle_recognition.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 3b interface (recognition): lists the Engine module and the
                layer's dependency rules.
   Usage: Import: add hack.recognition to (libraries ...) and
          (:standard -open Doodle_recognition) to (flags ...) in a dune file.
          Build: dune build
*)

(** {1 Layer 3b — Recognition engine}

    A small transformer, trained from scratch by [engine/train.py], that
    names the constellation figure a stroke looks like (or ["none"]).
    Independent of the geometric matcher: the two run side by side.

    {b May use:} core.
    {b Used by:} game.

    {2 Modules}
    {ul
    {- {!Engine} — loads [data/engine_weights.txt]; preprocesses a stroke
                   and runs the forward pass in pure OCaml.}}

    {2 Key types}
    {ul
    {- [Engine.t] — a loaded model (abstract).}}

    Proofs: [Normalise.lean], [Engine.lean]; explained in
    [docs/PROOFS.md]. Retraining: see the README. *)

module Engine = Engine
