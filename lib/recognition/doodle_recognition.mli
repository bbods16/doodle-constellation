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
