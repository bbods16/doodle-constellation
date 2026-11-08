(* Locating the data folder. See data_dir.mli for the public contract. *)

let stars_file = "stars.csv"
let env_var = "DOODLE_DATA"

(**
   [ancestors dir] lists [dir] and its parents up to the root.
   Requires: nothing
   Returns: [dir] first, root last
   Raises: nothing
   Example: ancestors "/a/b" = ["/a/b"; "/a"; "/"]
   Complexity: O(d)
   Pseudocode:
     parent <- Filename.dirname dir
     if parent = dir then [dir]            (* reached the root *)
     else dir :: ancestors parent
*)
let rec ancestors dir =
  let parent = Filename.dirname dir in
  if parent = dir then [ dir ] else dir :: ancestors parent

(**
   [candidates ~env ~cwd ~exe] lists catalogue paths in search order.
   Requires: absolute [cwd]
   Returns: paths ending in stars.csv, no duplicates
   Raises: nothing
   Example: List.hd (candidates ~env:(Some "/d") ~cwd:"/r" ~exe:"/r/x.exe") = "/d/stars.csv"
   Complexity: O(d)
   Pseudocode:
     from_env <- [env/stars.csv] if env is set and non-empty
     exe_dir <- dirname exe (made absolute against cwd)
     from_cwd <- for each ancestor a of cwd: a/data/stars.csv
     from_exe <- for each ancestor a of exe_dir: a/data/stars.csv
     return from_env @ from_cwd @ from_exe, keeping first occurrences
*)
let candidates ~env ~cwd ~exe =
  let in_data dir = Filename.concat (Filename.concat dir "data") stars_file in
  let from_env =
    match env with Some d when d <> "" -> [ Filename.concat d stars_file ] | _ -> []
  in
  let exe = if Filename.is_relative exe then Filename.concat cwd exe else exe in
  let all =
    from_env
    @ List.map in_data (ancestors cwd)
    @ List.map in_data (ancestors (Filename.dirname exe))
  in
  List.fold_left (fun acc p -> if List.mem p acc then acc else p :: acc) [] all |> List.rev

(**
   [find ~env ~cwd ~exe ~exists] is the first existing candidate.
   Requires: absolute [cwd]
   Returns: [Ok path] or [Error tried]
   Raises: nothing
   Example: find ~env:None ~cwd:"/r/bin" ~exe:"/x" ~exists:(( = ) "/r/data/stars.csv")
            = Ok "/r/data/stars.csv"
   Complexity: O(d) calls to exists
   Pseudocode:
     tried <- candidates ~env ~cwd ~exe
     match first p in tried with exists p with
       | Some p -> Ok p
       | None -> Error tried
*)
let find ~env ~cwd ~exe ~exists =
  let tried = candidates ~env ~cwd ~exe in
  match List.find_opt exists tried with Some p -> Ok p | None -> Error tried
