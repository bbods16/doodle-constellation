(**
   File: play.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Play module: the free-draw screen glue - Controls ->
                Game -> Play_view.
   Usage: Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(** The drawing game as a scene (registered as ["play"]).

    Drag with the left mouse button to draw. On release the stroke is
    simplified, matched against the star index, and morphed onto the
    stars, while the recognition engine names the figure it sees.
    Keys: [C] clears, [S] saves a share card, [N] asks for an invented
    story, [M] goes back to the ["welcome"] scene. *)

include Scene.S
