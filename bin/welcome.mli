(** The welcome page (registered as ["welcome"]): the title screen and
    main menu. Glue only, like [Play] and [Collect_scene]:

    {v
    input ─Title.update─► state + outcome ─► Continue / Goto scene / Quit
    Reset outcome ─► delete data/progress.csv ─► Title.after_reset
    state ─Title_view.draw─► screen
    v}

    Menu: Collect the constellations (goes to ["collect"]), Free draw
    (goes to ["play"]), How to play, Reset progress, Quit. Arrow keys or
    W/S and Enter/Space, or the mouse; Escape quits from the main menu.
    For a minimal example of a screen, see [docs/SCENES.md]. *)

include Scene.S
