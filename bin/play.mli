(** The drawing game as a scene (registered as ["play"]).

    Drag with the left mouse button to draw. On release the stroke is
    simplified, matched against the star index, and morphed onto the
    stars, while the recognition engine names the figure it sees.
    Keys: [C] clears, [S] saves a share card, [N] asks for an invented
    story, [M] goes back to the ["welcome"] scene. *)

include Scene.S
