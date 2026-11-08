(**
   File: candidates.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Candidates module: turns drawn corners into
                candidate star matches, using the triangle index and the two-point
                (handle) rule.
   Usage: The contract is in candidates.mli.
          Import: add hack.matching to (libraries ...) in a dune file, then use
          Doodle_matching.Candidates (or Candidates with -open Doodle_matching).
          Build: dune build    Test: dune test
*)

(* Candidate generator. See candidates.mli for the public contract. *)

type hypothesis = {
  drawn : Geom.pt array;
  corners : int array;
  stars : int array;
  centre : float * float;
  sim : Geom.sim;
}

let max_hypotheses = 5000

(**
   [triangles n] lists every 3-subset of [0 .. n-1].
   Requires: nothing
   Returns: lexicographic list of [(i, j, k)], [i < j < k]
   Raises: nothing
   Example: triangles 4 = [(0,1,2); (0,1,3); (0,2,3); (1,2,3)]
   Complexity: O(n^3) time and space
   Pseudocode:
     acc <- []
     for i = n-1 downto 0, j = n-1 downto i+1, k = n-1 downto j+1:
       acc <- (i, j, k) :: acc            (* built backwards = sorted *)
     return acc
*)
let triangles n =
  let acc = ref [] in
  for i = n - 1 downto 0 do
    for j = n - 1 downto i + 1 do
      for k = n - 1 downto j + 1 do
        acc := (i, j, k) :: !acc
      done
    done
  done;
  !acc

exception Full

(**
   [generate index corners] proposes star matches for a drawing.
   Requires: screen-pixel corners
   Returns: up to [max_hypotheses] hypotheses
   Raises: nothing
   Example: generate (Index.build [||]) corners = []
   Complexity: O(n^3 r) time
   Pseudocode:
     out <- [] ; count <- 0
     for each (i, j, k) in triangles |corners|:
       (key, perm) <- Index.key corners.(i) corners.(j) corners.(k)
                      (skip on degenerate)
       tri <- [|i; j; k|] ; canon <- [|tri.(perm.(0)); tri.(perm.(1)); tri.(perm.(2))|]
       for each (s0, s1, s2) in Index.find_near index key:
         centre <- Skyvec.centre of the three star positions
         (q0, q1) <- gnomonic ~centre of s0, s1 (skip on None)
         sim <- sim_of_pair corners.(canon.(0)) corners.(canon.(1)) q0 q1
         push { drawn = corners; corners = canon; stars = [|s0;s1;s2|];
                centre; sim }
         if count = max_hypotheses then stop everything
     return reverse out
*)
let generate index corners =
  let stars = Index.stars index in
  let out = ref [] and count = ref 0 in
  let n = Array.length corners in
  (try
     List.iter
       (fun (i, j, k) ->
         match Index.key corners.(i) corners.(j) corners.(k) with
         | exception Invalid_argument _ -> ()
         | key, perm ->
             let tri = [| i; j; k |] in
             let canon = Array.map (fun p -> tri.(p)) perm in
             List.iter
               (fun (s0, s1, s2) ->
                 let pos s = Catalogue.position stars.(s) in
                 match Skyvec.centre [ pos s0; pos s1; pos s2 ] with
                 | exception Invalid_argument _ -> ()
                 | centre -> (
                     match (Geom.gnomonic ~centre (pos s0), Geom.gnomonic ~centre (pos s1)) with
                     | Some q0, Some q1 -> (
                         match Geom.sim_of_pair corners.(canon.(0)) corners.(canon.(1)) q0 q1 with
                         | exception Invalid_argument _ -> ()
                         | sim ->
                             out :=
                               { drawn = corners; corners = canon; stars = [| s0; s1; s2 |];
                                 centre; sim }
                               :: !out;
                             incr count;
                             if !count >= max_hypotheses then raise Full)
                     | _ -> ()))
               (Index.find_near index key))
       (triangles n)
   with Full -> ());
  List.rev !out
