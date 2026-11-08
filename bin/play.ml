(* The drawing game scene: glue between Controls, Game and Play_view.
   See play.mli for the public contract.

     input ──Controls.read──► commands ──Game.apply / Game.tick──► state
     state ──Play_view.draw──► screen                                      *)

type t = Game.t

let name = "play"

(**
   [init ctx] enters the game with a blank sky.
   Requires: nothing
   Returns: [Game.init ()]
   Raises: nothing
   Example: (init ctx).stage = Game.Drawing
   Complexity: O(1)
   Pseudocode:
     return Game.init ()
*)
let init (_ : Scene.ctx) = Game.init ()

(**
   [screen_of inp] is what the game rules need to know about the window
   and the clock.
   Requires: nothing
   Returns: window size from [inp], current Unix time
   Raises: nothing
   Example: (screen_of inp).width = inp.width
   Complexity: O(1)
   Pseudocode:
     return { width = inp.width; height = inp.height; now = Unix.gettimeofday () }
*)
let screen_of (inp : Scene.input) =
  { Game.width = inp.width; height = inp.height; now = Unix.gettimeofday () }

(**
   [effects_of cmds] is the screen-level side effects the commands ask for.
   Requires: nothing
   Returns: [[Screenshot card_path]] if [Save_card] is among [cmds], else [[]]
   Raises: nothing
   Example: effects_of [Controls.Save_card] = [Scene.Screenshot "doodle_card.png"]
   Complexity: O(c), c commands
   Pseudocode:
     if Save_card in cmds then [Screenshot card_path] else []
*)
let effects_of cmds =
  if List.mem Controls.Save_card cmds then [ Scene.Screenshot Play_view.card_path ] else []

(**
   [update ctx inp g] is one frame: read commands, apply them, tick.
   Requires: nothing
   Returns: [Goto "welcome"] on [Open_menu], else [Continue] with effects
   Raises: nothing
   Example: update ctx { inp with keys = [Letter 'm'] } g = Goto "welcome"
   Complexity: that of the commands applied
   Pseudocode:
     cmds <- Controls.read inp
     if Open_menu in cmds then Goto "welcome"
     else g <- fold (Game.apply ctx (screen_of inp)) g cmds
          g <- Game.tick inp.dt g
          Continue (g, effects_of cmds)
*)
let update ctx (inp : Scene.input) g =
  let cmds = Controls.read inp in
  if List.mem Controls.Open_menu cmds then Scene.Goto "welcome"
  else
    let g = List.fold_left (Game.apply ctx (screen_of inp)) g cmds |> Game.tick inp.dt in
    Scene.Continue (g, effects_of cmds)

(**
   [draw ctx g] hands the state to the view.
   Requires: inside the loop's drawing block
   Returns: unit
   Raises: nothing
   Example: draw ctx (init ctx)
   Complexity: see Play_view.draw
   Pseudocode:
     Play_view.draw ctx g
*)
let draw = Play_view.draw
