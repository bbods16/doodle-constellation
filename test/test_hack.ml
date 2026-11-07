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

let () =
  run_test_tt_main
    ("doodle"
    >::: [ geom_tests; simplify_tests; capture_tests; catalogue_tests; index_tests;
           matching_tests; visibility_tests; morph_tests; narrate_tests; engine_tests ])
