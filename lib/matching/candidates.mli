(**
   File: candidates.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Candidates module: turns drawn corners into candidate
                star matches, using the triangle index and the two-point (handle)
                rule.
   Usage: Import: add hack.matching to (libraries ...) in a dune file, then use
          Doodle_matching.Candidates (or Candidates with -open Doodle_matching).
          Build: dune build    Test: dune test
*)

(** Candidate generator: turns drawn corners into guesses.

    For each drawn triangle, looks up {!Index.find_near} and, for each
    star triple found, derives a first transform with
    {!Geom.sim_of_pair} from the triangle's longest side (the steadiest
    baseline), the two-handle rule from GIMP's Handle Transform tool. *)

type hypothesis = {
  drawn : Geom.pt array;   (** all simplified corners, screen pixels *)
  corners : int array;     (** the 3 seed corners, canonical order *)
  stars : int array;       (** the 3 seed stars, same order *)
  centre : float * float;  (** (ra, dec) of the gnomonic plane used *)
  sim : Geom.sim;          (** maps screen pixels onto that plane *)
}

val max_hypotheses : int
(** Cap on the list length so the fitter stays fast. [5000]. *)

val triangles : int -> (int * int * int) list
(**
   [triangles n] lists every 3-subset of [0 .. n-1] as [(i, j, k)] with
   [i < j < k], in lexicographic order (84 for [n = 9]).
   Requires: nothing ([n < 3] gives [\[\]])
   Returns: [n choose 3] triples
   Raises: nothing
   Example: triangles 4 = [(0,1,2); (0,1,3); (0,2,3); (1,2,3)]
   Complexity: O(n^3) time and space
*)

val generate : Index.t -> Geom.pt array -> hypothesis list
(**
   [generate index corners] proposes star matches for a drawing:
   + forms every triangle of [corners];
   + computes {!Index.key} and looks up {!Index.find_near} (degenerate
     drawn triangles are skipped);
   + projects each hit's stars with {!Geom.gnomonic} around the
     triple's centroid;
   + pairs the drawn longest side [(a, b)] (the corners opposite the
     short and middle sides) with the star longest side [(a', b')] and
     sets [sim = Geom.sim_of_pair a b a' b'].
   Holds no state between drawings.
   Requires: [corners] in screen pixels (normally 5 to 9 of them)
   Returns: at most {!max_hypotheses} hypotheses, in triangle order
   Raises: nothing
   Example: generate (Index.build [||]) corners = []
   Complexity: O(n^3 * r) time and O(min (n^3 r, max_hypotheses)) space,
               n corners, r hits per lookup
*)
