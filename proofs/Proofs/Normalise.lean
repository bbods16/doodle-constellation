import Mathlib

/-!
# Stroke normalisation for the engine (`Engine.normalise`)

Before the transformer sees a stroke, `Engine.normalise` subtracts the
centroid and divides by the root-mean-square radius. In complex form,
with points `z : Fin n → ℂ`:

* `mean z = (∑ zᵢ) / n`,
* `rms z = √((∑ ‖zᵢ - mean z‖²) / n)`,
* `normalise z i = (zᵢ - mean z) / rms z`.

Proved here:
* `normalise_equivariant`: moving, scaling and rotating the drawing by
  `z ↦ a z + b` (`a ≠ 0`) only rotates the normalised points by the unit
  number `a / ‖a‖`. Position and size are gone; rotation remains, which
  is why the training data is augmented with random rotations.
* `normalise_invariant`: for a positive real scale (no rotation) the
  normalised stroke is *identical*, so the engine's answer cannot depend
  on where or how large the user draws.
-/

open Complex

namespace Doodle

variable {n : ℕ}

noncomputable def mean (z : Fin n → ℂ) : ℂ := (∑ i, z i) / n

noncomputable def rms (z : Fin n → ℂ) : ℝ := Real.sqrt ((∑ i, normSq (z i - mean z)) / n)

noncomputable def normalise (z : Fin n → ℂ) (i : Fin n) : ℂ := (z i - mean z) / (rms z : ℂ)

lemma mean_affine (z : Fin n → ℂ) (a b : ℂ) (hn : n ≠ 0) :
    mean (fun i => a * z i + b) = a * mean z + b := by
  have hn' : (n : ℂ) ≠ 0 := Nat.cast_ne_zero.mpr hn
  unfold mean
  rw [Finset.sum_add_distrib, ← Finset.mul_sum, Finset.sum_const, Finset.card_univ,
    Fintype.card_fin, nsmul_eq_mul]
  field_simp

lemma rms_affine (z : Fin n → ℂ) (a b : ℂ) (hn : n ≠ 0) :
    rms (fun i => a * z i + b) = ‖a‖ * rms z := by
  unfold rms
  rw [mean_affine z a b hn]
  have : ∀ i, normSq (a * z i + b - (a * mean z + b)) = normSq a * normSq (z i - mean z) := by
    intro i
    rw [show a * z i + b - (a * mean z + b) = a * (z i - mean z) by ring, map_mul]
  simp only [this, ← Finset.mul_sum, mul_div_assoc]
  rw [Real.sqrt_mul (normSq_nonneg a), Complex.normSq_eq_norm_sq, Real.sqrt_sq (norm_nonneg a)]

theorem normalise_equivariant (z : Fin n → ℂ) (a b : ℂ) (hn : n ≠ 0) (ha : a ≠ 0)
    (hr : rms z ≠ 0) (i : Fin n) :
    normalise (fun j => a * z j + b) i = (a / (‖a‖ : ℂ)) * normalise z i := by
  have hna : (‖a‖ : ℂ) ≠ 0 := ofReal_ne_zero.mpr (norm_ne_zero_iff.mpr ha)
  have hr' : (rms z : ℂ) ≠ 0 := ofReal_ne_zero.mpr hr
  unfold normalise
  rw [rms_affine z a b hn, mean_affine z a b hn]
  push_cast
  rw [show a * z i + b - (a * mean z + b) = a * (z i - mean z) by ring]
  field_simp

theorem normalise_invariant (z : Fin n → ℂ) (k : ℝ) (b : ℂ) (hn : n ≠ 0) (hk : 0 < k)
    (hr : rms z ≠ 0) (i : Fin n) :
    normalise (fun j => (k : ℂ) * z j + b) i = normalise z i := by
  rw [normalise_equivariant z (k : ℂ) b hn (ofReal_ne_zero.mpr hk.ne') hr i]
  have : ((‖(k : ℂ)‖ : ℝ) : ℂ) = k := by
    rw [Complex.norm_real, Real.norm_of_nonneg hk.le]
  rw [this, div_self (ofReal_ne_zero.mpr hk.ne'), one_mul]

end Doodle
