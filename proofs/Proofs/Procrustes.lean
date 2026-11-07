import Proofs.Similarity

/-!
# Procrustes gives the best similarity (`Geom.procrustes`)

`Geom.procrustes p q` returns, in closed form, the similarity that best
maps the points `p i` onto `q i` in the least-squares sense. In complex
form the cost of `z ↦ a z + b` is `∑ ‖a pᵢ + b - qᵢ‖²`, and the code's
recipe is

* centre both sets on their means,
* `a = A / S` where `A = ∑ conj(p'ᵢ) q'ᵢ` and `S = ∑ ‖p'ᵢ‖²`,
* `b = c_q - a c_p`.

Proved here:
* `conj_mul_coords`: `conj(p) q` has real part `px qx + py qy` and
  imaginary part `px qy - py qx`, the code's sums `a` and `b`; so
  `θ = atan2 b a` is the argument and `s = √(a²+b²)/S` the modulus of
  `A / S` (`code_scale`, `code_angle`).
* `cost_expand`: for centred data, the cost splits into a part that
  depends only on `a`, a part `n ‖b‖²`, and a constant.
* `procrustes_centered_optimal`: for centred data `a = A / S, b = 0` is a
  global minimiser.
* `cost_shift` and `procrustes_optimal`: for any data, `a = A / S` with
  `b = c_q - a c_p` is a global minimiser.
-/

open Complex ComplexConjugate

namespace Doodle

variable {n : ℕ}

/-- Least-squares cost of `z ↦ a z + b` as a fit from `p` to `q`. -/
noncomputable def cost (p q : Fin n → ℂ) (a b : ℂ) : ℝ :=
  ∑ i, normSq (a * p i + b - q i)

/-- The code's two Procrustes sums are the real and imaginary parts of
`conj(p) q`. -/
theorem conj_mul_coords (px py qx qy : ℝ) :
    (conj (⟨px, py⟩ : ℂ) * ⟨qx, qy⟩).re = px * qx + py * qy ∧
    (conj (⟨px, py⟩ : ℂ) * ⟨qx, qy⟩).im = px * qy - py * qx := by
  constructor <;> simp [Complex.mul_re, Complex.mul_im] <;> ring

/-- The code's scale `s = √(a² + b²) / S` is the modulus of `A / S`. -/
theorem code_scale (A : ℂ) {S : ℝ} (hS : 0 < S) : ‖A / (S : ℂ)‖ = ‖A‖ / S := by
  rw [norm_div, Complex.norm_real, Real.norm_of_nonneg hS.le]

/-- The code's angle `θ = atan2 b a` is the argument of `A / S` (dividing
by a positive real does not turn the vector). -/
theorem code_angle (A : ℂ) {S : ℝ} (hS : 0 < S) : arg (A / (S : ℂ)) = arg A := by
  rw [div_eq_inv_mul, ← ofReal_inv, arg_real_mul A (inv_pos.mpr hS)]

/-- Pointwise expansion of one residual. -/
lemma normSq_residual (a b p q : ℂ) :
    normSq (a * p + b - q) = normSq a * normSq p + normSq b + normSq q
      - 2 * (conj a * (conj p * q)).re + 2 * (a * p * conj b).re
      - 2 * (b * conj q).re := by
  simp only [normSq_apply, mul_re, mul_im, add_re, add_im, sub_re, sub_im, conj_re, conj_im]
  ring

/-- For centred data the cross terms with `b` vanish, so the cost splits. -/
theorem cost_expand (p q : Fin n → ℂ) (a b : ℂ) (hp : ∑ i, p i = 0) (hq : ∑ i, q i = 0) :
    cost p q a b = normSq a * (∑ i, normSq (p i)) + n * normSq b + ∑ i, normSq (q i)
      - 2 * (conj a * ∑ i, conj (p i) * q i).re := by
  unfold cost
  simp only [normSq_residual]
  have h1 : ∑ i, (a * p i * conj b).re = 0 := by
    rw [← Complex.re_sum, ← Finset.sum_mul, ← Finset.mul_sum, hp]; simp
  have h2 : ∑ i, (b * conj (q i)).re = 0 := by
    rw [← Complex.re_sum, ← Finset.mul_sum, ← map_sum, hq]; simp
  have h3 : ∑ i, (conj a * (conj (p i) * q i)).re = (conj a * ∑ i, conj (p i) * q i).re := by
    rw [← Complex.re_sum, Finset.mul_sum]
  simp only [Finset.sum_add_distrib, Finset.sum_sub_distrib, ← Finset.mul_sum,
    Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  rw [h1, h2, h3]
  ring

/-- **Optimality, centred case.** If both point sets have mean zero and
`p` is not collapsed to a point, then `a = A / S`, `b = 0` has the
smallest cost of all similarities. The proof completes the square:
`cost a b - cost (A/S) 0 = S ‖a - A/S‖² + n ‖b‖² ≥ 0`. -/
theorem procrustes_centered_optimal (p q : Fin n → ℂ) (hp : ∑ i, p i = 0)
    (hq : ∑ i, q i = 0) (hS : 0 < ∑ i, normSq (p i)) (a b : ℂ) :
    cost p q ((∑ i, conj (p i) * q i) / ((∑ i, normSq (p i) : ℝ) : ℂ)) 0 ≤ cost p q a b := by
  rw [cost_expand p q _ _ hp hq, cost_expand p q a b hp hq]
  set S := ∑ i, normSq (p i)
  set A := ∑ i, conj (p i) * q i
  set a0 := A / (S : ℂ)
  have hS0 : (S : ℂ) ≠ 0 := ofReal_ne_zero.mpr hS.ne'
  have hA : A = (S : ℂ) * a0 := by simp only [a0]; field_simp
  rw [hA]
  have e : normSq a * S - 2 * (conj a * ((S : ℂ) * a0)).re
      - (normSq a0 * S - 2 * (conj a0 * ((S : ℂ) * a0)).re) = S * normSq (a - a0) := by
    simp only [normSq_apply, mul_re, mul_im, sub_re, sub_im, conj_re, conj_im, ofReal_re,
      ofReal_im]
    ring
  have h1 : 0 ≤ S * normSq (a - a0) := mul_nonneg hS.le (normSq_nonneg _)
  have h2 : 0 ≤ (n : ℝ) * normSq b := mul_nonneg (Nat.cast_nonneg n) (normSq_nonneg _)
  simp only [map_zero, mul_zero, add_zero]
  linarith

/-- Moving both point sets (and compensating in `b`) does not change the
cost. This is why the code may centre first. -/
theorem cost_shift (p q : Fin n → ℂ) (a b cp cq : ℂ) :
    cost p q a b = cost (fun i => p i - cp) (fun i => q i - cq) a (b + a * cp - cq) := by
  unfold cost
  refine Finset.sum_congr rfl fun i _ => ?_
  congr 1
  ring

/-- Subtracting the mean leaves points that sum to zero. -/
lemma sum_sub_mean (p : Fin n → ℂ) (hn : n ≠ 0) : ∑ i, (p i - (∑ j, p j) / n) = 0 := by
  have hn' : (n : ℂ) ≠ 0 := Nat.cast_ne_zero.mpr hn
  rw [Finset.sum_sub_distrib, Finset.sum_const, Finset.card_univ, Fintype.card_fin,
    nsmul_eq_mul, mul_div_cancel₀ _ hn', sub_self]

/-- **Optimality, general case** (`Geom.procrustes`): centre on the means
`c_p`, `c_q`, take `a = A / S` from the centred points, and
`b = c_q - a c_p`. No similarity has a smaller least-squares cost. -/
theorem procrustes_optimal (p q : Fin n → ℂ) (hn : n ≠ 0)
    (hS : 0 < ∑ i, normSq (p i - (∑ j, p j) / n)) (a b : ℂ) :
    let cp := (∑ j, p j) / n
    let cq := (∑ j, q j) / n
    let a0 := (∑ i, conj (p i - cp) * (q i - cq)) / ((∑ i, normSq (p i - cp) : ℝ) : ℂ)
    cost p q a0 (cq - a0 * cp) ≤ cost p q a b := by
  intro cp cq a0
  rw [cost_shift p q a0 _ cp cq, cost_shift p q a b cp cq,
    show cq - a0 * cp + a0 * cp - cq = 0 by ring]
  exact procrustes_centered_optimal _ _ (sum_sub_mean p hn) (sum_sub_mean q hn) hS _ _

end Doodle
