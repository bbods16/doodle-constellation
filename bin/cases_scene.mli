(**
   File: cases_scene.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Cases_scene module: the case screen glue - Controls
                -> Case_opening -> Cases_view, saving the inventory after each case.
   Usage: Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(** The case screen (registered as ["cases"]): open cases earned in
    collect mode to unlock insult packs. Glue only, like the other screens:

    {v
    input ─Controls.read─► commands ─Case_opening.apply / tick─► state
    state ─Cases_view.draw─► screen
    Case_opening.take_save_request ─► Inventory.save   (data/unlocks.csv)
    Open_menu (M / Escape)         ─► Scene.Goto "welcome"
    v}

    Design notes: [docs/CASES.md]. *)

include Scene.S
