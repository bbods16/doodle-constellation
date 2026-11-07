import Mathlib

/-!
# The engine's probabilities (`Engine.softmax`, `Engine.classify`)

`Engine.softmax` subtracts the largest score before exponentiating, to
avoid overflow, and `Engine.classify` reports the results as
probabilities.

Proved here:
* `softmax_pos`, `softmax_sum`: every class gets a positive probability
  and the probabilities add up to 1.
* `softmax_shift`: subtracting the same number (the maximum) from every
  score does not change the answer, so the overflow guard is exact.
* `softmax_mono`: a larger score never gets a smaller probability, so
  sorting by probability is the same as sorting by score.
-/

open Real

namespace Doodle

variable {n : ℕ}

noncomputable def softmax (z : Fin n → ℝ) (i : Fin n) : ℝ := exp (z i) / ∑ j, exp (z j)

lemma denom_pos [NeZero n] (z : Fin n → ℝ) : 0 < ∑ j, exp (z j) :=
  Finset.sum_pos (fun j _ => exp_pos (z j)) Finset.univ_nonempty

theorem softmax_pos [NeZero n] (z : Fin n → ℝ) (i : Fin n) : 0 < softmax z i :=
  div_pos (exp_pos _) (denom_pos z)

theorem softmax_sum [NeZero n] (z : Fin n → ℝ) : ∑ i, softmax z i = 1 := by
  unfold softmax
  rw [← Finset.sum_div, div_self (denom_pos z).ne']

theorem softmax_shift (z : Fin n → ℝ) (m : ℝ) (i : Fin n) :
    softmax (fun j => z j - m) i = softmax z i := by
  unfold softmax
  simp only [Real.exp_sub, ← Finset.sum_div]
  rw [div_div_div_cancel_right₀ (exp_pos m).ne']

theorem softmax_mono [NeZero n] (z : Fin n → ℝ) {i j : Fin n} (h : z i ≤ z j) :
    softmax z i ≤ softmax z j := by
  unfold softmax
  exact div_le_div_of_nonneg_right (exp_le_exp.mpr h) (denom_pos z).le

end Doodle
