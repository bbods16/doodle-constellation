(** The collect mode as a screen (registered as ["collect"]).

    Design notes: [docs/COLLECT_PLAN.md].

    Glue only, like [Play]:
    {v
    input ─Controls.read─► commands ─Collect.apply / Collect.tick─► state
    state ─Collect_view.draw─► screen
    Collect.take_save_request ─► Collection.save   (progress.csv)
    Collect.wants_quit        ─► Scene.Quit        (after the final diss)
    Open_menu                 ─► Scene.Goto "welcome"
    v} *)

include Scene.S
