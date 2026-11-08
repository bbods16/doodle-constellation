(**
   File: index.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Index module: a geometric-hashing index of small star
                triangles, keyed by a shape that ignores position, size, rotation and
                mirroring.
   Usage: Import: add hack.matching to (libraries ...) in a dune file, then use
          Doodle_matching.Index (or Index with -open Doodle_matching).
          Build: dune build    Test: dune test
*)

(** Invariant index: geometric hashing of star triangles.

    Every triangle of stars within {!max_sep_deg} of each other is
    projected with {!Geom.gnomonic} around its own centroid and
    described by a key that ignores position, size and rotation. The
    same {!key} function is used for drawn corners, so drawn and
    catalogued shapes land in the same bins. No GIMP counterpart; the
    design follows Astrometry.net.

    The key also ignores reflection (side ratios and an angle are the
    same for a triangle and its mirror image), which is why
    {!Fitter} can try a mirrored drawing against the same hits. *)

type key = int * int * int
(** Binned (short/long side ratio, middle/long side ratio, angle
    opposite the longest side). *)

type triple = int * int * int
(** Star indices into the catalogue array, ordered like the key:
    the vertices opposite the short, middle and long sides. *)

type t
(** The built index: the catalogue plus a hash table from key to the
    triples filed under it. *)

val ratio_bins : int
(** Bins across [0, 1] for each side ratio. [40]. *)

val angle_bins : int
(** Bins across [0, pi] for the angle. [36] (5 degrees each). *)

val max_sep_deg : float
(** Largest angular distance between two stars of one triangle. [25.]. *)

val key : Geom.pt -> Geom.pt -> Geom.pt -> key * int array
(**
   [key a b c] is the binned shape key of the triangle and the
   permutation [\[|i; j; k|\]] of [0, 1, 2] that puts its vertices in
   canonical order (opposite the short, middle and long sides).
   Requires: the three points form a proper triangle
   Returns: [(key, perm)]; [perm.(0)] is the vertex opposite the
            shortest side, [perm.(2)] the vertex opposite the longest
   Raises: [Invalid_argument] for a degenerate triangle (longest side
           under 1e-12, or the points (nearly) collinear)
   Example: key {x=0.;y=0.} {x=4.;y=0.} {x=0.;y=3.}
            = ((24, 32, 18), [|1; 2; 0|])   (* 3-4-5 right triangle *)
   Complexity: O(1) time, O(1) space
*)

val neighbours : key -> key list
(**
   [neighbours k] is the key and its 26 neighbours ([+-1] in each part),
   clamped to the valid ranges, without duplicates.
   Requires: [k] is a valid key
   Returns: between 8 and 27 distinct keys, always including [k]
   Raises: nothing
   Example: List.length (neighbours (10, 10, 10)) = 27
   Complexity: O(1) time, O(1) space
*)

val build : Catalogue.star array -> t
(**
   [build stars] builds the index once at startup: every triangle whose
   three pairwise separations are at most {!max_sep_deg} is projected
   around its sky centroid, keyed with {!key}, and filed as a triple in
   canonical order. Degenerate triangles are skipped.
   Requires: radians in [stars]
   Returns: the index
   Raises: nothing
   Example: size (build [||]) = 0
   Complexity: O(N * m^2) time and O(T) space, N stars, m neighbours per
               star within the separation limit, T triangles stored
*)

val stars : t -> Catalogue.star array
(**
   [stars t] is the catalogue the index was built from.
   Requires: nothing
   Returns: the same array passed to {!build}
   Raises: nothing
   Example: stars (build s) == s
   Complexity: O(1) time, O(1) space
*)

val find : t -> key -> triple list
(**
   [find t k] is the triples filed under exactly [k].
   Requires: nothing
   Returns: possibly empty list
   Raises: nothing
   Example: find (build [||]) (0, 0, 0) = []
   Complexity: O(1) expected time, O(1) space (returns the stored list)
*)

val find_near : t -> key -> triple list
(**
   [find_near t k] is the triples filed under [k] or any of its
   {!neighbours}, which tolerates a shaky hand.
   Requires: nothing
   Returns: possibly empty list; no triple appears twice (each triple
            is filed under exactly one key)
   Raises: nothing
   Example: find_near (build [||]) (0, 0, 0) = []
   Complexity: O(27 + r) time and space, r = number of results
*)

val size : t -> int
(**
   [size t] is the number of triples stored.
   Requires: nothing
   Returns: a count [>= 0]
   Raises: nothing
   Example: size (build [||]) = 0
   Complexity: O(1) time, O(1) space
*)
