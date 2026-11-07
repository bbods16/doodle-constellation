(* Recognition engine: pure-OCaml transformer forward pass.
   See engine.mli for the public contract. *)

open Geom

let n_points = 32
let none_label = "none"
let ln_eps = 1e-5

(* A linear map y = W x + b with W stored row-major as (out, in). *)
type linear = { w : float array; b : float array; n_in : int; n_out : int }
type norm = { g : float array; beta : float array }

type block = {
  ln1 : norm; q : linear; k : linear; v : linear; o : linear;
  ln2 : norm; ff1 : linear; ff2 : linear;
}

type t = {
  names : string array;
  d : int;
  heads : int;
  inp : linear;
  cls : float array;
  pos : float array array;
  blocks : block array;
  ln_f : norm;
  head : linear;
}

(**
   [resample n pts] spaces [n] points evenly by arc length.
   Requires: [n >= 2], [pts] non-empty
   Returns: [n] points along the polyline
   Raises: [Invalid_argument] on empty [pts] or [n < 2]
   Example: resample 4 [|{x=0.;y=0.}; {x=3.;y=0.}|] = [|(0,0); (1,0); (2,0); (3,0)|]
   Complexity: O(m + n) time and space
   Pseudocode:
     cum.(0) <- 0 ; cum.(i) <- cum.(i-1) + |p.(i) - p.(i-1)|
     if m = 1 or total < 1e-12 then return n copies of p.(0)
     j <- 0
     for k = 0 to n-1:
       t <- k * total / (n-1)
       while j < m-2 and cum.(j+1) < t: j <- j+1
       seg <- cum.(j+1) - cum.(j)
       u <- if seg > 0 then clamp 0 1 ((t - cum.(j)) / seg) else 0
       out.(k) <- lerp p.(j) p.(j+1) u
*)
let resample n pts =
  let m = Array.length pts in
  if m = 0 then invalid_arg "Engine.resample: empty stroke";
  if n < 2 then invalid_arg "Engine.resample: n < 2";
  let cum = Array.make m 0. in
  for i = 1 to m - 1 do
    cum.(i) <- cum.(i - 1) +. dist pts.(i) pts.(i - 1)
  done;
  let total = cum.(m - 1) in
  if m = 1 || total < 1e-12 then Array.make n pts.(0)
  else begin
    let j = ref 0 in
    Array.init n (fun k ->
        let t = float_of_int k *. total /. float_of_int (n - 1) in
        while !j < m - 2 && cum.(!j + 1) < t do
          incr j
        done;
        let seg = cum.(!j + 1) -. cum.(!j) in
        let u = if seg > 0. then Float.min 1. (Float.max 0. ((t -. cum.(!j)) /. seg)) else 0. in
        lerp pts.(!j) pts.(!j + 1) u)
  end

(**
   [normalise pts] centres and scales to unit RMS radius.
   Requires: non-empty
   Returns: normalised copy
   Raises: [Invalid_argument] on empty input
   Example: normalise [|{x=0.;y=0.}; {x=2.;y=0.}|] = [|(-1,0); (1,0)|]
   Complexity: O(n) time and space
   Pseudocode:
     c <- centroid pts ; q <- map (fun p -> p - c) pts
     r <- sqrt (mean |q|^2) ; if r < 1e-12 then r <- 1
     return map (scale (1 / r)) q
*)
let normalise pts =
  if Array.length pts = 0 then invalid_arg "Engine.normalise: empty";
  let c = centroid pts in
  let q = Array.map (fun p -> sub p c) pts in
  let ms = Array.fold_left (fun a p -> a +. (p.x *. p.x) +. (p.y *. p.y)) 0. q in
  let r = sqrt (ms /. float_of_int (Array.length q)) in
  let r = if r < 1e-12 then 1. else r in
  Array.map (scale (1. /. r)) q

(**
   [preprocess stroke] is the model input.
   Requires: non-empty
   Returns: [n_points] normalised points
   Raises: [Invalid_argument] on empty input
   Example: Array.length (preprocess stroke) = 32
   Complexity: O(m + n_points)
   Pseudocode:
     return normalise (resample n_points stroke)
*)
let preprocess stroke = normalise (resample n_points stroke)

(* ------------------------------------------------------------------ *)
(* Loading                                                             *)
(* ------------------------------------------------------------------ *)

(**
   [parse_floats line] reads space-separated floats.
   Requires: nothing
   Returns: the numbers in order
   Raises: [Failure] if a token is not a float
   Example: parse_floats "1 2.5 -3e-2" = [|1.; 2.5; -0.03|]
   Complexity: O(L) time and space
   Pseudocode:
     return map float_of_string (non-empty tokens of split line on ' ')
*)
let parse_floats line =
  String.split_on_char ' ' (String.trim line)
  |> List.filter (fun s -> s <> "")
  |> List.map (fun s ->
         match float_of_string_opt s with
         | Some f -> f
         | None -> failwith ("Engine.load: bad number " ^ s))
  |> Array.of_list

(**
   [load path] reads the weights file.
   Requires: matching [n_points]
   Returns: the model
   Raises: [Sys_error] if missing; [Failure] on format or shape errors
   Example: classes (load "data/engine_weights.txt") = [| "Big Dipper"; ...; "none" |]
   Complexity: O(P) time and space
   Pseudocode:
     lines <- file lines (CR stripped)
     check "doodle-engine 1" ; read config n_points d heads layers ff C
     check n_points ; read "classes" then C names
     loop: "tensor name ndims dims..." followed by a values line
           -> table[name] <- (dims, values) after checking the count
     get name dims: look up and check the shape, else fail
     build inp, cls, pos (rows of d), each block, ln_f, head from table
*)
let load path =
  let text = In_channel.with_open_bin path In_channel.input_all in
  let lines =
    String.split_on_char '\n' text
    |> List.map (fun l ->
           let n = String.length l in
           if n > 0 && l.[n - 1] = '\r' then String.sub l 0 (n - 1) else l)
    |> Array.of_list
  in
  let fail msg = failwith ("Engine.load: " ^ msg) in
  let line i = if i < Array.length lines then lines.(i) else fail "unexpected end of file" in
  if line 0 <> "doodle-engine 1" then fail "not a doodle-engine 1 file";
  let np, d, heads, layers, ff, nc =
    match String.split_on_char ' ' (line 1) with
    | [ "config"; a; b; c; e; f; g ] -> (
        match List.map int_of_string_opt [ a; b; c; e; f; g ] with
        | [ Some a; Some b; Some c; Some e; Some f; Some g ] -> (a, b, c, e, f, g)
        | _ -> fail "bad config line")
    | _ -> fail "missing config line"
  in
  if np <> n_points then fail (Printf.sprintf "model uses %d points, engine expects %d" np n_points);
  if heads <= 0 || d mod heads <> 0 then fail "d_model not divisible by n_heads";
  if line 2 <> "classes" then fail "missing classes";
  let names = Array.init nc (fun i -> line (3 + i)) in
  let table = Hashtbl.create 64 in
  let i = ref (3 + nc) in
  while !i < Array.length lines && String.trim lines.(!i) <> "" do
    (match String.split_on_char ' ' lines.(!i) with
    | "tensor" :: name :: nd :: dims ->
        let dims = List.map int_of_string dims in
        if List.length dims <> int_of_string nd then fail ("bad header for " ^ name);
        let vals = parse_floats (line (!i + 1)) in
        if Array.length vals <> List.fold_left ( * ) 1 dims then fail ("wrong value count for " ^ name);
        Hashtbl.replace table name (dims, vals)
    | _ -> fail ("unexpected line " ^ string_of_int (!i + 1)));
    i := !i + 2
  done;
  let get name dims =
    match Hashtbl.find_opt table name with
    | None -> fail ("missing tensor " ^ name)
    | Some (dims', v) ->
        if dims' <> dims then fail ("shape mismatch for " ^ name);
        v
  in
  let linear name n_in n_out =
    { w = get (name ^ ".weight") [ n_out; n_in ]; b = get (name ^ ".bias") [ n_out ]; n_in; n_out }
  in
  let norm name = { g = get (name ^ ".weight") [ d ]; beta = get (name ^ ".bias") [ d ] } in
  let pos_flat = get "pos" [ 1; np + 1; d ] in
  let block l =
    let p = Printf.sprintf "blocks.%d." l in
    { ln1 = norm (p ^ "ln1"); q = linear (p ^ "q") d d; k = linear (p ^ "k") d d;
      v = linear (p ^ "v") d d; o = linear (p ^ "o") d d; ln2 = norm (p ^ "ln2");
      ff1 = linear (p ^ "ff1") d ff; ff2 = linear (p ^ "ff2") ff d }
  in
  { names; d; heads; inp = linear "inp" 2 d; cls = get "cls" [ 1; 1; d ];
    pos = Array.init (np + 1) (fun t -> Array.sub pos_flat (t * d) d);
    blocks = Array.init layers block; ln_f = norm "ln_f"; head = linear "head" d nc }

(**
   [classes m] is the class names.
   Requires: nothing
   Returns: [m.names]
   Raises: nothing
   Example: (classes m).(0) = "Big Dipper"
   Complexity: O(1)
   Pseudocode:
     return m.names
*)
let classes m = m.names

(* ------------------------------------------------------------------ *)
(* Forward pass                                                        *)
(* ------------------------------------------------------------------ *)

(**
   [apply_linear l x] is [W x + b].
   Requires: [Array.length x = l.n_in]
   Returns: vector of length [l.n_out]
   Raises: nothing (bounds are guaranteed by {!load})
   Example: apply_linear {w=[|2.|]; b=[|1.|]; n_in=1; n_out=1} [|3.|] = [|7.|]
   Complexity: O(n_in * n_out) time, O(n_out) space
   Pseudocode:
     for o: y.(o) <- b.(o) + sum_i w.(o * n_in + i) * x.(i)
*)
let apply_linear l x =
  Array.init l.n_out (fun o ->
      let acc = ref l.b.(o) and base = o * l.n_in in
      for i = 0 to l.n_in - 1 do
        acc := !acc +. (l.w.(base + i) *. x.(i))
      done;
      !acc)

(**
   [layer_norm nm x] normalises [x] to mean 0 and variance 1, then scales
   and shifts per feature.
   Requires: [Array.length x = Array.length nm.g]
   Returns: [(x - mean) / sqrt (var + 1e-5) * g + beta]
   Raises: nothing
   Example: layer_norm {g=[|1.;1.|]; beta=[|0.;0.|]} [|1.;3.|] = [|-1.;1.|] (approx.)
   Complexity: O(d) time and space
   Pseudocode:
     mean <- average x ; var <- average (x - mean)^2   (biased, like PyTorch)
     return map (fun i -> (x.(i) - mean) / sqrt (var + eps) * g.(i) + beta.(i))
*)
let layer_norm nm x =
  let n = float_of_int (Array.length x) in
  let mean = Array.fold_left ( +. ) 0. x /. n in
  let var = Array.fold_left (fun a v -> a +. ((v -. mean) ** 2.)) 0. x /. n in
  let inv = 1. /. sqrt (var +. ln_eps) in
  Array.mapi (fun i v -> ((v -. mean) *. inv *. nm.g.(i)) +. nm.beta.(i)) x

(**
   [gelu x] is the exact Gaussian error linear unit.
   Requires: nothing
   Returns: [0.5 x (1 + erf (x / sqrt 2))]
   Raises: nothing
   Example: gelu 0. = 0.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return 0.5 * x * (1 + erf (x / sqrt 2))
*)
let gelu x = 0.5 *. x *. (1. +. Float.erf (x /. Float.sqrt 2.))

(**
   [softmax z] is the numerically stable softmax.
   Requires: non-empty finite [z]
   Returns: probabilities summing to 1
   Raises: [Invalid_argument] on empty input
   Example: softmax [|0.; 0.|] = [|0.5; 0.5|]
   Complexity: O(n) time and space
   Pseudocode:
     m <- max z ; e <- map (fun v -> exp (v - m)) z
     return map (fun v -> v / sum e) e
*)
let softmax z =
  if Array.length z = 0 then invalid_arg "Engine.softmax: empty";
  let m = Array.fold_left Float.max neg_infinity z in
  let e = Array.map (fun v -> exp (v -. m)) z in
  let s = Array.fold_left ( +. ) 0. e in
  Array.map (fun v -> v /. s) e

(**
   [attention m blk h] is multi-head self-attention over all tokens,
   including the output projection (no residual).
   Requires: [h] is T tokens of width [m.d]
   Returns: T vectors of width [m.d]
   Raises: nothing
   Example: Array.length (attention m blk h) = Array.length h
   Complexity: O(T^2 d + T d^2) time, O(T d + T) space
   Pseudocode:
     x <- map (layer_norm blk.ln1) h
     q, k, v <- linear maps of each token ; hd <- d / heads
     for each head g and token i:
       s_j <- (q_i[g] . k_j[g]) / sqrt hd for all j ; w <- softmax s
       out_i[g] <- sum_j w_j v_j[g]
     return map (apply_linear blk.o) out
*)
let attention m blk h =
  let t = Array.length h and d = m.d in
  let hd = d / m.heads in
  let x = Array.map (layer_norm blk.ln1) h in
  let q = Array.map (apply_linear blk.q) x
  and k = Array.map (apply_linear blk.k) x
  and v = Array.map (apply_linear blk.v) x in
  let out = Array.init t (fun _ -> Array.make d 0.) in
  let scale = 1. /. sqrt (float_of_int hd) in
  for g = 0 to m.heads - 1 do
    let off = g * hd in
    for i = 0 to t - 1 do
      let s =
        Array.init t (fun j ->
            let acc = ref 0. in
            for c = 0 to hd - 1 do
              acc := !acc +. (q.(i).(off + c) *. k.(j).(off + c))
            done;
            !acc *. scale)
      in
      let w = softmax s in
      for j = 0 to t - 1 do
        for c = 0 to hd - 1 do
          out.(i).(off + c) <- out.(i).(off + c) +. (w.(j) *. v.(j).(off + c))
        done
      done
    done
  done;
  Array.map (apply_linear blk.o) out

(**
   [add_into a b] adds [b] to [a] in place (a residual connection).
   Requires: equal lengths
   Returns: unit; [a] now holds [a + b]
   Raises: nothing
   Example: let a = [|1.|] in add_into a [|2.|]; a = [|3.|]
   Complexity: O(n) time, O(1) space
   Pseudocode:
     for i: a.(i) <- a.(i) + b.(i)
*)
let add_into a b = Array.iteri (fun i v -> a.(i) <- a.(i) +. v) b

(**
   [logits m stroke] runs the full forward pass.
   Requires: non-empty stroke
   Returns: one score per class
   Raises: [Invalid_argument] on empty stroke
   Example: Array.length (logits m stroke) = Array.length (classes m)
   Complexity: O(L (T^2 d + T d f))
   Pseudocode:
     x <- preprocess stroke
     h.(0) <- cls + pos.(0) ; h.(t+1) <- inp x.(t) + pos.(t+1)
     for each block:
       h <- h + attention h
       h <- h + ff2 (gelu (ff1 (ln2 h)))     (per token)
     return head (ln_f h.(0))
*)
let logits m stroke =
  let x = preprocess stroke in
  let h =
    Array.init (Array.length x + 1) (fun t ->
        let base = if t = 0 then Array.copy m.cls else apply_linear m.inp [| x.(t - 1).x; x.(t - 1).y |] in
        add_into base m.pos.(t);
        base)
  in
  Array.iter
    (fun blk ->
      let a = attention m blk h in
      Array.iteri (fun i ai -> add_into h.(i) ai) a;
      Array.iter
        (fun tok ->
          let f = apply_linear blk.ff2 (Array.map gelu (apply_linear blk.ff1 (layer_norm blk.ln2 tok))) in
          add_into tok f)
        h)
    m.blocks;
  apply_linear m.head (layer_norm m.ln_f h.(0))

(**
   [classify m stroke] ranks the classes by probability.
   Requires: non-empty stroke
   Returns: (name, probability) pairs, most likely first
   Raises: [Invalid_argument] on empty stroke
   Example: fst (List.hd (classify m big_dipper_stroke)) = "Big Dipper"
   Complexity: forward pass + O(C log C)
   Pseudocode:
     p <- softmax (logits m stroke)
     return sort by descending p (zip names p)
*)
let classify m stroke =
  let p = softmax (logits m stroke) in
  Array.to_list (Array.mapi (fun i pi -> (m.names.(i), pi)) p)
  |> List.stable_sort (fun (_, a) (_, b) -> compare b a)
