(* Doodle Constellation: draw a shape, find it in the stars.

   Usage: hack [LAT_DEG LON_DEG] [CATALOGUE.csv]

   The catalogue is found automatically (see Data_dir) unless a path is
   given. This file only loads shared resources, lists the scenes, and
   hands control to the loop in app.ml. To add a screen, write a module
   that matches Scene.S (see welcome.ml) and add it to [scenes] below. *)

(**
   [parse_args argv] reads the optional location and catalogue path.
   Requires: nothing
   Returns: [((lat, lon), path)] with angles in radians; [path] is [None]
            when no catalogue was given (it is then searched for)
   Raises: nothing (unparsable numbers fall back to {!Visibility.buffalo})
   Example: parse_args [|"hack"; "40.7"; "-74.0"|] = ((rad 40.7, rad (-74.)), None)
   Complexity: O(1) time, O(1) space
   Pseudocode:
     match argv with
       | [_; lat; lon; path] -> ((rad lat, rad lon), Some path)
       | [_; lat; lon]       -> ((rad lat, rad lon), None)
       | [_; path]           -> (buffalo, Some path)
       | _                   -> (buffalo, None)
*)
let parse_args argv =
  let loc lat lon =
    match (float_of_string_opt lat, float_of_string_opt lon) with
    | Some a, Some b -> (Geom.rad a, Geom.rad b)
    | _ -> Visibility.buffalo
  in
  match argv with
  | [| _; lat; lon; path |] -> (loc lat lon, Some path)
  | [| _; lat; lon |] -> (loc lat lon, None)
  | [| _; path |] -> (Visibility.buffalo, Some path)
  | _ -> (Visibility.buffalo, None)

(**
   [fail_with_help lines] prints a readable error and exits with status 2.
   Requires: nothing
   Returns: never
   Raises: nothing (exits the process)
   Example: fail_with_help ["Could not find data/stars.csv."]
   Complexity: O(total length of lines)
   Pseudocode:
     print each line to stderr ; exit 2
*)
let fail_with_help lines =
  List.iter prerr_endline lines;
  exit 2

(**
   [catalogue_path given] decides which catalogue file to load.
   Requires: nothing
   Returns: [given] if one was passed and it exists; otherwise the first
            match from {!Data_dir.find}
   Raises: nothing (prints help and exits when no catalogue can be found)
   Example: catalogue_path None = "C:\\...\\hack\\data\\stars.csv" from anywhere in the repo
   Complexity: O(d) file-exists checks, d = folder depth
   Pseudocode:
     match given with
       | Some p when exists p -> p
       | Some p -> fail: "p not found"
       | None -> match Data_dir.find (env DOODLE_DATA, cwd, executable) with
                   | Ok p -> p
                   | Error tried -> fail: list tried paths and the fixes
*)
let catalogue_path given =
  match given with
  | Some p when Sys.file_exists p -> p
  | Some p -> fail_with_help [ "Star catalogue not found: " ^ p ]
  | None -> (
      match
        Data_dir.find ~env:(Sys.getenv_opt Data_dir.env_var) ~cwd:(Sys.getcwd ())
          ~exe:Sys.executable_name ~exists:Sys.file_exists
      with
      | Ok p -> p
      | Error tried ->
          fail_with_help
            ([ "Could not find the star catalogue (data/" ^ Data_dir.stars_file ^ ")."; "Looked in:" ]
            @ List.map (fun p -> "  " ^ p) tried
            @ [ "Fix: run from inside the repo (e.g. `dune exec hack` at the repo root),";
                "     pass the file: hack path/to/stars.csv,";
                "     or set " ^ Data_dir.env_var ^ " to the folder that contains "
                ^ Data_dir.stars_file ^ "." ]))

(**
   [load_ctx argv] loads everything the scenes share.
   Requires: nothing (a missing catalogue prints help and exits)
   Returns: the shared {!Scene.ctx}
   Raises: nothing
   Example: Scene.stars (load_ctx [|"hack"|]) = Catalogue.load (catalogue_path None)
   Complexity: O(N m^2) for the index build
   Pseudocode:
     (lat, lon), given <- parse_args argv
     path <- catalogue_path given
     stars <- Catalogue.load path ; index <- Index.build stars
     dir <- folder of the catalogue
     engine <- Engine.load (dir/engine_weights.txt), or None when missing or malformed
     figures <- Asterism.load stars (dir/asterisms.csv), or [||] when missing or malformed
                (collect mode is then disabled on the menu)
     return Scene.make_ctx ~stars ~index ?engine ~figures ~data_dir:dir ~lat ~lon ()
*)
let load_ctx argv =
  let (lat, lon), given = parse_args argv in
  let path = catalogue_path given in
  let dir = Filename.dirname path in
  let stars = Catalogue.load path in
  let optional file load =
    let f = Filename.concat dir file in
    if Sys.file_exists f then (try Some (load f) with Failure _ | Sys_error _ -> None) else None
  in
  let engine = optional "engine_weights.txt" Engine.load in
  let figures = Option.value ~default:[||] (optional "asterisms.csv" (Asterism.load stars)) in
  Scene.make_ctx ~stars ~index:(Index.build stars) ?engine ~figures ~data_dir:dir ~lat ~lon ()

(* Every screen of the app. Order does not matter; names must be unique. *)
let scenes : (module Scene.S) list = [ (module Welcome); (module Play); (module Collect_scene) ]

let () = App.run App.default_config (load_ctx Sys.argv) (Scene.registry scenes) ~first:"welcome"
