(** The collect mode as a screen (to be registered as ["collect"]).

    PLANNED (collect mode) — interface only; the implementation is a stub
    and the screen is not registered in [main.ml] yet.
    See [docs/COLLECT_PLAN.md].

    Glue only, like [Play]:
    {v
    input ─Controls.read─► commands ─Collect.apply / Collect.tick─► state
    state ─Collect_view.draw─► screen
    Collect.take_save_request ─► Collection.save   (progress.csv)
    Collect.wants_quit        ─► Scene.Quit        (after the final diss)
    Open_menu                 ─► Scene.Goto "welcome"
    v} *)

include Scene.S
