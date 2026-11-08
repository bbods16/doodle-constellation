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
