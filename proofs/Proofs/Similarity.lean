import Mathlib

/-!
# Similarity transforms (`Geom.sim`, `Geom.apply`, `Geom.sim_of_pair`)

The OCaml code stores a similarity as `{ s; theta; tx; ty }` and applies
`p ↦ s · R(θ) · p + t`. Identifying the point `(x, y)` with the complex
number `x + y i`, that map is exactly `z ↦ a z + b` with
`a = s · e^{iθ}` and `b = tx + ty i`. Every theorem here works in that
complex form, which turns rotation-and-scale into a single
multiplication.

Proved here:
* `polar_form`: the complex product `s e^{iθ} z` has the coordinates the
  OCaml `rotate`/`scale` code computes.
* `two_point_maps`, `two_point_unique`: `sim_of_pair` really maps
  `a ↦ a'`, `b ↦ b'`, and it is the only similarity that does.
* `dist_scale`, `dist_conj`: a similarity multiplies every distance by
  `‖a‖ = s`; a mirror (complex conjugation) keeps distances.
-/

open Complex ComplexConjugate

namespace Doodle

/-- A similarity of the plane in complex form: `z ↦ a z + b`. -/
def simApply (a b z : ℂ) : ℂ := a * z + b

/-- Multiplying by `s e^{iθ}` is "rotate by `θ`, then scale by `s`", with
exactly the coordinate formulas used by `Geom.rotate` and `Geom.apply`. -/
theorem polar_form (s θ x y : ℝ) :
    ((s : ℂ) * exp (θ * I) * ⟨x, y⟩).re = s * (Real.cos θ * x - Real.sin θ * y) ∧
    ((s : ℂ) * exp (θ * I) * ⟨x, y⟩).im = s * (Real.sin θ * x + Real.cos θ * y) := by
  constructor <;>
  simp [Complex.mul_re, Complex.mul_im, Complex.exp_ofReal_mul_I_re,
    Complex.exp_ofReal_mul_I_im] <;> ring

/-- `Geom.sim_of_pair`: with `a = (q' - p') / (q - p)` and `b = p' - a p`,
the similarity sends `p` to `p'` and `q` to `q'`. -/
theorem two_point_maps {p q p' q' : ℂ} (h : p ≠ q) :
    simApply ((q' - p') / (q - p)) (p' - (q' - p') / (q - p) * p) p = p' ∧
    simApply ((q' - p') / (q - p)) (p' - (q' - p') / (q - p) * p) q = q' := by
  have hqp : q - p ≠ 0 := sub_ne_zero.mpr (Ne.symm h)
  refine ⟨by simp [simApply], ?_⟩
  unfold simApply
  have : (q' - p') / (q - p) * q + (p' - (q' - p') / (q - p) * p)
      = (q' - p') / (q - p) * (q - p) + p' := by ring
  rw [this, div_mul_cancel₀ _ hqp]
  ring

/-- Uniqueness: any similarity that sends `p ↦ p'` and `q ↦ q'` (with
`p ≠ q`) has exactly the coefficients `sim_of_pair` computes. So the
two-handle rule loses no generality. -/
theorem two_point_unique {a b p q p' q' : ℂ} (h : p ≠ q)
    (hp : simApply a b p = p') (hq : simApply a b q = q') :
    a = (q' - p') / (q - p) ∧ b = p' - a * p := by
  have hqp : q - p ≠ 0 := sub_ne_zero.mpr (Ne.symm h)
  unfold simApply at hp hq
  constructor
  · rw [eq_div_iff hqp, ← hp, ← hq]; ring
  · rw [← hp]; ring

/-- A similarity multiplies every distance by `‖a‖` (the scale `s`). -/
theorem dist_scale (a b z w : ℂ) :
    ‖simApply a b z - simApply a b w‖ = ‖a‖ * ‖z - w‖ := by
  unfold simApply
  rw [show a * z + b - (a * w + b) = a * (z - w) by ring, norm_mul]

/-- A mirror image (complex conjugation, `y ↦ -y`, i.e. `Geom.mirror_y`)
keeps every distance. -/
theorem dist_conj (z w : ℂ) : ‖conj z - conj w‖ = ‖z - w‖ := by
  rw [← map_sub, Complex.norm_conj]

end Doodle
