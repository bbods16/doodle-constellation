(** Asterism: the constellation figures the player can collect.

    Design notes: [docs/COLLECT_PLAN.md].

    One figure per row of [data/asterisms.csv] ([name,con,stars]), where
    [stars] is the HR ids of the stars in drawing order. A figure drawn
    as a closed loop repeats its first star at the end. The same file
    trains the recognition engine, so adding a row adds a collectible
    figure and (after retraining) a class the engine knows. *)

type t
(** One figure: name, constellation, stars in drawing order, and its
    ideal shape. Abstract. *)

val load : Catalogue.star array -> string -> t array
(**
   [load stars path] reads the figure file and resolves every star id
   against the catalogue.
   Requires: [path] in the [name,con,stars] format; every id in [stars]
   Returns: the figures in file order
   Raises: [Sys_error] if the file is missing; [Failure] naming the figure
           and id when a star id is not in the catalogue
   Example: Array.length (load stars "data/asterisms.csv") = 7
   Complexity: O(F + N) time and space, F = file size, N = catalogue size
*)

val name : t -> string
(**
   [name f] is the figure's display name.
   Requires: nothing
   Returns: e.g. ["Big Dipper"]
   Raises: nothing
   Example: name big_dipper = "Big Dipper"
   Complexity: O(1)
*)

val constellation : t -> string
(**
   [constellation f] is the IAU abbreviation of the constellation it belongs to.
   Requires: nothing
   Returns: e.g. ["UMa"]
   Raises: nothing
   Example: constellation big_dipper = "UMa"
   Complexity: O(1)
*)

val star_indices : t -> int array
(**
   [star_indices f] is the figure's stars as indices into the catalogue
   array given to {!load}, in drawing order (repeats included).
   Requires: nothing
   Returns: a fresh array
   Raises: nothing
   Example: Array.length (star_indices big_dipper) = 8
   Complexity: O(k), k stars
*)

val shape : t -> Geom.pt array
(**
   [shape f] is the figure's ideal outline: its stars projected with
   {!Geom.gnomonic} around their centre, in screen orientation, in
   drawing order. This is what a drawing is scored against.
   Requires: nothing
   Returns: a fresh array, one point per entry of {!star_indices}
   Raises: nothing
   Example: Array.length (shape orion) = 7
   Complexity: O(k)
*)

val is_closed : t -> bool
(**
   [is_closed f] tells whether the figure ends on its first star (a loop,
   which may then be drawn starting from any star).
   Requires: nothing
   Returns: [true] for loops such as Orion or the triangles
   Raises: nothing
   Example: is_closed cassiopeia = false
   Complexity: O(1)
*)
