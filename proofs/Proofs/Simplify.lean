import Mathlib

/-!
# The square-root-free distance test in `Simplify.rdp`

For a chord from `a` with direction `d = (dx, dy)` and a point `p`, the
code compares `|dx (a.y - p.y) - dy (a.x - p.x)|` with `eps · |d|` instead
of computing the perpendicular distance and comparing it with `eps`.

Writing `u = a - p`, the test value is the 2-D cross product `d × u`.

Proved here:
* `lagrange`: `(d × u)² + (d · u)² = |d|² |u|²`.
* `perp_dist_sq`: hence `(d × u)² / |d|² = |u|² - ((d · u) / |d|)²`, which
  by Pythagoras is the squared perpendicular distance from `p` to the
  chord's line: the cross product is "distance times chord length".
* `rdp_test_equiv`: comparing `cross > eps · L` is the same as comparing
  `cross / L > eps` when `L > 0`, so the cheap test keeps exactly the
  points the textbook test keeps.
-/

namespace Doodle

theorem lagrange (dx dy ux uy : ℝ) :
    (dx * uy - dy * ux) ^ 2 + (dx * ux + dy * uy) ^ 2 = (dx ^ 2 + dy ^ 2) * (ux ^ 2 + uy ^ 2) := by
  ring

theorem perp_dist_sq (dx dy ux uy : ℝ) (hd : dx ^ 2 + dy ^ 2 ≠ 0) :
    (dx * uy - dy * ux) ^ 2 / (dx ^ 2 + dy ^ 2)
      = (ux ^ 2 + uy ^ 2) - (dx * ux + dy * uy) ^ 2 / (dx ^ 2 + dy ^ 2) := by
  rw [eq_sub_iff_add_eq, ← add_div, lagrange, mul_div_cancel_left₀ _ hd]

theorem rdp_test_equiv {cross eps L : ℝ} (hL : 0 < L) : eps * L < cross ↔ eps < cross / L :=
  (lt_div_iff₀ hL).symm

end Doodle
