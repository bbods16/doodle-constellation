(** Welcome screen (registered as ["welcome"]), and the reference
    example of an outside scene module: it only knows {!Scene} and the
    renderer, and reaches the game by name with [Goto "play"].

    Click, Enter or Space starts the game; [Q] quits. *)

include Scene.S
