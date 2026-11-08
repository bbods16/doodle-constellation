(**
   File: doodle_core.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 1 interface (core maths): lists the layer's modules (Geom,
                Skyvec), their roles and the layer's dependency rules.
   Usage: Import: add hack.core to (libraries ...) and (:standard -open Doodle_core)
          to (flags ...) in a dune file.
          Build: dune build
*)

(** {1 Layer 1 — Core maths}

    Plain 2-D and sky geometry. Everything else is built on this.

    {b May use:} the standard library only.
    {b Used by:} every other layer.

    {2 Modules}
    {ul
    {- {!Geom}   — points, similarity transforms, Procrustes fitting,
                   tangent-plane projection, angle helpers.}
    {- {!Skyvec} — unit vectors on the celestial sphere: fast separation
                   tests and the centre of a group of stars.}}

    {2 Key types}
    {ul
    {- [Geom.pt]  — a point on screen (pixels) or a projection plane (radians).}
    {- [Geom.sim] — a similarity: scale, rotation, shift.}}

    Proofs of this layer's maths: [proofs/Proofs/Similarity.lean],
    [Procrustes.lean], [Angles.lean]; explained in [docs/PROOFS.md]. *)

module Geom = Geom
module Skyvec = Skyvec
