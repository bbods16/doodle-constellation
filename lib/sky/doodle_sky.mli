(** {1 Layer 2 — Sky data}

    The stars themselves and where they are tonight.

    {b May use:} core.
    {b Used by:} matching, game.

    {2 Modules}
    {ul
    {- {!Catalogue}  — loads [data/stars.csv]; one [star] per row
                       (id, name, ra, dec, magnitude, constellation).}
    {- {!Data_dir}   — finds data/stars.csv wherever the app is started.}
    {- {!Visibility} — sidereal time, altitude/azimuth, Sun position,
                       best viewing time, compass labels.}}

    {2 Key types}
    {ul
    {- [Catalogue.star] — one catalogue row, angles in radians.}} *)

module Catalogue = Catalogue
module Visibility = Visibility
module Data_dir = Data_dir
