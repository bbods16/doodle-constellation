(**
   File: visibility.mli
   Author: GitBetterKid
   Created: 2026-11-07

   Description: Interface of the Visibility module: where and when to look - sidereal
                time, altitude/azimuth, Sun position, darkness check and the best
                viewing time.
   Usage: Import: add hack.sky to (libraries ...) in a dune file, then use
          Doodle_sky.Visibility (or Visibility with -open Doodle_sky).
          Build: dune build    Test: dune test
*)

(** Visibility calculator: when and where the match is best seen.

    Pure float maths. Latitude and longitude come from command-line
    arguments (Buffalo by default) and the time from
    [Unix.gettimeofday ()], which closes gap G2. Angles in radians,
    times in Unix seconds, longitude positive east. No GIMP counterpart. *)

val buffalo : float * float
(** Default [(lat, lon)]: about 42.89 N, 78.88 W, in radians. *)

val local_sidereal_time : lon:float -> now:float -> float
(**
   [local_sidereal_time ~lon ~now] is the local sidereal time as an angle
   (Greenwich mean sidereal time from the IAU 1982 linear formula, plus
   the longitude).
   Requires: [lon] in radians (east positive), [now] in Unix seconds
   Returns: an angle in [0, 2 pi)
   Raises: nothing
   Example: local_sidereal_time ~lon:0. ~now:946728000. (* J2000.0 *)
            = rad 280.46 (approx.)
   Complexity: O(1) time, O(1) space
*)

val hour_angle : lon:float -> ra:float -> now:float -> float
(**
   [hour_angle ~lon ~ra ~now] is [LST - ra], wrapped.
   Requires: radians, Unix seconds
   Returns: an angle in (-pi, pi]; zero when the position crosses the
            meridian, positive after (west of the meridian)
   Raises: nothing
   Example: hour_angle ~lon ~ra:(local_sidereal_time ~lon ~now) ~now = 0.
   Complexity: O(1) time, O(1) space
*)

val altitude : lat:float -> lon:float -> ra:float -> dec:float -> now:float -> float
(**
   [altitude ~lat ~lon ~ra ~dec ~now] is the height above the horizon:
   [asin (sin lat sin dec + cos lat cos dec cos H)].
   Requires: radians, Unix seconds
   Returns: an angle in [-pi/2, pi/2]
   Raises: nothing
   Example: altitude ~lat ~lon ~ra ~dec:lat ~now (at culmination) = pi/2
   Complexity: O(1) time, O(1) space
*)

val azimuth : lat:float -> lon:float -> ra:float -> dec:float -> now:float -> float
(**
   [azimuth ~lat ~lon ~ra ~dec ~now] is the compass direction, measured
   from north through east.
   Requires: radians, Unix seconds
   Returns: an angle in [0, 2 pi)
   Raises: nothing
   Example: azimuth ~lat:(rad 43.) ~lon ~ra ~dec:0. ~now (on the meridian) = pi
   Complexity: O(1) time, O(1) space
*)

val culmination : lon:float -> ra:float -> now:float -> float
(**
   [culmination ~lon ~ra ~now] is the next time at or after [now] when
   the hour angle is zero.
   Requires: radians, Unix seconds
   Returns: a Unix time in [now, now + one sidereal day)
   Raises: nothing
   Example: culmination ~lon ~ra ~now >= now
   Complexity: O(1) time, O(1) space
*)

val sun_altitude : lat:float -> lon:float -> now:float -> float
(**
   [sun_altitude ~lat ~lon ~now] is the approximate Sun altitude, good to
   about a degree (Astronomical Almanac low-precision solar position),
   enough for a darkness check.
   Requires: radians, Unix seconds
   Returns: an angle in [-pi/2, pi/2]
   Raises: nothing
   Example: sun_altitude ~lat ~lon ~now:(local midnight) < 0.
   Complexity: O(1) time, O(1) space
*)

val is_dark : lat:float -> lon:float -> now:float -> bool
(**
   [is_dark ~lat ~lon ~now] is [true] when the Sun is more than 12
   degrees below the horizon (nautical twilight or darker).
   Requires: radians, Unix seconds
   Returns: the darkness flag
   Raises: nothing
   Example: is_dark ~lat ~lon ~now:(local noon) = false
   Complexity: O(1) time, O(1) space
*)

val best_view :
  lat:float -> lon:float -> ra:float -> dec:float -> now:float ->
  float * float * float
(**
   [best_view ~lat ~lon ~ra ~dec ~now] is [(time, altitude, azimuth)]
   for the best time in the next 24 hours: the culmination if it falls
   in darkness, otherwise the dark moment (sampled every 10 minutes)
   when the region stands highest. When no moment is dark (polar
   summer), the highest moment overall.
   Requires: radians, Unix seconds
   Returns: Unix time in [now, now + 24 h], altitude and azimuth there
   Raises: nothing
   Example: let (t, _, _) = best_view ~lat ~lon ~ra ~dec ~now in t >= now
   Complexity: O(1) time (145 samples), O(1) space
*)

val compass : float -> string
(**
   [compass az] turns an azimuth into an 8-point label.
   Requires: radians (any value; it is wrapped)
   Returns: one of "north", "north-east", "east", "south-east",
            "south", "south-west", "west", "north-west"
   Raises: nothing
   Example: compass Float.pi = "south"
   Complexity: O(1) time, O(1) space
*)
