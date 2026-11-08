(** The game loop: opens the window, samples input, runs the current
    {!Scene} and applies the effects it asks for.

    This is the only place that knows the frame cycle. Every frame it:
    + samples raylib's mouse and keyboard into a {!Scene.input};
    + calls {!Scene.step}, which updates the current scene and follows
      any [Goto]/[Quit];
    + clears the screen and calls the scene's [draw];
    + applies the scene's effects (e.g. screenshots) after [end_drawing].

    Screens themselves live in separate modules ([welcome.ml],
    [play.ml], ...) registered in [main.ml]. *)

type config = {
  title : string;             (** window title *)
  width : int;                (** window width in pixels *)
  height : int;               (** window height in pixels *)
  fps : int;                  (** target frames per second *)
  background : Raylib.Color.t;  (** clear colour for every frame *)
}

val default_config : config
(** ["Doodle Constellation"], 1280 x 800, 60 fps, deep navy background. *)

val read_input : time:float -> unit -> Scene.input
(**
   [read_input ~time ()] samples this frame's mouse, keys and timing.
   Requires: an open raylib window
   Returns: the input record, with [time] as given
   Raises: nothing
   Example: (read_input ~time:0. ()).width = get_screen_width ()
   Complexity: O(K) time and space, K = number of mapped keys (about 50)
*)

val run : config -> Scene.ctx -> Scene.registry -> first:string -> unit
(**
   [run cfg ctx reg ~first] opens the window and runs the loop, starting
   on the scene named [first], until a scene returns [Quit] or the window
   is closed (close button or Escape, raylib's default exit key).
   Requires: a display; [first] is registered in [reg]
   Returns: unit after closing the window
   Raises: [Invalid_argument] if [first] (or a later [Goto]) names an
           unregistered scene
   Example: run default_config ctx reg ~first:"welcome"
   Complexity: per frame, the current scene's [update] and [draw]
*)
