(**
   File: visibility.ml
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Implementation of the Visibility module: where and when to look -
                sidereal time, altitude/azimuth, Sun position, darkness check and the
                best viewing time.
   Usage: The contract is in visibility.mli.
          Import: add hack.sky to (libraries ...) in a dune file, then use
          Doodle_sky.Visibility (or Visibility with -open Doodle_sky).
          Build: dune build    Test: dune test
*)

(* Visibility calculator. See visibility.mli for the public contract. *)

let two_pi = 2. *. Float.pi
let buffalo = (Geom.rad 42.89, Geom.rad (-78.88))

(* Earth turns once relative to the stars every 86164.0905 s. *)
let sidereal_rate = two_pi /. 86164.0905

(**
   [norm_2pi a] brings an angle into [0, 2 pi).
   Requires: finite [a]
   Returns: the equivalent angle in [0, 2 pi)
   Raises: nothing
   Example: norm_2pi (-. Float.pi /. 2.) = 3. *. Float.pi /. 2.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     r <- a mod 2pi ; if r < 0 then r + 2pi else r
*)
let norm_2pi a =
  let r = Float.rem a two_pi in
  if r < 0. then r +. two_pi else r

(**
   [days_since_j2000 now] is the number of days since 2000-01-01 12:00 TT
   (UT used as an approximation).
   Requires: Unix seconds
   Returns: [JD - 2451545.0]
   Raises: nothing
   Example: days_since_j2000 946728000. = 0.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     jd <- now / 86400 + 2440587.5
     return jd - 2451545.0
*)
let days_since_j2000 now = (now /. 86400.) +. 2440587.5 -. 2451545.0

(**
   [local_sidereal_time ~lon ~now] is the local sidereal time.
   Requires: radians, Unix seconds
   Returns: angle in [0, 2 pi)
   Raises: nothing
   Example: local_sidereal_time ~lon:0. ~now:946728000. = rad 280.46 (approx.)
   Complexity: O(1) time, O(1) space
   Pseudocode:
     d <- days_since_j2000 now
     gmst_deg <- 280.46061837 + 360.98564736629 * d
     return norm_2pi (rad gmst_deg + lon)
*)
let local_sidereal_time ~lon ~now =
  let d = days_since_j2000 now in
  let gmst = 280.46061837 +. (360.98564736629 *. d) in
  norm_2pi (Geom.rad (Float.rem gmst 360.) +. lon)

(**
   [hour_angle ~lon ~ra ~now] is the wrapped hour angle.
   Requires: radians, Unix seconds
   Returns: angle in (-pi, pi]
   Raises: nothing
   Example: hour_angle ~lon ~ra:(local_sidereal_time ~lon ~now) ~now = 0.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return wrap_angle (local_sidereal_time ~lon ~now - ra)
*)
let hour_angle ~lon ~ra ~now = Geom.wrap_angle (local_sidereal_time ~lon ~now -. ra)

(**
   [alt_of ~lat ~dec ~h] is the altitude for a given hour angle.
   Requires: radians
   Returns: [asin (sin lat sin dec + cos lat cos dec cos h)]
   Raises: nothing
   Example: alt_of ~lat:0. ~dec:0. ~h:0. = pi/2
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return asin (clamp (sin lat sin dec + cos lat cos dec cos h))
*)
let alt_of ~lat ~dec ~h =
  let v = (sin lat *. sin dec) +. (cos lat *. cos dec *. cos h) in
  Float.asin (Float.max (-1.) (Float.min 1. v))

(**
   [altitude ~lat ~lon ~ra ~dec ~now] is the height above the horizon.
   Requires: radians, Unix seconds
   Returns: angle in [-pi/2, pi/2]
   Raises: nothing
   Example: altitude ~lat ~lon ~ra ~dec:lat ~now (at culmination) = pi/2
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return alt_of ~lat ~dec ~h:(hour_angle ~lon ~ra ~now)
*)
let altitude ~lat ~lon ~ra ~dec ~now = alt_of ~lat ~dec ~h:(hour_angle ~lon ~ra ~now)

(**
   [azimuth ~lat ~lon ~ra ~dec ~now] is the compass bearing.
   Requires: radians, Unix seconds
   Returns: angle in [0, 2 pi), north = 0, east = pi/2
   Raises: nothing
   Example: azimuth ~lat:(rad 43.) ~lon ~ra ~dec:0. ~now (on the meridian) = pi
   Complexity: O(1) time, O(1) space
   Pseudocode:
     h <- hour_angle ~lon ~ra ~now
     y <- -cos dec sin h
     x <- sin dec cos lat - cos dec cos h sin lat
     return norm_2pi (atan2 y x)
*)
let azimuth ~lat ~lon ~ra ~dec ~now =
  let h = hour_angle ~lon ~ra ~now in
  let y = -.(cos dec *. sin h) in
  let x = (sin dec *. cos lat) -. (cos dec *. cos h *. sin lat) in
  norm_2pi (Float.atan2 y x)

(**
   [culmination ~lon ~ra ~now] is the next meridian crossing.
   Requires: radians, Unix seconds
   Returns: Unix time in [now, now + sidereal day)
   Raises: nothing
   Example: culmination ~lon ~ra ~now >= now
   Complexity: O(1) time, O(1) space
   Pseudocode:
     h <- hour_angle ~lon ~ra ~now
     wait <- norm_2pi (-h)               (* angle still to turn *)
     return now + wait / sidereal_rate
*)
let culmination ~lon ~ra ~now =
  let h = hour_angle ~lon ~ra ~now in
  now +. (norm_2pi (-.h) /. sidereal_rate)

(**
   [sun_radec now] is the Sun's approximate (ra, dec).
   Requires: Unix seconds
   Returns: radians, good to about a degree
   Raises: nothing
   Example: snd (sun_radec (March equinox)) = 0. (approx.)
   Complexity: O(1) time, O(1) space
   Pseudocode:
     n <- days_since_j2000 now
     L <- 280.460 + 0.9856474 n ; g <- 357.528 + 0.9856003 n   (degrees)
     lambda <- L + 1.915 sin g + 0.020 sin 2g
     eps <- 23.439 - 0.0000004 n
     ra <- atan2 (cos eps sin lambda) (cos lambda)
     dec <- asin (sin eps sin lambda)
*)
let sun_radec now =
  let n = days_since_j2000 now in
  let l = Geom.rad (Float.rem (280.460 +. (0.9856474 *. n)) 360.) in
  let g = Geom.rad (Float.rem (357.528 +. (0.9856003 *. n)) 360.) in
  let lambda = l +. Geom.rad ((1.915 *. sin g) +. (0.020 *. sin (2. *. g))) in
  let eps = Geom.rad (23.439 -. (0.0000004 *. n)) in
  (Float.atan2 (cos eps *. sin lambda) (cos lambda), Float.asin (sin eps *. sin lambda))

(**
   [sun_altitude ~lat ~lon ~now] is the Sun's altitude.
   Requires: radians, Unix seconds
   Returns: angle in [-pi/2, pi/2]
   Raises: nothing
   Example: sun_altitude ~lat ~lon ~now:(local midnight) < 0.
   Complexity: O(1) time, O(1) space
   Pseudocode:
     (ra, dec) <- sun_radec now
     return altitude ~lat ~lon ~ra ~dec ~now
*)
let sun_altitude ~lat ~lon ~now =
  let ra, dec = sun_radec now in
  altitude ~lat ~lon ~ra ~dec ~now

(**
   [is_dark ~lat ~lon ~now] is the nautical-darkness test.
   Requires: radians, Unix seconds
   Returns: [sun_altitude < -12 degrees]
   Raises: nothing
   Example: is_dark ~lat ~lon ~now:(local noon) = false
   Complexity: O(1) time, O(1) space
   Pseudocode:
     return sun_altitude ~lat ~lon ~now < rad (-12)
*)
let is_dark ~lat ~lon ~now = sun_altitude ~lat ~lon ~now < Geom.rad (-12.)

(**
   [best_view ~lat ~lon ~ra ~dec ~now] picks the best time in 24 hours.
   Requires: radians, Unix seconds
   Returns: [(time, altitude, azimuth)]
   Raises: nothing
   Example: let (t, _, _) = best_view ~lat ~lon ~ra ~dec ~now in t >= now
   Complexity: O(1) time, O(1) space
   Pseudocode:
     at t = (t, altitude at t, azimuth at t)
     c <- culmination ~lon ~ra ~now
     if c <= now + 24h and is_dark at c then return at c
     samples <- now, now + 10 min, ..., now + 24 h
     dark <- samples where is_dark
     pool <- if dark <> [] then dark else samples
     return at (sample in pool with the highest altitude)
*)
let best_view ~lat ~lon ~ra ~dec ~now =
  let at t = (t, altitude ~lat ~lon ~ra ~dec ~now:t, azimuth ~lat ~lon ~ra ~dec ~now:t) in
  let day = 86400. in
  let c = culmination ~lon ~ra ~now in
  if c <= now +. day && is_dark ~lat ~lon ~now:c then at c
  else begin
    let samples = List.init 145 (fun i -> now +. (float_of_int i *. 600.)) in
    let dark = List.filter (fun t -> is_dark ~lat ~lon ~now:t) samples in
    let pool = if dark <> [] then dark else samples in
    let alt t = altitude ~lat ~lon ~ra ~dec ~now:t in
    let best =
      List.fold_left (fun b t -> if alt t > alt b then t else b) (List.hd pool) pool
    in
    at best
  end

(**
   [compass az] is the 8-point compass label.
   Requires: radians
   Returns: "north", "north-east", ... "north-west"
   Raises: nothing
   Example: compass Float.pi = "south"
   Complexity: O(1) time, O(1) space
   Pseudocode:
     d <- deg (norm_2pi az)
     i <- floor ((d + 22.5) / 45) mod 8
     return names.(i)
*)
let compass az =
  let names =
    [| "north"; "north-east"; "east"; "south-east"; "south"; "south-west"; "west"; "north-west" |]
  in
  let d = Geom.deg (norm_2pi az) in
  names.(int_of_float (Float.floor ((d +. 22.5) /. 45.)) mod 8)
