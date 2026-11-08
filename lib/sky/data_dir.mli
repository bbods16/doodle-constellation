(**
   File: data_dir.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Data_dir module: finds data/stars.csv wherever the
                app is started - DOODLE_DATA, then the current folder and its parents,
                then the executable's.
   Usage: Import: add hack.sky to (libraries ...) in a dune file, then use
          Doodle_sky.Data_dir (or Data_dir with -open Doodle_sky).
          Build: dune build    Test: dune test
*)

(** Data_dir: finds [data/stars.csv] no matter where the app is started.

    Running the app from a folder other than the repo root (from inside
    [bin/], by double-clicking the executable, or from an IDE) used to
    fail with [Sys_error "data/stars.csv: No such file or directory"],
    because the path was relative to the current folder.

    {!find} instead tries, in order:
    + the [DOODLE_DATA] environment variable (a folder holding [stars.csv]);
    + [data/] in the current folder, then in each parent folder;
    + [data/] next to the executable, then in each parent folder (this
      covers [_build/default/bin/main.exe] inside the repo).

    The search is pure: the caller passes the current folder, the
    executable path and a file-exists test, so it is unit-tested without
    touching the disk. *)

val stars_file : string
(** The catalogue's file name: ["stars.csv"]. *)

val env_var : string
(** The environment variable checked first: ["DOODLE_DATA"]. *)

val ancestors : string -> string list
(**
   [ancestors dir] is [dir] followed by each parent folder up to the root.
   Requires: nothing
   Returns: a non-empty list, [dir] first, the root last
   Raises: nothing
   Example: ancestors "/a/b" = ["/a/b"; "/a"; "/"]
   Complexity: O(d) time and space, d = folder depth
*)

val candidates : env:string option -> cwd:string -> exe:string -> string list
(**
   [candidates ~env ~cwd ~exe] is every catalogue path {!find} will try,
   in search order, without duplicates.
   Requires: [cwd] absolute; [exe] absolute or relative to [cwd]
   Returns: full paths ending in [stars.csv]
   Raises: nothing
   Example: List.hd (candidates ~env:(Some "/d") ~cwd:"/r" ~exe:"/r/x.exe") = "/d/stars.csv"
   Complexity: O(d) time and space
*)

val find :
  env:string option -> cwd:string -> exe:string -> exists:(string -> bool) ->
  (string, string list) result
(**
   [find ~env ~cwd ~exe ~exists] is the first of {!candidates} for which
   [exists] holds.
   Requires: same as {!candidates}
   Returns: [Ok path] to the catalogue, or [Error tried] listing every
            path that was checked, in order
   Raises: nothing (unless [exists] raises)
   Example: find ~env:None ~cwd:"/r/bin" ~exe:"/x" ~exists:(( = ) "/r/data/stars.csv")
            = Ok "/r/data/stars.csv"
   Complexity: O(d) calls to [exists]
*)
