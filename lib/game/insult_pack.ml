(**
   File: insult_pack.ml
   Author: GitBetterKid
   Created: 2026-11-07
   Description: Implementation of the Insult_pack module: the catalogue of unlockable
                insult packs that cases drop, each with a rarity and extra insults.
   Usage: The contract is in insult_pack.mli.
          Import: add hack.game to (libraries ...) in a dune file, then use
          Doodle_game.Insult_pack (or Insult_pack with -open Doodle_game).
          Build: dune build    Test: dune test
*)
(* The unlockable insult packs. See insult_pack.mli for the contract. *)
type t = {
  id : string;
  name : string;
  rarity : Rarity.t;
  insults : string list;
  final_disses : string list;
}
let all =
  [ (* ---- Mil-Spec ---- *)
    { id = "astro_101"; name = "Astronomy 101"; rarity = Rarity.Mil_spec; final_disses = [];
      insults =
        [ "{score}. Even a light-polluted sky has more structure than that.";
          "My telescope saw that and switched itself to airplane mode.";
          "That's not {target}. That's a connect-the-dots someone gave up on.";
          "{score}? The stars are rated 'visible'. Your drawing is rated 'no'.";
          "You drew {target} like you've only heard it described over a bad phone line." ] };
    { id = "cloudy_night"; name = "Cloudy Night"; rarity = Rarity.Mil_spec; final_disses = [];
      insults =
        [ "Forecast for this drawing: 100% chance of embarrassment.";
          "{score}. Even an overcast sky shows more than you did.";
          "That {target} looks like it was traced through fog wearing oven mitts.";
          "I've seen clearer shapes in a smudged windshield.";
          "{score}? Cloud cover would have been an improvement." ] };
    { id = "mission_control"; name = "Mission Control"; rarity = Rarity.Mil_spec; final_disses = [];
      insults =
        [ "Houston, we have a problem. It's your drawing.";
          "{score}. Launch scrubbed due to catastrophic artistic failure.";
          "Telemetry suggests your hand was in free fall.";
          "That {target} would fail every pre-launch check we have.";
          "Abort, abort. Nobody can unsee that." ] };
    { id = "gift_shop"; name = "Planetarium Gift Shop"; rarity = Rarity.Mil_spec; final_disses = [];
      insults =
        [ "{score}. The glow-in-the-dark ceiling stickers are judging you.";
          "A school trip drew {target} better than this. While asleep.";
          "That belongs on a fridge, and not proudly.";
          "The gift shop won't even sell this as a postcard.";
          "{score}? Please exit through the gift shop and keep walking." ] };
    (* ---- Restricted ---- *)
    { id = "black_hole"; name = "Event Horizon"; rarity = Rarity.Restricted;
      insults =
        [ "{score}. Your talent crossed the event horizon and is never coming back.";
          "Even light can't escape that drawing, and it really wants to.";
          "That {target} has the gravitational pull of zero viewers.";
          "Spaghettification would improve that line work.";
          "{score}? Hawking radiation leaks faster than your skill." ];
      final_disses =
        [ "Five strikes. Your drawings collapsed into a black hole of shame. Game over." ] };
    { id = "cosmic_scale"; name = "Cosmic Scale"; rarity = Rarity.Restricted;
      insults =
        [ "On a cosmic timescale, that drawing still took too long to be this bad.";
          "{score}. The universe is 13.8 billion years old and has never seen worse.";
          "That {target} is the dark matter of art: everyone agrees it's there, nobody can see it.";
          "Somewhere a quasar just dimmed out of second-hand embarrassment.";
          "Your lines are drifting apart faster than the expanding universe." ];
      final_disses =
        [ "Five misses. The cosmos has reclassified you as background noise. Goodbye." ] };
    (* ---- Classified ---- *)
    { id = "supernova"; name = "Supernova"; rarity = Rarity.Classified;
      insults =
        [ "{score}. That drawing went supernova and took the sky's reputation with it.";
          "Astronomers in 2,000 years will still study how you got {target} this wrong.";
          "Your hand drew {target} like it was dodging asteroids.";
          "Neutron stars are less dense than the choices behind those lines.";
          "{score}? The Big Bang had better composition, and it was literally chaos." ];
      final_disses =
        [ "Strike five. You have been gravitationally ejected from the solar system. Bye." ] };
    (* ---- Covert ---- *)
    { id = "night_shift"; name = "Observatory Night Shift"; rarity = Rarity.Covert;
      insults =
        [ "{score}. The night-shift astronomer saw this and asked to move to days.";
          "That {target} was peer-reviewed and rejected by every star involved.";
          "Voyager is 24 billion kilometres away and can still tell that's wrong.";
          "I'd call it abstract, but abstract art usually means it on purpose.";
          "{score}. Galileo stood trial for less than what you just did to {target}." ];
      final_disses =
        [ "Five strikes. The observatory has revoked your sky privileges. Lights out." ] };
    (* ---- Exceedingly Rare ---- *)
    { id = "golden_sky"; name = "Golden Sky"; rarity = Rarity.Exceedingly_rare;
      insults =
        [ "{score}. You unlocked the rarest pack in the game just to hear it describe this.";
          "That {target} is so wrong it bends light around itself.";
          "Somewhere a star saw your drawing and decided to die early.";
          "Legend says if you squint at that drawing, it gets worse.";
          "{score}. The stars took billions of years to form. You undid them in four seconds." ];
      final_disses =
        [ "Five strikes. Even with the rarest insults in the game, you still lost. Game over." ] } ]
(**
   [find id] looks a pack up by id.
   Requires: nothing
   Returns: Some pack or None
   Raises: nothing
   Example: Option.map (fun p -> p.name) (find "black_hole") = Some "Event Horizon"
   Complexity: O(n)
   Pseudocode:
     first pack in all with p.id = id
*)
let find id = List.find_opt (fun p -> p.id = id) all
(**
   [of_rarity r] is the packs of one tier.
   Requires: nothing
   Returns: packs in catalogue order
   Raises: nothing
   Example: List.length (of_rarity Rarity.Mil_spec) = 4
   Complexity: O(n)
   Pseudocode:
     filter all by p.rarity = r
*)
let of_rarity r = List.filter (fun p -> p.rarity = r) all
