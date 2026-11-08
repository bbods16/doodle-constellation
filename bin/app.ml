(**
   File: app.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the App module: the game loop - opens the window,
                samples input, steps the current screen, draws it and applies its side
                effects.
   Usage: The contract is in app.mli.
          Part of the hack executable (needs raylib and ctypes from opam).
          Build: dune build    Run: dune exec hack (from the repo root)
*)

(* The game loop. See app.mli for the public contract. *)

open Raylib

type config = { title : string; width : int; height : int; fps : int; background : Color.t }

let default_config =
  { title = "Doodle Constellation"; width = 1280; height = 800; fps = 60;
    background = Color.create 8 10 24 255 }

(* raylib keys the scenes can see, and their Scene.key names. *)
let key_map : (Key.t * Scene.key) list =
  let letters =
    [ Key.A; Key.B; Key.C; Key.D; Key.E; Key.F; Key.G; Key.H; Key.I; Key.J; Key.K; Key.L; Key.M;
      Key.N; Key.O; Key.P; Key.Q; Key.R; Key.S; Key.T; Key.U; Key.V; Key.W; Key.X; Key.Y; Key.Z ]
  in
  let digits =
    [ Key.Zero; Key.One; Key.Two; Key.Three; Key.Four; Key.Five; Key.Six; Key.Seven; Key.Eight;
      Key.Nine ]
  in
  [ (Key.Enter, Scene.Enter); (Key.Kp_enter, Scene.Enter); (Key.Space, Scene.Space);
    (Key.Escape, Scene.Escape); (Key.Backspace, Scene.Backspace); (Key.Tab, Scene.Tab);
    (Key.Up, Scene.Up); (Key.Down, Scene.Down); (Key.Left, Scene.Left); (Key.Right, Scene.Right) ]
  @ List.mapi (fun i k -> (k, Scene.Letter (Char.chr (Char.code 'a' + i)))) letters
  @ List.mapi (fun i k -> (k, Scene.Digit i)) digits

(**
   [read_input ~time ()] samples one frame of input from raylib.
   Requires: an open window
   Returns: the {!Scene.input} for this frame
   Raises: nothing
   Example: (read_input ~time:0. ()).width = get_screen_width ()
   Complexity: O(K) time and space
   Pseudocode:
     m <- get_mouse_position ()
     keys <- scene keys whose raylib key was pressed this frame (no duplicates)
     return { dt = get_frame_time (); time; screen size; mouse = m;
              left button down / pressed / released; keys }
*)
let read_input ~time () =
  let m = get_mouse_position () in
  let keys =
    List.fold_left
      (fun acc (rk, sk) -> if is_key_pressed rk && not (List.mem sk acc) then sk :: acc else acc)
      [] key_map
    |> List.rev
  in
  { Scene.dt = get_frame_time (); time; width = get_screen_width (); height = get_screen_height ();
    mouse = { Geom.x = Vector2.x m; y = Vector2.y m };
    mouse_down = is_mouse_button_down MouseButton.Left;
    mouse_pressed = is_mouse_button_pressed MouseButton.Left;
    mouse_released = is_mouse_button_released MouseButton.Left; keys }

(**
   [apply_effect e] performs one effect requested by a scene.
   Requires: called after [end_drawing], so the finished frame is saved
   Returns: unit
   Raises: nothing
   Example: apply_effect (Scene.Screenshot "doodle_card.png")
   Complexity: O(W H) for a screenshot
   Pseudocode:
     match e with Screenshot path -> take_screenshot path
*)
let apply_effect = function Scene.Screenshot path -> take_screenshot path

(**
   [run cfg ctx reg ~first] is the main loop.
   Requires: a display, [first] registered
   Returns: unit when the app closes
   Raises: [Invalid_argument] for an unknown scene name
   Example: run default_config ctx reg ~first:"welcome"
   Complexity: per frame, the current scene's update and draw
   Pseudocode:
     open window (title, size) ; set target fps ; disable raylib's Escape-to-exit
     current <- Scene.launch reg ctx first ; time <- 0 ; running <- true
     while running and not window_should_close ():
       inp <- read_input ~time () ; time <- time + inp.dt
       match Scene.step reg ctx inp current with
         | Stopped -> running <- false
         | Next (scene, effects) ->
             current <- scene
             begin_drawing ; clear background ; Scene.draw ctx scene ; end_drawing
             apply each effect
     close window (also when an exception escapes)
*)
let run cfg ctx reg ~first =
  init_window cfg.width cfg.height cfg.title;
  set_target_fps cfg.fps;
  (* Escape is handled by the screens (back / quit), not by raylib. *)
  set_exit_key Key.Null;
  Fun.protect ~finally:close_window (fun () ->
      let current = ref (Scene.launch reg ctx first) in
      let time = ref 0. and running = ref true in
      while !running && not (window_should_close ()) do
        let inp = read_input ~time:!time () in
        time := !time +. inp.dt;
        match Scene.step reg ctx inp !current with
        | Scene.Stopped -> running := false
        | Scene.Next (scene, effects) ->
            current := scene;
            begin_drawing ();
            clear_background cfg.background;
            Scene.draw ctx scene;
            end_drawing ();
            List.iter apply_effect effects
      done)
