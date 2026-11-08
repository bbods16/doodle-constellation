(* Doodle Constellation: draw a shape, find it in the stars.

   Usage: hack [LAT_DEG LON_DEG] [CATALOGUE.csv]

   This file only loads shared resources, lists the scenes, and hands
   control to the loop in app.ml. To add a screen, write a module that
   matches Scene.S (see welcome.ml) and add it to [scenes] below. *)

(**
   [parse_args argv] reads the optional location and catalogue path.
   Requires: nothing
   Returns: [((lat, lon), path)] with angles in radians; defaults to
            {!Visibility.buffalo} and ["data/stars.csv"]
   Raises: nothing (unparsable numbers fall back to the defaults)
   Example: parse_args [|"hack"; "40.7"; "-74.0"|] = ((rad 40.7, rad (-74.)), "data/stars.csv")
   Complexity: O(1) time, O(1) space
   Pseudocode:
     match argv with
       | [_; lat; lon; path] -> ((rad lat, rad lon), path)
       | [_; lat; lon]       -> ((rad lat, rad lon), default path)
       | [_; path]           -> (buffalo, path)
       | _                   -> (buffalo, default path)
*)
let parse_args argv =
  let default_path = "data/stars.csv" in
  let loc lat lon =
    match (float_of_string_opt lat, float_of_string_opt lon) with
    | Some a, Some b -> (Geom.rad a, Geom.rad b)
    | _ -> Visibility.buffalo
  in
  match argv with
  | [| _; lat; lon; path |] -> (loc lat lon, path)
  | [| _; lat; lon |] -> (loc lat lon, default_path)
  | [| _; path |] -> (Visibility.buffalo, path)
  | _ -> (Visibility.buffalo, default_path)

(**
   [load_ctx argv] loads everything the scenes share.
   Requires: the catalogue file exists
   Returns: the shared {!Scene.ctx}
   Raises: [Sys_error] if the catalogue is missing
   Example: Scene.stars (load_ctx [|"hack"|]) = Catalogue.load "data/stars.csv"
   Complexity: O(N m^2) for the index build
   Pseudocode:
     (lat, lon), path <- parse_args argv
     stars <- Catalogue.load path ; index <- Index.build stars
     engine <- Engine.load (engine_weights.txt next to the catalogue),
               or None when missing or malformed
     return Scene.make_ctx ~stars ~index ?engine ~lat ~lon ()
*)
let load_ctx argv =
  let (lat, lon), path = parse_args argv in
  let stars = Catalogue.load path in
  let weights = Filename.concat (Filename.dirname path) "engine_weights.txt" in
  let engine =
    if Sys.file_exists weights then (try Some (Engine.load weights) with Failure _ -> None) else None
  in
  Scene.make_ctx ~stars ~index:(Index.build stars) ?engine ~lat ~lon ()

(* Every screen of the app. Order does not matter; names must be unique. *)
let scenes : (module Scene.S) list = [ (module Welcome); (module Play) ]

let () = App.run App.default_config (load_ctx Sys.argv) (Scene.registry scenes) ~first:"welcome"
