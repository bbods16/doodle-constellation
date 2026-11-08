(**
   File: scene.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Scene module: the screen framework - the Scene.S
                signature every screen implements, the per-frame input record, the
                shared context, the registry and step.
   Usage: The contract is in scene.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Scene (or Scene with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Scenes and the scene router. See scene.mli for the public contract. *)

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
  | Letter of char
  | Digit of int

type input = {
  dt : float;
  time : float;
  width : int;
  height : int;
  mouse : Geom.pt;
  mouse_down : bool;
  mouse_pressed : bool;
  mouse_released : bool;
  keys : key list;
}

type ctx = {
  stars : Catalogue.star array;
  index : Index.t;
  engine : Engine.t option;
  figures : Asterism.t array;
  data_dir : string;
  lat : float;
  lon : float;
}

(**
   [make_ctx ~stars ~index ?engine ?figures ?data_dir ~lat ~lon ()]
   bundles shared resources.
   Requires: [index] built from [stars]
   Returns: the context
   Raises: nothing
   Example: stars (make_ctx ~stars ~index ~lat ~lon ()) == stars
   Complexity: O(1)
   Pseudocode:
     return { stars; index; engine; figures (default [||]);
              data_dir (default "data"); lat; lon }
*)
let make_ctx ~stars ~index ?engine ?(figures = [||]) ?(data_dir = "data") ~lat ~lon () =
  { stars; index; engine; figures; data_dir; lat; lon }

(**
   [figures ctx] is the collectible figures.
   Requires: nothing
   Returns: [ctx.figures]
   Raises: nothing
   Example: figures (make_ctx ~stars ~index ~lat ~lon ()) = [||]
   Complexity: O(1)
   Pseudocode:
     return ctx.figures
*)
let figures ctx = ctx.figures

(**
   [data_dir ctx] is the data folder.
   Requires: nothing
   Returns: [ctx.data_dir]
   Raises: nothing
   Example: data_dir (make_ctx ~stars ~index ~lat ~lon ()) = "data"
   Complexity: O(1)
   Pseudocode:
     return ctx.data_dir
*)
let data_dir ctx = ctx.data_dir

(**
   [stars ctx] is the catalogue.
   Requires: nothing
   Returns: [ctx.stars]
   Raises: nothing
   Example: stars (make_ctx ~stars:s ~index ~lat ~lon ()) == s
   Complexity: O(1)
   Pseudocode:
     return ctx.stars
*)
let stars ctx = ctx.stars

(**
   [index ctx] is the triangle index.
   Requires: nothing
   Returns: [ctx.index]
   Raises: nothing
   Example: index (make_ctx ~stars ~index:ix ~lat ~lon ()) == ix
   Complexity: O(1)
   Pseudocode:
     return ctx.index
*)
let index ctx = ctx.index

(**
   [engine ctx] is the recognition engine, if loaded.
   Requires: nothing
   Returns: [ctx.engine]
   Raises: nothing
   Example: engine (make_ctx ~stars ~index ~lat ~lon ()) = None
   Complexity: O(1)
   Pseudocode:
     return ctx.engine
*)
let engine ctx = ctx.engine

(**
   [location ctx] is the observer's location.
   Requires: nothing
   Returns: [(ctx.lat, ctx.lon)]
   Raises: nothing
   Example: location (make_ctx ~stars ~index ~lat:0.7 ~lon:(-1.4) ()) = (0.7, -1.4)
   Complexity: O(1)
   Pseudocode:
     return (ctx.lat, ctx.lon)
*)
let location ctx = (ctx.lat, ctx.lon)

type side_effect = Screenshot of string
type 'a outcome = Continue of 'a * side_effect list | Goto of string | Quit

module type S = sig
  type t

  val name : string
  val init : ctx -> t
  val update : ctx -> input -> t -> t outcome
  val draw : ctx -> t -> unit
end

(* The state type differs per scene, so it is hidden with a GADT. *)
type running = Running : (module S with type t = 'a) * 'a -> running

type registry = (module S) list
type step_result = Next of running * side_effect list | Stopped

(**
   [idle ~width ~height] is an empty frame of input.
   Requires: nothing
   Returns: zero time, mouse at the origin, nothing pressed
   Raises: nothing
   Example: (idle ~width:1280 ~height:800).keys = []
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return { dt = 0; time = 0; width; height; mouse = (0, 0);
              all buttons false; keys = [] }
*)
let idle ~width ~height =
  { dt = 0.; time = 0.; width; height; mouse = { Geom.x = 0.; y = 0. };
    mouse_down = false; mouse_pressed = false; mouse_released = false; keys = [] }

(**
   [pressed inp k] tells whether [k] was pressed this frame.
   Requires: nothing
   Returns: membership of [k] in [inp.keys]
   Raises: nothing
   Example: pressed { (idle ~width:1 ~height:1) with keys = [Enter] } Enter = true
   Complexity: O(k) time, O(1) space
   Pseudocode:
     return k is a member of inp.keys
*)
let pressed inp k = List.mem k inp.keys

(**
   [start (module M) ctx] enters scene [M] with fresh state.
   Requires: nothing
   Returns: the running scene
   Raises: whatever [M.init] raises
   Example: current_name (start (module Welcome) ctx) = "welcome"
   Complexity: O(1) plus [M.init]
   Pseudocode:
     return Running (M, M.init ctx)
*)
let start (module M : S) ctx = Running ((module M), M.init ctx)

(**
   [current_name r] is the running scene's name.
   Requires: nothing
   Returns: [M.name]
   Raises: nothing
   Example: current_name (start (module Welcome) ctx) = "welcome"
   Complexity: O(1)
   Pseudocode:
     unpack Running (M, _) ; return M.name
*)
let current_name (Running ((module M), _)) = M.name

(**
   [draw ctx r] draws the running scene.
   Requires: inside the loop's drawing block
   Returns: unit
   Raises: whatever [M.draw] raises
   Example: draw ctx r
   Complexity: [M.draw]
   Pseudocode:
     unpack Running (M, state) ; M.draw ctx state
*)
let draw ctx (Running ((module M), st)) = M.draw ctx st

(**
   [name_of (module M)] is [M.name] (helper for the registry).
   Requires: nothing
   Returns: the scene's name
   Raises: nothing
   Example: name_of (module Welcome) = "welcome"
   Complexity: O(1)
   Pseudocode:
     return M.name
*)
let name_of (module M : S) = M.name

(**
   [registry scenes] collects scenes by name.
   Requires: distinct names, non-empty list
   Returns: the registry
   Raises: [Invalid_argument] on an empty list or a duplicate name
   Example: names (registry [(module Welcome); (module Play)]) = ["welcome"; "play"]
   Complexity: O(n^2) time, O(n) space
   Pseudocode:
     if scenes = [] then fail
     for each scene, if an earlier scene has the same name then fail
     return scenes
*)
let registry scenes =
  (match scenes with [] -> invalid_arg "Scene.registry: no scenes" | _ -> ());
  let rec check seen = function
    | [] -> ()
    | s :: rest ->
        let n = name_of s in
        if List.mem n seen then invalid_arg ("Scene.registry: duplicate scene name " ^ n);
        check (n :: seen) rest
  in
  check [] scenes;
  scenes

(**
   [names reg] is the registered names in order.
   Requires: nothing
   Returns: the names
   Raises: nothing
   Example: names (registry [(module Welcome)]) = ["welcome"]
   Complexity: O(n)
   Pseudocode:
     return map name_of reg
*)
let names reg = List.map name_of reg

(**
   [launch reg ctx name] starts the named scene.
   Requires: [name] registered
   Returns: the running scene
   Raises: [Invalid_argument] for an unknown name
   Example: current_name (launch reg ctx "play") = "play"
   Complexity: O(n) plus [init]
   Pseudocode:
     match the first scene in reg whose name = name with
       | Some m -> start m ctx
       | None -> fail with the unknown name and the known names
*)
let launch reg ctx name =
  match List.find_opt (fun s -> name_of s = name) reg with
  | Some m -> start m ctx
  | None ->
      invalid_arg
        (Printf.sprintf "Scene.launch: unknown scene %S (known: %s)" name
           (String.concat ", " (names reg)))

(**
   [step reg ctx inp r] advances the app by one frame of logic.
   Requires: nothing
   Returns: [Next (scene, effects)] or [Stopped]
   Raises: [Invalid_argument] if [Goto] names an unknown scene
   Example: step reg ctx { inp with keys = [Enter] } welcome = Next (play, [])
   Complexity: [M.update] (plus [init] on a switch)
   Pseudocode:
     unpack Running (M, state)
     match M.update ctx inp state with
       | Continue (state', effects) -> Next (Running (M, state'), effects)
       | Goto name -> Next (launch reg ctx name, [])
       | Quit -> Stopped
*)
let step reg ctx inp (Running ((module M), st)) =
  match M.update ctx inp st with
  | Continue (st', effects) -> Next (Running ((module M), st'), effects)
  | Goto name -> Next (launch reg ctx name, [])
  | Quit -> Stopped
