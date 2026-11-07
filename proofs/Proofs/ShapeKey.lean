import Proofs.Similarity

/-!
# Shape keys ignore position, size, rotation and reflection (`Index.key`)

`Index.key a b c` sorts the three side lengths `ls ≤ lm ≤ ll` and bins
`(ls / ll, lm / ll, angle opposite ll)`, where the angle comes from the
law of cosines `cos C = (ls² + lm² - ll²) / (2 ls lm)`. The matcher only
works if a drawn triangle and the same star triangle, moved, turned,
resized or mirrored, land in the same bin.

Proved here:
* `side_scale`: under `z ↦ a z + b` every side becomes `‖a‖` times longer.
* `order_preserved`: multiplying by `k > 0` keeps the sort order, so the
  same vertices are called short, middle and long.
* `features_scale`: the three key features are unchanged when all sides
  are multiplied by the same `k ≠ 0`.
* `features_similarity`, `features_mirror`: putting these together, the
  features (hence the bins) of a similar or mirrored triangle are equal.
-/

open Complex ComplexConjugate

namespace Doodle

/-- Law-of-cosines expression for the angle opposite side `l3`. -/
noncomputable def lawCos (l1 l2 l3 : ℝ) : ℝ := (l1 ^ 2 + l2 ^ 2 - l3 ^ 2) / (2 * l1 * l2)

/-- The real numbers `Index.key` bins: short/long, middle/long, cos of the
angle opposite the long side. -/
noncomputable def features (ls lm ll : ℝ) : ℝ × ℝ × ℝ := (ls / ll, lm / ll, lawCos ls lm ll)

/-- Every side of the image triangle is `‖a‖` times the original side. -/
theorem side_scale (a b z w : ℂ) :
    ‖simApply a b z - simApply a b w‖ = ‖a‖ * ‖z - w‖ := dist_scale a b z w

/-- Scaling by a positive factor does not change which side is shorter, so
the canonical vertex order (and the permutation `Index.key` returns) is
the same for the image triangle. -/
theorem order_preserved {k x y : ℝ} (hk : 0 < k) : k * x ≤ k * y ↔ x ≤ y := by
  constructor
  · intro h; nlinarith
  · intro h; nlinarith

/-- The law-of-cosines expression does not depend on the overall size. -/
theorem lawCos_scale (k l1 l2 l3 : ℝ) (hk : k ≠ 0) :
    lawCos (k * l1) (k * l2) (k * l3) = lawCos l1 l2 l3 := by
  unfold lawCos
  rw [show (k * l1) ^ 2 + (k * l2) ^ 2 - (k * l3) ^ 2 = k ^ 2 * (l1 ^ 2 + l2 ^ 2 - l3 ^ 2) by ring,
    show 2 * (k * l1) * (k * l2) = k ^ 2 * (2 * l1 * l2) by ring,
    mul_div_mul_left _ _ (pow_ne_zero 2 hk)]

/-- All three key features are scale-invariant. -/
theorem features_scale (k ls lm ll : ℝ) (hk : k ≠ 0) :
    features (k * ls) (k * lm) (k * ll) = features ls lm ll := by
  unfold features
  rw [mul_div_mul_left _ _ hk, mul_div_mul_left _ _ hk, lawCos_scale k ls lm ll hk]

/-- The key of a triangle equals the key of its image under any similarity
`z ↦ a z + b` with `a ≠ 0`: drawn shapes and star shapes meet in the same
bin no matter where, how large, or at what angle the user draws. -/
theorem features_similarity (a b z0 z1 z2 : ℂ) (ha : a ≠ 0) :
    features ‖simApply a b z1 - simApply a b z2‖ ‖simApply a b z0 - simApply a b z2‖
        ‖simApply a b z0 - simApply a b z1‖ =
      features ‖z1 - z2‖ ‖z0 - z2‖ ‖z0 - z1‖ := by
  rw [side_scale, side_scale, side_scale]
  exact features_scale _ _ _ _ (norm_ne_zero_iff.mpr ha)

/-- Mirror images share the key, which is why `Fitter` may try the
reflected drawing against the very same index hits. -/
theorem features_mirror (z0 z1 z2 : ℂ) :
    features ‖conj z1 - conj z2‖ ‖conj z0 - conj z2‖ ‖conj z0 - conj z1‖ =
      features ‖z1 - z2‖ ‖z0 - z2‖ ‖z0 - z1‖ := by
  rw [dist_conj, dist_conj, dist_conj]

end Doodle
