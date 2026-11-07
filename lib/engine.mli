(** Recognition engine: a small trained transformer that reads a drawn
    stroke and names the constellation figure it resembles.

    The model is trained from scratch by [engine/train.py] (PyTorch) on
    synthetic hand-drawn versions of the figures in
    [data/asterisms.csv], plus a ["none"] class of scribbles. This module
    is a pure-OCaml forward pass over the exported weights
    ([data/engine_weights.txt]), so the app needs no Python at run time.

    Architecture (the decoder-free "encoder" half of a language model,
    scaled down to about 100k parameters): the stroke is resampled to
    {!n_points} points by arc length and normalised (centroid 0, RMS
    radius 1); each point becomes a token through a linear map, a learned
    [CLS] token is prepended, learned position embeddings are added, then
    [n_layers] pre-norm blocks of multi-head self-attention and a GELU
    MLP run, and the final [CLS] state is layer-normed and mapped to one
    logit per class.

    Normalisation makes the input independent of where and how large the
    drawing is (proved in [proofs/Proofs/Normalise.lean]); rotation and
    mirroring are learned from augmented training data. *)

type t
(** A loaded model: configuration, class names and weights. *)

val n_points : int
(** Tokens per stroke after resampling. [32]. Must equal the value the
    model was trained with; {!load} checks it. *)

val none_label : string
(** The class meaning "not any known figure": ["none"]. *)

val resample : int -> Geom.pt array -> Geom.pt array
(**
   [resample n pts] places [n] points evenly by arc length along the
   polyline [pts], keeping the first and last points.
   Requires: [n >= 2], [pts] non-empty
   Returns: [n] points; [n] copies of [pts.(0)] when the stroke has one
            point or zero length
   Raises: [Invalid_argument] if [pts] is empty or [n < 2]
   Example: resample 4 [|{x=0.;y=0.}; {x=3.;y=0.}|]
            = [|{x=0.;y=0.}; {x=1.;y=0.}; {x=2.;y=0.}; {x=3.;y=0.}|]
   Complexity: O(m + n) time, O(m + n) space, m = Array.length pts
*)

val normalise : Geom.pt array -> Geom.pt array
(**
   [normalise pts] removes position and size: subtract the centroid,
   divide by the root-mean-square distance from it.
   Requires: [pts] non-empty
   Returns: points with centroid 0 and RMS radius 1 (only centred when
            all points coincide)
   Raises: [Invalid_argument] if [pts] is empty
   Example: normalise [|{x=0.;y=0.}; {x=2.;y=0.}|] = [|{x=-1.;y=0.}; {x=1.;y=0.}|]
   Complexity: O(n) time, O(n) space
*)

val preprocess : Geom.pt array -> Geom.pt array
(**
   [preprocess stroke] is the model input: [normalise (resample n_points stroke)].
   Requires: [stroke] non-empty
   Returns: {!n_points} normalised points
   Raises: [Invalid_argument] if [stroke] is empty
   Example: Array.length (preprocess stroke) = 32
   Complexity: O(m + n_points) time and space
*)

val load : string -> t
(**
   [load path] reads a weights file written by [engine/train.py].
   Requires: the file's [n_points] equals {!n_points}
   Returns: the model
   Raises: [Sys_error] if the file is missing; [Failure] with a message
           if the format is wrong, a tensor is missing, or a shape does
           not match the configuration
   Example: classes (load "data/engine_weights.txt")
            = [| "Big Dipper"; ...; "none" |]
   Complexity: O(P) time and space, P = number of parameters
*)

val classes : t -> string array
(**
   [classes m] is the class names in logit order (["none"] last).
   Requires: nothing
   Returns: the stored array
   Raises: nothing
   Example: (classes m).(0) = "Big Dipper"
   Complexity: O(1) time, O(1) space
*)

val logits : t -> Geom.pt array -> float array
(**
   [logits m stroke] runs the forward pass on a raw stroke (screen
   pixels, drawing order); preprocessing is included.
   Requires: [stroke] non-empty
   Returns: one unnormalised score per class, in {!classes} order
   Raises: [Invalid_argument] if [stroke] is empty
   Example: Array.length (logits m stroke) = Array.length (classes m)
   Complexity: O(L (T^2 d + T d f)) time, O(T d + T^2) space; T = 33
               tokens, d = model width, f = MLP width, L = layers
*)

val softmax : float array -> float array
(**
   [softmax z] turns scores into probabilities, computed stably by
   subtracting the maximum first.
   Requires: [z] non-empty and finite
   Returns: positive values summing to 1, in the same order
   Raises: [Invalid_argument] if [z] is empty
   Example: softmax [|0.; 0.|] = [|0.5; 0.5|]
   Complexity: O(n) time, O(n) space
*)

val classify : t -> Geom.pt array -> (string * float) list
(**
   [classify m stroke] names the figure: class names paired with
   probabilities, most likely first.
   Requires: [stroke] non-empty
   Returns: every class exactly once, sorted by descending probability
   Raises: [Invalid_argument] if [stroke] is empty
   Example: fst (List.hd (classify m big_dipper_stroke)) = "Big Dipper"
   Complexity: same as {!logits} plus O(C log C) for the sort
*)
