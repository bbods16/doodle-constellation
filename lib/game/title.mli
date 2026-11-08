(** Title: the welcome page's logic, pure (no drawing, no disk). The
    [Welcome] screen becomes glue over this and [Title_view].

    PLANNED (welcome page) — interface only; the implementation is a stub.
    See [docs/WELCOME_PLAN.md].

    {2 Pages}
    {v
      ┌───────────────────────────────┐  How to play  ┌──────────────┐
      │ Main                          ├──────────────►│ Help         │
      │  ▸ Collect the constellations │◄──────────────┤ rules text   │
      │      3 / 7 collected          │ Esc/Enter/click└──────────────┘
      │    Free draw                  │
      │    How to play                │  Reset        ┌──────────────┐
      │    Reset progress             ├──────────────►│ Confirm_reset│
      │    Quit                       │◄──────────────┤  No / Yes    │
      └───┬──────────┬──────────┬─────┘   No / Esc    └──────┬───────┘
          │ Collect  │ Free     │ Quit                 Yes   │
          ▼          ▼          ▼                            ▼
      Go "collect" Go "play"   Quit                Reset (screen deletes
                                                   the progress file)
    v} *)

type action =
  | Start_collect   (** go to collect mode *)
  | Free_draw       (** go to the free-drawing game *)
  | How_to_play     (** open the rules page *)
  | Reset_progress  (** ask to wipe collected figures and best scores *)
  | Quit_game       (** close the app *)
  | Confirm_yes     (** on the confirm page: really reset *)
  | Confirm_no      (** on the confirm page: go back *)
(** What a welcome-page button does. *)

type page =
  | Main           (** the main menu *)
  | Help           (** the rules *)
  | Confirm_reset  (** "Reset all progress?" No / Yes *)
(** Which page is showing. *)

type summary = {
  collected : int;              (** figures collected so far *)
  total : int;                  (** figures in the game *)
  best_average : float option;  (** mean best score over attempted figures *)
}
(** Saved progress, shown under the Collect button. Built by the screen
    from {!Collection}. *)

type outcome =
  | Stay            (** stay on the welcome page *)
  | Go of string    (** switch to the scene with this name *)
  | Quit            (** close the app *)
  | Reset           (** the player confirmed: delete saved progress, then call {!after_reset} *)
(** What the screen should do after this frame. *)

type t
(** Page, menus, progress summary, animation and clock. Abstract. *)

val collect_scene : string
(** Scene name for collect mode: ["collect"]. *)

val free_draw_scene : string
(** Scene name for the free-drawing game: ["play"]. *)

val help_lines : string list
(** The rules, one line each, built from {!Accuracy.pass_mark},
    {!Roast.max_strikes} and the site-style tiers, e.g.
    ["Score 50.0% or more to collect a constellation."]. *)

val main_items : summary option -> action Menu.item list
(**
   [main_items s] is the main menu: Collect (with ["k / n collected"] as
   its detail), Free draw, How to play, Reset progress (disabled when
   nothing is saved), Quit.
   Requires: nothing
   Returns: five items in that order
   Raises: nothing
   Example: (List.hd (main_items (Some { collected = 3; total = 7; best_average = None }))).detail
            = Some "3 / 7 collected"
   Complexity: O(1)
*)

val init : Asterism.t array -> summary option -> t
(**
   [init figures s] opens the welcome page on the main menu, with the
   background animation cycling through [figures].
   Requires: nothing ([figures] may be empty: no animation)
   Returns: state on [Main], first item selected
   Raises: nothing
   Example: page (init figures None) = Main
   Complexity: O(n)
*)

val update : Scene.input -> t -> t * outcome
(**
   [update inp t] is one frame: advance the clock and animation, read
   {!Menu} commands from [inp], apply them to the current page's menu,
   and turn a chosen action into a page change or an outcome. Escape on
   [Help] or [Confirm_reset] returns to [Main]; on [Help] any key or
   click also returns.
   Requires: nothing
   Returns: the new state and what the screen should do
   Raises: nothing
   Example: snd (update { inp with keys = [Enter] } (init f s)) = Go "collect"
   Complexity: O(n) for the menu, plus the animation step
*)

val after_reset : t -> t
(**
   [after_reset t] is the page after the screen has deleted the saved
   progress: back on [Main] with the summary cleared.
   Requires: the screen has handled [Reset]
   Returns: state on [Main] with [summary = Some { collected = 0; ... }]
   Raises: nothing
   Example: page (after_reset t) = Main
   Complexity: O(1)
*)

(** {1 Accessors (for the view)} *)

val page : t -> page
(**
   [page t] is the page showing.
   Requires: nothing
   Returns: the page
   Raises: nothing
   Example: page (init figures None) = Main
   Complexity: O(1)
*)

val menu : t -> action Menu.t
(**
   [menu t] is the current page's menu (main, or No/Yes on confirm).
   Requires: nothing
   Returns: the menu
   Raises: nothing
   Example: List.length (Menu.items (menu (init f None))) = 5
   Complexity: O(1)
*)

val summary : t -> summary option
(**
   [summary t] is the saved progress shown on the page.
   Requires: nothing
   Returns: the summary, or [None] if there is none
   Raises: nothing
   Example: summary (init f None) = None
   Complexity: O(1)
*)

val elapsed : t -> float
(**
   [elapsed t] is the seconds spent on the welcome page (for pulsing text).
   Requires: nothing
   Returns: a non-negative number
   Raises: nothing
   Example: elapsed (init f None) = 0.
   Complexity: O(1)
*)

val attract : t -> Attract.t
(**
   [attract t] is the background animation's state.
   Requires: nothing
   Returns: the animation
   Raises: nothing
   Example: Attract.current (attract (init [||] None)) = None
   Complexity: O(1)
*)
