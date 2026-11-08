(**
   File: collect_scene.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Collect_scene module: the collect-mode screen glue -
                Controls -> Collect -> Collect_view, saving progress after each
                verdict.
   Usage: Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(** The collect mode as a screen (registered as ["collect"]).

    Design notes: [docs/COLLECT_PLAN.md].

    Glue only, like [Play]:
    {v
    input ─Controls.read─► commands ─Collect.apply / Collect.tick─► state
    state ─Collect_view.draw─► screen
    Collect.take_save_request ─► Collection.save   (progress.csv)
    Collect.wants_quit        ─► Scene.Quit        (Enter on the final diss)
    Collect.wants_cases       ─► Scene.Goto "cases" (Enter on the win screen)
    Open_menu                 ─► Scene.Goto "welcome"
    v} *)

include Scene.S
