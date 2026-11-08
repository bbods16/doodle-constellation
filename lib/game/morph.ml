(**
   File: morph.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Morph module: the animation that slides, turns
                and scales the drawing onto the matched stars.
   Usage: The contract is in morph.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Morph (or Morph with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* Morph animation. See morph.mli for the public contract. *)

open Geom

type t = { c0 : pt; t1 : sim; u : float }

let duration = 1.5

(**
   [ease u] is smoothstep on the clamped input.
   Requires: nothing
   Returns: value in [0, 1]
   Raises: nothing
   Example: ease 0.5 = 0.5
   Complexity: O(1) time, O(1) space
   Pseudocode:
     u <- clamp u to [0, 1]
     return u * u * (3 - 2u)
*)
let ease u =
  let u = Float.max 0. (Float.min 1. u) in
  u *. u *. (3. -. (2. *. u))

(**
   [start ~drawn ~target] creates the animation.
   Requires: non-empty [drawn]
   Returns: animation at progress 0
   Raises: [Invalid_argument] on empty [drawn]
   Example: progress (start ~drawn ~target) = 0.
   Complexity: O(n) time, O(n) space
   Pseudocode:
     t1 <- procrustes drawn target, or identity when it returns None
     return { c0 = centroid drawn; t1; u = 0 }
*)
let start ~drawn ~target =
  let t1 = Option.value ~default:identity (procrustes drawn target) in
  { c0 = centroid drawn; t1; u = 0. }

(**
   [step t dt] advances the animation.
   Requires: [dt >= 0.]
   Returns: animation with [u = min 1 (u + dt / duration)]
   Raises: nothing
   Example: progress (step (start ~drawn ~target) 0.75) = 0.5
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return { t with u = min 1 (t.u + dt / duration) }
*)
let step t dt = { t with u = Float.min 1. (t.u +. (dt /. duration)) }

(**
   [progress t] is the raw progress.
   Requires: nothing
   Returns: [t.u]
   Raises: nothing
   Example: progress (start ~drawn ~target) = 0.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return t.u
*)
let progress t = t.u

(**
   [finished t] tells whether the animation is done.
   Requires: nothing
   Returns: [t.u >= 1.]
   Raises: nothing
   Example: finished (step (start ~drawn ~target) 10.) = true
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return t.u >= 1
*)
let finished t = t.u >= 1.

(**
   [current_sim t] is the blended transform.
   Requires: nothing
   Returns: identity at e = 0, T1 at e = 1
   Raises: nothing
   Example: current_sim (start ~drawn ~target) = Geom.identity
   Complexity: O(1) time, O(1) space
   Pseudocode:
     e <- ease t.u
     s <- t1.s ** e ; theta <- e * wrap_angle t1.theta
     c <- lerp c0 (apply t1 c0) e
     (* p -> c + s R (p - c0)  =  s R p + (c - s R c0) *)
     shift <- c - s * R(theta) * c0
     return { s; theta; tx = shift.x; ty = shift.y }
*)
let current_sim t =
  let e = ease t.u in
  let s = t.t1.s ** e and theta = e *. wrap_angle t.t1.theta in
  let c = lerp t.c0 (apply t.t1 t.c0) e in
  let rc = scale s (rotate theta t.c0) in
  { s; theta; tx = c.x -. rc.x; ty = c.y -. rc.y }

(**
   [current t pts] moves points by the blended transform.
   Requires: nothing
   Returns: fresh array of moved points
   Raises: nothing
   Example: current (start ~drawn ~target) pts = pts
   Complexity: O(n) time, O(n) space
   Pseudocode:
     return apply_all (current_sim t) pts
*)
let current t pts = apply_all (current_sim t) pts

(**
   [end_sim t] is the final transform.
   Requires: nothing
   Returns: [t.t1]
   Raises: nothing
   Example: end_sim (start ~drawn:p ~target:p) = Geom.identity (to rounding)
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return t.t1
*)
let end_sim t = t.t1
