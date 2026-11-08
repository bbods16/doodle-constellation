(**
   File: narrate.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Narrate module: an optional invented story about a
                match, fetched from the Claude API in a background domain.
   Usage: Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Narrate (or Narrate with -open Doodle_game).
          Build: dune build    Test: dune test
*)

(** Narration layer (optional, not in the two-hour build).

    Asks a language model for a short invented myth built only from the
    facts passed in. Runs in its own [Domain] so the raylib frame loop
    never waits on the network.

    Transport: the Anthropic Messages API through the system [curl]
    binary (no extra OCaml dependencies). The key is read from the
    [ANTHROPIC_API_KEY] environment variable and passed to curl in a
    temporary header file, never on the command line. *)

type request = {
  shape : string;          (** the user's name for the drawing, e.g. ["Bolt"] *)
  stars : string list;     (** matched star labels *)
  neighbour : string;      (** nearest official constellation *)
}

val prompt : request -> string
(**
   [prompt r] is the text sent to the model: only these facts, no
   numbers beyond them, and an instruction to write about 70 words.
   An empty [neighbour] is left out.
   Requires: nothing
   Returns: a plain-text prompt
   Raises: nothing
   Example: prompt { shape = "Bolt"; stars = ["Vega"]; neighbour = "Lyra" }
            contains "Bolt", "Vega" and "Lyra"
   Complexity: O(L) time and space, L = total length of the facts
*)

val fiction_label : string
(** ["This story is invented."], shown with every story. *)

val story : shape:string -> stars:string list -> string option
(**
   [story ~shape ~stars] makes a blocking call to the model.
   Requires: [curl] on the PATH and [ANTHROPIC_API_KEY] set for a story
   Returns: [Some text], or [None] if the key is missing, the service is
            unreachable or the reply cannot be read, in which case the
            app simply shows no story
   Raises: nothing
   Example: story ~shape:"Bolt" ~stars:["Vega"] = None (when offline)
   Complexity: O(L) time and space plus one network round trip
               (curl's timeout is 20 s)
*)

val story_async : request -> (string option -> unit) -> unit
(**
   [story_async r k] runs {!story} (with [r]'s neighbour in the prompt)
   in a new [Domain] and calls [k] with the result. The callback must
   only store the result (for example in an [Atomic.t]); drawing happens
   on the main loop.
   Requires: [k] is safe to call from another domain
   Returns: immediately
   Raises: nothing (exceptions inside the domain become [k None])
   Example: story_async r (fun s -> Atomic.set slot s)
   Complexity: O(1) time on the caller's side
*)
