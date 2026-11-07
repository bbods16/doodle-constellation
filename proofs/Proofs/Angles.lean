import Mathlib

/-!
# Angle wrapping (`Geom.wrap_angle`)

`Geom.wrap_angle` must return an angle in `(-π, π]` that points the same
way as its input, so that `Morph` always turns the short way round.

The OCaml code uses `Float.rem`; here the same function is defined with a
ceiling, `wrap a = a - 2π ⌈(a - π) / 2π⌉`, and three facts are proved:

* `wrap_mem`: the result lies in `(-π, π]`;
* `wrap_congr`: the result differs from the input by a whole number of
  turns;
* `wrap_unique`: any two angles in `(-π, π]` that differ by whole turns
  are equal.

Together these say that `wrap` is *the* representative of the input in
`(-π, π]`. The OCaml version also returns a value in that interval that
differs from the input by whole turns, so by `wrap_unique` it computes
the same angle (up to floating-point rounding, which Lean does not
model).
-/

open Real

namespace Doodle

/-- The representative of `a` in `(-π, π]`. -/
noncomputable def wrap (a : ℝ) : ℝ := a - 2 * π * ⌈(a - π) / (2 * π)⌉

theorem wrap_mem (a : ℝ) : -π < wrap a ∧ wrap a ≤ π := by
  have hpi : 0 < 2 * π := by positivity
  set t := (a - π) / (2 * π) with ht_def
  have ht : 2 * π * t = a - π := by rw [ht_def]; field_simp
  have h1 : 2 * π * t ≤ 2 * π * ⌈t⌉ := mul_le_mul_of_nonneg_left (Int.le_ceil t) hpi.le
  have h2 : 2 * π * (⌈t⌉ : ℝ) < 2 * π * (t + 1) :=
    mul_lt_mul_of_pos_left (Int.ceil_lt_add_one t) hpi
  unfold wrap
  rw [← ht_def]
  constructor <;> nlinarith

theorem wrap_congr (a : ℝ) : ∃ k : ℤ, wrap a = a + 2 * π * k :=
  ⟨-⌈(a - π) / (2 * π)⌉, by unfold wrap; push_cast; ring⟩

theorem wrap_unique {x y : ℝ} (hx : -π < x ∧ x ≤ π) (hy : -π < y ∧ y ≤ π) (k : ℤ)
    (h : x = y + 2 * π * k) : x = y := by
  have hpi : 0 < 2 * π := by positivity
  have hlt : (k : ℝ) < 1 := by
    have : 2 * π * (k : ℝ) < 2 * π * 1 := by linarith [hx.2, hy.1]
    exact lt_of_mul_lt_mul_left this hpi.le
  have hgt : (-1 : ℝ) < k := by
    have : 2 * π * (-1 : ℝ) < 2 * π * (k : ℝ) := by linarith [hx.1, hy.2]
    exact lt_of_mul_lt_mul_left this hpi.le
  have hk : k = 0 := by
    have a : k < 1 := by exact_mod_cast hlt
    have b : -1 < k := by exact_mod_cast hgt
    omega
  subst hk
  simpa using h

/-- Wrapping an angle that is already in `(-π, π]` changes nothing. -/
theorem wrap_of_mem {a : ℝ} (ha : -π < a ∧ a ≤ π) : wrap a = a := by
  obtain ⟨k, hk⟩ := wrap_congr a
  exact wrap_unique (wrap_mem a) ha k hk

end Doodle
