(* PLANNED (collect mode): stub implementation. The interface in
   asterism.mli is the contract; replace each [todo] with the real code.
   See docs/COLLECT_PLAN.md. *)

type t = {
  name : string;
  con : string;
  stars : int array;       (* catalogue indices, drawing order *)
  shape : Geom.pt array;   (* gnomonic outline, same order *)
}

let todo what = failwith ("Asterism." ^ what ^ ": not implemented yet (see asterism.mli)")

(**
   [load stars path] reads and resolves the figure file.
   Requires: see asterism.mli
   Returns: figures in file order
   Raises: Sys_error, Failure
   Example: Array.length (load stars "data/asterisms.csv") = 7
   Complexity: O(F + N)
   Pseudocode:
     by_id <- table from HR id to catalogue index
     for each data line "name,con,ids":
       idx <- map (lookup by_id) (split ids)   (fail on unknown id)
       centre <- Skyvec.centre of their positions
       shape <- Geom.gnomonic ~centre of each star
       emit { name; con; stars = idx; shape }
*)
let load (_ : Catalogue.star array) (_ : string) : t array = todo "load"

(**
   [name f] is the display name.
   Requires: nothing
   Returns: [f.name]
   Raises: nothing
   Example: name big_dipper = "Big Dipper"
   Complexity: O(1)
   Pseudocode:
     return f.name
*)
let name f = f.name

(**
   [constellation f] is the constellation abbreviation.
   Requires: nothing
   Returns: [f.con]
   Raises: nothing
   Example: constellation big_dipper = "UMa"
   Complexity: O(1)
   Pseudocode:
     return f.con
*)
let constellation f = f.con

(**
   [star_indices f] is the stars in drawing order.
   Requires: nothing
   Returns: a copy of [f.stars]
   Raises: nothing
   Example: Array.length (star_indices big_dipper) = 8
   Complexity: O(k)
   Pseudocode:
     return copy f.stars
*)
let star_indices f = Array.copy f.stars

(**
   [shape f] is the ideal outline.
   Requires: nothing
   Returns: a copy of [f.shape]
   Raises: nothing
   Example: Array.length (shape orion) = 7
   Complexity: O(k)
   Pseudocode:
     return copy f.shape
*)
let shape f = Array.copy f.shape

(**
   [is_closed f] tells whether the figure is a loop.
   Requires: nothing
   Returns: first star index = last star index
   Raises: nothing
   Example: is_closed cassiopeia = false
   Complexity: O(1)
   Pseudocode:
     return k >= 2 and stars.(0) = stars.(k-1)
*)
let is_closed f =
  let k = Array.length f.stars in
  k >= 2 && f.stars.(0) = f.stars.(k - 1)
