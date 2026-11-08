# Case openings — unlockable insult packs

CS2-style cases that unlock extra packs of insults for collect mode.
There's no money or store anywhere: cases only come from playing.

## How it works

1. **Earn cases in collect mode**: one for each constellation you
   collect for the first time, and one for each **NEW RECORD**. A gold
   "+1 case! Open it from the menu." appears under the verdict. After
   the last constellation, Enter on the win screen goes straight to the
   case screen.
2. **Open them** from the welcome menu → **Open cases** (its detail line
   shows e.g. `2 cases - 3 / 9 packs`). Press **Enter** or click.
3. **The reel spins** for 6 seconds, starting fast and easing to a stop
   with the winning pack under the gold marker. Like CS2, it can't be
   skipped.
4. **The reveal** shows `NEW PACK: <name>` (or `DUPLICATE`) in its rarity
   colour, how many insults it adds, and a sample line. Enter or a click
   goes back to the shelf.
5. **Unlocked packs join collect mode's insult pool** from the next time
   you enter it, alongside the base insults. Rarer packs also add new
   final disses for the 5th strike.

## Rarities and odds (CS2's published case odds)

| Tier | Colour | Odds | Packs |
| --- | --- | --- | --- |
| Mil-Spec | blue | 79.92% | Astronomy 101, Cloudy Night, Mission Control, Planetarium Gift Shop |
| Restricted | purple | 15.98% | Event Horizon, Cosmic Scale |
| Classified | pink | 3.20% | Supernova |
| Covert | red | 0.64% | Observatory Night Shift |
| Exceedingly Rare | gold | 0.26% | Golden Sky |

A roll picks the tier by those odds, then a pack in that tier,
**preferring packs you don't own yet**. A duplicate only happens once
you own every pack of the tier that came up.

Every pack adds 5 insults. The Restricted and rarer packs also add one
final diss. Like the base lines they swear freely at the drawing and
the player's skill, with no slurs and nothing about identity or looks.

## Modules

| Layer | Module | Job |
| --- | --- | --- |
| game | [`Rarity`](../lib/game/rarity.mli) | tiers, odds, colours, rolling a tier |
| game | [`Insult_pack`](../lib/game/insult_pack.mli) | the 9 packs (id, name, rarity, lines) |
| game | [`Inventory`](../lib/game/inventory.mli) | unopened cases + unlocked packs; save/load `data/unlocks.csv` |
| game | [`Case`](../lib/game/case.mli) | rolling a case, building the reel, the reel's ease-out position |
| game | [`Case_opening`](../lib/game/case_opening.mli) | the case screen's rules: Idle → Spinning → Revealed |
| app | [`Cases_scene`](../bin/cases_scene.mli) | the screen (`"cases"`): glue + saving |
| app | [`Cases_view`](../bin/cases_view.mli) | drawing: header, reel, reveal, shelf, footer |

Changes to existing modules:

- **`Roast.create`** takes `?extra_insults` and `?extra_disses`; lines are
  picked from the base lists plus these. The base lists are untouched.
- **`Collect`** counts earned cases (`earns_case`, `take_earned_cases`).
  `Collect_scene` adds them to the saved inventory and starts `Roast`
  with the unlocked packs' lines.
- **`Title`** has an **Open cases** menu item (action `Open_cases`, scene
  `"cases"`), and its `summary` gained `cases` and `packs_owned`.

## Details worth knowing

- **Unlock happens on open, not on reveal**, so closing the game
  mid-spin never loses the pack (or refunds the case).
- **The click that opens the screen doesn't open a case.** A click only
  counts if the button also went down on the case screen.
- **Saving** is load-modify-save in collect mode, so cases earned there
  never overwrite packs unlocked on the case screen.
- **Reset progress** on the welcome menu resets collected constellations
  and best scores only; cases and packs are kept. Delete
  `data/unlocks.csv` to wipe those too.
- **Adding a pack**: add an entry to `Insult_pack.all` with a new `id`.
  The `packs` test checks every line fills its placeholders cleanly.

## Tests

`test/test_hack.ml`, suite `cases`:

- odds sum to 1, and 20,000 rolls match them;
- pack counts per tier and unique ids;
- inventory spend, unlock and save/load;
- new packs are preferred over duplicates;
- the reel lands exactly on the winner and slows down;
- the reel can't be skipped, and unlock happens on open;
- a stray mouse release isn't a click;
- pack lines reach the insult pool;
- collect mode earns cases.
