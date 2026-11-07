(* Doodle Constellation: draw a shape, find it in the stars.

   Usage: hack [LAT_DEG LON_DEG] [CATALOGUE.csv]
   Keys:  drag with the left mouse button to draw, C clears,
          S saves a share card, N asks for an (invented) story. *)

open Raylib

type stage =
  | Drawing                                   (* waiting for / capturing a stroke *)
  | Hint of string                            (* stroke refused, show why *)
  | Morphing of Morph.t * Geom.pt array * Fitter.fit
  | Showing of Geom.pt array * Fitter.fit

let width = 1280
let height = 800

(**
   [parse_args argv] reads the optional location and catalogue path.
   Requires: nothing
   Returns: [((lat, lon), path)] with angles in radians; defaults to
            {!Visibility.buffalo} and ["data/stars.csv"]
   Raises: nothing (unparsable numbers fall back to the defaults)
   Example: parse_args [|"hack"; "40.7"; "-74.0"|] = ((rad 40.7, rad (-74.)), "data/stars.csv")
   Complexity: O(1) time, O(1) space
   Pseudocode:
     match argv with
       | [_; lat; lon; path] -> ((rad lat, rad lon), path)
       | [_; lat; lon]       -> ((rad lat, rad lon), default path)
       | [_; path]           -> (buffalo, path)
       | _                   -> (buffalo, default path)
*)
let parse_args argv =
  let default_path = "data/stars.csv" in
  let loc lat lon =
    match (float_of_string_opt lat, float_of_string_opt lon) with
    | Some a, Some b -> (Geom.rad a, Geom.rad b)
    | _ -> Visibility.buffalo
  in
  match argv with
  | [| _; lat; lon; path |] -> (loc lat lon, path)
  | [| _; lat; lon |] -> (loc lat lon, default_path)
  | [| _; path |] -> (Visibility.buffalo, path)
  | _ -> (Visibility.buffalo, default_path)

(**
   [hint_of reason] is the on-screen text for a refused stroke (gap G4).
   Requires: nothing
   Returns: a short instruction
   Raises: nothing
   Example: hint_of `Too_simple = "Too simple - add a few sharp corners"
   Complexity: O(1) time, O(1) space
   Pseudocode:
     Too_simple -> ask for more corners ; Too_complex -> ask for fewer
*)
let hint_of = function
  | `Too_simple -> "Too simple - add a few sharp corners (5 to 9)"
  | `Too_complex -> "Too busy - try a bolder shape with 5 to 9 corners"

(**
   [mirror_about_centroid c pts] reflects [pts] top-to-bottom about the
   centroid of [c], so a mirrored fit animates from a matching stroke.
   Requires: [c] non-empty
   Returns: reflected copy of [pts]
   Raises: [Invalid_argument] if [c] is empty
   Example: mirror_about_centroid [|{x=0.;y=0.};{x=0.;y=2.}|] [|{x=0.;y=0.}|] = [|{x=0.;y=2.}|]
   Complexity: O(n) time, O(n) space
   Pseudocode:
     cy <- (centroid c).y
     return map (fun p -> (p.x, 2 cy - p.y)) pts
*)
let mirror_about_centroid c pts =
  let cy = (Geom.centroid c).y in
  Array.map (fun (p : Geom.pt) -> { p with y = (2. *. cy) -. p.y }) pts

(**
   [main ()] runs the window loop.
   Requires: a display; the catalogue file exists
   Returns: unit when the window closes
   Raises: [Sys_error] if the catalogue is missing
   Example: main () opens the "Doodle Constellation" window
   Complexity: O(N m^2) start-up (index build), then per frame O(N)
   Pseudocode:
     load catalogue, build index, load the engine if its weights exist,
     open window
     loop until window closes:
       mouse down  -> add sample to capture (start a new stroke if not Drawing)
       mouse up    -> guess <- top class of Engine.classify stroke
                      corners <- Simplify.corners stroke
                      Error r -> stage Hint (hint_of r)
                      Ok c    -> fit <- Fitter.best (Candidates.generate index c)
                                 None -> Hint "no match"
                                 Some f -> view <- view_for f
                                           target <- screen positions of f.stars
                                           stage Morphing (Morph.start c target)
       Morphing    -> step by frame time ; Showing when finished
       keys C / S / N -> clear, save card, request story
       draw sky, stroke (morphed), info, hint, engine guess and story
*)
let main () =
  let (lat, lon), path = parse_args Sys.argv in
  let stars = Catalogue.load path in
  let index = Index.build stars in
  let engine =
    let path = Filename.concat (Filename.dirname path) "engine_weights.txt" in
    if Sys.file_exists path then (try Some (Engine.load path) with Failure _ -> None) else None
  in
  let guess = ref None in
  init_window width height "Doodle Constellation";
  set_target_fps 60;
  let view = ref (Sky.empty_view stars ~width ~height) in
  let capture = ref Capture.empty in
  let stage = ref Drawing in
  let best_view = ref None in
  let story : string option Atomic.t = Atomic.make None in
  let save_next = ref false in
  while not (window_should_close ()) do
    (* ---- input ---- *)
    if is_mouse_button_down MouseButton.Left then begin
      (match !stage with
      | Drawing -> ()
      | _ ->
          capture := Capture.empty;
          stage := Drawing;
          guess := None;
          Atomic.set story None);
      let m = get_mouse_position () in
      capture := Capture.add !capture { Geom.x = Vector2.x m; y = Vector2.y m }
    end;
    if is_mouse_button_released MouseButton.Left && not (Capture.is_empty !capture) then begin
      let stroke = Capture.stroke !capture in
      guess := Option.bind engine (fun m -> List.nth_opt (Engine.classify m stroke) 0);
      match Simplify.corners stroke with
      | Error r -> stage := Hint (hint_of r)
      | Ok c -> (
          match Fitter.best stars (Candidates.generate index c) with
          | None -> stage := Hint "No stars match that shape - try another"
          | Some f ->
              view := Sky.view_for stars f ~width ~height;
              let target =
                Array.map (fun i -> Sky.to_screen !view (Catalogue.position stars.(i))) f.stars
              in
              let c, stroke =
                if f.mirrored then (mirror_about_centroid c c, mirror_about_centroid c stroke)
                else (c, stroke)
              in
              let ra, dec = f.centre in
              best_view := Some (Visibility.best_view ~lat ~lon ~ra ~dec ~now:(Unix.gettimeofday ()));
              stage := Morphing (Morph.start ~drawn:c ~target, stroke, f))
    end;
    (match !stage with
    | Morphing (m, stroke, f) ->
        let m = Morph.step m (get_frame_time ()) in
        stage := if Morph.finished m then Showing (Morph.current m stroke, f) else Morphing (m, stroke, f)
    | _ -> ());
    if is_key_pressed Key.C then begin
      capture := Capture.empty;
      stage := Drawing;
      view := Sky.empty_view stars ~width ~height;
      guess := None;
      Atomic.set story None
    end;
    if is_key_pressed Key.S then save_next := true;
    if is_key_pressed Key.N then begin
      match !stage with
      | Showing (_, f) | Morphing (_, _, f) ->
          let labels = Array.to_list (Array.map (fun i -> Catalogue.label stars.(i)) f.stars) in
          let neighbour = stars.(f.stars.(0)).con in
          Narrate.story_async { Narrate.shape = "Doodle"; stars = labels; neighbour } (fun s ->
              Atomic.set story s)
      | _ -> ()
    end;
    (* ---- drawing ---- *)
    begin_drawing ();
    clear_background (Color.create 8 10 24 255);
    (match !stage with
    | Drawing ->
        Sky.draw !view None;
        Sky.draw_stroke (Capture.stroke !capture);
        draw_text "Draw a shape with 5 to 9 corners" 20 20 20 Color.lightgray
    | Hint msg ->
        Sky.draw !view None;
        Sky.draw_stroke (Capture.stroke !capture);
        draw_text msg 20 20 20 Color.gold
    | Morphing (m, stroke, f) ->
        Sky.draw !view (Some f);
        Sky.draw_stroke (Morph.current m stroke)
    | Showing (stroke, f) ->
        Sky.draw !view (Some f);
        Sky.draw_stroke stroke;
        Sky.draw_info ~fit:f ~best:!best_view);
    (match !guess with
    | Some (name, p) ->
        let label =
          if name = Engine.none_label then "Engine: no known figure"
          else Printf.sprintf "Engine: %s (%.0f%%)" name (100. *. p)
        in
        draw_text label (width - 20 - measure_text label 20) 20 20 Color.skyblue
    | None -> ());
    (match Atomic.get story with
    | Some s ->
        draw_text s 20 60 18 Color.raywhite;
        draw_text Narrate.fiction_label 20 84 14 Color.gray
    | None -> ());
    end_drawing ();
    if !save_next then begin
      Sky.save_card "doodle_card.png";
      save_next := false
    end
  done;
  close_window ()

let () = main ()
