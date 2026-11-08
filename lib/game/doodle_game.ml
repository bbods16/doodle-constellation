(**
   File: doodle_game.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 4 interface (game): lists the screen framework, free-draw,
                collect-mode and welcome-page modules and the dependency rules.
   Usage: Import: add hack.game to (libraries ...) and (:standard -open Doodle_game)
          to (flags ...) in a dune file.
          Build: dune build
*)

(* Layer 4 interface. See doodle_game.mli. *)

module Scene = Scene
module Controls = Controls
module Game = Game
module Projection = Projection
module Morph = Morph
module Narrate = Narrate
module Collect = Collect
module Judge = Judge
module Roast = Roast
module Collection = Collection
module Accuracy = Accuracy
module Menu = Menu
module Title = Title
module Attract = Attract
module Case_opening = Case_opening
module Case = Case
module Inventory = Inventory
module Insult_pack = Insult_pack
module Rarity = Rarity
