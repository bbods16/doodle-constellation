import Mathlib

/-!
# Discrete facts: triangles, bins, neighbourhoods, snapping, smoothing

Small properties the OCaml code relies on.

* `triangles_card`, `triangles_nine` (`Candidates.triangles`): there are
  `n choose 3` triangles of `n` corners, 84 for the maximum of 9 corners,
  which bounds the candidate generator's work.
* `clampBin_mem` (`Index.bin`): a clamped bin index is always valid, so
  hash keys never fall outside the table's ranges.
* `neighbours_card_le`, `self_mem_neighbours` (`Index.neighbours`): a key
  has at most 27 neighbours, and a valid key is its own neighbour, so
  `find_near` always includes the exact bin.
* `snap_nodup` (`Fitter.snap`): if each pick avoids the stars already
  used, the result never uses a star twice.
* `weighted_mean_le` (`Capture.add`): a weighted mean with non-negative
  weights is at most the largest value, so smoothing never moves the
  stroke outside its bounding box.
-/

namespace Doodle

theorem triangles_card (n : ℕ) : (Finset.powersetCard 3 (Finset.range n)).card = n.choose 3 := by
  simp [Finset.card_powersetCard]

theorem triangles_nine : Nat.choose 9 3 = 84 := by decide

/-- `Index.bin` after clamping: `max 0 (min (n - 1) v)`. -/
def clampBin (n v : ℤ) : ℤ := max 0 (min (n - 1) v)

theorem clampBin_mem {n : ℤ} (hn : 1 ≤ n) (v : ℤ) : 0 ≤ clampBin n v ∧ clampBin n v ≤ n - 1 := by
  unfold clampBin; omega

theorem clampBin_of_mem {n v : ℤ} (h0 : 0 ≤ v) (h1 : v ≤ n - 1) : clampBin n v = v := by
  unfold clampBin; omega

/-- The offsets `-1, 0, 1`. -/
def offsets : Finset ℤ := {-1, 0, 1}

/-- `Index.neighbours` with bin counts `r1`, `r2`, `ra`. -/
def neighbours (r1 r2 ra : ℤ) (k : ℤ × ℤ × ℤ) : Finset (ℤ × ℤ × ℤ) :=
  (offsets ×ˢ offsets ×ˢ offsets).image fun d =>
    (clampBin r1 (k.1 + d.1), clampBin r2 (k.2.1 + d.2.1), clampBin ra (k.2.2 + d.2.2))

theorem neighbours_card_le (r1 r2 ra : ℤ) (k : ℤ × ℤ × ℤ) : (neighbours r1 r2 ra k).card ≤ 27 :=
  Finset.card_image_le.trans (by decide)

theorem self_mem_neighbours {r1 r2 ra : ℤ} {k : ℤ × ℤ × ℤ}
    (h1 : 0 ≤ k.1 ∧ k.1 ≤ r1 - 1) (h2 : 0 ≤ k.2.1 ∧ k.2.1 ≤ r2 - 1)
    (h3 : 0 ≤ k.2.2 ∧ k.2.2 ≤ ra - 1) : k ∈ neighbours r1 r2 ra k := by
  unfold neighbours
  refine Finset.mem_image.mpr ⟨(0, 0, 0), by simp [offsets], ?_⟩
  simp only [add_zero, clampBin_of_mem h1.1 h1.2, clampBin_of_mem h2.1 h2.2,
    clampBin_of_mem h3.1 h3.2]

/-- `Fitter.snap` as a greedy pass: each corner asks `pick` for a star,
given the stars used so far. -/
def snapAux {α : Type*} (pick : List ℕ → α → Option ℕ) : List ℕ → List α → Option (List ℕ)
  | _, [] => some []
  | used, c :: cs =>
    match pick used c with
    | none => none
    | some s => (snapAux pick (s :: used) cs).map (s :: ·)

theorem snap_nodup {α : Type*} (pick : List ℕ → α → Option ℕ)
    (hpick : ∀ used c s, pick used c = some s → s ∉ used) :
    ∀ (cs : List α) (used r : List ℕ), snapAux pick used cs = some r →
      r.Nodup ∧ ∀ x ∈ r, x ∉ used := by
  intro cs
  induction cs with
  | nil =>
    intro used r h
    simp only [snapAux, Option.some.injEq] at h
    subst h
    simp
  | cons c cs ih =>
    intro used r h
    simp only [snapAux] at h
    split at h
    · simp at h
    · rename_i s hs
      obtain ⟨r', hr', rfl⟩ := Option.map_eq_some_iff.mp h
      obtain ⟨hnd, hout⟩ := ih (s :: used) r' hr'
      have hs_used : s ∉ used := hpick used c s hs
      refine ⟨List.nodup_cons.mpr ⟨fun hm => hout s hm (List.mem_cons_self), hnd⟩, ?_⟩
      intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hs_used
      · exact fun hu => hout x hx (List.mem_cons_of_mem s hu)

/-- Smoothing stays inside the bounding box (one coordinate at a time). -/
theorem weighted_mean_le {ι : Type*} (s : Finset ι) (w x : ι → ℝ) (M : ℝ)
    (hw : ∀ i ∈ s, 0 ≤ w i) (hx : ∀ i ∈ s, x i ≤ M) (hpos : 0 < ∑ i ∈ s, w i) :
    (∑ i ∈ s, w i * x i) / ∑ i ∈ s, w i ≤ M := by
  rw [div_le_iff₀ hpos, Finset.mul_sum]
  exact Finset.sum_le_sum fun i hi => by
    rw [mul_comm M]; exact mul_le_mul_of_nonneg_left (hx i hi) (hw i hi)

end Doodle
