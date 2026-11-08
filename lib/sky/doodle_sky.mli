(**
   File: doodle_sky.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Layer 2 interface (sky data): lists the layer's modules (Catalogue,
                Visibility, Data_dir, Asterism) and its dependency rules.
   Usage: Import: add hack.sky to (libraries ...) and (:standard -open Doodle_sky) to
          (flags ...) in a dune file.
          Build: dune build
*)

(** {1 Layer 2 — Sky data}

    The stars themselves and where they are tonight.

    {b May use:} core.
    {b Used by:} matching, game.

    {2 Modules}
    {ul
    {- {!Catalogue}  — loads [data/stars.csv]; one [star] per row
                       (id, name, ra, dec, magnitude, constellation).}
    {- {!Data_dir}   — finds data/stars.csv wherever the app is started.}
    {- {!Asterism}   — the collectible constellation figures
                       (data/asterisms.csv).}
    {- {!Visibility} — sidereal time, altitude/azimuth, Sun position,
                       best viewing time, compass labels.}}

    {2 Key types}
    {ul
    {- [Catalogue.star] — one catalogue row, angles in radians.}} *)

module Catalogue = Catalogue
module Visibility = Visibility
module Data_dir = Data_dir
module Asterism = Asterism
