(**
   File: main.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Main module (exports nothing): the entry point: loads
                the shared resources, registers the screens and starts the game loop.
   Usage: Run: dune exec hack -- [LAT_DEG LON_DEG] [CATALOGUE.csv] (from the repo
          root).
          Build: dune build (needs raylib and ctypes from opam).
*)

(** Entry point of the app: loads the shared resources into a
    {!Scene.ctx}, lists the screens, and hands control to {!App.run}.

    It exports nothing. To add a screen, see [docs/SCENES.md]; to see
    how the layers fit together, see [ARCHITECTURE.md]. *)
