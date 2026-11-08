(** {1 Layer 3 — Matching}

    Turns a hand-drawn stroke into the star pattern it matches. A stroke
    flows through the modules in this order:

    {v
    mouse samples ─► Capture ─► Simplify ─► Candidates ─► Fitter ─► fit
                    (smooth)   (5-9 corners) (guesses via  (refine and
                                              Index)        score)
    v}

    {b May use:} core, sky.
    {b Used by:} game.

    {2 Modules}
    {ul
    {- {!Capture}    — collects mouse samples, drops jitter, smooths.}
    {- {!Simplify}   — reduces a stroke to 5–9 corners, or says why not.}
    {- {!Index}      — geometric hash of every small star triangle,
                       built once at start-up.}
    {- {!Candidates} — looks up each drawn triangle, proposes star matches.}
    {- {!Fitter}     — snaps corners to stars, least-squares refits, scores,
                       keeps the best.}}

    {2 Key types}
    {ul
    {- [Capture.t]               — a stroke in progress (abstract).}
    {- [Index.t]                 — the triangle index (abstract).}
    {- [Candidates.hypothesis]   — one guess: seed stars and a transform.}
    {- [Fitter.fit]              — the final match: stars, error, score.}}

    Proofs: [ShapeKey.lean], [Procrustes.lean], [Simplify.lean],
    [Discrete.lean]; explained in [docs/PROOFS.md]. *)

module Capture = Capture
module Simplify = Simplify
module Index = Index
module Candidates = Candidates
module Fitter = Fitter
