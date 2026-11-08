(**
   File: scene.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Scene module: the screen framework - the Scene.S
                signature every screen implements, the per-frame input record, the
                shared context, the registry and step.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Scene (or Scene with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Scenes: the pluggable screens of the app (welcome, play, ...).

    The game loop no longer knows about any particular screen. Each
    screen is an independent module matching {!S}: it has a name, builds
    its state from the shared {!ctx}, updates that state from one frame
    of {!input}, and draws it. A {!registry} maps names to scenes, and a
    scene changes screen by returning [Goto "other-name"], so scenes never
    depend on each other's modules.

    This module is pure OCaml (no raylib): [bin/app.ml] turns raylib's
    mouse and keyboard into an {!input} record and runs {!step} every
    frame, which lets scene switching be unit-tested without a window.

    {2 Adding a screen}
    Write a module with [name], [init], [update] and [draw] (see
    [bin/welcome.ml] for a small example), then add [(module My_scene)]
    to the registry list in [bin/main.ml]. Full guide: [docs/SCENES.md]. *)

(** {1 Input} *)

type key =
  | Enter
  | Space
  | Escape
  | Backspace
  | Tab
  | Up
  | Down
  | Left
  | Right
  | Letter of char  (** lower-case ['a'] .. ['z'] *)
  | Digit of int    (** [0] .. [9] *)
(** Keys a scene can react to; [bin/app.ml] maps raylib's keys onto these. *)

type input = {
  dt : float;              (** seconds since the previous frame *)
  time : float;            (** seconds since the app started *)
  width : int;             (** window width in pixels *)
  height : int;            (** window height in pixels *)
  mouse : Geom.pt;         (** mouse position in pixels *)
  mouse_down : bool;       (** left button held this frame *)
  mouse_pressed : bool;    (** left button went down this frame *)
  mouse_released : bool;   (** left button went up this frame *)
  keys : key list;         (** keys pressed (not held) this frame *)
}
(** One frame of user input, sampled once by the loop before [update]. *)

val idle : width:int -> height:int -> input
(**
   [idle ~width ~height] is a frame with no input at all: zero time, the
   mouse at the origin, no buttons, no keys.
   Requires: nothing
   Returns: an input record; tests build on it with [{ (idle ...) with ... }]
   Raises: nothing
   Example: (idle ~width:1280 ~height:800).keys = []
   Complexity: O(1) time, O(1) space
*)

val pressed : input -> key -> bool
(**
   [pressed inp k] tells whether [k] was pressed this frame.
   Requires: nothing
   Returns: [true] when [k] is in [inp.keys]
   Raises: nothing
   Example: pressed { (idle ~width:1 ~height:1) with keys = [Enter] } Enter = true
   Complexity: O(k) time, O(1) space, k = keys pressed this frame
*)

(** {1 Shared context} *)

type ctx
(** Resources loaded once at start-up and shared by every scene:
    the star catalogue, its triangle index, the recognition engine (if
    its weights loaded) and the observer's location. Abstract: build it
    with {!make_ctx}, read it with the accessors below. *)

val make_ctx :
  stars:Catalogue.star array -> index:Index.t -> ?engine:Engine.t ->
  ?figures:Asterism.t array -> ?data_dir:string -> lat:float -> lon:float -> unit -> ctx
(**
   [make_ctx ~stars ~index ?engine ?figures ?data_dir ~lat ~lon ()]
   bundles the shared resources.
   Requires: [index] was built from [stars]; [figures] were loaded against
             [stars]; [lat], [lon] in radians (east +)
   Returns: the context; [figures] defaults to none, [data_dir] to ["data"]
   Raises: nothing
   Example: stars (make_ctx ~stars ~index ~lat ~lon ()) == stars
   Complexity: O(1) time, O(1) space
*)

val figures : ctx -> Asterism.t array
(**
   [figures ctx] is the collectible constellation figures.
   Requires: nothing
   Returns: the figures given to {!make_ctx} (empty if none)
   Raises: nothing
   Example: figures (make_ctx ~stars ~index ~lat ~lon ()) = [||]
   Complexity: O(1)
*)

val data_dir : ctx -> string
(**
   [data_dir ctx] is the folder holding the catalogue and other data
   files (where collect mode saves progress).
   Requires: nothing
   Returns: the folder given to {!make_ctx}, ["data"] by default
   Raises: nothing
   Example: data_dir (make_ctx ~stars ~index ~lat ~lon ()) = "data"
   Complexity: O(1)
*)

val stars : ctx -> Catalogue.star array
(**
   [stars ctx] is the loaded catalogue.
   Requires: nothing
   Returns: the array given to {!make_ctx}
   Raises: nothing
   Example: stars (make_ctx ~stars:s ~index ~lat ~lon ()) == s
   Complexity: O(1)
*)

val index : ctx -> Index.t
(**
   [index ctx] is the triangle index built from {!stars}.
   Requires: nothing
   Returns: the index given to {!make_ctx}
   Raises: nothing
   Example: index (make_ctx ~stars ~index:ix ~lat ~lon ()) == ix
   Complexity: O(1)
*)

val engine : ctx -> Engine.t option
(**
   [engine ctx] is the recognition engine, if one was loaded.
   Requires: nothing
   Returns: [Some m] or [None]
   Raises: nothing
   Example: engine (make_ctx ~stars ~index ~lat ~lon ()) = None
   Complexity: O(1)
*)

val location : ctx -> float * float
(**
   [location ctx] is the observer's [(lat, lon)] in radians.
   Requires: nothing
   Returns: the pair given to {!make_ctx}
   Raises: nothing
   Example: location (make_ctx ~stars ~index ~lat:0.7 ~lon:(-1.4) ()) = (0.7, -1.4)
   Complexity: O(1)
*)

(** {1 Scenes} *)

type side_effect = Screenshot of string  (** save the frame just drawn to this file *)
(** Side effects a scene asks the loop to perform after drawing. *)

type 'a outcome =
  | Continue of 'a * side_effect list  (** stay on this scene with the new state *)
  | Goto of string                (** switch to the scene with this name *)
  | Quit                          (** close the app *)
(** What a scene's [update] decides for the next frame. *)

module type S = sig
  type t
  (** The scene's private state. *)

  val name : string
  (** Unique name used by [Goto] and by the registry, e.g. ["welcome"]. *)

  val init : ctx -> t
  (** Fresh state, built each time the app switches to this scene. *)

  val update : ctx -> input -> t -> t outcome
  (** One frame of logic. Must not draw. *)

  val draw : ctx -> t -> unit
  (** Draw the current state. Called between [begin_drawing] and
      [end_drawing], after the background is cleared. *)
end
(** The interface every screen implements. *)

type running
(** A scene module paired with its current state. *)

val start : (module S) -> ctx -> running
(**
   [start (module M) ctx] enters scene [M] with [M.init ctx].
   Requires: nothing
   Returns: the running scene
   Raises: whatever [M.init] raises
   Example: current_name (start (module Welcome) ctx) = "welcome"
   Complexity: O(1) plus the cost of [M.init]
*)

val current_name : running -> string
(**
   [current_name r] is the [name] of the running scene.
   Requires: nothing
   Returns: the scene's name
   Raises: nothing
   Example: current_name (start (module Welcome) ctx) = "welcome"
   Complexity: O(1) time, O(1) space
*)

val draw : ctx -> running -> unit
(**
   [draw ctx r] draws the running scene's current state.
   Requires: called inside the loop's drawing block
   Returns: unit
   Raises: whatever the scene's [draw] raises
   Example: draw ctx r   (* calls M.draw ctx state *)
   Complexity: the cost of the scene's [draw]
*)

(** {1 Registry and stepping} *)

type registry
(** The set of scenes the app knows, by name. *)

val registry : (module S) list -> registry
(**
   [registry scenes] collects the scenes so they can be reached by name.
   Requires: distinct names
   Returns: the registry
   Raises: [Invalid_argument] if two scenes share a name or the list is empty
   Example: names (registry [(module Welcome); (module Play)]) = ["welcome"; "play"]
   Complexity: O(n^2) time in the (small) number of scenes, O(n) space
*)

val names : registry -> string list
(**
   [names reg] is the registered scene names, in registration order.
   Requires: nothing
   Returns: the names
   Raises: nothing
   Example: names (registry [(module Welcome)]) = ["welcome"]
   Complexity: O(n) time and space
*)

val launch : registry -> ctx -> string -> running
(**
   [launch reg ctx name] starts the scene registered under [name].
   Requires: [name] is registered
   Returns: the running scene with fresh state
   Raises: [Invalid_argument] naming the unknown scene and the known ones
   Example: current_name (launch reg ctx "play") = "play"
   Complexity: O(n) lookup plus the scene's [init]
*)

type step_result =
  | Next of running * side_effect list  (** keep running this scene (maybe a new one) *)
  | Stopped                        (** a scene returned [Quit] *)
(** The result of advancing the app by one frame. *)

val step : registry -> ctx -> input -> running -> step_result
(**
   [step reg ctx inp r] runs one frame of logic: it calls the running
   scene's [update] and follows its decision, entering a new scene (with
   fresh state) on [Goto].
   Requires: nothing
   Returns: [Next] with the scene to draw and the effects to apply after
            drawing, or [Stopped]
   Raises: [Invalid_argument] if [Goto] names an unregistered scene
   Example: step reg ctx { inp with keys = [Enter] } welcome = Next (play, [])
   Complexity: the scene's [update] (plus [init] when switching)
*)
