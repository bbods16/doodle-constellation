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
        [ "{score}. Even a light-polluted sky has more structure than that crap.";
          "My telescope saw that shit and switched itself to airplane mode.";
          "That's not {target}. That's a connect-the-dots some asshole gave up on.";
          "{score}? The stars are rated 'visible'. Your drawing is rated 'hell no'.";
          "You drew {target} like a drunk described it to you over a shitty phone line." ] };
    { id = "cloudy_night"; name = "Cloudy Night"; rarity = Rarity.Mil_spec; final_disses = [];
      insults =
        [ "Forecast for this drawing: 100% chance of shit.";
          "{score}. Even an overcast sky shows more than your sorry ass did.";
          "That {target} looks like it was traced through fog by a drunk in oven mitts.";
          "I've seen clearer shapes in the crap on a windshield.";
          "{score}? Cloud cover would've been a goddamn mercy." ] };
    { id = "mission_control"; name = "Mission Control"; rarity = Rarity.Mil_spec; final_disses = [];
      insults =
        [ "Houston, we have a problem. It's this piece of shit drawing.";
          "{score}. Launch scrubbed because what the actual fuck is that.";
          "Telemetry suggests your hand was in free fall and your brain never launched.";
          "That {target} would fail every pre-launch check we have, dumbass.";
          "Abort, abort. Nobody can unsee that shit." ] };
    { id = "gift_shop"; name = "Planetarium Gift Shop"; rarity = Rarity.Mil_spec; final_disses = [];
      insults =
        [ "{score}. The glow-in-the-dark ceiling stickers are calling you a dumbass.";
          "A school trip drew {target} better than this. Half-asleep, you clown.";
          "That belongs on a fridge. Inside it, with the door shut, you hack.";
          "The gift shop wouldn't sell this crap as a toilet mat.";
          "{score}? Exit through the gift shop and keep fucking walking." ] };
    (* ---- Restricted ---- *)
    { id = "black_hole"; name = "Event Horizon"; rarity = Rarity.Restricted;
      insults =
        [ "{score}. Your talent crossed the event horizon and it isn't coming the fuck back.";
          "Even light can't escape that shitty drawing, and it's really fucking trying.";
          "That {target} has the gravitational pull of a wet fart.";
          "Spaghettification would improve that garbage line work.";
          "{score}? Hawking radiation leaks faster than your dumb ass learns." ];
      final_disses =
        [ "Five strikes. Your drawings collapsed into a black hole of shit. Game over, jackass." ] };
    { id = "cosmic_scale"; name = "Cosmic Scale"; rarity = Rarity.Restricted;
      insults =
        [ "On a cosmic timescale, that still took too long to look this fucking bad.";
          "{score}. The universe is 13.8 billion years old and has never seen worse shit.";
          "That {target} is the dark matter of art: it's out there, and it blows.";
          "Somewhere a quasar just dimmed so it wouldn't have to look at this crap.";
          "Your lines are drifting apart faster than the universe, you absolute walnut." ];
      final_disses =
        [ "Five misses. The cosmos has reclassified you as background noise. Shut the fuck up." ] };
    (* ---- Classified ---- *)
    { id = "supernova"; name = "Supernova"; rarity = Rarity.Classified;
      insults =
        [ "{score}. That shit went supernova and took the sky's reputation with it.";
          "Astronomers in 2,000 years will still ask how the fuck you got {target} this wrong.";
          "Your hand drew {target} like it was dodging asteroids, shitfaced.";
          "Neutron stars are less dense than the dumbass behind those lines.";
          "{score}? The Big Bang had better composition, and it was literally a fucking explosion." ];
      final_disses =
        [ "Strike five. You have been gravitationally ejected from the solar system. Fuck off into the void." ] };
    (* ---- Covert ---- *)
    { id = "night_shift"; name = "Observatory Night Shift"; rarity = Rarity.Covert;
      insults =
        [ "{score}. The night-shift astronomer saw this shit and asked to move to days.";
          "That {target} was peer-reviewed by every star involved. The review was 'fuck no'.";
          "Voyager is 25 billion kilometres away and can still tell that's dogshit.";
          "I'd call it abstract, but abstract artists fuck up on purpose.";
          "{score}. Galileo stood trial for less than the bullshit you just did to {target}." ];
      final_disses =
        [ "Five strikes. The observatory revoked your sky privileges, you talentless shit. Lights out." ] };
    (* ---- Exceedingly Rare ---- *)
    { id = "golden_sky"; name = "Golden Sky"; rarity = Rarity.Exceedingly_rare;
      insults =
        [ "{score}. You unlocked the rarest pack in the game just to hear it call this shit.";
          "That {target} is so fucking wrong it bends light around itself.";
          "Somewhere a star saw your drawing and said 'fuck this' and died early.";
          "Legend says if you squint at that drawing, it gets even shittier.";
          "{score}. The stars took billions of years to form. You shat on them in four seconds." ];
      final_disses =
        [ "Five strikes. The rarest insults in the game, and you still fucking lost. Get out, dumbass." ] } ]

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
