(**
   File: game.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Game module: the free-draw game rules - one
                function per command (pen down/up, tick, clear, story), each
                delegating to a lower layer.
   Usage: The contract is in game.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Game (or Game with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(* The drawing game's rules. See game.mli for the public contract. *)

type stage =
  | Drawing
  | Hint of string
  | Morphing of Morph.t * Geom.pt array * Fitter.fit
  | Showing of Geom.pt array * Fitter.fit

type t = {
  capture : Capture.t;
  stage : stage;
  view : Projection.view option;
  best : (float * float * float) option;
  guess : (string * float) option;
  story : string option Atomic.t;
}

type screen = { width : int; height : int; now : float }

(**
   [init ()] is a blank sky.
   Requires: nothing
   Returns: fresh state
   Raises: nothing
   Example: (init ()).stage = Drawing
   Complexity: O(1)
   Pseudocode:
     return { empty capture; Drawing; no view, best or guess; new story slot }
*)
let init () =
  { capture = Capture.empty; stage = Drawing; view = None; best = None; guess = None;
    story = Atomic.make None }

(**
   [clear t] starts over.
   Requires: nothing
   Returns: [init ()]
   Raises: nothing
   Example: (clear t).stage = Drawing
   Complexity: O(1)
   Pseudocode:
     return init ()
*)
let clear _t = init ()

(**
   [hint_of reason] explains a refused stroke.
   Requires: nothing
   Returns: a short instruction
   Raises: nothing
   Example: hint_of `Too_simple = "Too simple - add a few sharp corners (5 to 9)"
   Complexity: O(1)
   Pseudocode:
     Too_simple -> ask for more corners ; Too_complex -> ask for fewer
*)
let hint_of = function
  | `Too_simple -> "Too simple - add a few sharp corners (5 to 9)"
  | `Too_complex -> "Too busy - try a bolder shape with 5 to 9 corners"

(**
   [mirror_about_centroid c pts] reflects [pts] about the centroid of [c].
   Requires: [c] non-empty
   Returns: reflected copy
   Raises: [Invalid_argument] if [c] is empty
   Example: mirror_about_centroid [|{x=0.;y=0.};{x=0.;y=2.}|] [|{x=0.;y=0.}|] = [|{x=0.;y=2.}|]
   Complexity: O(n)
   Pseudocode:
     cy <- (centroid c).y
     return map (fun p -> (p.x, 2 cy - p.y)) pts
*)
let mirror_about_centroid c pts =
  let cy = (Geom.centroid c).y in
  Array.map (fun (p : Geom.pt) -> { p with y = (2. *. cy) -. p.y }) pts

(**
   [pen_down p t] adds a sample, starting a new stroke if needed.
   Requires: screen pixels
   Returns: state in [Drawing]
   Raises: nothing
   Example: Capture.length (pen_down p (init ())).capture = 1
   Complexity: O(Capture.window)
   Pseudocode:
     t <- if stage = Drawing then t else clear t
     return { t with capture = Capture.add t.capture p }
*)
let pen_down p t =
  let t = match t.stage with Drawing -> t | _ -> clear t in
  { t with capture = Capture.add t.capture p }

(**
   [recognise ctx stroke] is the engine's best guess.
   Requires: non-empty stroke
   Returns: [Some (class, p)] or [None] without an engine
   Raises: nothing
   Example: recognise ctx dipper_stroke = Some ("Big Dipper", 0.99)
   Complexity: one forward pass
   Pseudocode:
     match ctx.engine with
       | None -> None
       | Some m -> first element of Engine.classify m stroke
*)
let recognise (ctx : Scene.ctx) stroke =
  Option.bind (Scene.engine ctx) (fun m -> List.nth_opt (Engine.classify m stroke) 0)

(**
   [match_stroke ctx stroke] finds the stroke in the sky.
   Requires: nothing
   Returns: [Ok (corners, fit)] or [Error hint]
   Raises: nothing
   Example: match_stroke ctx straight_line = Error "Too simple - ..."
   Complexity: candidate generation and fitting
   Pseudocode:
     match Simplify.corners stroke with
       | Error r -> Error (hint_of r)
       | Ok c -> match Fitter.best stars (Candidates.generate index c) with
                   | None -> Error "No stars match that shape - try another"
                   | Some f -> Ok (c, f)
*)
let match_stroke (ctx : Scene.ctx) stroke =
  match Simplify.corners stroke with
  | Error r -> Error (hint_of r)
  | Ok c -> (
      match Fitter.best (Scene.stars ctx) (Candidates.generate (Scene.index ctx) c) with
      | None -> Error "No stars match that shape - try another"
      | Some f -> Ok (c, f))

(**
   [begin_morph ctx screen ~corners ~stroke fit t] starts the animation.
   Requires: corners match [fit.stars]
   Returns: state in [Morphing]
   Raises: nothing
   Example: (begin_morph ctx screen ~corners ~stroke fit t).stage = Morphing (...)
   Complexity: O(n + s)
   Pseudocode:
     view <- Projection.view_for stars fit (screen size)
     target <- Projection.to_screen view of each matched star
     if fit mirrored then reflect corners and stroke about the corners' centroid
     best <- Visibility.best_view at the fit centre from screen.now
     return { t with view; best; stage = Morphing (Morph.start corners target, stroke, fit) }
*)
let begin_morph (ctx : Scene.ctx) screen ~corners ~stroke (fit : Fitter.fit) t =
  let view = Projection.view_for (Scene.stars ctx) fit ~width:screen.width ~height:screen.height in
  let target =
    Array.map (fun i -> Projection.to_screen view (Catalogue.position (Scene.stars ctx).(i))) fit.stars
  in
  let corners, stroke =
    if fit.mirrored then (mirror_about_centroid corners corners, mirror_about_centroid corners stroke)
    else (corners, stroke)
  in
  let ra, dec = fit.centre in
  let lat, lon = Scene.location ctx in
  let best = Visibility.best_view ~lat ~lon ~ra ~dec ~now:screen.now in
  { t with view = Some view; best = Some best;
    stage = Morphing (Morph.start ~drawn:corners ~target, stroke, fit) }

(**
   [pen_up ctx screen t] finishes the stroke.
   Requires: nothing
   Returns: state in [Hint] or [Morphing] (unchanged if nothing captured)
   Raises: nothing
   Example: (pen_up ctx screen t).stage = Morphing (...) for a Big Dipper drawing
   Complexity: dominated by match_stroke
   Pseudocode:
     if nothing captured then return t
     stroke <- Capture.stroke t.capture
     t <- { t with guess = recognise ctx stroke }
     match match_stroke ctx stroke with
       | Error hint -> { t with stage = Hint hint }
       | Ok (c, f) -> begin_morph ctx screen ~corners:c ~stroke f t
*)
let pen_up ctx screen t =
  if Capture.is_empty t.capture then t
  else begin
    let stroke = Capture.stroke t.capture in
    let t = { t with guess = recognise ctx stroke } in
    match match_stroke ctx stroke with
    | Error hint -> { t with stage = Hint hint }
    | Ok (corners, fit) -> begin_morph ctx screen ~corners ~stroke fit t
  end

(**
   [tick dt t] advances the morph.
   Requires: [dt >= 0.]
   Returns: the advanced state
   Raises: nothing
   Example: (tick 10. morphing).stage = Showing (...)
   Complexity: O(1), O(s) when finishing
   Pseudocode:
     match stage with
       | Morphing (m, stroke, f) ->
           m <- Morph.step m dt
           if finished then Showing (Morph.current m stroke, f) else Morphing (m, stroke, f)
       | other -> unchanged
*)
let tick dt t =
  match t.stage with
  | Morphing (m, stroke, f) ->
      let m = Morph.step m dt in
      let stage =
        if Morph.finished m then Showing (Morph.current m stroke, f) else Morphing (m, stroke, f)
      in
      { t with stage }
  | Drawing | Hint _ | Showing _ -> t

(**
   [current_fit t] is the match on screen, if any.
   Requires: nothing
   Returns: [Some fit] in Morphing and Showing
   Raises: nothing
   Example: current_fit (init ()) = None
   Complexity: O(1)
   Pseudocode:
     Morphing (_, _, f) | Showing (_, f) -> Some f ; otherwise None
*)
let current_fit t =
  match t.stage with
  | Morphing (_, _, f) | Showing (_, f) -> Some f
  | Drawing | Hint _ -> None

(**
   [ask_story ctx t] requests a story in the background.
   Requires: nothing
   Returns: [t]
   Raises: nothing
   Example: ask_story ctx (init ()) == init state
   Complexity: O(n)
   Pseudocode:
     match current_fit t with
       | None -> ()
       | Some f -> labels <- star labels ; neighbour <- first star's constellation
                   Narrate.story_async { "Doodle"; labels; neighbour } (store in t.story)
     return t
*)
let ask_story (ctx : Scene.ctx) t =
  (match current_fit t with
  | None -> ()
  | Some f ->
      let stars = Scene.stars ctx in
      let labels = Array.to_list (Array.map (fun i -> Catalogue.label stars.(i)) f.stars) in
      let neighbour = stars.(f.stars.(0)).con in
      let slot = t.story in
      Narrate.story_async { Narrate.shape = "Doodle"; stars = labels; neighbour } (fun s ->
          Atomic.set slot s));
  t

(**
   [visible_stroke t] is the stroke to draw now.
   Requires: nothing
   Returns: screen points
   Raises: nothing
   Example: visible_stroke (init ()) = [||]
   Complexity: O(s)
   Pseudocode:
     Drawing | Hint -> Capture.stroke capture
     Morphing (m, stroke, _) -> Morph.current m stroke
     Showing (stroke, _) -> stroke
*)
let visible_stroke t =
  match t.stage with
  | Drawing | Hint _ -> Capture.stroke t.capture
  | Morphing (m, stroke, _) -> Morph.current m stroke
  | Showing (stroke, _) -> stroke

(**
   [apply ctx screen t cmd] dispatches one command to its step.
   Requires: nothing
   Returns: the new state
   Raises: nothing
   Example: (apply ctx screen (init ()) Controls.Clear).stage = Drawing
   Complexity: that of the step
   Pseudocode:
     Pen_down p -> pen_down p t
     Pen_up     -> pen_up ctx screen t
     Clear      -> clear t
     Ask_story  -> ask_story ctx t
     Save_card | Open_menu | Dismiss -> t   (* screen-level, see bin/play.ml *)
*)
let apply ctx screen t (cmd : Controls.command) =
  match cmd with
  | Pen_down p -> pen_down p t
  | Pen_up -> pen_up ctx screen t
  | Clear -> clear t
  | Ask_story -> ask_story ctx t
  | Save_card | Open_menu | Dismiss -> t

(**
   [stage t] is where the game is.
   Requires: nothing
   Returns: [t.stage]
   Raises: nothing
   Example: stage (init ()) = Drawing
   Complexity: O(1)
   Pseudocode:
     return t.stage
*)
let stage t = t.stage

(**
   [view t] is the sky framing.
   Requires: nothing
   Returns: [t.view]
   Raises: nothing
   Example: view (init ()) = None
   Complexity: O(1)
   Pseudocode:
     return t.view
*)
let view t = t.view

(**
   [best_view t] is the best viewing time, altitude and azimuth.
   Requires: nothing
   Returns: [t.best]
   Raises: nothing
   Example: best_view (init ()) = None
   Complexity: O(1)
   Pseudocode:
     return t.best
*)
let best_view t = t.best

(**
   [guess t] is the engine's guess.
   Requires: nothing
   Returns: [t.guess]
   Raises: nothing
   Example: guess (init ()) = None
   Complexity: O(1)
   Pseudocode:
     return t.guess
*)
let guess t = t.guess

(**
   [story t] is the story, if it has arrived.
   Requires: nothing
   Returns: the current content of the story slot
   Raises: nothing
   Example: story (init ()) = None
   Complexity: O(1)
   Pseudocode:
     return Atomic.get t.story
*)
let story t = Atomic.get t.story

(**
   [stroke_length t] is the number of kept stroke points.
   Requires: nothing
   Returns: [Capture.length t.capture]
   Raises: nothing
   Example: stroke_length (init ()) = 0
   Complexity: O(1)
   Pseudocode:
     return Capture.length t.capture
*)
let stroke_length t = Capture.length t.capture
