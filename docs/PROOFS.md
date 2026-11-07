# Proofs behind Doodle Constellation

This document explains, in plain paragraphs, every fact the program relies
on that has been proved formally. Each section names the OCaml code it
supports and the Lean theorem that checks it. The Lean sources live in
[`proofs/Proofs/`](../proofs/Proofs); `cd proofs && lake build` re-checks
all of them against Mathlib. None of them uses `sorry`.

**What is and is not proved.** Lean reasons about exact real and complex
numbers. The OCaml code uses 64-bit floats, so these proofs show that the
*algorithms* are right (the formulas compute what they claim, the method
finds the true optimum, the invariances hold). They do not bound rounding
error, and they do not prove the OCaml source line by line. Where the code
and the mathematics are written differently (for example `wrap_angle`
uses `Float.rem` while Lean uses a ceiling), the section explains why the
two agree.

**One idea used throughout.** A point `(x, y)` is identified with the
complex number `x + y·i`. Then the program's similarity transform
"rotate by θ, scale by s, shift by (tx, ty)" is the single complex
formula `z ↦ a·z + b` with `a = s·e^{iθ}` and `b = tx + ty·i`. Rotation
and scaling become one multiplication, which makes most proofs short
algebra.

---

## 1. Similarity transforms — `Proofs/Similarity.lean`

Supports `Geom.rotate`, `Geom.apply`, `Geom.sim_of_pair`, `Geom.mirror_y`.

**The complex form matches the code (`polar_form`).** Multiplying
`x + y·i` by `s·e^{iθ}` gives real part `s(cos θ·x − sin θ·y)` and
imaginary part `s(sin θ·x + cos θ·y)`. These are exactly the expressions
`Geom.rotate` followed by scaling computes. The proof expands the complex
product with Euler's formula (`e^{iθ} = cos θ + i sin θ`) and collects
terms. This lemma is what justifies every later proof done in complex
form.

**The two-handle rule works (`two_point_maps`).** `Geom.sim_of_pair`
takes two points `p, q` and their desired images `p', q'` and sets
`a = (q' − p')/(q − p)`, `b = p' − a·p`. Then `a·p + b = p'` holds
immediately. For `q`, `a·q + b = a(q − p) + p'`, and since
`a(q − p) = q' − p'` (we divide and multiply by the same non-zero number
`q − p`), this equals `q'`. The only requirement is `p ≠ q`, which is
also the condition under which the OCaml function refuses to run.

**It is the only such transform (`two_point_unique`).** Suppose some
`z ↦ a·z + b` sends `p ↦ p'` and `q ↦ q'`. Subtracting the two equations
cancels `b` and leaves `a(q − p) = q' − p'`, so `a` is forced. Then `b`
is forced by the first equation. So the candidate generator, which
seeds every guess with this rule, never misses a transform that fits the
two longest-side corners.

**Distances scale by `s`; mirrors keep them (`dist_scale`, `dist_conj`).**
The difference of two images is `(a·z + b) − (a·w + b) = a(z − w)`, and
the length of a product is the product of lengths, so every distance is
multiplied by `‖a‖ = s`. Reflecting through the x axis is complex
conjugation, and conjugation preserves length. Both facts feed the next
section.

## 2. Shape keys — `Proofs/ShapeKey.lean`

Supports `Index.key` and the reflection pass in `Fitter.best`.

The index files each star triangle under a key built from its three side
lengths sorted `ls ≤ lm ≤ ll`: the ratios `ls/ll`, `lm/ll`, and the angle
opposite the longest side, from the law of cosines
`cos C = (ls² + lm² − ll²)/(2·ls·lm)`. Matching only works if a drawn
triangle and the same star triangle, moved, turned, resized or mirrored,
produce the same key.

**Sides scale together (`side_scale`).** From Section 1, a similarity
multiplies all three sides by the same factor `k = s`.

**The sort order survives (`order_preserved`).** For `k > 0`,
`k·x ≤ k·y` exactly when `x ≤ y`. So the same vertices are called
short, middle and long before and after the transform, and `Index.key`
returns the same vertex permutation. That matters because the candidate
generator pairs vertices by that permutation.

**The features ignore size (`lawCos_scale`, `features_scale`).** A ratio
`(k·x)/(k·y)` cancels `k`. In the cosine formula the numerator becomes
`k²(ls² + lm² − ll²)` and the denominator `k²(2·ls·lm)`, so `k²` cancels
too. No case split is needed: the proof factors `k²` out of both and uses
"multiplying top and bottom by a non-zero number changes nothing".

**Conclusion (`features_similarity`, `features_mirror`).** For any
similarity with `a ≠ 0`, the features of the image triangle equal those
of the original, so both land in the same bin. The same holds for a
mirror image, because conjugation preserves all three lengths. That is
why `Fitter` may try a reflected drawing against exactly the same index
hits instead of searching again.

## 3. Procrustes is optimal — `Proofs/Procrustes.lean`

Supports `Geom.procrustes`, used by `Fitter.fit_one` and `Morph.start`.

Given corners `p₁…pₙ` and target stars `q₁…qₙ`, the fitter wants the
similarity with the smallest total squared error
`cost(a, b) = Σ ‖a·pᵢ + b − qᵢ‖²`. The code uses a closed-form recipe:
centre both sets on their means, compute `A = Σ conj(p'ᵢ)·q'ᵢ` and
`S = Σ ‖p'ᵢ‖²` from the centred points, take `a = A/S`, and set
`b = c_q − a·c_p`.

**The code's sums are `A` (`conj_mul_coords`, `code_scale`,
`code_angle`).** The real part of `conj(p)·q` is `px·qx + py·qy` and the
imaginary part is `px·qy − py·qx`. These are precisely the two sums the
OCaml code accumulates (it calls them `a` and `b`). So the code's angle
`θ = atan2(b, a)` is the argument of `A/S` (dividing by a positive real
does not turn a vector), and its scale `s = √(a² + b²)/S` is the length
of `A/S`.

**The cost splits apart (`normSq_residual`, `cost_expand`).** Expanding
one squared residual gives `‖a‖²‖p‖² + ‖b‖² + ‖q‖²` plus three
cross terms. Summed over centred data (`Σpᵢ = Σqᵢ = 0`), the two cross
terms that involve `b` contain `Σpᵢ` or `Σqᵢ` and vanish. What remains is

  `cost(a, b) = ‖a‖²·S + n‖b‖² + Σ‖qᵢ‖² − 2·Re(conj(a)·A)`.

The proof does the expansion once for a single point (pure algebra on
real and imaginary parts), then pushes the sum through each term.

**Completing the square (`procrustes_centered_optimal`).** Write
`a₀ = A/S`, so `A = S·a₀`. Comparing any `(a, b)` with `(a₀, 0)`, the
constant `Σ‖qᵢ‖²` cancels and the rest rearranges into

  `cost(a, b) − cost(a₀, 0) = S·‖a − a₀‖² + n·‖b‖²`.

Both terms are non-negative (`S > 0` because the corners are not all in
one place), so no `(a, b)` beats `(a₀, 0)`. This is the same reasoning as
"the mean minimises squared error", done for complex numbers.

**Uncentred data (`cost_shift`, `sum_sub_mean`, `procrustes_optimal`).**
The identity `a·p + b − q = a(p − c_p) + (b + a·c_p − c_q) − (q − c_q)`
shows that moving both point sets and compensating in `b` leaves the
cost unchanged. Subtracting the means gives point sets that sum to zero.
So the centred result transfers: `a = A/S` with `b = c_q − a·c_p` is a
global minimiser for the original points, which is exactly what
`Geom.procrustes` returns.

## 4. Angle wrapping — `Proofs/Angles.lean`

Supports `Geom.wrap_angle`, used by `Morph.current_sim`.

The morph must turn the short way round, so it blends `wrap(θ)`, the
equivalent angle in `(−π, π]`. Lean defines
`wrap(a) = a − 2π·⌈(a − π)/(2π)⌉`.

**It lands in range (`wrap_mem`).** Let `t = (a − π)/(2π)`. The ceiling
satisfies `t ≤ ⌈t⌉ < t + 1`. Multiplying by `2π` and substituting
`2π·t = a − π` turns the left inequality into `wrap(a) ≤ π` and the
right one into `wrap(a) > −π`.

**It is the same direction (`wrap_congr`).** By construction
`wrap(a) = a + 2π·k` for the integer `k = −⌈t⌉`.

**It is the only such angle (`wrap_unique`).** If two angles in
`(−π, π]` differ by `2π·k`, their difference is strictly between `−2π`
and `2π`, so `−1 < k < 1`, so `k = 0` and they are equal.

**Why the OCaml version agrees.** `Geom.wrap_angle` computes a value in
`(−π, π]` that differs from its input by whole turns. By `wrap_unique` it
is therefore the same number as Lean's `wrap` (rounding aside), even
though it is computed with `Float.rem` instead of a ceiling.
`wrap_of_mem` adds that an angle already in range is left alone.

## 5. Easing and the morph — `Proofs/Morph.lean`

Supports `Morph.ease`, `Morph.current_sim`, `Morph.current`.

**Smoothstep behaves (`ease_zero`, `ease_one`, `ease_half`, `ease_mem`,
`ease_mono`).** `ease(u) = u²(3 − 2u)` gives 0 at 0, 1 at 1 and ½ at ½.
On `[0, 1]` it is never negative (a square times something at least 1),
and never above 1, because `1 − ease(u) = (1 − u)²(1 + 2u) ≥ 0`. It never
decreases: `ease(v) − ease(u)` factors as `(v − u)` times a sum of terms
each non-negative when `0 ≤ u ≤ v ≤ 1`. So the animation never overshoots
or runs backwards.

**It starts and stops gently (`ease_hasDerivAt`, `ease_flat_ends`).**
Rewriting `ease(u) = 3u² − 2u³` and differentiating gives slope
`6u(1 − u)`, which is 0 at both ends.

**The animation ends exactly on the fit (`exp_wrap`, `morph_start`,
`morph_end`).** In complex form the blended map at eased progress `e` is

  `z ↦ c(e) + s^e·e^{i·e·wrap(θ)}·(z − c₀)`, with `c(e) = c₀ + e(T₁c₀ − c₀)`.

At `e = 0` the factor is `s⁰·e⁰ = 1` and `c(0) = c₀`, so the map is the
identity. At `e = 1` it is `T₁c₀ + s·e^{i·wrap(θ)}(z − c₀)`. Since
`wrap(θ) = θ + 2πk`, `e^{i·wrap(θ)} = e^{iθ}·e^{2πik} = e^{iθ}`. So the
map is `s·e^{iθ}·z + b = T₁(z)`: the stroke finishes exactly on the
fitted stars, even though the code blends the wrapped angle.

## 6. The cheap distance test in RDP — `Proofs/Simplify.lean`

Supports `Simplify.rdp`.

For a chord from `a` with direction `d` and a point `p`, write
`u = a − p`. The code compares the cross product
`|d × u| = |dx·uy − dy·ux|` with `eps·|d|`, avoiding a square root in the
inner loop.

**Lagrange's identity (`lagrange`).** `(d × u)² + (d · u)² = |d|²|u|²`,
checked by expanding both sides.

**The cross product is "distance times length" (`perp_dist_sq`).**
Dividing by `|d|²` gives `(d × u)²/|d|² = |u|² − ((d · u)/|d|)²`. The
last term is the squared length of `u`'s projection onto the chord, so by
Pythagoras the right side is the squared perpendicular distance from `p`
to the chord's line. Therefore `|d × u| = distance · |d|`.

**Same decisions as the textbook test (`rdp_test_equiv`).** For `L > 0`,
`eps·L < cross` holds exactly when `eps < cross/L`. So the
square-root-free comparison keeps exactly the points the usual
"distance > eps" test keeps.

## 7. Engine input normalisation — `Proofs/Normalise.lean`

Supports `Engine.normalise` and `Engine.preprocess` (and the matching
Python `normalise` in `engine/train.py`).

The engine subtracts the stroke's mean point and divides by the
root-mean-square distance from it.

**The mean follows the transform (`mean_affine`).** The mean of
`a·zᵢ + b` is `a·mean(z) + b`. The sum splits, `a` comes out of the sum,
and the `n` copies of `b` divided by `n` give `b`.

**So does the size (`rms_affine`).** Each centred point becomes
`a(zᵢ − mean z)`, whose squared length is `‖a‖²` times the old one. The
square root of `‖a‖²·(mean square)` is `‖a‖·rms(z)`.

**Position and size drop out; rotation does not
(`normalise_equivariant`).** Combining the two, the normalised point
becomes `a(zᵢ − mean)/(‖a‖·rms) = (a/‖a‖)·normalise(z)ᵢ`. The factor
`a/‖a‖` has length 1: it is a pure rotation. So normalisation removes
where the stroke is and how large it is, but a rotated drawing gives
rotated input. That is precisely why `train.py` augments every training
stroke with a random rotation (and a random mirror): the model learns
rotation invariance from data, while translation and scale invariance are
guaranteed by construction.

**Exact invariance for move-and-resize (`normalise_invariant`).** When
`a` is a positive real `k`, `a/‖a‖ = 1`, so the normalised stroke, and
hence the engine's answer, is identical no matter where or how large the
user draws.

## 8. Engine probabilities — `Proofs/Engine.lean`

Supports `Engine.softmax` and `Engine.classify`.

**They are probabilities (`softmax_pos`, `softmax_sum`).** Each value is
`exp(zᵢ)/Σexp(zⱼ)`. Exponentials are positive, so each value is positive,
and the values share one denominator, so they add up to 1.

**The overflow guard is exact (`softmax_shift`).** The code subtracts the
largest score `m` first. Since `exp(zᵢ − m) = exp(zᵢ)/exp(m)`, the
factor `exp(m)` divides numerator and denominator alike and cancels.

**Ranking by probability is ranking by score (`softmax_mono`).** A larger
score has a larger exponential over the same denominator, so sorting
`classify`'s output by probability gives the same order as sorting the
raw logits.

## 9. Discrete facts — `Proofs/Discrete.lean`

**Bounded work (`triangles_card`, `triangles_nine`).** The candidate
generator looks at every 3-element subset of the corners. Mathlib's
counting lemma gives `n choose 3` of them, which is 84 for the
simplifier's maximum of 9 corners.

**Bins are always valid (`clampBin_mem`, `clampBin_of_mem`).**
`max 0 (min (n − 1) v)` lies in `[0, n − 1]` whenever `n ≥ 1`, and leaves
an in-range `v` unchanged. Lean's `omega` decision procedure checks both.

**Neighbourhood lookups (`neighbours_card_le`, `self_mem_neighbours`).**
`Index.neighbours` is the image of the 27 offset triples
`{−1, 0, 1}³`, so it has at most 27 keys (an image is never larger than
its source). The offset `(0, 0, 0)` maps a valid key to itself, so
`find_near` always searches the exact bin as well as the nearby ones.

**No star is used twice (`snap_nodup`).** `Fitter.snap` assigns stars to
corners one at a time, never choosing a star already taken. Modelling
this as a greedy pass with a `pick` function that avoids the used list,
induction on the corners shows the resulting list has no duplicates and
avoids every star that was already used.

**Smoothing stays inside the stroke's box (`weighted_mean_le`).**
`Capture.add` replaces each point with a weighted mean of recent points,
with positive Gaussian weights. A weighted mean with non-negative weights
is at most the largest value: multiply out the division and compare term
by term. Applied to each coordinate (and, symmetrically, to the minimum),
smoothing can never push the stroke outside its bounding box.

---

## Theorem index

| Lean theorem | File | Backs |
| --- | --- | --- |
| `polar_form` | Similarity | `Geom.rotate`, `Geom.apply` |
| `two_point_maps`, `two_point_unique` | Similarity | `Geom.sim_of_pair`, `Candidates.generate` |
| `dist_scale`, `dist_conj` | Similarity | `Index.key`, `Geom.mirror_y` |
| `order_preserved`, `lawCos_scale`, `features_scale` | ShapeKey | `Index.key` |
| `features_similarity`, `features_mirror` | ShapeKey | `Index.key`, `Fitter.best` mirror pass |
| `conj_mul_coords`, `code_scale`, `code_angle` | Procrustes | `Geom.procrustes` formulas |
| `cost_expand`, `procrustes_centered_optimal` | Procrustes | `Geom.procrustes` optimality |
| `cost_shift`, `procrustes_optimal` | Procrustes | `Geom.procrustes` centring |
| `wrap_mem`, `wrap_congr`, `wrap_unique`, `wrap_of_mem` | Angles | `Geom.wrap_angle` |
| `ease_*` | Morph | `Morph.ease` |
| `exp_wrap`, `morph_start`, `morph_end` | Morph | `Morph.current_sim` |
| `lagrange`, `perp_dist_sq`, `rdp_test_equiv` | Simplify | `Simplify.rdp` |
| `mean_affine`, `rms_affine` | Normalise | `Engine.normalise` |
| `normalise_equivariant`, `normalise_invariant` | Normalise | `Engine.preprocess`, training augmentation |
| `softmax_pos`, `softmax_sum`, `softmax_shift`, `softmax_mono` | Engine | `Engine.softmax`, `Engine.classify` |
| `triangles_card`, `triangles_nine` | Discrete | `Candidates.triangles` |
| `clampBin_mem`, `clampBin_of_mem` | Discrete | `Index.bin` |
| `neighbours_card_le`, `self_mem_neighbours` | Discrete | `Index.neighbours`, `Index.find_near` |
| `snap_nodup` | Discrete | `Fitter.snap` |
| `weighted_mean_le` | Discrete | `Capture.add` |
