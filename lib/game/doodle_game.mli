(** {1 Layer 4 — Game}

    The rules of the app and the screen framework, all pure OCaml (no
    raylib), so every rule is unit-tested without a window. The raylib
    front end in [bin/] only reads input into {!Scene.input} and draws.

    {b May use:} core, sky, matching, recognition.
    {b Used by:} bin (the app).

    {2 Modules}
    {ul
    {- {!Scene}      — the screen framework: the {!Scene.S} signature every
                       screen implements, the shared context, the router.}
    {- {!Controls}   — raw input → game commands; the only place key
                       bindings live.}
    {- {!Game}       — the drawing game's rules: one function per command,
                       each delegating to a lower layer.}
    {- {!Projection} — sky → screen maths (stereographic view framing).}
    {- {!Morph}      — the animation that slides the drawing onto the stars.}
    {- {!Narrate}    — optional invented story, fetched in the background.}}

    {2 Collect mode (see docs/COLLECT_PLAN.md)}
    {ul
    {- {!Accuracy}   — drawing vs figure → "87.3%", tiers, colour, pass mark.}
    {- {!Collection} — collected figures and best score each; saved to disk.}
    {- {!Roast}      — strikes, insults under 50%, final diss on strike 5.}
    {- {!Judge}      — one score → one verdict (collected, record, insult, game over).}
    {- {!Collect}    — the mode's state machine: prompt, draw, verdict, quit.}}

    {2 Welcome page (see docs/WELCOME_PLAN.md)}
    {ul
    {- {!Menu}       — generic keyboard + mouse menu: items, selection, layout, hit-test.}
    {- {!Title}      — the welcome page's rules: main menu, how to play, confirm reset.}
    {- {!Attract}    — background animation: figures drawing themselves star by star.}}

    {2 Key types}
    {ul
    {- [Scene.ctx]        — resources shared by every screen (abstract).}
    {- [Scene.input]      — one frame of input (plain record).}
    {- [module type Scene.S] — what a screen must provide.}
    {- [Controls.command] — what the player asked for this frame.}
    {- [Game.t]           — the game state (abstract; read via accessors).}}

    Proofs: [Morph.lean], [Angles.lean]; explained in [docs/PROOFS.md]. *)

module Scene = Scene
module Controls = Controls
module Game = Game
module Projection = Projection
module Morph = Morph
module Narrate = Narrate
module Collect = Collect
module Judge = Judge
module Roast = Roast
module Collection = Collection
module Accuracy = Accuracy
module Menu = Menu
module Title = Title
module Attract = Attract
