# keys are the short constellation names the model uses (the part before " – ")
FACTS: dict[str, list[str]] = {
    "Andromeda": [
        "Andromeda is the princess from Greek myth who was chained to a rock as a sacrifice to the sea monster Cetus, until Perseus rescued her.",
        "The Andromeda Galaxy, about 2.5 million light-years away, is the most distant thing most people can see with their bare eyes.",
        "Andromeda's brightest star, Alpheratz, also forms one corner of the Great Square of Pegasus.",
    ],
    "Antlia": [
        "Antlia means 'air pump'. French astronomer Nicolas-Louis de Lacaille named it in the 1750s after an exciting new science instrument.",
        "Antlia is faint: none of its stars is brighter than fourth magnitude, so you need a dark sky to spot it.",
    ],
    "Apus": [
        "Apus is a bird of paradise. Its name comes from Greek for 'without feet', because Europeans first saw these birds as specimens with the feet removed.",
        "Apus sits close to the south celestial pole, so it can't be seen from most of the Northern Hemisphere.",
    ],
    "Aquarius": [
        "Aquarius, the Water-Bearer, is one of the oldest constellations and one of the 12 signs of the zodiac.",
        "The Helix Nebula in Aquarius is one of the closest planetary nebulae to Earth, the glowing shell of a dying star.",
        "The Eta Aquariid meteor shower each May comes from dust left behind by Halley's Comet.",
    ],
    "Aquila": [
        "Aquila is the eagle that carried Zeus's thunderbolts in Greek myth.",
        "Its brightest star, Altair, spins so fast (about once every 9 hours) that it bulges out at its middle.",
        "Altair is one of the three stars of the Summer Triangle, along with Vega and Deneb.",
    ],
    "Ara": [
        "Ara is the altar where, in Greek myth, the gods swore loyalty to each other before battling the Titans.",
        "Ara lies in a rich part of the Milky Way in the southern sky, and its star Mu Arae has several known planets.",
    ],
    "Aries": [
        "Aries is the ram whose golden fleece Jason and the Argonauts went searching for.",
        "About 2,000 years ago the Sun sat in Aries at the spring equinox, which is why that point is still called the 'First Point of Aries', even though it has drifted into Pisces.",
    ],
    "Auriga": [
        "Auriga is the Charioteer, often pictured carrying a mother goat and her kids.",
        "Its brightest star, Capella ('little she-goat'), looks like one star but is actually two pairs of stars.",
        "Capella is the sixth-brightest star in the night sky.",
    ],
    "Boötes": [
        "Boötes is the Herdsman. Its star Arcturus is the brightest star in the northern half of the sky.",
        "Follow the curve of the Big Dipper's handle and you'll 'arc to Arcturus'.",
        "In 1933, light from Arcturus was captured by a telescope and used to switch on the lights at the Chicago World's Fair.",
    ],
    "Caelum": [
        "Caelum means 'chisel'. Lacaille named it in the 1750s after an engraver's tool.",
        "Caelum is one of the smallest and faintest constellations, with only a couple of stars brighter than fifth magnitude.",
    ],
    "Camelopardalis": [
        "Camelopardalis is a giraffe. The old name means 'camel-leopard', because a giraffe looked like a camel with a leopard's spots.",
        "It was created in the early 1600s by Dutch astronomer Petrus Plancius, and it's big but very faint.",
    ],
    "Cancer": [
        "Cancer is the crab that the goddess Hera sent to nip Hercules while he fought the Hydra. He crushed it under his foot.",
        "The Beehive Cluster in Cancer is a swarm of stars you can see as a fuzzy patch without a telescope.",
        "The Tropic of Cancer is named after it, because the Sun was in Cancer at the June solstice about 2,000 years ago.",
    ],
    "Canes Venatici": [
        "Canes Venatici are the Hunting Dogs held on a leash by Boötes. Johannes Hevelius created the constellation in 1687.",
        "The famous Whirlpool Galaxy, a spiral galaxy seen face-on, is in Canes Venatici.",
        "Its brightest star is called Cor Caroli, 'Charles's Heart', in honour of an English King Charles.",
    ],
    "Canis Major": [
        "Canis Major, the Big Dog, is one of Orion's hunting dogs.",
        "It holds Sirius, the brightest star in the whole night sky, only about 8.6 light-years away.",
        "The 'dog days of summer' got their name because Sirius rose with the Sun in the hottest part of the year.",
    ],
    "Canis Minor": [
        "Canis Minor is the Little Dog, Orion's second hunting dog.",
        "Its brightest star, Procyon, means 'before the dog', because it rises just before Sirius.",
        "Procyon is one corner of the Winter Triangle, with Sirius and Betelgeuse.",
    ],
    "Capricornus": [
        "Capricornus is a sea goat: half goat, half fish. In one myth, the god Pan turned partly into a fish to escape the monster Typhon.",
        "The Tropic of Capricorn is named after it, because the Sun was in Capricornus at the December solstice about 2,000 years ago.",
        "It's one of the faintest zodiac constellations.",
    ],
    "Carina": [
        "Carina is the keel of the Argo, the ship of Jason and the Argonauts. The giant constellation Argo Navis was split into three pieces in the 1750s.",
        "Its star Canopus is the second-brightest star in the night sky.",
        "Eta Carinae is a huge, unstable star that had a giant outburst in the 1840s and briefly became one of the brightest stars in the sky.",
    ],
    "Cassiopeia": [
        "Cassiopeia was a vain queen who boasted about her beauty. As punishment she circles the pole, spending half her time upside down.",
        "Its five brightest stars make an easy-to-spot 'W' (or 'M') shape.",
        "In 1572 astronomer Tycho Brahe saw a brand-new star appear in Cassiopeia: a supernova.",
    ],
    "Centaurus": [
        "Centaurus holds Alpha Centauri, the closest star system to the Sun, about 4.4 light-years away.",
        "Proxima Centauri, the single closest star to the Sun, is part of the Alpha Centauri system.",
        "Omega Centauri is the biggest globular cluster in our galaxy, a ball of about 10 million stars.",
    ],
    "Cepheus": [
        "Cepheus is the king, husband of Cassiopeia and father of Andromeda.",
        "Its star Delta Cephei gave its name to Cepheid variable stars, which astronomers use as 'measuring sticks' for cosmic distances.",
        "Mu Cephei, the 'Garnet Star', is a deep red supergiant and one of the largest stars known.",
    ],
    "Cetus": [
        "Cetus is the sea monster sent to eat Andromeda. Perseus defeated it.",
        "Its star Mira ('the wonderful') slowly brightens and fades over about 11 months, and was one of the first variable stars discovered.",
        "Cetus is the fourth-largest constellation.",
    ],
    "Chamaeleon": [
        "Chamaeleon is a chameleon, added in the late 1500s from the observations of Dutch explorers sailing south.",
        "It sits right next to Musca, the fly, as if it's about to catch it.",
    ],
    "Circinus": [
        "Circinus is a drawing compass, named by Lacaille in the 1750s.",
        "It's the fourth-smallest constellation and sits right beside bright Alpha Centauri.",
    ],
    "Columba": [
        "Columba is the dove that Noah released from the ark to look for dry land.",
        "Dutch astronomer Petrus Plancius created it in the 1590s from stars near Canis Major.",
    ],
    "Coma Berenices": [
        "Coma Berenices is Queen Berenice's hair. She cut off her hair as an offering for her husband's safe return, and the story says the gods put it in the sky.",
        "Looking toward Coma Berenices, you look straight out of our galaxy's disc, at the north galactic pole.",
        "The Coma Cluster, a huge group of more than 1,000 galaxies, lies in this direction.",
    ],
    "Corona Australis": [
        "Corona Australis is the Southern Crown, one of the 48 constellations listed by Ptolemy almost 2,000 years ago.",
        "It's a small curve of stars that looks like a crown or wreath.",
    ],
    "Corona Borealis": [
        "Corona Borealis is the Northern Crown, the crown of Princess Ariadne in Greek myth.",
        "Its star T Coronae Borealis, the 'Blaze Star', is a nova that flares up roughly every 80 years. It erupted in 1866 and 1946.",
    ],
    "Corvus": [
        "Corvus is a crow. In myth, Apollo's crow lied to him and was placed in the sky beside a cup (Crater) it can never drink from.",
        "The Antennae Galaxies in Corvus are two galaxies crashing into each other.",
    ],
    "Crater": [
        "Crater is the cup of the god Apollo, sitting next to Corvus the crow.",
        "It's a faint constellation, shaped a little like a goblet.",
    ],
    "Crux": [
        "Crux, the Southern Cross, is the smallest of all 88 constellations.",
        "It appears on the flags of Australia, New Zealand, Brazil, Samoa and Papua New Guinea.",
        "Next to it is the Coalsack, a dark cloud of dust that blocks the stars behind it.",
    ],
    "Cygnus": [
        "Cygnus is a swan flying along the Milky Way. Its brightest stars form the 'Northern Cross'.",
        "Its star Deneb is one of the most luminous stars known, shining tens of thousands of times brighter than the Sun.",
        "Cygnus X-1 was the first object widely accepted to be a black hole.",
    ],
    "Delphinus": [
        "Delphinus is the dolphin that helped Poseidon find his bride, Amphitrite.",
        "Two of its stars are named Sualocin and Rotanev: 'Nicolaus Venator' spelled backwards, a sneaky joke by an astronomer's assistant.",
    ],
    "Dorado": [
        "Dorado is a dolphinfish (mahi-mahi), added by Dutch navigators in the late 1500s.",
        "Most of the Large Magellanic Cloud, a small galaxy orbiting our own, lies in Dorado.",
        "Supernova 1987A exploded in Dorado, the closest supernova seen since the telescope was invented.",
    ],
    "Draco": [
        "Draco is the dragon that guarded the golden apples of the Hesperides in Greek myth.",
        "When the Egyptian pyramids were being built, Draco's star Thuban was the North Star.",
        "The Cat's Eye Nebula, a dying star's colourful shell, is in Draco.",
    ],
    "Equuleus": [
        "Equuleus, the Little Horse, is the second-smallest constellation.",
        "Even though it's tiny and faint, it's one of the 48 ancient constellations listed by Ptolemy.",
    ],
    "Eridanus": [
        "Eridanus is a river winding across the sky. It's the sixth-largest constellation.",
        "Its brightest star, Achernar ('end of the river'), spins so fast that it's one of the most squashed stars known.",
        "Epsilon Eridani, only about 10.5 light-years away, is one of the closest stars like our Sun.",
    ],
    "Fornax": [
        "Fornax is a chemist's furnace, named by Lacaille in the 1750s.",
        "The Hubble Space Telescope's famous Ultra Deep Field photo, full of thousands of galaxies, was taken looking into Fornax.",
    ],
    "Gemini": [
        "Gemini is the twins Castor and Pollux. Its two brightest stars carry their names.",
        "The Geminid meteor shower every December is one of the best of the year.",
        "Pluto was discovered in 1930 in Gemini.",
    ],
    "Grus": [
        "Grus is a crane, created by Petrus Plancius from Dutch sailors' southern sky observations.",
        "Its brightest star is called Alnair, from Arabic for 'the bright one'.",
    ],
    "Hercules": [
        "Hercules is the Greek hero famous for completing 12 impossible labours.",
        "The Great Globular Cluster in Hercules (M13) is a ball of hundreds of thousands of stars.",
        "In 1974, scientists beamed the Arecibo radio message toward M13 in Hercules.",
    ],
    "Horologium": [
        "Horologium is a pendulum clock, named by Lacaille in the 1750s.",
        "Pendulum clocks had been invented by Christiaan Huygens about a century earlier, and they were key for accurate astronomy.",
    ],
    "Hydra": [
        "Hydra, the water snake, is the largest of all 88 constellations, stretching more than a quarter of the way around the sky.",
        "Its brightest star, Alphard, means 'the solitary one', because there are no other bright stars near it.",
    ],
    "Hydrus": [
        "Hydrus is a small water snake in the far southern sky, not to be confused with the giant Hydra.",
        "It lies between the Large and Small Magellanic Clouds.",
    ],
    "Indus": [
        "Indus represents a person from the Indies, added by Petrus Plancius from Dutch explorers' observations.",
        "Its star Epsilon Indi, about 12 light-years away, has two brown dwarfs orbiting it.",
    ],
    "Lacerta": [
        "Lacerta is a lizard, created by Johannes Hevelius in 1687.",
        "BL Lacertae, first thought to be a variable star in Lacerta, turned out to be a distant galaxy with a jet pointing at us: a 'blazar'.",
    ],
    "Leo Minor": [
        "Leo Minor, the Little Lion, was created by Johannes Hevelius in 1687.",
        "Strangely, Leo Minor has a 'Beta' star but no 'Alpha' star.",
    ],
    "Leo": [
        "Leo is the Nemean Lion, whose skin no weapon could pierce, defeated by Hercules.",
        "Its bright star Regulus means 'little king'.",
        "The Leonid meteor shower each November seems to come from Leo.",
    ],
    "Lepus": [
        "Lepus is a hare, sitting at Orion's feet and chased by his hunting dogs.",
        "Hind's Crimson Star in Lepus is one of the reddest stars in the sky.",
    ],
    "Libra": [
        "Libra, the Scales, is the only zodiac constellation that's an object rather than a living creature.",
        "Its two brightest stars have names meaning 'southern claw' and 'northern claw', because they were once part of Scorpius.",
    ],
    "Lupus": [
        "Lupus is a wolf, one of the 48 ancient constellations.",
        "In the year 1006 a supernova appeared in Lupus. It was the brightest exploding star in recorded history, visible in daylight.",
    ],
    "Lynx": [
        "Johannes Hevelius named Lynx in 1687, joking that you'd need the eyes of a lynx to see its faint stars.",
        "Lynx is big but has no bright stars, making it one of the hardest constellations to trace.",
    ],
    "Lyra": [
        "Lyra is the lyre (a small harp) of Orpheus, the musician of Greek myth.",
        "Its star Vega was the North Star around 14,000 years ago and will be again in roughly 12,000 years.",
        "The Ring Nebula, a smoke ring of gas from a dying star, is in Lyra.",
    ],
    "Mensa": [
        "Mensa is named after Table Mountain in Cape Town, where Lacaille mapped the southern sky. It's the only constellation named after a place on Earth.",
        "Mensa is the faintest constellation: none of its stars is brighter than fifth magnitude.",
    ],
    "Microscopium": [
        "Microscopium is a microscope, named by Lacaille in the 1750s.",
        "It's a faint constellation, and you need a dark sky to see any of its stars.",
    ],
    "Monoceros": [
        "Monoceros is a unicorn, added in the early 1600s by Petrus Plancius.",
        "It sits inside the Winter Triangle, and holds the beautiful Rosette Nebula.",
    ],
    "Musca": [
        "Musca, the Fly, is the only insect in the sky.",
        "It sits near the Southern Cross, right beside Chamaeleon.",
    ],
    "Norma": [
        "Norma is a carpenter's level and square, named by Lacaille in the 1750s.",
        "When its borders were redrawn, its Alpha and Beta stars ended up in Scorpius, so Norma has no Alpha star.",
    ],
    "Octans": [
        "Octans is an octant, a navigation tool, named by Lacaille in the 1750s.",
        "The south celestial pole is in Octans. Its 'south pole star', Sigma Octantis, is so faint it's hard to see.",
    ],
    "Ophiuchus": [
        "Ophiuchus is the serpent bearer, often linked to Asclepius, the Greek god of medicine.",
        "The Sun passes through Ophiuchus each year, which is why it's sometimes called the 13th zodiac sign.",
        "In 1604 Johannes Kepler watched a supernova in Ophiuchus, the last one seen with bare eyes in our galaxy.",
    ],
    "Orion": [
        "Orion the Hunter is one of the most recognisable constellations, with three stars in a row forming his belt.",
        "Betelgeuse, Orion's shoulder, is a red supergiant so big it would swallow Mars's orbit if it replaced the Sun.",
        "The Orion Nebula, below the belt, is a star nursery about 1,350 light-years away that you can see without a telescope.",
    ],
    "Pavo": [
        "Pavo is a peacock, a bird the ancient Greeks linked to the goddess Hera.",
        "It was created by Petrus Plancius from Dutch sailors' observations of the southern sky.",
    ],
    "Pegasus": [
        "Pegasus is the winged horse that sprang from Medusa when Perseus defeated her.",
        "Four of its stars form the Great Square of Pegasus, a giant box in the autumn sky.",
        "51 Pegasi was the first Sun-like star found with a planet orbiting it, in 1995.",
    ],
    "Perseus": [
        "Perseus is the hero who defeated Medusa and rescued Andromeda.",
        "Its star Algol, the 'Demon Star', dims every 2.9 days when a companion star passes in front of it.",
        "The Perseid meteor shower every August seems to come from Perseus.",
    ],
    "Phoenix": [
        "Phoenix is the mythical bird that is reborn from its own ashes.",
        "It was created by Petrus Plancius from Dutch explorers' observations in the late 1500s.",
    ],
    "Pictor": [
        "Pictor is a painter's easel, named by Lacaille in the 1750s.",
        "Its star Beta Pictoris is a young star surrounded by a dusty disc with planets forming in it.",
    ],
    "Pisces": [
        "Pisces is two fish tied together by a cord: Aphrodite and Eros, who turned into fish to escape the monster Typhon.",
        "The spring equinox point, where the Sun crosses the celestial equator in March, now lies in Pisces.",
    ],
    "Piscis Austrinus": [
        "Piscis Austrinus is the Southern Fish, drinking the water poured by Aquarius.",
        "Its brightest star, Fomalhaut ('mouth of the fish'), is one of the brightest stars in the sky.",
    ],
    "Puppis": [
        "Puppis is the stern (back end) of the Argo, Jason's ship. It's the biggest of the three pieces Argo Navis was split into.",
        "Puppis lies in the Milky Way and is packed with star clusters.",
    ],
    "Pyxis": [
        "Pyxis is a mariner's compass, named by Lacaille in the 1750s.",
        "It sits right next to the old ship Argo, which makes sense for a ship's compass.",
    ],
    "Reticulum": [
        "Reticulum is a reticle: the grid of fine lines in a telescope eyepiece used to measure star positions.",
        "Lacaille named it in the 1750s after the reticle he used to map almost 10,000 southern stars.",
    ],
    "Sagitta": [
        "Sagitta, the Arrow, is the third-smallest constellation.",
        "Despite its size it's ancient: one of the 48 constellations listed by Ptolemy.",
    ],
    "Sagittarius": [
        "Sagittarius is an archer, a centaur aiming his bow at Scorpius.",
        "The centre of our Milky Way galaxy lies in the direction of Sagittarius.",
        "A supermassive black hole about 4 million times the Sun's mass, Sagittarius A*, sits there.",
    ],
    "Scorpius": [
        "Scorpius is the scorpion that killed Orion. The two are placed on opposite sides of the sky, so one sets as the other rises.",
        "Its bright red star Antares means 'rival of Mars', because it's as red as the planet.",
    ],
    "Sculptor": [
        "Sculptor was named by Lacaille in the 1750s, originally as a sculptor's studio.",
        "The south galactic pole, pointing straight out of our galaxy, lies in Sculptor.",
    ],
    "Scutum": [
        "Scutum is a shield, named in 1684 by Johannes Hevelius to honour King John III Sobieski of Poland.",
        "The Wild Duck Cluster in Scutum is a cluster of stars shaped like a flying flock of ducks.",
    ],
    "Serpens": [
        "Serpens is the only constellation split in two: a head and a tail, on either side of Ophiuchus, who holds the snake.",
        "The Eagle Nebula, home of the famous 'Pillars of Creation', is in Serpens.",
    ],
    "Sextans": [
        "Sextans is a sextant, named by Johannes Hevelius after the instrument he used to measure star positions.",
        "Hevelius named it after his observatory and instruments were destroyed in a fire in 1679.",
    ],
    "Taurus": [
        "Taurus is the bull that the god Zeus disguised himself as to carry off Princess Europa.",
        "The Pleiades, or Seven Sisters, is a beautiful star cluster in Taurus.",
        "The Crab Nebula in Taurus is what's left of a supernova that astronomers saw in the year 1054.",
    ],
    "Telescopium": [
        "Telescopium is a telescope, named by Lacaille in the 1750s.",
        "It's a faint southern constellation with no bright, easy-to-spot pattern.",
    ],
    "Triangulum Australe": [
        "Triangulum Australe, the Southern Triangle, has three bright stars that make a neat triangle.",
        "It was added in the late 1500s from Dutch explorers' observations of the southern sky.",
    ],
    "Triangulum": [
        "Triangulum is a small, simple triangle of three stars in the northern sky.",
        "The Triangulum Galaxy, about 3 million light-years away, can be seen with bare eyes under very dark skies.",
    ],
    "Tucana": [
        "Tucana is a toucan, added in the late 1500s from Dutch explorers' observations.",
        "The Small Magellanic Cloud, a little galaxy near our own, lies in Tucana.",
        "47 Tucanae is the second-brightest globular cluster in the sky.",
    ],
    "Ursa Major": [
        "Ursa Major is the Great Bear, the third-largest constellation. The Big Dipper is part of it.",
        "The two stars at the end of the Big Dipper's bowl point straight to Polaris, the North Star.",
        "In Greek myth, Callisto was turned into a bear and placed in the sky.",
    ],
    "Ursa Minor": [
        "Ursa Minor, the Little Bear, contains the Little Dipper.",
        "Polaris, the North Star, is at the end of the Little Dipper's handle, and it barely moves as the sky turns.",
        "Polaris is actually a system of several stars, and the main one gently pulses in brightness.",
    ],
    "Vela": [
        "Vela is the sails of the Argo, Jason's ship.",
        "The Vela Pulsar is the leftover core of a star that exploded about 11,000 years ago, and it spins about 11 times a second.",
        "Four of its stars form the 'False Cross', which sailors sometimes mistook for the Southern Cross.",
    ],
    "Virgo": [
        "Virgo is the second-largest constellation, and the largest in the zodiac.",
        "Its brightest star, Spica, is a pair of hot blue stars orbiting each other closely.",
        "The first-ever photo of a black hole, released in 2019, showed the one at the heart of galaxy M87 in Virgo.",
    ],
    "Volans": [
        "Volans is a flying fish, added in the late 1500s from Dutch sailors' observations.",
        "Flying fish can glide above the waves, a sight that amazed early sailors in southern seas.",
    ],
    "Vulpecula": [
        "Vulpecula is a little fox, created by Johannes Hevelius in the 1680s.",
        "The Dumbbell Nebula in Vulpecula was the first planetary nebula ever discovered, in 1764.",
        "The first pulsar was discovered in Vulpecula in 1967 by Jocelyn Bell Burnell.",
    ],
}
