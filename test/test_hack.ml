(**
   File: test_hack.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: OUnit2 test suite for every library layer, including end-to-end
                matches and the OCaml-vs-PyTorch engine check.
   Usage: Run: dune test (from the repo root).
*)

(* Unit and end-to-end tests for the Doodle Constellation library. *)

open OUnit2
open Geom

let feq ?(eps = 1e-9) a b = Float.abs (a -. b) <= eps
let assert_feq ?(eps = 1e-9) msg exp got =
  assert_bool (Printf.sprintf "%s: expected %g, got %g" msg exp got) (feq ~eps exp got)
let assert_pt ?(eps = 1e-9) msg e g =
  assert_feq ~eps (msg ^ ".x") e.x g.x;
  assert_feq ~eps (msg ^ ".y") e.y g.y
let p x y = { x; y }

let catalogue = lazy (Catalogue.load "../data/stars.csv")
let index = lazy (Index.build (Lazy.force catalogue))

let idx_of name =
  let stars = Lazy.force catalogue in
  let rec go i = if stars.(i).Catalogue.name = name then i else go (i + 1) in
  go 0

let dipper_names = [ "Dubhe"; "Merak"; "Phecda"; "Megrez"; "Alioth"; "Mizar"; "Alkaid" ]

(* Screen pixels of the Big Dipper under a known similarity. *)
let dipper_screen () =
  let stars = Lazy.force catalogue in
  let ids = List.map idx_of dipper_names in
  let pos = List.map (fun i -> Catalogue.position stars.(i)) ids in
  let centre = Skyvec.centre pos in
  let sim0 = { s = 1500.; theta = 0.3; tx = 640.; ty = 400. } in
  let pts = List.map (fun q -> apply sim0 (Option.get (gnomonic ~centre q))) pos in
  (Array.of_list ids, Array.of_list pts)

let geom_tests =
  "geom"
  >::: [ ("arith" >:: fun _ ->
           assert_pt "add" (p 4. 6.) (add (p 1. 2.) (p 3. 4.));
           assert_pt "sub" (p 2. 3.) (sub (p 3. 4.) (p 1. 1.));
           assert_feq "dist" 5. (dist (p 0. 0.) (p 3. 4.));
           assert_pt "rotate" (p 0. 1.) (rotate (Float.pi /. 2.) (p 1. 0.));
           assert_pt "lerp" (p 5. 1.) (lerp (p 0. 0.) (p 10. 2.) 0.5);
           assert_feq "bbox" 5. (bbox_diagonal [| p 0. 0.; p 3. 1.; p 1. 4. |]));
         ("centroid_empty" >:: fun _ ->
           assert_raises (Invalid_argument "Geom.centroid: empty array") (fun () -> centroid [||]));
         ("wrap" >:: fun _ ->
           assert_feq "3pi/2" (-.Float.pi /. 2.) (wrap_angle (3. *. Float.pi /. 2.));
           assert_feq "pi" Float.pi (wrap_angle Float.pi);
           assert_feq "-pi" Float.pi (wrap_angle (-.Float.pi)));
         ("sim_of_pair" >:: fun _ ->
           let t = sim_of_pair (p 1. 1.) (p 3. 2.) (p (-2.) 5.) (p 0. 9.) in
           assert_pt "a" (p (-2.) 5.) (apply t (p 1. 1.));
           assert_pt "b" (p 0. 9.) (apply t (p 3. 2.));
           assert_raises (Invalid_argument "Geom.sim_of_pair: a and b coincide") (fun () ->
               sim_of_pair (p 1. 1.) (p 1. 1.) (p 0. 0.) (p 1. 0.)));
         ("procrustes" >:: fun _ ->
           let t0 = { s = 2.5; theta = -0.7; tx = 3.; ty = -4. } in
           let src = [| p 0. 0.; p 10. 0.; p 3. 7.; p (-5.) 2. |] in
           let t = Option.get (procrustes src (apply_all t0 src)) in
           assert_feq ~eps:1e-9 "s" 2.5 t.s;
           assert_feq ~eps:1e-9 "theta" (-0.7) t.theta;
           assert_feq ~eps:1e-9 "rms" 0. (rms t src (apply_all t0 src));
           assert_equal None (procrustes [| p 1. 1.; p 1. 1. |] [| p 0. 0.; p 1. 0. |]);
           assert_equal None (procrustes [| p 1. 1. |] [| p 0. 0. |]));
         ("gnomonic" >:: fun _ ->
           assert_pt "centre" (p 0. 0.) (Option.get (gnomonic ~centre:(1., 0.5) (1., 0.5)));
           assert_equal None (gnomonic ~centre:(0., 0.) (Float.pi, 0.));
           (* north of centre is up on screen: negative y *)
           assert_bool "north up" ((Option.get (gnomonic ~centre:(0., 0.) (0., 0.1))).y < 0.);
           (* east of centre is left on screen: negative x *)
           assert_bool "east left" ((Option.get (gnomonic ~centre:(0., 0.) (0.1, 0.))).x < 0.));
         ("angular_sep" >:: fun _ ->
           assert_feq "90deg" (Float.pi /. 2.) (angular_sep (0., 0.) (0., Float.pi /. 2.));
           assert_feq "deg/rad" 180. (deg (rad 180.))) ]

(* Dense samples along a polyline, every [step] pixels. *)
let sample_polyline step verts =
  let out = ref [] in
  for i = 0 to Array.length verts - 2 do
    let a = verts.(i) and b = verts.(i + 1) in
    let n = max 1 (int_of_float (dist a b /. step)) in
    for k = 0 to n - 1 do
      out := lerp a b (float_of_int k /. float_of_int n) :: !out
    done
  done;
  out := verts.(Array.length verts - 1) :: !out;
  Array.of_list (List.rev !out)

let simplify_tests =
  "simplify"
  >::: [ ("rdp_basic" >:: fun _ ->
           let r = Simplify.rdp ~eps:1. [| p 0. 0.; p 1. 0.1; p 2. 0. |] in
           assert_equal 2 (Array.length r));
         ("is_line" >:: fun _ ->
           assert_bool "line" (Simplify.is_line [| p 0. 0.; p 50. 1.; p 100. 0. |]);
           assert_bool "not line" (not (Simplify.is_line [| p 0. 0.; p 50. 60.; p 100. 0. |])));
         ("w_shape" >:: fun _ ->
           let verts = [| p 0. 0.; p 50. 100.; p 100. 0.; p 150. 100.; p 200. 0. |] in
           match Simplify.corners (sample_polyline 2. verts) with
           | Ok c ->
               assert_equal ~printer:string_of_int 5 (Array.length c);
               Array.iteri (fun i v -> assert_pt ~eps:1e-6 "corner" v c.(i)) verts
           | Error _ -> assert_failure "W should simplify");
         ("too_simple" >:: fun _ ->
           assert_equal (Error `Too_simple) (Simplify.corners [| p 0. 0.; p 1. 1. |]);
           assert_equal (Error `Too_simple)
             (Simplify.corners (sample_polyline 2. [| p 0. 0.; p 300. 2. |])));
         ("too_complex" >:: fun _ ->
           (* 30-point star burst: far more than 9 sharp corners *)
           let verts =
             Array.init 31 (fun i ->
                 let r = if i mod 2 = 0 then 200. else 40. in
                 let a = float_of_int i *. Float.pi /. 15. in
                 p (r *. cos a) (r *. sin a))
           in
           assert_equal (Error `Too_complex) (Simplify.corners (sample_polyline 2. verts))) ]

let capture_tests =
  "capture"
  >::: [ ("filter" >:: fun _ ->
           let t = Capture.add (Capture.add Capture.empty (p 0. 0.)) (p 1. 0.) in
           assert_equal 1 (Capture.length t);
           assert_bool "empty" (Capture.is_empty Capture.empty);
           let t = Capture.add t (p 5. 0.) in
           assert_equal 2 (Capture.length t);
           assert_pt "raw" (p 5. 0.) (Capture.raw t).(1));
         ("smooth_line" >:: fun _ ->
           let t = ref Capture.empty in
           for i = 0 to 20 do
             t := Capture.add !t (p (float_of_int (3 * i)) 7.)
           done;
           let s = Capture.stroke !t in
           assert_equal 21 (Array.length s);
           Array.iter (fun q -> assert_feq "on line" 7. q.y) s;
           assert_pt "first" (p 0. 7.) s.(0)) ]

let catalogue_tests =
  "catalogue"
  >::: [ ("parse" >:: fun _ ->
           (match Catalogue.parse_line "2061,Betelgeuse,88.793,7.407,0.50,Ori\r" with
           | Some s ->
               assert_equal 2061 s.Catalogue.id;
               assert_feq "ra" (rad 88.793) s.Catalogue.ra;
               assert_equal "Betelgeuse" (Catalogue.label s)
           | None -> assert_failure "parse");
           assert_equal None (Catalogue.parse_line "id,name,ra_deg,dec_deg,mag,con");
           assert_equal None (Catalogue.parse_line "");
           assert_equal None (Catalogue.parse_line "1,x,2");
           match Catalogue.parse_line "264,,14.177,60.717,2.47,Cas" with
           | Some s -> assert_equal "HR 264" (Catalogue.label s)
           | None -> assert_failure "unnamed");
         ("load" >:: fun _ ->
           let all = Lazy.force catalogue in
           assert_equal ~printer:string_of_int 48 (Array.length all);
           (* Segin, Meissa, Megrez and Albireo are fainter than 3.0 *)
           assert_equal ~printer:string_of_int 44
             (Array.length (Catalogue.load ~max_mag:3.0 "../data/stars.csv"));
           assert_raises (Sys_error "missing.csv: No such file or directory") (fun () ->
               Catalogue.load "missing.csv")) ]

let index_tests =
  "index"
  >::: [ ("key_345" >:: fun _ ->
           let k, perm = Index.key (p 0. 0.) (p 4. 0.) (p 0. 3.) in
           assert_equal (24, 32, 18) k;
           assert_equal [| 1; 2; 0 |] perm);
         ("key_invariant" >:: fun _ ->
           let a, b, c = (p 1. 2.), (p 7. 3.), (p 2. 9.) in
           let t = { s = 3.7; theta = 1.1; tx = -50.; ty = 20. } in
           let k1, _ = Index.key a b c and k2, _ = Index.key (apply t a) (apply t b) (apply t c) in
           assert_equal k1 k2;
           let k3, _ = Index.key c a b in
           assert_equal k1 k3);
         ("key_degenerate" >:: fun _ ->
           assert_raises (Invalid_argument "Index.key: degenerate triangle") (fun () ->
               Index.key (p 0. 0.) (p 1. 1.) (p 2. 2.)));
         ("neighbours" >:: fun _ ->
           assert_equal 27 (List.length (Index.neighbours (10, 10, 10)));
           assert_equal 8 (List.length (Index.neighbours (0, 0, 0))));
         ("build" >:: fun _ ->
           let ix = Lazy.force index in
           assert_bool "non-empty" (Index.size ix > 0);
           assert_equal 0 (Index.size (Index.build [||])));
         ("triangles" >:: fun _ ->
           assert_equal 84 (List.length (Candidates.triangles 9));
           assert_equal [ (0, 1, 2); (0, 1, 3); (0, 2, 3); (1, 2, 3) ] (Candidates.triangles 4)) ]

let matching_tests =
  "matching"
  >::: [ ("big_dipper" >:: fun _ ->
           let stars = Lazy.force catalogue in
           let ids, pts = dipper_screen () in
           let hs = Candidates.generate (Lazy.force index) pts in
           assert_bool "has hypotheses" (hs <> []);
           match Fitter.best stars hs with
           | None -> assert_failure "no fit"
           | Some f ->
               assert_equal ~printer:(fun a -> String.concat "," (Array.to_list (Array.map string_of_int a)))
                 ids f.Fitter.stars;
               assert_bool "not weak" (not f.Fitter.weak);
               assert_bool "not mirrored" (not f.Fitter.mirrored);
               assert_bool "tiny rms" (f.Fitter.rms_deg < 0.05));
         ("big_dipper_mirrored" >:: fun _ ->
           let stars = Lazy.force catalogue in
           let ids, pts = dipper_screen () in
           let pts = Array.map (fun q -> p q.x (800. -. q.y)) pts in
           match Fitter.best stars (Candidates.generate (Lazy.force index) pts) with
           | None -> assert_failure "no fit"
           | Some f ->
               assert_equal ids f.Fitter.stars;
               assert_bool "mirrored" f.Fitter.mirrored);
         ("snap_none" >:: fun _ ->
           assert_equal None
             (Fitter.snap (Lazy.force catalogue) ~centre:(0., -1.4) [| p 0. 0. |]));
         ("best_empty" >:: fun _ -> assert_equal None (Fitter.best (Lazy.force catalogue) [])) ]

let visibility_tests =
  let lat, lon = Visibility.buffalo in
  "visibility"
  >::: [ ("lst_j2000" >:: fun _ ->
           assert_feq ~eps:1e-6 "gmst" (rad 280.46061837)
             (Visibility.local_sidereal_time ~lon:0. ~now:946728000.));
         ("culmination" >:: fun _ ->
           let now = 1782000000. and ra = rad 279.234 in
           let c = Visibility.culmination ~lon ~ra ~now in
           assert_bool "future" (c >= now && c < now +. 86400.);
           assert_feq ~eps:1e-6 "ha" 0. (Visibility.hour_angle ~lon ~ra ~now:c);
           assert_feq ~eps:1e-6 "zenith" (Float.pi /. 2.)
             (Visibility.altitude ~lat ~lon ~ra ~dec:lat ~now:c);
           assert_feq ~eps:1e-6 "south" Float.pi
             (Visibility.azimuth ~lat ~lon ~ra ~dec:0. ~now:c));
         ("sun" >:: fun _ ->
           assert_bool "june noon high" (Visibility.sun_altitude ~lat ~lon ~now:1782062400. > rad 60.);
           assert_bool "dec midnight dark" (Visibility.is_dark ~lat ~lon ~now:1797829200.);
           assert_bool "noon not dark" (not (Visibility.is_dark ~lat ~lon ~now:1782062400.)));
         ("best_view" >:: fun _ ->
           let now = 1782000000. in
           let t, alt, _ = Visibility.best_view ~lat ~lon ~ra:(rad 279.234) ~dec:(rad 38.784) ~now in
           assert_bool "window" (t >= now && t <= now +. 86400.);
           assert_bool "dark" (Visibility.is_dark ~lat ~lon ~now:t);
           assert_bool "up" (alt > 0.));
         ("compass" >:: fun _ ->
           assert_equal "south" (Visibility.compass Float.pi);
           assert_equal "north" (Visibility.compass (rad 350.));
           assert_equal "north-east" (Visibility.compass (rad 45.));
           assert_equal "west" (Visibility.compass (rad (-90.)))) ]

let morph_tests =
  "morph"
  >::: [ ("ease" >:: fun _ ->
           assert_feq "0" 0. (Morph.ease 0.);
           assert_feq "half" 0.5 (Morph.ease 0.5);
           assert_feq "1" 1. (Morph.ease 1.));
         ("animate" >:: fun _ ->
           let drawn = [| p 0. 0.; p 100. 0.; p 50. 80. |] in
           let t0 = { s = 0.5; theta = 2.5; tx = 300.; ty = 200. } in
           let target = apply_all t0 drawn in
           let m = Morph.start ~drawn ~target in
           assert_feq "p0" 0. (Morph.progress m);
           Array.iteri (fun i q -> assert_pt ~eps:1e-9 "start" drawn.(i) q) (Morph.current m drawn);
           assert_feq "half" 0.5 (Morph.progress (Morph.step m 0.75));
           let m = Morph.step m 10. in
           assert_bool "finished" (Morph.finished m);
           Array.iteri (fun i q -> assert_pt ~eps:1e-6 "end" target.(i) q) (Morph.current m drawn);
           let e = Morph.end_sim m in
           assert_feq ~eps:1e-9 "s1" 0.5 e.s) ]

let narrate_tests =
  "narrate"
  >::: [ ("prompt" >:: fun _ ->
           let s = Narrate.prompt { Narrate.shape = "Bolt"; stars = [ "Vega"; "Deneb" ]; neighbour = "Lyra" } in
           let has sub =
             let n = String.length s and m = String.length sub in
             let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
             go 0
           in
           List.iter (fun w -> assert_bool w (has w)) [ "Bolt"; "Vega"; "Deneb"; "Lyra"; "70" ];
           assert_equal "This story is invented." Narrate.fiction_label) ]

(* Reads data/engine_testvec.txt: pairs of (raw stroke, PyTorch logits). *)
let load_testvec path =
  let lines = In_channel.with_open_text path In_channel.input_all |> String.split_on_char '\n' in
  let floats l =
    String.split_on_char ' ' (String.trim l) |> List.filter (( <> ) "") |> List.map float_of_string
    |> Array.of_list
  in
  let rec go acc = function
    | h1 :: s :: h2 :: lg :: rest
      when String.length h1 > 6 && String.sub h1 0 6 = "stroke" && String.sub h2 0 6 = "logits" ->
        let c = floats s in
        let stroke = Array.init (Array.length c / 2) (fun i -> p c.(2 * i) c.((2 * i) + 1)) in
        go ((stroke, floats lg) :: acc) rest
    | _ -> List.rev acc
  in
  go [] lines

let engine = lazy (Engine.load "../data/engine_weights.txt")

let engine_tests =
  "engine"
  >::: [ ("resample" >:: fun _ ->
           let r = Engine.resample 4 [| p 0. 0.; p 3. 0. |] in
           Array.iteri (fun i q -> assert_pt "pt" (p (float_of_int i) 0.) q) r;
           let r = Engine.resample 5 [| p 0. 0.; p 1. 0.; p 1. 1. |] in
           assert_pt "mid corner" (p 1. 0.) r.(2);
           assert_pt "last" (p 1. 1.) r.(4);
           Array.iter (fun q -> assert_pt "dot" (p 2. 2.) q) (Engine.resample 3 [| p 2. 2. |]));
         ("normalise" >:: fun _ ->
           let n = Engine.normalise [| p 0. 0.; p 2. 0. |] in
           assert_pt "a" (p (-1.) 0.) n.(0);
           assert_pt "b" (p 1. 0.) n.(1);
           (* translation and positive scale do not change the result *)
           let s = [| p 1. 2.; p 5. 3.; p 2. 9.; p (-4.) 1. |] in
           let s' = Array.map (fun q -> add (scale 7.5 q) (p 100. (-40.))) s in
           Array.iteri (fun i q -> assert_pt ~eps:1e-9 "invariant" q (Engine.normalise s').(i))
             (Engine.normalise s));
         ("softmax" >:: fun _ ->
           let s = Engine.softmax [| 1000.; 1000. |] in
           assert_feq "half" 0.5 s.(0);
           assert_feq "sum" 1. (Array.fold_left ( +. ) 0. (Engine.softmax [| 1.; -2.; 3.5 |])));
         ("load" >:: fun _ ->
           let m = Lazy.force engine in
           let cs = Engine.classes m in
           assert_equal "Big Dipper" cs.(0);
           assert_equal Engine.none_label cs.(Array.length cs - 1);
           assert_raises (Sys_error "missing.txt: No such file or directory") (fun () ->
               Engine.load "missing.txt"));
         ("matches_pytorch" >:: fun _ ->
           let m = Lazy.force engine in
           let vecs = load_testvec "../data/engine_testvec.txt" in
           assert_bool "has vectors" (vecs <> []);
           List.iter
             (fun (stroke, expected) ->
               let got = Engine.logits m stroke in
               Array.iteri (fun i e -> assert_feq ~eps:1e-4 "logit" e got.(i)) expected)
             vecs);
         ("recognises_big_dipper" >:: fun _ ->
           (* the real catalogue stars, drawn as a closed-bowl dipper *)
           let stars = Lazy.force catalogue in
           let order = [ "Alkaid"; "Mizar"; "Alioth"; "Megrez"; "Phecda"; "Merak"; "Dubhe"; "Megrez" ] in
           let pos = List.map (fun n -> Catalogue.position stars.(idx_of n)) order in
           let centre = Skyvec.centre pos in
           let t = { s = 900.; theta = 2.0; tx = 500.; ty = 300. } in
           let verts = Array.of_list (List.map (fun q -> apply t (Option.get (gnomonic ~centre q))) pos) in
           let stroke = sample_polyline 3. verts in
           match Engine.classify (Lazy.force engine) stroke with
           | (name, prob) :: _ ->
               assert_equal ~printer:(fun s -> s) "Big Dipper" name;
               assert_bool "confident" (prob > 0.5)
           | [] -> assert_failure "no classes");
         ("rejects_line" >:: fun _ ->
           let stroke = sample_polyline 3. [| p 0. 0.; p 400. 30. |] in
           match Engine.classify (Lazy.force engine) stroke with
           | (name, _) :: _ -> assert_equal ~printer:(fun s -> s) Engine.none_label name
           | [] -> assert_failure "no classes") ]

(* Two throwaway scenes for testing the router without a window. [draw]
   records the state it was given so tests can observe it. *)
let drawn_a = ref (-1)

module Scene_a = struct
  type t = int

  let name = "a"
  let init (_ : Scene.ctx) = 0

  let update (_ : Scene.ctx) inp n =
    if Scene.pressed inp Scene.Enter then Scene.Goto "b"
    else if Scene.pressed inp (Scene.Letter 'q') then Scene.Quit
    else if Scene.pressed inp (Scene.Letter 's') then Scene.Continue (n + 1, [ Scene.Screenshot "x.png" ])
    else Scene.Continue (n + 1, [])

  let draw (_ : Scene.ctx) n = drawn_a := n
end

module Scene_b = struct
  type t = unit

  let name = "b"
  let init (_ : Scene.ctx) = ()

  let update (_ : Scene.ctx) inp () =
    if Scene.pressed inp Scene.Tab then Scene.Goto "missing"
    else if Scene.pressed inp Scene.Escape then Scene.Goto "a"
    else Scene.Continue ((), [])

  let draw (_ : Scene.ctx) () = ()
end

let scene_tests =
  let ctx =
    lazy
      (Scene.make_ctx ~stars:(Lazy.force catalogue) ~index:(Lazy.force index) ~lat:0. ~lon:0. ())
  in
  let reg = lazy (Scene.registry [ (module Scene_a); (module Scene_b) ]) in
  let inp keys = { (Scene.idle ~width:800 ~height:600) with keys } in
  let next r = function
    | Scene.Next (r', _) -> r'
    | Scene.Stopped -> assert_failure ("unexpected stop in " ^ Scene.current_name r)
  in
  "scene"
  >::: [ ("registry" >:: fun _ ->
           assert_equal [ "a"; "b" ] (Scene.names (Lazy.force reg));
           assert_raises (Invalid_argument "Scene.registry: duplicate scene name a") (fun () ->
               Scene.registry [ (module Scene_a); (module Scene_a) ]);
           assert_raises (Invalid_argument "Scene.registry: no scenes") (fun () -> Scene.registry []));
         ("launch" >:: fun _ ->
           let ctx = Lazy.force ctx and reg = Lazy.force reg in
           assert_equal "b" (Scene.current_name (Scene.launch reg ctx "b"));
           assert_raises (Invalid_argument "Scene.launch: unknown scene \"zzz\" (known: a, b)")
             (fun () -> Scene.launch reg ctx "zzz"));
         ("continue_keeps_state" >:: fun _ ->
           let ctx = Lazy.force ctx and reg = Lazy.force reg in
           let r = Scene.launch reg ctx "a" in
           let r = next r (Scene.step reg ctx (inp []) r) in
           let r = next r (Scene.step reg ctx (inp []) r) in
           assert_equal "a" (Scene.current_name r);
           Scene.draw ctx r;
           assert_equal 2 !drawn_a);
         ("effects" >:: fun _ ->
           let ctx = Lazy.force ctx and reg = Lazy.force reg in
           match Scene.step reg ctx (inp [ Scene.Letter 's' ]) (Scene.launch reg ctx "a") with
           | Scene.Next (_, effects) -> assert_equal [ Scene.Screenshot "x.png" ] effects
           | Scene.Stopped -> assert_failure "stopped");
         ("goto_switches_with_fresh_state" >:: fun _ ->
           let ctx = Lazy.force ctx and reg = Lazy.force reg in
           let r = Scene.launch reg ctx "a" in
           let r = next r (Scene.step reg ctx (inp []) r) in
           let r = next r (Scene.step reg ctx (inp [ Scene.Enter ]) r) in
           assert_equal "b" (Scene.current_name r);
           let r = next r (Scene.step reg ctx (inp [ Scene.Escape ]) r) in
           assert_equal "a" (Scene.current_name r);
           Scene.draw ctx r;
           assert_equal 0 !drawn_a);
         ("quit_and_bad_goto" >:: fun _ ->
           let ctx = Lazy.force ctx and reg = Lazy.force reg in
           assert_equal Scene.Stopped
             (match Scene.step reg ctx (inp [ Scene.Letter 'q' ]) (Scene.launch reg ctx "a") with
             | Scene.Stopped -> Scene.Stopped
             | Scene.Next (_, e) -> Scene.Next (Scene.launch reg ctx "a", e));
           assert_raises (Invalid_argument "Scene.launch: unknown scene \"missing\" (known: a, b)")
             (fun () -> Scene.step reg ctx (inp [ Scene.Tab ]) (Scene.launch reg ctx "b")));
         ("pressed" >:: fun _ ->
           assert_bool "enter" (Scene.pressed (inp [ Scene.Enter ]) Scene.Enter);
           assert_bool "not space" (not (Scene.pressed (inp [ Scene.Enter ]) Scene.Space))) ]

let controls_tests =
  let base = Scene.idle ~width:800 ~height:600 in
  "controls"
  >::: [ ("pen" >:: fun _ ->
           assert_equal [ Controls.Pen_down (p 3. 4.) ]
             (Controls.read { base with mouse_down = true; mouse = p 3. 4. });
           assert_equal [ Controls.Pen_up ] (Controls.read { base with mouse_released = true });
           assert_equal [] (Controls.read base));
         ("keys" >:: fun _ ->
           assert_equal [ Controls.Clear; Controls.Open_menu; Controls.Dismiss ]
             (Controls.read { base with keys = [ Scene.Letter 'm'; Scene.Letter 'c'; Scene.Enter ] });
           assert_equal [ Controls.Save_card ] (Controls.read { base with keys = [ Scene.Letter 's' ] })) ]

let game_tests =
  let ctx engine =
    Scene.make_ctx ~stars:(Lazy.force catalogue) ~index:(Lazy.force index) ?engine ~lat:0.75 ~lon:(-1.38) ()
  in
  let screen = { Game.width = 1280; height = 800; now = 1782000000. } in
  (* feed a polyline to the game as mouse samples, then release *)
  let draw_and_release c verts g =
    let g = Array.fold_left (fun g q -> Game.apply c screen g (Controls.Pen_down q)) g
        (sample_polyline 3. verts) in
    Game.apply c screen g Controls.Pen_up
  in
  "game"
  >::: [ ("big_dipper_flow" >:: fun _ ->
           let c = ctx (Some (Lazy.force engine)) in
           let ids, verts = dipper_screen () in
           let g = draw_and_release c verts (Game.init ()) in
           (match Game.stage g with
           | Game.Morphing _ -> ()
           | Game.Hint h -> assert_failure ("refused: " ^ h)
           | _ -> assert_failure "expected Morphing");
           (match Game.current_fit g with
           | Some f ->
               let show a =
                 String.concat ","
                   (Array.to_list (Array.map (fun i -> (Lazy.force catalogue).(i).Catalogue.name) a))
               in
               (* Smoothing + simplification may drop Alioth, a near-straight
                  bend in the handle; every star matched must still be a
                  Dipper star, in drawing order. *)
               let positions = Array.map (fun s ->
                   let rec find k = if k = Array.length ids then -1
                     else if ids.(k) = s then k else find (k + 1) in find 0) f.Fitter.stars in
               assert_bool ("only Dipper stars: " ^ show f.Fitter.stars)
                 (Array.for_all (fun k -> k >= 0) positions);
               assert_bool ("in drawing order: " ^ show f.Fitter.stars)
                 (Array.for_all Fun.id
                    (Array.init (Array.length positions - 1) (fun k -> positions.(k) < positions.(k + 1))));
               assert_bool "at least 5 stars" (Array.length positions >= 5)
           | None -> assert_failure "no fit");
           assert_bool "engine guessed" (Game.guess g <> None);
           assert_bool "view set" (Game.view g <> None);
           assert_bool "best view set" (Game.best_view g <> None);
           let g = Game.tick 10. g in
           (match Game.stage g with Game.Showing _ -> () | _ -> assert_failure "expected Showing");
           assert_bool "stroke shown" (Array.length (Game.visible_stroke g) > 0);
           (* drawing again starts a fresh stroke *)
           let g = Game.apply c screen g (Controls.Pen_down (p 1. 1.)) in
           assert_equal 1 (Game.stroke_length g);
           assert_equal None (Game.current_fit g));
         ("refused_line" >:: fun _ ->
           let c = ctx None in
           let g = draw_and_release c [| p 0. 0.; p 400. 20. |] (Game.init ()) in
           (match Game.stage g with
           | Game.Hint h -> assert_equal (Game.hint_of `Too_simple) h
           | _ -> assert_failure "expected Hint");
           assert_equal None (Game.guess g));
         ("clear_and_noops" >:: fun _ ->
           let c = ctx None in
           let g = Game.apply c screen (Game.init ()) (Controls.Pen_down (p 5. 5.)) in
           assert_equal 0 (Game.stroke_length (Game.apply c screen g Controls.Clear));
           assert_bool "pen_up without stroke" (Game.stage (Game.pen_up c screen (Game.init ())) = Game.Drawing);
           assert_equal 1 (Game.stroke_length (Game.apply c screen g Controls.Save_card));
           assert_equal 1 (Game.stroke_length (Game.ask_story c g)));
         ("mirror" >:: fun _ ->
           let r = Game.mirror_about_centroid [| p 0. 0.; p 0. 2. |] [| p 0. 0. |] in
           assert_pt "mirrored" (p 0. 2.) r.(0)) ]

let data_dir_tests =
  (* Unix-style paths keep the expectations readable; Filename is
     platform-aware, so build expected paths with it too. *)
  let ( / ) = Filename.concat in
  let root = Filename.dirname (Sys.getcwd ()) |> Filename.dirname |> Filename.dirname in
  let repo = root / "repo" in
  let stars_in d = d / "data" / Data_dir.stars_file in
  "data_dir"
  >::: [ ("ancestors" >:: fun _ ->
           let a = Data_dir.ancestors (repo / "bin") in
           assert_equal (repo / "bin") (List.hd a);
           assert_bool "includes repo" (List.mem repo a);
           assert_equal (Filename.dirname (List.nth a (List.length a - 1))) (List.nth a (List.length a - 1)));
         ("found_from_subfolder" >:: fun _ ->
           (* started inside bin/: the parent folder's data/ is found *)
           let want = stars_in repo in
           assert_equal (Ok want)
             (Data_dir.find ~env:None ~cwd:(repo / "bin") ~exe:(root / "elsewhere" / "x.exe")
                ~exists:(( = ) want)));
         ("found_next_to_executable" >:: fun _ ->
           (* started from an unrelated folder: found by walking up from the exe *)
           let want = stars_in repo in
           assert_equal (Ok want)
             (Data_dir.find ~env:None ~cwd:(root / "tmp")
                ~exe:(repo / "_build" / "default" / "bin" / "main.exe") ~exists:(( = ) want)));
         ("env_wins" >:: fun _ ->
           let d = root / "mydata" in
           match Data_dir.candidates ~env:(Some d) ~cwd:repo ~exe:(repo / "x.exe") with
           | first :: _ -> assert_equal (d / Data_dir.stars_file) first
           | [] -> assert_failure "no candidates");
         ("not_found_lists_tried" >:: fun _ ->
           match Data_dir.find ~env:None ~cwd:(repo / "bin") ~exe:(repo / "x.exe") ~exists:(fun _ -> false) with
           | Error tried ->
               assert_bool "tried bin/data" (List.mem (stars_in (repo / "bin")) tried);
               assert_bool "tried repo/data" (List.mem (stars_in repo) tried);
               assert_equal (List.length tried) (List.length (List.sort_uniq compare tried))
           | Ok _ -> assert_failure "should not be found");
         ("real_repo" >:: fun _ ->
           (* from the test's own build folder the real catalogue is found *)
           match Data_dir.find ~env:None ~cwd:(Sys.getcwd ()) ~exe:Sys.executable_name ~exists:Sys.file_exists with
           | Ok p -> assert_bool p (Sys.file_exists p)
           | Error _ -> assert_failure "real catalogue not found") ]

(* ---------------- collect mode ---------------- *)

let figures = lazy (Asterism.load (Lazy.force catalogue) "../data/asterisms.csv")

let figure name =
  match List.find_opt (fun f -> Asterism.name f = name) (Array.to_list (Lazy.force figures)) with
  | Some f -> f
  | None -> failwith ("no figure " ^ name)

(* A figure outline turned into a dense, moved, scaled, rotated stroke. *)
let as_stroke ?(sim = { s = 300.; theta = 0.8; tx = 500.; ty = 350. }) shape =
  sample_polyline 2. (apply_all sim shape)

let asterism_tests =
  "asterism"
  >::: [ ("load" >:: fun _ ->
           let fs = Lazy.force figures in
           assert_equal ~printer:string_of_int 7 (Array.length fs);
           let o = figure "Orion" and c = figure "Cassiopeia" in
           assert_bool "orion closed" (Asterism.is_closed o);
           assert_bool "cassiopeia open" (not (Asterism.is_closed c));
           assert_equal 7 (Array.length (Asterism.shape o));
           assert_equal "UMa" (Asterism.constellation (figure "Big Dipper"));
           assert_equal 8 (Array.length (Asterism.star_indices (figure "Big Dipper"))));
         ("unknown_star" >:: fun _ ->
           let path = Filename.temp_file "fig" ".csv" in
           Out_channel.with_open_text path (fun oc -> output_string oc "name,con,stars\nBad,X,1 999999\n");
           assert_raises (Failure "Asterism.load: Bad uses unknown star id 1") (fun () ->
               Asterism.load (Lazy.force catalogue) path)) ]

let accuracy_tests =
  "accuracy"
  >::: [ ("perfect_trace" >:: fun _ ->
           Array.iter
             (fun f ->
               let target = Asterism.shape f in
               let s = Accuracy.score ~target (as_stroke target) in
               assert_bool (Printf.sprintf "%s scored %s" (Asterism.name f) (Accuracy.format s)) (s > 99.))
             (Lazy.force figures));
         ("invariant" >:: fun _ ->
           let target = Asterism.shape (figure "Orion") in
           let rev a = Array.init (Array.length a) (fun i -> a.(Array.length a - 1 - i)) in
           List.iter
             (fun (label, stroke) ->
               let s = Accuracy.score ~target stroke in
               assert_bool (label ^ " scored " ^ Accuracy.format s) (s > 99.))
             [ ("moved/scaled/rotated", as_stroke ~sim:{ s = 50.; theta = -2.; tx = 9.; ty = 999. } target);
               ("reversed", as_stroke (rev target));
               ("mirrored", as_stroke (mirror_y target)) ]);
         ("line_fails_everywhere" >:: fun _ ->
           (* regression: a flat line once collected Cassiopeia's shallow W at 57.6% *)
           let straight = sample_polyline 2. [| p 0. 0.; p 400. 10. |] in
           let wobbly = sample_polyline 2. [| p 0. 0.; p 100. 12.; p 200. (-6.); p 300. 10.; p 400. 0. |] in
           Array.iter
             (fun f ->
               let target = Asterism.shape f in
               List.iter
                 (fun (label, stroke) ->
                   let s = Accuracy.score ~target stroke in
                   assert_bool (Printf.sprintf "%s line on %s scored %s" label (Asterism.name f) (Accuracy.format s))
                     (s < Accuracy.pass_mark))
                 [ ("straight", straight); ("wobbly", wobbly) ];
               assert_feq ~eps:1e-6 ("exact line on " ^ Asterism.name f) 0. (Accuracy.score ~target straight))
             (Lazy.force figures));
         ("wrong_figure_fails" >:: fun _ ->
           let s = Accuracy.score ~target:(Asterism.shape (figure "Cassiopeia"))
               (as_stroke (Asterism.shape (figure "Orion"))) in
           assert_bool ("orion as cassiopeia scored " ^ Accuracy.format s) (s < Accuracy.pass_mark));
         ("empty" >:: fun _ ->
           assert_feq "empty" 0. (Accuracy.score ~target:(Asterism.shape (figure "Leo")) [||]);
           assert_feq "dot" 0. (Accuracy.score ~target:(Asterism.shape (figure "Leo")) [| p 1. 1.; p 1. 1. |]));
         ("live" >:: fun _ ->
           let target = Asterism.shape (figure "Cassiopeia") in
           let full = as_stroke target in
           let half = Accuracy.prefix full 0.5 in   (* exactly half the length *)
           let s = Accuracy.live ~target half in
           assert_bool ("half trace live " ^ Accuracy.format s) (s > 95.);
           assert_feq "nothing yet" 0. (Accuracy.live ~target [||]));
         ("format" >:: fun _ ->
           assert_equal "87.3%" (Accuracy.format 87.25);
           assert_equal "0.0%" (Accuracy.format (-3.));
           assert_equal "100.0%" (Accuracy.format 140.);
           assert_equal "Best: 0.0%" (Accuracy.format_best None);
           assert_equal "Best: 91.2%" (Accuracy.format_best (Some 91.2)));
         ("tiers" >:: fun _ ->
           let open Accuracy in
           assert_equal Near_perfect (tier 94.);
           assert_equal Incredible (tier 93.99);
           assert_equal Amazing (tier 81.);
           assert_equal Great (tier 72.);
           assert_equal Collected (tier 50.);
           assert_equal Failed (tier 49.9);
           assert_equal "Near Perfect" (tier_label Near_perfect));
         ("colour" >:: fun _ ->
           assert_equal (230, 60, 60) (Accuracy.colour 0.);
           assert_equal (240, 200, 60) (Accuracy.colour 50.);
           assert_equal (60, 220, 90) (Accuracy.colour 100.)) ]

let roast_tests =
  "roast"
  >::: [ ("insult_fill" >:: fun _ ->
           assert_equal "12.0% on Leo? Bold." (Roast.insult "{score} on {target}? Bold." ~score:12.04 ~target:"Leo"));
         ("five_strikes" >:: fun _ ->
           let rec go r k =
             let r, v = Roast.miss r ~score:10. ~target:"Orion" in
             match v with
             | Roast.Insult _ when k < 5 -> go r (k + 1)
             | Roast.Final_diss line when k = 5 -> (r, line)
             | _ -> assert_failure (Printf.sprintf "wrong verdict on strike %d" k)
           in
           let r, line = go (Roast.create ()) 1 in
           assert_bool "diss text" (String.length line > 0);
           assert_equal 0 (Roast.strikes_left r);
           assert_raises (Invalid_argument "Roast.miss: no strikes left") (fun () ->
               Roast.miss r ~score:1. ~target:"Orion"));
         ("deterministic" >:: fun _ ->
           let line seed = snd (Roast.miss (Roast.create ~seed ()) ~score:20. ~target:"Leo") in
           assert_equal (line 7) (line 7);
           assert_bool "seeds differ" (line 0 <> line 1)) ]

let collection_tests =
  "collection"
  >::: [ ("pass_mark" >:: fun _ ->
           let c = Collection.create (Lazy.force figures) in
           let c, r = Collection.record c ~name:"Orion" ~score:49.9 in
           assert_bool "not collected" (not r.collected_now);
           assert_bool "first attempt is a best" r.new_best;
           let c, r = Collection.record c ~name:"Orion" ~score:50.0 in
           assert_bool "collected at 50.0" r.collected_now;
           assert_bool "collected" (Collection.is_collected c "Orion");
           let c, r = Collection.record c ~name:"Orion" ~score:45. in
           assert_bool "no new best" (not r.new_best);
           assert_feq "best kept" 50. r.best;
           assert_bool "still collected" (Collection.is_collected c "Orion");
           assert_equal "1 / 7 collected" (Collection.progress_label c));
         ("next_target" >:: fun _ ->
           let c = Collection.create (Lazy.force figures) in
           assert_equal (Some "Big Dipper") (Option.map Asterism.name (Collection.next_target c));
           let c, _ = Collection.record c ~name:"Big Dipper" ~score:80. in
           assert_equal (Some "Cassiopeia") (Option.map Asterism.name (Collection.next_target c));
           let c = Array.fold_left (fun c f -> fst (Collection.record c ~name:(Asterism.name f) ~score:90.)) c
               (Lazy.force figures) in
           assert_bool "complete" (Collection.is_complete c);
           assert_equal None (Collection.next_target c));
         ("save_load" >:: fun _ ->
           let fs = Lazy.force figures in
           let c, _ = Collection.record (Collection.create fs) ~name:"Leo" ~score:73.456 in
           let c, _ = Collection.record c ~name:"Orion" ~score:12.5 in
           let path = Filename.temp_file "progress" ".csv" in
           Collection.save path c;
           let c' = Collection.load fs path in
           assert_bool "leo collected" (Collection.is_collected c' "Leo");
           assert_bool "orion not" (not (Collection.is_collected c' "Orion"));
           assert_equal (Some 73.456) (Collection.best c' "Leo");
           assert_equal (Some 12.5) (Collection.best c' "Orion");
           assert_equal None (Collection.best c' "Cassiopeia");
           assert_equal 0 (Collection.collected_count (Collection.load fs "missing.csv")));
         ("bad_name" >:: fun _ ->
           assert_raises (Invalid_argument "Collection.record: unknown figure Nope") (fun () ->
               Collection.record (Collection.create (Lazy.force figures)) ~name:"Nope" ~score:1.)) ]

let judge_tests =
  let fresh () = (Collection.create (Lazy.force figures), Roast.create ()) in
  "judge"
  >::: [ ("verdicts" >:: fun _ ->
           let c, r = fresh () in
           let o = figure "Orion" in
           let c, r, v = Judge.judge c r ~target:o ~score:63. in
           (match v with Judge.Collected_new { tier = Accuracy.Collected; _ } -> () | _ -> assert_failure "collected");
           assert_equal "Collected!" (Judge.headline v);
           let c, r, v = Judge.judge c r ~target:o ~score:91. in
           (match v with Judge.New_record _ -> () | _ -> assert_failure "record");
           assert_equal "NEW RECORD!" (Judge.headline v);
           let c, r, v = Judge.judge c r ~target:o ~score:75. in
           (match v with Judge.Passed { best = 91.; tier = Accuracy.Great; _ } -> () | _ -> assert_failure "passed");
           assert_equal "Great" (Judge.headline v);
           let _, r, v = Judge.judge c r ~target:o ~score:20. in
           (match v with Judge.Insulted { strikes_left = 4; _ } -> () | _ -> assert_failure "insulted");
           assert_equal 1 (Roast.strikes r);
           assert_feq "score_of" 20. (Judge.score_of v));
         ("game_over" >:: fun _ ->
           let c, r = fresh () in
           let o = figure "Leo" in
           let rec go c r k =
             let c, r, v = Judge.judge c r ~target:o ~score:5. in
             if k < 5 then go c r (k + 1) else v
           in
           (match go c r 1 with Judge.Game_over _ -> () | _ -> assert_failure "game over");
           (* a miss still counts as an attempt for the best score *)
           let c, _, _ = Judge.judge c r ~target:o ~score:30. in
           assert_equal (Some 30.) (Collection.best c "Leo")) ]

(* One frame of collect mode: apply the commands, then tick. *)
let frame ?(dt = 1. /. 60.) t cmds = List.fold_left Collect.apply t cmds |> Collect.tick dt

(* Draw [stroke] one sample per frame, then release. *)
let draw_in t stroke =
  let t = Array.fold_left (fun t q -> frame t [ Controls.Pen_down q ]) t stroke in
  frame t [ Controls.Pen_up ]

let collect_tests =
  let start () = Collect.init (Collection.create (Lazy.force figures)) (Roast.create ()) in
  let target_shape t = Asterism.shape (Option.get (Collect.target t)) in
  "collect"
  >::: [ ("held_click_ignored" >:: fun _ ->
           (* the click that opened the mode is still down on the first frames *)
           let t = frame (start ()) [ Controls.Pen_down (p 5. 5.) ] in
           let t = frame t [ Controls.Pen_up ] in
           assert_equal Collect.Prompt (Collect.phase t);
           assert_equal 0 (Roast.strikes (Collect.roast t)));
         ("collect_one" >:: fun _ ->
           let t = frame (start ()) [] in
           assert_equal (Some "Big Dipper") (Option.map Asterism.name (Collect.target t));
           let t = Array.fold_left (fun t q -> frame t [ Controls.Pen_down q ]) t
               (as_stroke (target_shape t)) in
           assert_equal Collect.Drawing (Collect.phase t);
           assert_bool ("live score " ^ Accuracy.format (Collect.live_score t)) (Collect.live_score t > 90.);
           let t = frame t [ Controls.Pen_up ] in
           (match Collect.phase t with
           | Collect.Verdict (Judge.Collected_new _, _) -> ()
           | _ -> assert_failure "expected Collected_new");
           let t, save = Collect.take_save_request t in
           assert_bool "save requested" (save <> None);
           assert_equal None (snd (Collect.take_save_request t));
           (* the verdict times out and the next figure is asked for *)
           let t = frame ~dt:3. t [] in
           assert_equal Collect.Prompt (Collect.phase t);
           assert_equal (Some "Cassiopeia") (Option.map Asterism.name (Collect.target t)));
         ("win" >:: fun _ ->
           let rec play t n =
             if n > 20 then assert_failure "never completed"
             else match Collect.phase t with
               | Collect.Complete -> t
               | _ -> play (frame ~dt:3. (draw_in t (as_stroke (target_shape t))) []) (n + 1)
           in
           let t = play (frame (start ()) []) 0 in
           assert_bool "complete" (Collection.is_complete (Collect.collection t));
           assert_equal None (Collect.target t);
           (* winning never closes the game: time, clicks and keys keep the
              win screen up, and Enter asks for the case screen *)
           let t = frame ~dt:60. t [ Controls.Pen_down (p 1. 1.); Controls.Pen_up; Controls.Clear ] in
           assert_equal Collect.Complete (Collect.phase t);
           assert_bool "no quit" (not (Collect.wants_quit t));
           assert_bool "no cases yet" (not (Collect.wants_cases t));
           let t = frame t [ Controls.Dismiss ] in
           assert_bool "Enter opens the cases" (Collect.wants_cases t);
           assert_bool "still no quit" (not (Collect.wants_quit t)));
         ("five_strikes_quit" >:: fun _ ->
           let line = sample_polyline 3. [| p 0. 0.; p 300. 5. |] in
           let rec miss t k =
             let t = draw_in t line in
             (* each insult waits for Enter before the next drawing *)
             if k < 5 then miss (frame t [ Controls.Dismiss ]) (k + 1) else t
           in
           let t = miss (frame (start ()) []) 1 in
           (match Collect.phase t with
           | Collect.Dissed line -> assert_bool "diss" (String.length line > 0)
           | _ -> assert_failure "expected Dissed");
           assert_bool "waiting for Enter" (Collect.waiting_for_enter t);
           assert_bool "not yet" (not (Collect.wants_quit t));
           (* no timer: still up a minute later *)
           let t = frame ~dt:60. t [] in
           assert_bool "still not quitting after 60 s" (not (Collect.wants_quit t));
           (* clicks, drawing and other keys are ignored *)
           let t = frame t [ Controls.Pen_down (p 1. 1.) ] in
           let t = frame t [ Controls.Pen_up; Controls.Clear; Controls.Save_card ] in
           assert_bool "still not quitting after input" (not (Collect.wants_quit t));
           (* Enter ends the game *)
           let t = frame t [ Controls.Dismiss ] in
           assert_bool "quits on Enter" (Collect.wants_quit t);
           assert_bool "no longer waiting" (not (Collect.waiting_for_enter t)));
         ("insult_waits_for_enter" >:: fun _ ->
           let line = sample_polyline 3. [| p 0. 0.; p 300. 5. |] in
           let t = draw_in (frame (start ()) []) line in
           assert_bool "insulted" (Collect.waiting_for_enter t);
           (* no timer: still showing a minute later *)
           let t = frame ~dt:60. t [] in
           assert_bool "still showing after 60 s" (Collect.waiting_for_enter t);
           (* drawing, clearing and other keys don't dismiss it *)
           let t = frame t [ Controls.Pen_down (p 5. 5.) ] in
           let t = frame t [ Controls.Pen_down (p 90. 5.) ] in
           let t = frame t [ Controls.Pen_up ] in
           let t = frame t [ Controls.Clear; Controls.Save_card ] in
           assert_bool "still showing after clicks and keys" (Collect.waiting_for_enter t);
           assert_equal 1 (Roast.strikes (Collect.roast t));
           (* Enter moves on to the next prompt *)
           let t = frame t [ Controls.Dismiss ] in
           assert_bool "dismissed" (not (Collect.waiting_for_enter t));
           assert_equal Collect.Prompt (Collect.phase t));
         ("passing_verdict_still_times_out" >:: fun _ ->
           let t = frame (start ()) [] in
           let t = draw_in t (as_stroke (Asterism.shape (Option.get (Collect.target t)))) in
           assert_bool "not waiting for Enter" (not (Collect.waiting_for_enter t));
           let t = frame ~dt:(Collect.verdict_seconds +. 0.1) t [] in
           assert_equal Collect.Prompt (Collect.phase t));
         ("clear" >:: fun _ ->
           let t = frame (start ()) [] in
           let t = frame t [ Controls.Pen_down (p 1. 1.) ] in
           let t = frame t [ Controls.Pen_down (p 50. 1.); Controls.Clear ] in
           assert_equal Collect.Prompt (Collect.phase t);
           assert_equal 0 (Array.length (Collect.stroke t))) ]

(* ---------------- welcome page ---------------- *)

let item ?(enabled = true) label action = { Menu.label; detail = None; action; enabled }

let menu_tests =
  let m () = Menu.create [ item ~enabled:false "off" 0; item "a" 1; item "b" 2; item ~enabled:false "x" 3 ] in
  let rects m = Menu.layout m ~width:1280 ~height:800 in
  "menu"
  >::: [ ("create" >:: fun _ ->
           assert_equal 1 (Menu.selected_index (m ()));
           assert_raises (Invalid_argument "Menu.create: no enabled item") (fun () ->
               Menu.create [ item ~enabled:false "off" 0 ]));
         ("keys_skip_disabled_and_wrap" >:: fun _ ->
           let m = m () in
           let r = rects m in
           let down m = fst (Menu.apply m ~rects:r Menu.Down) and up m = fst (Menu.apply m ~rects:r Menu.Up) in
           assert_equal 2 (Menu.selected_index (down m));
           assert_equal 1 (Menu.selected_index (down (down m)));
           assert_equal 2 (Menu.selected_index (up m));
           assert_equal (Some 1) (snd (Menu.apply m ~rects:r Menu.Choose)));
         ("mouse" >:: fun _ ->
           let m = m () in
           let r = rects m in
           let centre i = p (r.(i).x +. (r.(i).w /. 2.)) (r.(i).y +. (r.(i).h /. 2.)) in
           assert_equal 2 (Menu.selected_index (fst (Menu.apply m ~rects:r (Menu.Point (centre 2)))));
           assert_equal (Some 2) (snd (Menu.apply m ~rects:r (Menu.Click (centre 2))));
           assert_equal None (snd (Menu.apply m ~rects:r (Menu.Click (centre 0))));
           assert_equal None (snd (Menu.apply m ~rects:r (Menu.Click (p (-5.) (-5.))))));
         ("layout_and_hit" >:: fun _ ->
           let r = rects (m ()) in
           assert_equal 4 (Array.length r);
           Array.iter (fun (q : Menu.rect) ->
               assert_bool "inside window" (q.x >= 0. && q.y >= 0. && q.x +. q.w <= 1280. && q.y +. q.h <= 800.)) r;
           let one = [| { Menu.x = 0.; y = 0.; w = 10.; h = 10. } |] in
           assert_equal (Some 0) (Menu.item_at one (p 10. 10.));
           assert_equal None (Menu.item_at one (p 10.1 5.)));
         ("read" >:: fun _ ->
           let base = Scene.idle ~width:800 ~height:600 in
           assert_equal [ Menu.Down; Menu.Choose; Menu.Point (p 0. 0.) ]
             (Menu.read { base with keys = [ Scene.Down; Scene.Enter ] });
           assert_equal [ Menu.Point (p 3. 4.); Menu.Click (p 3. 4.) ]
             (Menu.read { base with mouse = p 3. 4.; mouse_pressed = true })) ]

let attract_tests =
  let box = { Menu.x = 0.; y = 0.; w = 400.; h = 300. } in
  "attract"
  >::: [ ("empty" >:: fun _ ->
           let a = Attract.create [||] in
           assert_equal None (Attract.current a);
           assert_equal 0 (Array.length (Attract.visible_path a ~box));
           assert_equal 0 (Array.length (Attract.star_points (Attract.step 10. a) ~box)));
         ("draws_then_moves_on" >:: fun _ ->
           let fs = Lazy.force figures in
           let a = Attract.create fs in
           assert_equal 0 (Array.length (Attract.visible_path a ~box));
           let half = Attract.step (Attract.seconds_per_figure /. 2.) a in
           (match Attract.current half with
           | Some (f, frac) -> assert_equal "Big Dipper" (Asterism.name f); assert_feq "half" 0.5 frac
           | None -> assert_failure "no figure");
           let full = Attract.step Attract.seconds_per_figure a in
           let path = Attract.visible_path full ~box in
           let stars = Attract.star_points full ~box in
           assert_equal 7 (Array.length stars);
           Array.iter (fun (q : pt) -> assert_bool "in box" (q.x >= 0. && q.x <= 400. && q.y >= 0. && q.y <= 300.)) path;
           assert_feq "ends at last star" 0. (dist path.(Array.length path - 1) (Attract.star_points full ~box).(3)) ~eps:1e-6;
           assert_feq "opaque" 1. (Attract.alpha full);
           let next = Attract.step (Attract.seconds_per_figure +. Attract.hold_seconds +. 0.1) a in
           assert_equal (Some "Cassiopeia") (Option.map (fun (f, _) -> Asterism.name f) (Attract.current next));
           let wrapped = Attract.step (7. *. (Attract.seconds_per_figure +. Attract.hold_seconds)) a in
           assert_equal (Some "Big Dipper") (Option.map (fun (f, _) -> Asterism.name f) (Attract.current wrapped))) ]

let title_tests =
  let s = Some { Title.collected = 3; total = 7; best_average = Some 71.4; cases = 2; packs_owned = 1 } in
  let fresh () = Title.init (Lazy.force figures) s in
  let base = Scene.idle ~width:1280 ~height:800 in
  let keys ks t = Title.update { base with keys = ks } t in
  "title"
  >::: [ ("main_items" >:: fun _ ->
           let items = Title.main_items s in
           assert_equal 6 (List.length items);
           assert_equal (Some "3 / 7 collected - avg best 71.4%") (List.hd items).detail;
           assert_equal (Some "2 cases - 1 / 9 packs") (List.nth items 1).detail;
           let none = Title.main_items None in
           assert_bool "collect off without figures" (not (List.hd none).enabled);
           assert_bool "reset off without progress" (not (List.nth none 4).enabled));
         ("go_places" >:: fun _ ->
           assert_equal Title.(Go "collect") (snd (keys [ Scene.Enter ] (fresh ())));
           let t, _ = keys [ Scene.Down ] (fresh ()) in
           assert_equal Title.(Go "cases") (snd (keys [ Scene.Enter ] t));
           let t, _ = keys [ Scene.Down ] t in
           assert_equal Title.(Go "play") (snd (keys [ Scene.Enter ] t));
           (* Esc selects Quit; only a second Esc (on Quit) closes the game *)
           let t, o = keys [ Scene.Escape ] (fresh ()) in
           assert_equal Title.Stay o;
           assert_equal 5 (Menu.selected_index (Title.menu t));
           assert_equal Title.Quit (snd (keys [ Scene.Escape ] t)));
         ("help" >:: fun _ ->
           let t, _ = keys [ Scene.Down ] (fresh ()) in
           let t, _ = keys [ Scene.Down ] t in
           let t, _ = keys [ Scene.Down ] t in
           let t, o = keys [ Scene.Enter ] t in
           assert_equal Title.Stay o;
           assert_equal Title.Help (Title.page t);
           let t, _ = Title.update base t in
           assert_equal Title.Help (Title.page t);
           let t, _ = keys [ Scene.Space ] t in
           assert_equal Title.Main (Title.page t));
         ("reset_flow" >:: fun _ ->
           let to_reset t = List.fold_left (fun t _ -> fst (keys [ Scene.Down ] t)) t [ 1; 2; 3; 4 ] in
           let t, _ = keys [ Scene.Enter ] (to_reset (fresh ())) in
           assert_equal Title.Confirm_reset (Title.page t);
           assert_equal 0 (Menu.selected_index (Title.menu t));
           let back, _ = keys [ Scene.Escape ] t in
           assert_equal Title.Main (Title.page back);
           let no, o = keys [ Scene.Enter ] t in
           assert_equal Title.Stay o;
           assert_equal Title.Main (Title.page no);
           let t, _ = keys [ Scene.Down ] t in
           let t, o = keys [ Scene.Enter ] t in
           assert_equal Title.Reset o;
           let t = Title.after_reset t in
           assert_equal Title.Main (Title.page t);
           (match Title.summary t with
           | Some { collected = 0; best_average = None; _ } -> ()
           | _ -> assert_failure "summary not cleared");
           assert_bool "reset now disabled" (not (List.nth (Menu.items (Title.menu t)) 4).enabled));
         ("resting_mouse" >:: fun _ ->
           (* a mouse resting on Quit must not undo the arrow keys every frame *)
           let t = fresh () in
           let r = Menu.layout (Title.menu t) ~width:1280 ~height:800 in
           let on_quit = p (r.(5).x +. 10.) (r.(5).y +. 10.) in
           let t, _ = Title.update { base with mouse = on_quit } t in
           assert_equal 5 (Menu.selected_index (Title.menu t));
           let t, _ = Title.update { base with mouse = on_quit; keys = [ Scene.Up ] } t in
           assert_equal 4 (Menu.selected_index (Title.menu t)));
         ("help_text" >:: fun _ ->
           let all = String.concat " " Title.help_lines in
           let has sub =
             let n = String.length all and m = String.length sub in
             let rec go i = i + m <= n && (String.sub all i m = sub || go (i + 1)) in
             go 0
           in
           assert_bool "pass mark" (has "50.0%");
           assert_bool "strikes" (has "5 strikes")) ]

(* ---------------- case openings ---------------- *)

let case_tests =
  let rng seed = Random.State.make [| seed |] in
  let one_case = Inventory.add_cases 1 Inventory.empty in
  "cases"
  >::: [ ("rarity_odds" >:: fun _ ->
           let total = List.fold_left (fun a r -> a +. Rarity.odds r) 0. Rarity.all in
           assert_feq ~eps:1e-9 "odds sum to 1" 1. total;
           assert_equal Rarity.Mil_spec (Rarity.of_roll 0.);
           assert_equal Rarity.Mil_spec (Rarity.of_roll 0.7991);
           assert_equal Rarity.Restricted (Rarity.of_roll 0.7993);
           assert_equal Rarity.Exceedingly_rare (Rarity.of_roll 0.9999);
           assert_equal "Exceedingly Rare" (Rarity.label Rarity.Exceedingly_rare));
         ("rolls_follow_odds" >:: fun _ ->
           (* 20,000 rolls land close to CS2's published odds *)
           let r = rng 7 and n = 20000 in
           let counts = Hashtbl.create 5 in
           for _ = 1 to n do
             let t = Rarity.of_roll (Random.State.float r 1.) in
             Hashtbl.replace counts t (1 + Option.value ~default:0 (Hashtbl.find_opt counts t))
           done;
           let share t = float_of_int (Option.value ~default:0 (Hashtbl.find_opt counts t)) /. float_of_int n in
           assert_feq ~eps:0.015 "mil-spec" 0.7992 (share Rarity.Mil_spec);
           assert_feq ~eps:0.01 "restricted" 0.1598 (share Rarity.Restricted);
           assert_feq ~eps:0.005 "classified" 0.032 (share Rarity.Classified));
         ("packs" >:: fun _ ->
           assert_equal 9 (List.length Insult_pack.all);
           assert_equal [ 4; 2; 1; 1; 1 ]
             (List.map (fun r -> List.length (Insult_pack.of_rarity r)) Rarity.all);
           let ids = List.map (fun (p : Insult_pack.t) -> p.id) Insult_pack.all in
           assert_equal (List.length ids) (List.length (List.sort_uniq compare ids));
           List.iter
             (fun (p : Insult_pack.t) ->
               assert_equal ~msg:p.id 5 (List.length p.insults);
               (* placeholders fill in cleanly: no stray braces left *)
               List.iter
                 (fun line ->
                   let filled = Roast.insult line ~score:12.3 ~target:"Leo" in
                   assert_bool (p.id ^ ": " ^ filled) (not (String.contains filled '{')))
                 (p.insults @ p.final_disses))
             Insult_pack.all;
           assert_equal (Some "Event Horizon")
             (Option.map (fun (p : Insult_pack.t) -> p.name) (Insult_pack.find "black_hole")));
         ("inventory" >:: fun _ ->
           let inv = Inventory.add_cases 2 Inventory.empty in
           assert_equal 2 (Inventory.cases inv);
           let inv = Option.get (Inventory.spend_case inv) in
           let inv = Option.get (Inventory.spend_case inv) in
           assert_equal None (Inventory.spend_case inv);
           let inv = Inventory.unlock "black_hole" (Inventory.unlock "nope" inv) in
           let inv = Inventory.unlock "black_hole" inv in
           assert_equal 1 (List.length (Inventory.owned_packs inv));
           assert_equal 5 (List.length (Inventory.extra_insults inv));
           assert_equal 1 (List.length (Inventory.extra_disses inv));
           assert_raises (Invalid_argument "Inventory.add_cases: negative") (fun () ->
               Inventory.add_cases (-1) inv));
         ("inventory_save_load" >:: fun _ ->
           let inv = Inventory.add_cases 3 Inventory.empty |> Inventory.unlock "supernova"
                     |> Inventory.unlock "gift_shop" in
           let path = Filename.temp_file "unlocks" ".csv" in
           Inventory.save path inv;
           let back = Inventory.load path in
           assert_equal 3 (Inventory.cases back);
           assert_bool "supernova" (Inventory.owns back "supernova");
           assert_bool "gift shop" (Inventory.owns back "gift_shop");
           assert_equal 0 (Inventory.cases (Inventory.load "missing.csv")));
         ("roll_prefers_new_packs" >:: fun _ ->
           let r = rng 3 in
           for _ = 1 to 200 do
             let _, dup = Case.roll r ~owned:(fun _ -> false) in
             assert_bool "nothing owned, never a duplicate" (not dup)
           done;
           let p, dup = Case.roll r ~owned:(fun _ -> true) in
           assert_bool ("everything owned, always a duplicate: " ^ p.id) dup);
         ("reel" >:: fun _ ->
           let s = Case.open_case (rng 11) ~owned:(fun _ -> false) in
           assert_equal Case.reel_length (Array.length s.reel);
           assert_bool "winner on the reel" (s.reel.(s.winner_index) == s.won);
           assert_feq "starts at 0" 0. (Case.position 0.);
           assert_feq "stops on the winner" (float_of_int Case.winner_slot) (Case.position Case.spin_seconds);
           assert_bool "slows down" (Case.position 1. -. Case.position 0. > Case.position 6. -. Case.position 5.);
           assert_bool "finished" (Case.finished Case.spin_seconds));
         ("opening_flow" >:: fun _ ->
           let t = Case_opening.init ~seed:5 Inventory.empty in
           let t = Case_opening.apply t Controls.Dismiss in
           assert_equal Case_opening.Idle (Case_opening.phase t);
           let t = Case_opening.init ~seed:5 one_case in
           let t = Case_opening.apply t Controls.Dismiss in
           let won =
             match Case_opening.phase t with
             | Case_opening.Spinning (s, _) -> s.won
             | _ -> assert_failure "expected Spinning"
           in
           (* unlocked immediately, case spent, save requested *)
           assert_equal 0 (Inventory.cases (Case_opening.inventory t));
           assert_bool "unlocked" (Inventory.owns (Case_opening.inventory t) won.id);
           let t, save = Case_opening.take_save_request t in
           assert_bool "save requested" (save <> None);
           (* the reel can't be skipped *)
           let t = Case_opening.apply t Controls.Dismiss in
           (match Case_opening.phase t with Case_opening.Spinning _ -> () | _ -> assert_failure "skipped");
           let t = Case_opening.tick (Case.spin_seconds +. 0.1) t in
           (match Case_opening.phase t with Case_opening.Revealed _ -> () | _ -> assert_failure "not revealed");
           (* a release without a press on this screen is not a click *)
           let t0 = Case_opening.apply t Controls.Pen_up in
           (match Case_opening.phase t0 with Case_opening.Revealed _ -> () | _ -> assert_failure "stray release");
           let t = Case_opening.apply (Case_opening.apply t (Controls.Pen_down (p 1. 1.))) Controls.Pen_up in
           assert_equal Case_opening.Idle (Case_opening.phase t));
         ("roast_uses_packs" >:: fun _ ->
           (* with only the extras pickable at this seed, the pack line appears *)
           let line = "PACK LINE {score}" in
           let found = ref false in
           for seed = 0 to 40 do
             let r = Roast.create ~seed ~extra_insults:[ line ] () in
             match snd (Roast.miss r ~score:10. ~target:"Leo") with
             | Roast.Insult l when l = "PACK LINE 10.0%" -> found := true
             | _ -> ()
           done;
           assert_bool "pack insults are in the pool" !found);
         ("collect_earns_cases" >:: fun _ ->
           let t = frame (Collect.init (Collection.create (Lazy.force figures)) (Roast.create ())) [] in
           let target = Asterism.shape (Option.get (Collect.target t)) in
           let t = draw_in t (as_stroke target) in
           let t, n = Collect.take_earned_cases t in
           assert_equal ~msg:"collecting a new constellation" 1 n;
           assert_equal 0 (snd (Collect.take_earned_cases t));
           assert_bool "Collected_new earns" (Collect.earns_case (Judge.Collected_new { score = 60.; tier = Accuracy.Collected }));
           assert_bool "an insult doesn't" (not (Collect.earns_case (Judge.Insulted { score = 1.; line = ""; strikes_left = 4 })))) ]

let () =
  run_test_tt_main
    ("doodle"
    >::: [ geom_tests; simplify_tests; capture_tests; catalogue_tests; index_tests;
           matching_tests; visibility_tests; morph_tests; narrate_tests; engine_tests;
           scene_tests; controls_tests; game_tests; data_dir_tests; asterism_tests;
           accuracy_tests; roast_tests; collection_tests; judge_tests; collect_tests;
           menu_tests; attract_tests; title_tests; case_tests ])
