import Proofs.Angles

/-!
# Easing and the morph animation (`Morph.ease`, `Morph.current_sim`)

`Morph` blends the identity transform into the final fit `T₁` over time.
At eased progress `e` it uses scale `s₁^e`, angle `e · wrap θ₁`, and moves
the drawing's centroid `c₀` in a straight line towards `T₁ c₀`.

Proved here:
* `ease_zero`, `ease_one`, `ease_half`, `ease_mem`, `ease_mono`: the
  smoothstep curve starts at 0, ends at 1, stays in `[0, 1]` and never
  goes backwards, so the animation never overshoots.
* `ease_hasDerivAt`, `ease_flat_ends`: its slope is `6u(1-u)`, zero at
  both ends, so the motion starts and stops gently.
* `morph_start`, `morph_end`: the blended map is the identity at `e = 0`
  and exactly `T₁` at `e = 1`, even though the code blends the *wrapped*
  angle (`exp_wrap`).
-/

open Complex Real

namespace Doodle

/-- Smoothstep. -/
def ease (u : ℝ) : ℝ := u ^ 2 * (3 - 2 * u)

theorem ease_zero : ease 0 = 0 := by norm_num [ease]
theorem ease_one : ease 1 = 1 := by norm_num [ease]
theorem ease_half : ease (1 / 2) = 1 / 2 := by norm_num [ease]

theorem ease_mem {u : ℝ} (h0 : 0 ≤ u) (h1 : u ≤ 1) : 0 ≤ ease u ∧ ease u ≤ 1 := by
  unfold ease
  constructor
  · exact mul_nonneg (sq_nonneg u) (by linarith)
  · have e : 1 - u ^ 2 * (3 - 2 * u) = (1 - u) ^ 2 * (1 + 2 * u) := by ring
    have : 0 ≤ (1 - u) ^ 2 * (1 + 2 * u) := mul_nonneg (sq_nonneg _) (by linarith)
    linarith

theorem ease_mono {u v : ℝ} (hu : 0 ≤ u) (huv : u ≤ v) (hv : v ≤ 1) : ease u ≤ ease v := by
  unfold ease
  have e : v ^ 2 * (3 - 2 * v) - u ^ 2 * (3 - 2 * u)
      = (v - u) * (u * (3 - 2 * u - v) + v * (3 - 2 * v - u)) := by ring
  have f : 0 ≤ u * (3 - 2 * u - v) + v * (3 - 2 * v - u) := by
    have : 0 ≤ u * (3 - 2 * u - v) := mul_nonneg hu (by linarith)
    have : 0 ≤ v * (3 - 2 * v - u) := mul_nonneg (by linarith) (by linarith)
    linarith
  nlinarith [mul_nonneg (sub_nonneg.mpr huv) f]

theorem ease_hasDerivAt (u : ℝ) : HasDerivAt ease (6 * u * (1 - u)) u := by
  have h := ((hasDerivAt_pow 2 u).const_mul 3).sub ((hasDerivAt_pow 3 u).const_mul 2)
  have hf : ease = fun x => 3 * x ^ 2 - 2 * x ^ 3 := by funext x; unfold ease; ring
  rw [hf]
  convert h using 1
  norm_num
  ring

/-- The animation starts and stops with zero speed. -/
theorem ease_flat_ends : HasDerivAt ease 0 0 ∧ HasDerivAt ease 0 1 := by
  constructor
  · simpa using ease_hasDerivAt 0
  · simpa using ease_hasDerivAt 1

/-- The wrapped angle turns the plane exactly as the original angle does. -/
theorem exp_wrap (θ : ℝ) : exp ((wrap θ : ℂ) * I) = exp ((θ : ℂ) * I) := by
  obtain ⟨k, hk⟩ := wrap_congr θ
  rw [hk]
  push_cast
  rw [show ((θ : ℂ) + 2 * π * k) * I = θ * I + (k : ℂ) * (2 * π * I) by ring, Complex.exp_add,
    Complex.exp_int_mul_two_pi_mul_I, mul_one]

/-- The blended map at eased progress `e`, in complex form:
`z ↦ c(e) + s^e e^{i e wrap θ} (z - c₀)` with
`c(e) = c₀ + e (T₁ c₀ - c₀)` and `T₁ z = s e^{iθ} z + b`. -/
noncomputable def morphMap (s θ : ℝ) (b c0 : ℂ) (e : ℝ) (z : ℂ) : ℂ :=
  (c0 + (e : ℂ) * (((s : ℂ) * exp ((θ : ℂ) * I) * c0 + b) - c0))
    + ((s ^ e : ℝ) : ℂ) * exp (((e * wrap θ : ℝ) : ℂ) * I) * (z - c0)

theorem morph_start (s θ : ℝ) (b c0 z : ℂ) : morphMap s θ b c0 0 z = z := by
  simp [morphMap]

theorem morph_end (s θ : ℝ) (b c0 z : ℂ) :
    morphMap s θ b c0 1 z = (s : ℂ) * exp ((θ : ℂ) * I) * z + b := by
  simp only [morphMap, Real.rpow_one, one_mul, ofReal_one]
  rw [exp_wrap]
  ring

end Doodle
