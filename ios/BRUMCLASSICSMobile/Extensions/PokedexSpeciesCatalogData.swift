import Foundation

enum PokedexSpeciesCatalogData {
    static let allSpecies: [PokedexSpeciesDefinition] = parseCatalog()

    private static func parseCatalog() -> [PokedexSpeciesDefinition] {
        let lines = rawTSV.split(separator: "\n", omittingEmptySubsequences: true)
        var result: [PokedexSpeciesDefinition] = []
        result.reserveCapacity(lines.count)
        for line in lines {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 6,
                  let dex = Int(parts[0]),
                  let gen = Int(parts[1]) else { continue }
            let numStr = String(format: "%03d", dex)
            result.append(PokedexSpeciesDefinition(
                nationalDexNumber: dex,
                generation: gen,
                slug: String(parts[2]),
                name: String(parts[3]),
                genus: String(parts[4]),
                description: String(parts[5]),
                spriteAsset: PokedexSpriteAsset(
                    activeKey: "pokedex/normal/\(numStr)",
                    normalKey: "pokedex/normal/\(numStr)",
                    shinyKey: "pokedex/shiny/\(numStr)",
                    silhouetteKey: "pokedex/silhouette/\(numStr)"
                )
            ))
        }
        return result
    }

    private static let rawTSV: String = #"""
1	1	bulbasaur	Bulbasaur	Seed Pokémon	There is a plant seed on its back right from the day this Pokémon is born. The seed slowly grows larger.
2	1	ivysaur	Ivysaur	Seed Pokémon	There is a plant bulb on its back. When it absorbs nutrients, the bulb is said to blossom into a large flower.
3	1	venusaur	Venusaur	Seed Pokémon	A bewitching aroma wafts from its flower. The fragrance becalms those engaged in a battle.
4	1	charmander	Charmander	Lizard Pokémon	From the time it is born, a flame burns at the tip of its tail. Its life would end if the flame were to go out.
5	1	charmeleon	Charmeleon	Flame Pokémon	It lashes about with its tail to knock down its foe. It then tears up the fallen opponent with sharp claws.
6	1	charizard	Charizard	Flame Pokémon	Its wings can carry this Pokémon close to an altitude of 4,600 feet. It blows out fire at very high temperatures.
7	1	squirtle	Squirtle	Tiny Turtle Pokémon	When it retracts its long neck into its shell, it squirts out water with vigorous force.
8	1	wartortle	Wartortle	Turtle Pokémon	This Pokémon is very popular as a pet. Its fur-covered tail is a symbol of its longevity.
9	1	blastoise	Blastoise	Shellfish Pokémon	It crushes its foe under its heavy body to cause fainting. In a pinch, it will withdraw inside its shell.
10	1	caterpie	Caterpie	Worm Pokémon	It is covered with a green skin. When it grows, it sheds the skin, covers itself with silk, and becomes a cocoon.
11	1	metapod	Metapod	Cocoon Pokémon	Even though it is encased in a sturdy shell, the body inside is tender. It can’t withstand a harsh attack.
12	1	butterfree	Butterfree	Butterfly Pokémon	The wings are protected by rain-repellent dust. As a result, this Pokémon can fly about even in rain.
13	1	weedle	Weedle	Hairy Bug Pokémon	Often found in forests and grasslands. It has a sharp, toxic barb of around two inches on top of its head.
14	1	kakuna	Kakuna	Cocoon Pokémon	This Pokémon is in a temporary stage while making its body. It is almost completely unable to move on its own.
15	1	beedrill	Beedrill	Poison Bee Pokémon	May appear in a swarm. Flies at violent speeds, all the while stabbing with the toxic stinger on its rear.
16	1	pidgey	Pidgey	Tiny Bird Pokémon	Does not like to fight. It hides in tall grass and so on, foraging for food such as small bugs.
17	1	pidgeotto	Pidgeotto	Bird Pokémon	The claws on its feet are well developed. It can carry prey such as an EXEGGCUTE to its nest over 60 miles away.
18	1	pidgeot	Pidgeot	Bird Pokémon	It spreads its gorgeous wings widely to intimidate enemies. It races through the skies at Mach-2 speed.
19	1	rattata	Rattata	Mouse Pokémon	Its fangs are long and very sharp. They grow continuously, so it gnaws on hard things to whittle them down.
20	1	raticate	Raticate	Mouse Pokémon	Its rear feet have three toes each. They are webbed, enabling it to swim across rivers.
21	1	spearow	Spearow	Tiny Bird Pokémon	It busily flits around here and there. Even if it is frail, it can be a tough foe that uses MIRROR MOVE.
22	1	fearow	Fearow	Beak Pokémon	Its huge and magnificent wings can keep it aloft in the sky. It can remain flying a whole day without landing.
23	1	ekans	Ekans	Snake Pokémon	A very common sight in grassland, etc. It flicks its tongue in and out to sense danger in its surroundings.
24	1	arbok	Arbok	Cobra Pokémon	The pattern on its belly appears to be a frightening face. Weak foes will flee just at the sight of the pattern.
25	1	pikachu	Pikachu	Mouse Pokémon	It has small electric sacs on both its cheeks. If threatened, it looses electric charges from the sacs.
26	1	raichu	Raichu	Mouse Pokémon	Its electric charges can reach even 100,000 volts. Careless contact can cause even an Indian elephant to faint.
27	1	sandshrew	Sandshrew	Mouse Pokémon	It burrows and lives underground. If threatened, it curls itself up into a ball for protection.
28	1	sandslash	Sandslash	Mouse Pokémon	It is adept at attacking with the spines on its back and its sharp claws while quickly scurrying about.
29	1	nidoran-f	Nidoran♀	Poison Pin Pokémon	Though small, it must be treated with caution because of its powerfully toxic barbs. The female has smaller horns.
30	1	nidorina	Nidorina	Poison Pin Pokémon	The female has a gentle temperament. It emits ultrasonic cries that have the power to befuddle foes.
31	1	nidoqueen	Nidoqueen	Drill Pokémon	The body is covered by stiff, needle- like scales. If it becomes excited, the needles bristle outwards.
32	1	nidoran-m	Nidoran♂	Poison Pin Pokémon	Its large ears are flapped like wings when it is listening to distant sounds. It extends toxic barbs when angered.
33	1	nidorino	Nidorino	Poison Pin Pokémon	It is easily angered. By swinging its well- developed horn wildly, it can even punch through diamond.
34	1	nidoking	Nidoking	Drill Pokémon	It is recognized by its rock-hard hide and its extended horn. Be careful with the horn as it contains venom.
35	1	clefairy	Clefairy	Fairy Pokémon	Its adorable appearance makes it popular as a pet. However, it is rare and difficult to find.
36	1	clefable	Clefable	Fairy Pokémon	It has an acute sense of hearing. It can easily hear a pin being dropped nearly 1,100 yards away.
37	1	vulpix	Vulpix	Fox Pokémon	While young, it has six gorgeous tails. When it grows, several new tails are sprouted.
38	1	ninetales	Ninetales	Fox Pokémon	It has nine long tails and fur that gleams gold. It is said to live for 1,000 years.
39	1	jigglypuff	Jigglypuff	Balloon Pokémon	It captivates foes with its huge, round eyes, then lulls them to sleep by singing a soothing melody.
40	1	wigglytuff	Wigglytuff	Balloon Pokémon	Its fur is extremely fine, dense, and supple. The exquisitely pleasant fur conveys an image of luxury.
41	1	zubat	Zubat	Bat Pokémon	It has no eyes. Instead, it relies on its ultrasonic cries for echo location to flit about in darkness.
42	1	golbat	Golbat	Bat Pokémon	It clamps down on its prey with needle- sharp fangs and drains over 10 ounces of blood in one gulp.
43	1	oddish	Oddish	Weed Pokémon	Its scientific name is “Oddium Wanderus.” At night, it is said to walk nearly 1,000 feet on its two roots.
44	1	gloom	Gloom	Weed Pokémon	Its pistils exude an incredibly foul odor. The horrid stench can cause fainting at a distance of 1.25 miles.
45	1	vileplume	Vileplume	Flower Pokémon	Its petals are the largest in the world. It fiendishly scatters allergy-causing pollen from its petals.
46	1	paras	Paras	Mushroom Pokémon	Growing out of the bug’s back are mushrooms called tochukaso. The mushrooms grow with the bug host.
47	1	parasect	Parasect	Mushroom Pokémon	It scatters toxic spores from the mushroom cap. In China, the spores are used as herbal medicine.
48	1	venonat	Venonat	Insect Pokémon	Its eyes act as radar, enabling it to be active in darkness. The eyes can also shoot powerful beams.
49	1	venomoth	Venomoth	Poison Moth Pokémon	The wings are covered with dustlike scales. Every time it flaps its wings, it looses highly toxic dust.
50	1	diglett	Diglett	Mole Pokémon	It burrows through the ground at a shallow depth. It leaves raised earth in its wake, making it easy to spot.
51	1	dugtrio	Dugtrio	Mole Pokémon	In battle, it digs through the ground and strikes the unsuspecting foe from an unexpected direction.
52	1	meowth	Meowth	Scratch Cat Pokémon	All it does is sleep during the daytime. At night, it patrols its territory with its eyes aglow.
53	1	persian	Persian	Classy Cat Pokémon	Has a vicious temperament. Beware if it raises its tail straight up. It is a signal that it is about to pounce and bite.
54	1	psyduck	Psyduck	Duck Pokémon	It is constantly wracked by a headache. When the headache turns intense, it begins using mysterious powers.
55	1	golduck	Golduck	Duck Pokémon	The forelegs are webbed, helping to make it an adept swimmer. It can be seen swimming elegantly in lakes, etc.
56	1	mankey	Mankey	Pig Monkey Pokémon	Light and agile on its feet, and ferocious in temperament. When angered, it flies into an uncontrollable frenzy.
57	1	primeape	Primeape	Pig Monkey Pokémon	It is always outrageously furious. If it gives chase, it will tenaciously track the target no matter how far.
58	1	growlithe	Growlithe	Puppy Pokémon	Very friendly and faithful to people. It will try to repel enemies by barking and biting.
59	1	arcanine	Arcanine	Legendary Pokémon	A Pokémon that is described in Chinese legends. It is said to race at an unbelievable speed.
60	1	poliwag	Poliwag	Tadpole Pokémon	Its slick black skin is thin and damp. A part of its internal organs can be seen through the skin as a spiral pattern.
61	1	poliwhirl	Poliwhirl	Tadpole Pokémon	Its two legs are well developed. Even though it can live on the ground, it prefers living in water.
62	1	poliwrath	Poliwrath	Tadpole Pokémon	An adept swimmer, it knows the front crawl, butterfly, and more. It is faster than the best human swimmers.
63	1	abra	Abra	Psi Pokémon	It sleeps for 18 hours a day. It uses a variety of extrasensory powers even while asleep.
64	1	kadabra	Kadabra	Psi Pokémon	It happened one morning - a boy with extrasensory powers awoke in bed transformed into KADABRA.
65	1	alakazam	Alakazam	Psi Pokémon	It does not like physical attacks very much. Instead, it freely uses extra sensory powers to defeat foes.
66	1	machop	Machop	Superpower Pokémon	Its whole body is composed of muscles. Even though it’s the size of a human child, it can hurl 100 grown-ups.
67	1	machoke	Machoke	Superpower Pokémon	Its formidable body never gets tired. It helps people by doing work such as the moving of heavy goods.
68	1	machamp	Machamp	Superpower Pokémon	Its four ruggedly developed arms can launch a flurry of 1,000 punches in just two seconds.
69	1	bellsprout	Bellsprout	Flower Pokémon	Its bud looks like a human face. Because of the bud, it is rumored to be a type of legendary mandrake plant.
70	1	weepinbell	Weepinbell	Flycatcher Pokémon	The leafy parts act as cutters for slashing foes. It spits a fluid that dissolves everything.
71	1	victreebel	Victreebel	Flycatcher Pokémon	Lures prey into its mouth with a honeylike aroma. The helpless prey is melted with a dissolving fluid.
72	1	tentacool	Tentacool	Jellyfish Pokémon	Its eyes are as transparent as crystals. From them, it shoots mysterious beams of light.
73	1	tentacruel	Tentacruel	Jellyfish Pokémon	It has 80 tentacles that move about freely. They can sting, causing poisoning and sharp, stabbing pain.
74	1	geodude	Geodude	Rock Pokémon	Its round form makes it easy to pick up. Some people have used them to hurl at each other in a snowball fight.
75	1	graveler	Graveler	Rock Pokémon	Be careful while hiking on mountain trails. GRAVELER may come rolling down the path without slowing.
76	1	golem	Golem	Megaton Pokémon	It is enclosed in a hard shell that is as rugged as slabs of rock. It sheds skin once a year to grow larger.
77	1	ponyta	Ponyta	Fire Horse Pokémon	Its body is light, and its legs are incredibly powerful. It can clear Ayers Rock in one leap.
78	1	rapidash	Rapidash	Fire Horse Pokémon	It can gallop at a top speed of 150 miles per hour. It can race as fast as a bullet train while ablaze.
79	1	slowpoke	Slowpoke	Dopey Pokémon	It is always vacantly lost in thought, but no one knows what it is thinking about. It is good at fishing with its tail.
80	1	slowbro	Slowbro	Hermit Crab Pokémon	When a SLOWPOKE went hunting in the sea, its tail was bitten by a SHELLDER. That made it evolve into SLOWBRO.
81	1	magnemite	Magnemite	Magnet Pokémon	It moves while constantly hovering. It discharges THUNDER WAVE and so on from the units at its sides.
82	1	magneton	Magneton	Magnet Pokémon	A linked cluster formed of several MAGNEMITE. It discharges powerful magnetic waves at high voltage.
83	1	farfetchd	Farfetch’d	Wild Duck Pokémon	It always walks about with a plant stalk clamped in its beak. The stalk is used for building its nest.
84	1	doduo	Doduo	Twin Bird Pokémon	A two-headed Pokémon that was discovered as a sudden mutation. It runs at a pace of over 60 miles per hour.
85	1	dodrio	Dodrio	Triple Bird Pokémon	An odd species that is rarely found. The three heads respectively represent joy, sadness, and anger.
86	1	seel	Seel	Sea Lion Pokémon	Covered with light blue fur, its hide is thick and tough. It is active in bitter cold of minus 40 degrees Fahrenheit.
87	1	dewgong	Dewgong	Sea Lion Pokémon	Its body is covered with a pure white fur. The colder the weather, the more active it becomes.
88	1	grimer	Grimer	Sludge Pokémon	Sludge exposed to X rays from the moon transformed into GRIMER. It loves feeding on filthy things.
89	1	muk	Muk	Sludge Pokémon	It is usually undetectable because it blends in with the ground. Touching it can cause terrible poisoning.
90	1	shellder	Shellder	Bivalve Pokémon	It is encased in a shell that is harder than diamond. Inside, however, it is surprisingly tender.
91	1	cloyster	Cloyster	Bivalve Pokémon	Its shell is extremely hard. It cannot be shattered, even with a bomb. The shell opens only when it is attacking.
92	1	gastly	Gastly	Gas Pokémon	A being that exists as a thin gas. It can topple an Indian elephant by enveloping the prey in two seconds.
93	1	haunter	Haunter	Gas Pokémon	If you get the feeling of being watched in darkness when nobody is around, HAUNTER is there.
94	1	gengar	Gengar	Shadow Pokémon	It is said to emerge from darkness to steal the lives of those who become lost in mountains.
95	1	onix	Onix	Rock Snake Pokémon	It usually lives underground. It searches for food while boring its way through the ground at 50 miles per hour.
96	1	drowzee	Drowzee	Hypnosis Pokémon	A descendent of the legendary animal baku, which is said to eat dreams. It is skilled at hypnotism.
97	1	hypno	Hypno	Hypnosis Pokémon	It carries a pendulum-like device. There once was an incident in which it took away a child it hypnotized.
98	1	krabby	Krabby	River Crab Pokémon	It can be found near the sea. The large pincers grow back if they are torn out of their sockets.
99	1	kingler	Kingler	Pincer Pokémon	Its large and hard pincer has 10,000- horsepower strength. However, being so big, it is unwieldy to move.
100	1	voltorb	Voltorb	Ball Pokémon	A life-form whose identity is unknown. It is said to SCREECH or suddenly SELFDESTRUCT.
101	1	electrode	Electrode	Ball Pokémon	It explodes in response to even minor stimuli. It is feared, with the nickname of “The Bomb Ball.”
102	1	exeggcute	Exeggcute	Egg Pokémon	Even though it appears to be eggs of some sort, it was discovered to be a life- form more like plant seeds.
103	1	exeggutor	Exeggutor	Coconut Pokémon	It is called “The Walking Tropical Rainforest.” Each of the nuts has a face and a will of its own.
104	1	cubone	Cubone	Lonely Pokémon	It wears the skull of its dead mother on its head. When it becomes lonesome, it is said to cry loudly.
105	1	marowak	Marowak	Bone Keeper Pokémon	It is small and was originally very weak. Its temperament turned ferocious when it began using bones.
106	1	hitmonlee	Hitmonlee	Kicking Pokémon	The legs freely contract and stretch. The stretchy legs allow it to hit a distant foe with a rising kick.
107	1	hitmonchan	Hitmonchan	Punching Pokémon	The spirit of a pro boxer has infused this Pokémon. It throws punches that are faster than a bullet train.
108	1	lickitung	Lickitung	Licking Pokémon	Its tongue is twice the length of its body. It can be moved like an arm for grabbing food and attacking.
109	1	koffing	Koffing	Poison Gas Pokémon	Its thin, balloon-like body is inflated by horribly toxic gases. It reeks when it is nearby.
110	1	weezing	Weezing	Poison Gas Pokémon	Very rarely, a sudden mutation can result in two small KOFFING twins becoming conjoined as a WEEZING.
111	1	rhyhorn	Rhyhorn	Spikes Pokémon	Strong, but not too bright, this Pokémon can shatter even a skyscraper with its charging TACKLES.
112	1	rhydon	Rhydon	Drill Pokémon	It begins walking on its hind legs after evolution. It can punch holes through boulders with its horn.
113	1	chansey	Chansey	Egg Pokémon	It lays several eggs a day. The eggs are apparently rich in nutrients and extremely delicious.
114	1	tangela	Tangela	Vine Pokémon	Blue plant vines cloak the Pokémon’s identity in a tangled mass. It entangles anything that gets close.
115	1	kangaskhan	Kangaskhan	Parent Pokémon	The female raises its offspring in a pouch on its belly. It is skilled at attacking using COMET PUNCH.
116	1	horsea	Horsea	Dragon Pokémon	It maintains balance using its tail, which is wound up like a coil. It may spray ink from its mouth.
117	1	seadra	Seadra	Dragon Pokémon	Its body bristles with sharp spikes. Carelessly trying to touch it could cause fainting from the spikes.
118	1	goldeen	Goldeen	Goldfish Pokémon	Its dorsal and pectoral fins are strongly developed like muscles. It can swim at a speed of five knots.
119	1	seaking	Seaking	Goldfish Pokémon	The horn on its head is sharp like a drill. It bores a hole in a boulder to make its nest.
120	1	staryu	Staryu	Star Shape Pokémon	It appears in large numbers by seashores. At night, its central core flashes with a red light.
121	1	starmie	Starmie	Mysterious Pokémon	This Pokémon has a geometric body. Because of its body, the locals suspect that it is an alien creature.
122	1	mr-mime	Mr. Mime	Barrier Pokémon	It is adept at conning people. It is said to be able to create walls out of thin air by miming.
123	1	scyther	Scyther	Mantis Pokémon	It tears and shreds prey with its wickedly sharp scythes. It very rarely spreads its wings to fly.
124	1	jynx	Jynx	Human Shape Pokémon	It speaks using a language that sounds human. Research is under way to determine what is being said.
125	1	electabuzz	Electabuzz	Electric Pokémon	It loves to feed on strong electricity. It occasionally appears around large power plants and so on.
126	1	magmar	Magmar	Spitfire Pokémon	Found near the mouth of a volcano. This fire-breather’s body temperature is nearly 2,200 degrees Fahrenheit.
127	1	pinsir	Pinsir	Stag Beetle Pokémon	Its two long pincer horns are powerful. Once they grip an enemy, they won’t release until the foe is torn.
128	1	tauros	Tauros	Wild Bull Pokémon	When it is about to TACKLE, it whips its body repeatedly with its three long tails.
129	1	magikarp	Magikarp	Fish Pokémon	It is virtually worthless in terms of both power and speed. It is the most weak and pathetic Pokémon in the world.
130	1	gyarados	Gyarados	Atrocious Pokémon	It has an extremely aggressive nature. The HYPER BEAM it shoots from its mouth totally incinerates all targets.
131	1	lapras	Lapras	Transport Pokémon	Its high intelligence enables it to understand human speech. It likes to ferry people on its back.
132	1	ditto	Ditto	Transform Pokémon	It can freely recombine its own cellular structure to transform into other life- forms.
133	1	eevee	Eevee	Evolution Pokémon	An extremely rare Pokémon that may evolve in a number of different ways depending on stimuli.
134	1	vaporeon	Vaporeon	Bubble Jet Pokémon	Its body’s cellular structure is similar to the molecular composition of water. It can melt invisibly in water.
135	1	jolteon	Jolteon	Lightning Pokémon	If it is angered or startled, the fur all over its body bristles like sharp needles that pierce foes.
136	1	flareon	Flareon	Flame Pokémon	It has a flame bag inside its body. After inhaling deeply, it blows out flames of nearly 3,100 degrees Fahrenheit.
137	1	porygon	Porygon	Virtual Pokémon	Using the most advanced technologies, scientists finally succeeded in making the first artificial Pokémon.
138	1	omanyte	Omanyte	Spiral Pokémon	A prehistoric Pokémon that lived in the primordial sea, it swims by twisting its 10 tentacles about.
139	1	omastar	Omastar	Spiral Pokémon	Its tentacles are highly developed as if they are hands and feet. As soon as it ensnares prey, it bites.
140	1	kabuto	Kabuto	Shellfish Pokémon	This Pokémon was regenerated from the fossil of an ancient creature. It protects itself with a hard shell.
141	1	kabutops	Kabutops	Shellfish Pokémon	It swims freely through water. It catches prey with its scythe-like arms and drains the victim’s fluids.
142	1	aerodactyl	Aerodactyl	Fossil Pokémon	It was regenerated from a dinosaur’s genetic matter that was found in amber. It flies with high-pitched cries.
143	1	snorlax	Snorlax	Sleeping Pokémon	It is not satisfied unless it eats over 880 pounds of food every day. When it is done eating, it goes promptly to sleep.
144	1	articuno	Articuno	Freeze Pokémon	One of the legendary bird Pokémon. With its long tail trailing behind, its flying form is magnificent.
145	1	zapdos	Zapdos	Electric Pokémon	One of the legendary bird Pokémon. While it is flying, it makes crackling and snapping sounds.
146	1	moltres	Moltres	Flame Pokémon	One of the legendary bird Pokémon. Those seeing it are overwhelmed by its orange wings that seem to be on fire.
147	1	dratini	Dratini	Dragon Pokémon	Even the young can exceed 6.5 feet in length. It grows larger by repeatedly shedding skin.
148	1	dragonair	Dragonair	Dragon Pokémon	It is said to live in seas and lakes. Even though it has no wings, it has been seen flying occasionally.
149	1	dragonite	Dragonite	Dragon Pokémon	It can fly in spite of its big and bulky physique. It circles the globe in just 16 hours.
150	1	mewtwo	Mewtwo	Genetic Pokémon	A Pokémon whose genetic code was repeatedly recombined for research. It turned vicious as a result.
151	1	mew	Mew	New Species Pokémon	A Pokémon of South America that was thought to have been extinct. It is very intelligent and learns any move.
152	2	chikorita	Chikorita	Leaf Pokémon	Its pleasantly aromatic leaves have the ability to check the humidity and temperature.
153	2	bayleef	Bayleef	Leaf Pokémon	A spicy aroma emanates from around its neck. The aroma acts as a stimulant to restore health.
154	2	meganium	Meganium	Herb Pokémon	MEGANIUM’s breath has the power to revive dead grass and plants. It can make them healthy again.
155	2	cyndaquil	Cyndaquil	Fire Mouse Pokémon	It usually stays hunched over. If it is angry or surprised, it shoots flames out of its back.
156	2	quilava	Quilava	Volcano Pokémon	This Pokémon is fully covered by nonflammable fur. It can withstand any kind of fire attack.
157	2	typhlosion	Typhlosion	Volcano Pokémon	It has a secret, devastating move. It rubs its blazing fur together to cause huge explosions.
158	2	totodile	Totodile	Big Jaw Pokémon	It is small but rough and tough. It won’t hesitate to take a bite out of anything that moves.
159	2	croconaw	Croconaw	Big Jaw Pokémon	It opens its huge jaws wide when attacking. If it loses any fangs while biting, they grow back in.
160	2	feraligatr	Feraligatr	Big Jaw Pokémon	It is hard for it to support its own weight out of water, so it gets down on all fours. But it moves fast.
161	2	sentret	Sentret	Scout Pokémon	It stands on its tail so it can see a long way. If it spots an enemy, it cries loudly to warn its kind.
162	2	furret	Furret	Long Body Pokémon	There is no telling where its tail begins. Despite its short legs, it is quick at hunting RATTATA.
163	2	hoothoot	Hoothoot	Owl Pokémon	It has a perfect sense of time. Whatever happens, it keeps rhythm by precisely tilting its head in time.
164	2	noctowl	Noctowl	Owl Pokémon	When it needs to think, it rotates its head 180 degrees to sharpen its intellectual power.
165	2	ledyba	Ledyba	Five Star Pokémon	When the weather turns cold, numerous LEDYBA gather from everywhere to cluster and keep each other warm.
166	2	ledian	Ledian	Five Star Pokémon	The star patterns on its back grow larger or smaller depending on the number of stars in the night sky.
167	2	spinarak	Spinarak	String Spit Pokémon	It spins a web using fine--but durable-- thread. It then waits patiently for prey to be trapped.
168	2	ariados	Ariados	Long Leg Pokémon	A single strand of a special string is endlessly spun out of its rear. The string leads back to its nest.
169	2	crobat	Crobat	Bat Pokémon	The development of wings on its legs enables it to fly fast but also makes it tough to stop and rest.
170	2	chinchou	Chinchou	Angler Pokémon	On the dark ocean floor, its only means of communication is its constantly flashing lights.
171	2	lanturn	Lanturn	Light Pokémon	It blinds prey with an intense burst of light, then swallows the immobilized prey in a single gulp.
172	2	pichu	Pichu	Tiny Mouse Pokémon	Despite its small size, it can zap even adult humans. However, if it does so, it also surprises itself.
173	2	cleffa	Cleffa	Star Shape Pokémon	When numerous meteors illuminate the night sky, sightings of CLEFFA strangely increase.
174	2	igglybuff	Igglybuff	Balloon Pokémon	Its extremely flexible and elastic body makes it bounce continuously--anytime, anywhere.
175	2	togepi	Togepi	Spike Ball Pokémon	A proverb claims that happiness will come to anyone who can make a sleeping TOGEPI stand up.
176	2	togetic	Togetic	Happiness Pokémon	It grows dispirited if it is not with kind people. It can float in midair without moving its wings.
177	2	natu	Natu	Tiny Bird Pokémon	It usually forages for food on the ground but may, on rare occasions, hop onto branches to peck at shoots.
178	2	xatu	Xatu	Mystic Pokémon	In South America, it is said that its right eye sees the future and its left eye views the past.
179	2	mareep	Mareep	Wool Pokémon	Its fleece grows continually. In the summer, the fleece is fully shed, but it grows back in a week.
180	2	flaaffy	Flaaffy	Wool Pokémon	Its fluffy fleece easily stores electricity. Its rubbery hide keeps it from being electrocuted.
181	2	ampharos	Ampharos	Light Pokémon	The bright light on its tail can be seen far away. It has been treasured since ancient times as a beacon.
182	2	bellossom	Bellossom	Flower Pokémon	Plentiful in the tropics. When it dances, its petals rub together and make a pleasant ringing sound.
183	2	marill	Marill	Aqua Mouse Pokémon	The end of its tail serves as a buoy that keeps it from drowning, even in a vicious current.
184	2	azumarill	Azumarill	Aqua Rabbit Pokémon	When it plays in water, it rolls up its elongated ears to prevent their insides from getting wet.
185	2	sudowoodo	Sudowoodo	Imitation Pokémon	It disguises itself as a tree to avoid attack. It hates water, so it will disappear if it starts raining.
186	2	politoed	Politoed	Frog Pokémon	Whenever three or more of these get together, they sing in a loud voice that sounds like bellowing.
187	2	hoppip	Hoppip	Cottonweed Pokémon	Its body is so light, it must grip the ground firmly with its feet to keep from being blown away.
188	2	skiploom	Skiploom	Cottonweed Pokémon	It spreads its petals to absorb sunlight. It also floats in the air to get closer to the sun.
189	2	jumpluff	Jumpluff	Cottonweed Pokémon	It drifts on seasonal winds and spreads its cotton-like spores all over the world to make more offspring.
190	2	aipom	Aipom	Long Tail Pokémon	It lives atop tall trees. When leaping from branch to branch, it deftly uses its tail for balance.
191	2	sunkern	Sunkern	Seed Pokémon	It lives by drinking only dewdrops from under the leaves of plants. It is said that it eats nothing else.
192	2	sunflora	Sunflora	Sun Pokémon	In the daytime, it rushes about in a hectic manner, but it comes to a complete stop when the sun sets.
193	2	yanma	Yanma	Clear Wing Pokémon	Its large eyes can scan 360 degrees. It looks in all directions to seek out insects as its prey.
194	2	wooper	Wooper	Water Fish Pokémon	When it walks around on the ground, it coats its body with a slimy, poisonous film.
195	2	quagsire	Quagsire	Water Fish Pokémon	Due to its relaxed and carefree attitude, it often bumps its head on boulders and boat hulls as it swims.
196	2	espeon	Espeon	Sun Pokémon	By reading air currents, it can predict things such as the weather or its foe’s next move.
197	2	umbreon	Umbreon	Moonlight Pokémon	When darkness falls, the rings on its body begin to glow, striking fear in the hearts of anyone nearby.
198	2	murkrow	Murkrow	Darkness Pokémon	It is said that when chased, it lures its attacker onto dark mountain trails where the foe will get lost.
199	2	slowking	Slowking	Royal Pokémon	When its head was bitten, toxins entered SLOWPOKE’s head and unlocked an extraordinary power.
200	2	misdreavus	Misdreavus	Screech Pokémon	It loves to bite and yank people’s hair from behind without warning, just to see their shocked reactions.
201	2	unown	Unown	Symbol Pokémon	Its flat, thin body is always stuck on walls. Its shape appears to have some meaning.
202	2	wobbuffet	Wobbuffet	Patient Pokémon	To keep its pitch-black tail hidden, it lives quietly in the darkness. It is never first to attack.
203	2	girafarig	Girafarig	Long Neck Pokémon	Its tail, which also contains a small brain, may bite on its own if it notices an alluring smell.
204	2	pineco	Pineco	Bagworm Pokémon	It hangs and waits for flying-insect prey to come near. It does not move about much on its own.
205	2	forretress	Forretress	Bagworm Pokémon	It remains immovably rooted to its tree. It scatters pieces of its hard shell to drive its enemies away.
206	2	dunsparce	Dunsparce	Land Snake Pokémon	If spotted, it escapes by burrowing with its tail. It can hover just slightly using its wings.
207	2	gligar	Gligar	Fly Scorpion Pokémon	It usually clings to cliffs. When it spots its prey, it spreads its wings and glides down to attack.
208	2	steelix	Steelix	Iron Snake Pokémon	It is said that if an ONIX lives for over 100 years, its composition changes to become diamond-like.
209	2	snubbull	Snubbull	Fairy Pokémon	It has an active, playful nature. Many women like to frolic with it because of its affectionate ways.
210	2	granbull	Granbull	Fairy Pokémon	Because its fangs are too heavy, it always keeps its head tilted down. However, its BITE is powerful.
211	2	qwilfish	Qwilfish	Balloon Pokémon	The small spikes covering its body developed from scales. They inject a toxin that causes fainting.
212	2	scizor	Scizor	Pincer Pokémon	Its wings are not used for flying. They are flapped at high speed to adjust its body temperature.
213	2	shuckle	Shuckle	Mold Pokémon	It stores BERRIES inside its shell. To avoid attacks, it hides beneath rocks and remains completely still.
214	2	heracross	Heracross	Single Horn Pokémon	Usually docile, but if disturbed while sipping honey, it chases off the intruder with its horn.
215	2	sneasel	Sneasel	Sharp Claw Pokémon	Vicious in nature, it drives PIDGEY from their nests and feasts on the eggs that are left behind.
216	2	teddiursa	Teddiursa	Little Bear Pokémon	Before food becomes scarce in wintertime, its habit is to hoard food in many hidden locations.
217	2	ursaring	Ursaring	Hibernator Pokémon	With its ability to distinguish any smell, it unfailingly finds all food buried deep underground.
218	2	slugma	Slugma	Lava Pokémon	A common sight in volcanic areas, it slowly slithers around in a constant search for warm places.
219	2	magcargo	Magcargo	Lava Pokémon	Its brittle shell occasionally spouts intense flames that circulate throughout its body.
220	2	swinub	Swinub	Pig Pokémon	If it smells something enticing, it dashes off headlong to find the source of the aroma.
221	2	piloswine	Piloswine	Swine Pokémon	If it charges at an enemy, the hairs on its back stand up straight. It is very sensitive to sound.
222	2	corsola	Corsola	Coral Pokémon	In a south sea nation, the people live in communities that are built on groups of these Pokémon.
223	2	remoraid	Remoraid	Jet Pokémon	Using its dorsal fin as a suction pad, it clings to a MANTINE’s underside to scavenge for leftovers.
224	2	octillery	Octillery	Jet Pokémon	It instinctively sneaks into rocky holes. If it gets sleepy, it steals the nest of a fellow OCTILLERY.
225	2	delibird	Delibird	Delivery Pokémon	It nests at the edge of sharp cliffs. It spends all day carrying food to its awaiting chicks.
226	2	mantine	Mantine	Kite Pokémon	Swimming freely in open seas, it may fly out of the water and over the waves if it builds up enough speed.
227	2	skarmory	Skarmory	Armor Bird Pokémon	After nesting in bramble bushes, the wings of its chicks grow hard from scratches by thorns.
228	2	houndour	Houndour	Dark Pokémon	To corner prey, they check each other’s location using barks that only they can understand.
229	2	houndoom	Houndoom	Dark Pokémon	Upon hearing its eerie howls, other Pokémon get the shivers and head straight back to their nests.
230	2	kingdra	Kingdra	Dragon Pokémon	It sleeps deep on the ocean floor to build its energy. It is said to cause tornadoes as it wakes.
231	2	phanpy	Phanpy	Long Nose Pokémon	As a sign of affection, it bumps with its snout. However, it is so strong, it may send you flying.
232	2	donphan	Donphan	Armor Pokémon	The longer and bigger its tusks, the higher its rank in its herd. The tusks take a long time to grow.
233	2	porygon2	Porygon2	Virtual Pokémon	Further research enhanced its abilities. Sometimes, it may exhibit motions that were not programmed.
234	2	stantler	Stantler	Big Horn Pokémon	Those who stare at its antlers will gradually lose control of their senses and be unable to stand.
235	2	smeargle	Smeargle	Painter Pokémon	Once it becomes an adult, it has a tendency to let its comrades plant footprints on its back.
236	2	tyrogue	Tyrogue	Scuffle Pokémon	Even though it is small, it can’t be ignored because it will slug any handy target without warning.
237	2	hitmontop	Hitmontop	Handstand Pokémon	It launches kicks while spinning. If it spins at high speed, it may bore its way into the ground.
238	2	smoochum	Smoochum	Kiss Pokémon	It always rocks its head slowly backwards and forwards as if it is trying to kiss someone.
239	2	elekid	Elekid	Electric Pokémon	Even in the most vicious storm, this Pokémon plays happily if thunder rumbles in the sky.
240	2	magby	Magby	Live Coal Pokémon	It is found in volcanic craters. Its body heat exceeds 1,100 degrees Fahrenheit, so don’t underestimate it.
241	2	miltank	Miltank	Milk Cow Pokémon	If it has just had a baby, the milk it produces contains much more nutrition than usual.
242	2	blissey	Blissey	Happiness Pokémon	It has a very compassionate nature. If it sees a sick Pokémon, it will nurse the sufferer back to health.
243	2	raikou	Raikou	Thunder Pokémon	This Pokémon races across the land while barking a cry that sounds like crashing thunder.
244	2	entei	Entei	Volcano Pokémon	A Pokémon that races across the land. It is said that one is born every time a new volcano appears.
245	2	suicune	Suicune	Aurora Pokémon	This Pokémon races across the land. It is said that north winds will somehow blow whenever it appears.
246	2	larvitar	Larvitar	Rock Skin Pokémon	It is born deep underground. It can’t emerge until it has entirely consumed the soil around it.
247	2	pupitar	Pupitar	Hard Shell Pokémon	Even sealed in its shell, it can move freely. Hard and fast, it has outstanding destructive power.
248	2	tyranitar	Tyranitar	Armor Pokémon	Its body can’t be harmed by any sort of attack, so it is very eager to make challenges against enemies.
249	2	lugia	Lugia	Diving Pokémon	It is said to be the guardian of the seas. It is rumored to have been seen on the night of a storm.
250	2	ho-oh	Ho-Oh	Rainbow Pokémon	A legend says that its body glows in seven colors. A rainbow is said to form behind it when it flies.
251	2	celebi	Celebi	Time Travel Pokémon	When CELEBI disappears deep in a forest, it is said to leave behind an egg it brought from the future.
252	3	treecko	Treecko	Wood Gecko Pokémon	It quickly scales even vertical walls. It senses humidity with its tail to predict the next day’s weather.
253	3	grovyle	Grovyle	Wood Gecko Pokémon	Its strongly developed thigh muscles give it astounding agility and jumping performance.
254	3	sceptile	Sceptile	Forest Pokémon	The leaves on its forelegs are as sharp as swords. It agilely leaps about the branches of trees to strike.
255	3	torchic	Torchic	Chick Pokémon	It has a flame sac inside its belly that perpetually burns. It feels warm if it is hugged.
256	3	combusken	Combusken	Young Fowl Pokémon	It boosts its concentration by emitting harsh cries. Its kicks have outstanding destructive power.
257	3	blaziken	Blaziken	Blaze Pokémon	When facing a tough foe, it looses flames from its wrists. Its powerful legs let it jump clear over buildings.
258	3	mudkip	Mudkip	Mud Fish Pokémon	Its large tail fin propels it through water with powerful acceleration. It is strong in spite of its size.
259	3	marshtomp	Marshtomp	Mud Fish Pokémon	It is at its best when on muddy ground with poor footing. It quickly overwhelms foes struggling in mud.
260	3	swampert	Swampert	Mud Fish Pokémon	Its arms are rock-hard. With one swing, they can batter down its foe. It makes its nest on beautiful beaches.
261	3	poochyena	Poochyena	Bite Pokémon	It has a very tenacious nature. Its acute sense of smell lets it chase a chosen prey without ever losing track.
262	3	mightyena	Mightyena	Bite Pokémon	It will always obey the commands of a skilled TRAINER. Its behavior arises from its living in packs in ancient times.
263	3	zigzagoon	Zigzagoon	Tiny Raccoon Pokémon	A Pokémon with abundant curiosity. It shows an interest in everything, so it always zigs and zags.
264	3	linoone	Linoone	Rushing Pokémon	When running in a straight line, it can top 60 miles per hour. However, it has a tough time with curved roads.
265	3	wurmple	Wurmple	Worm Pokémon	It lives amidst tall grass and in forests. When attacked, it resists by pointing its venomous spikes at the foe.
266	3	silcoon	Silcoon	Cocoon Pokémon	It conserves its energy by moving as little as possible. It awaits evolution while drinking only a little rainwater.
267	3	beautifly	Beautifly	Butterfly Pokémon	Despite its appearance, it has an aggressive nature. It attacks by jabbing with its long, thin mouth.
268	3	cascoon	Cascoon	Cocoon Pokémon	Its body, which is made of soft silk, hardens over time. When cracks appear, evolution is near.
269	3	dustox	Dustox	Poison Moth Pokémon	It scatters horribly toxic dust when it senses danger. They tend to gather in the glow of streetlamps at night.
270	3	lotad	Lotad	Water Weed Pokémon	It searches about for clean water. If it does not drink water for too long, the leaf on its head wilts.
271	3	lombre	Lombre	Jolly Pokémon	It lives at the water’s edge where it is sunny. It sleeps on a bed of water grass by day and becomes active at night.
272	3	ludicolo	Ludicolo	Carefree Pokémon	The rhythm of bright, festive music activates LUDICOLO’s cells, making it more powerful.
273	3	seedot	Seedot	Acorn Pokémon	If it remains still, it becomes impossible to distinguish from real nuts. It delights in surprising foraging PIDGEY.
274	3	nuzleaf	Nuzleaf	Wily Pokémon	They live in holes bored in large trees. The sound of NUZLEAF’s grass flute fills listeners with dread.
275	3	shiftry	Shiftry	Wicked Pokémon	A Pokémon that was feared as a forest guardian. It can read the foe’s mind and take preemptive action.
276	3	taillow	Taillow	Tiny Swallow Pokémon	It dislikes cold seasons. They migrate to other lands in search of warmth, flying over 180 miles a day.
277	3	swellow	Swellow	Swallow Pokémon	If its two tail feathers are standing at attention, it is proof of good health. It soars elegantly in the sky.
278	3	wingull	Wingull	Seagull Pokémon	It rides upon ocean winds as if it were a glider. In the winter, it hides food around its nest.
279	3	pelipper	Pelipper	Water Bird Pokémon	It is a flying transporter that carries small Pokémon in its beak. It bobs on the waves to rest its wings.
280	3	ralts	Ralts	Feeling Pokémon	It is highly attuned to the emotions of people and Pokémon. It hides if it senses hostility.
281	3	kirlia	Kirlia	Emotion Pokémon	The cheerful spirit of its TRAINER gives it energy for its psychokinetic power. It spins and dances when happy.
282	3	gardevoir	Gardevoir	Embrace Pokémon	It has the power to predict the future. Its power peaks when it is protecting its TRAINER.
283	3	surskit	Surskit	Pond Skater Pokémon	They usually live on ponds, but after an evening shower, they may appear on puddles in towns.
284	3	masquerain	Masquerain	Eyeball Pokémon	The antennae have distinctive patterns that look like eyes. When it rains, they grow heavy, making flight impossible.
285	3	shroomish	Shroomish	Mushroom Pokémon	It prefers damp places. By day it remains still in the forest shade. It releases toxic powder from its head.
286	3	breloom	Breloom	Mushroom Pokémon	The seeds on its tail are made of toxic spores. It knocks out foes with quick, virtually invisible punches.
287	3	slakoth	Slakoth	Slacker Pokémon	It sleeps for 20 hours every day. Making drowsy those that see it is one of its abilities.
288	3	vigoroth	Vigoroth	Wild Monkey Pokémon	It is always hungry because it won’t stop rampaging. Even while it is eating, it can’t keep still.
289	3	slaking	Slaking	Lazy Pokémon	It is the world’s most slothful Pokémon. However, it can exert horrifying power by releasing pent-up energy all at once.
290	3	nincada	Nincada	Trainee Pokémon	Because it lived almost entirely underground, it is nearly blind. It uses its antennae instead.
291	3	ninjask	Ninjask	Ninja Pokémon	This Pokémon is so quick, it is said to be able to avoid any attack. It loves to feed on tree sap.
292	3	shedinja	Shedinja	Shed Pokémon	A most peculiar Pokémon that somehow appears in a POKé BALL when a NINCADA evolves.
293	3	whismur	Whismur	Whisper Pokémon	It usually murmurs, but starts crying loudly if it senses danger. It stops when its ear covers are shut.
294	3	loudred	Loudred	Big Voice Pokémon	When it stamps its feet and bellows, it generates ultrasonic waves that can blow apart a house.
295	3	exploud	Exploud	Loud Noise Pokémon	It emits a variety of sounds from the holes all over its body. Its loud cries can be heard from over six miles away.
296	3	makuhita	Makuhita	Guts Pokémon	It grows stronger by enduring harsh training. It is a gutsy Pokémon that can withstand any attack.
297	3	hariyama	Hariyama	Arm Thrust Pokémon	It stomps on the ground to build power. It can send a 10-ton truck flying with a straight-arm punch.
298	3	azurill	Azurill	Polka Dot Pokémon	It battles by flinging around its tail, which is bigger than its body. The tail is a flotation device in water.
299	3	nosepass	Nosepass	Compass Pokémon	Its magnetic nose consistently faces north. Travelers check NOSEPASS to get their bearings.
300	3	skitty	Skitty	Kitten Pokémon	It is said to be difficult to earn its trust. However, it is extremely popular for its cute looks and behavior.
301	3	delcatty	Delcatty	Prim Pokémon	The favorite of trend-conscious female TRAINERS, they are used in competition for their style and fur.
302	3	sableye	Sableye	Darkness Pokémon	It feeds on gemstone crystals. In darkness, its eyes sparkle with the glitter of jewels.
303	3	mawile	Mawile	Deceiver Pokémon	It uses its docile-looking face to lull foes into complacency, then bites with its huge, relentless jaws.
304	3	aron	Aron	Iron Armor Pokémon	It eats iron to build its steel body. It is a pest that descends from mountains to eat bridges and train tracks.
305	3	lairon	Lairon	Iron Armor Pokémon	It habitually shows off its strength with the size of sparks it creates by ramming its steel body into boulders.
306	3	aggron	Aggron	Iron Armor Pokémon	It claims a large mountain as its sole territory. It mercilessly thrashes those that violate its space.
307	3	meditite	Meditite	Meditate Pokémon	It never skips its daily yoga training. It heightens its inner strength through meditation.
308	3	medicham	Medicham	Meditate Pokémon	It elegantly avoids attacks with dance- like steps, then launches a devastating blow in the same motion.
309	3	electrike	Electrike	Lightning Pokémon	It stores static electricity in its fur for discharging. It gives off sparks if a storm approaches.
310	3	manectric	Manectric	Discharge Pokémon	It rarely appears before people. It is said to nest where lightning has fallen.
311	3	plusle	Plusle	Cheering Pokémon	It cheers on partners while scattering sparks from its body. It climbs telephone poles to absorb electricity.
312	3	minun	Minun	Cheering Pokémon	Its dislike of water makes it take shelter under the eaves of houses in rain. It uses pom-poms made of sparks for cheering.
313	3	volbeat	Volbeat	Firefly Pokémon	It lives around clean ponds. At night, its rear lights up. It converses with others by flashing its light.
314	3	illumise	Illumise	Firefly Pokémon	It guides VOLBEAT to draw signs in night skies. There are scientists that study the patterns it creates.
315	3	roselia	Roselia	Thorn Pokémon	Its flowers give off a relaxing fragrance. The stronger its aroma, the healthier the ROSELIA is.
316	3	gulpin	Gulpin	Stomach Pokémon	There is nothing its stomach can’t digest. While it is digesting, vile, overpowering gases are expelled.
317	3	swalot	Swalot	Poison Bag Pokémon	It can swallow a tire whole in one gulp. It secretes a horribly toxic fluid from the pores on its body.
318	3	carvanha	Carvanha	Savage Pokémon	It lives in massive rivers that course through jungles. It swarms prey that enter its territory.
319	3	sharpedo	Sharpedo	Brutal Pokémon	The ruffian of the seas, it has fangs that crunch through iron. It swims by jetting water from its rear.
320	3	wailmer	Wailmer	Ball Whale Pokémon	When it sucks in a large volume of seawater, it becomes like a big, bouncy ball. It eats a ton of food daily.
321	3	wailord	Wailord	Float Whale Pokémon	It is among the largest of all Pokémon. It herds prey in a pack then swallows the massed prey in one gulp.
322	3	numel	Numel	Numb Pokémon	Magma of almost 2,200 degrees Fahrenheit courses through its body. When it grows cold, the magma hardens and slows it.
323	3	camerupt	Camerupt	Eruption Pokémon	If angered, the humps on its back erupt in a shower of molten lava. It lives in the craters of volcanoes.
324	3	torkoal	Torkoal	Coal Pokémon	It burns coal inside its shell. If it is attacked, it belches thick, black smoke and flees.
325	3	spoink	Spoink	Bounce Pokémon	It apparently dies if it stops bouncing about. It carries a pearl from CLAMPERL on its head.
326	3	grumpig	Grumpig	Manipulate Pokémon	It can gain control over foes by doing odd dance steps. The black pearls on its forehead are precious gems.
327	3	spinda	Spinda	Spot Panda Pokémon	No two SPINDA are said to have identical patterns. It confuses foes with its stumbling motions.
328	3	trapinch	Trapinch	Ant Pit Pokémon	It lives in arid deserts. It makes a sloping pit trap in sand where it patiently awaits prey.
329	3	vibrava	Vibrava	Vibration Pokémon	It generates ultrasonic waves by violently flapping its wings. After making its prey faint, it melts the prey with acid.
330	3	flygon	Flygon	Mystic Pokémon	It hides itself by kicking up desert sand with its wings. Red covers shield its eyes from sand.
331	3	cacnea	Cacnea	Cactus Pokémon	It prefers harsh environments such as deserts. It can survive for 30 days on water stored in its body.
332	3	cacturne	Cacturne	Scarecrow Pokémon	It lives in deserts. It becomes active at night when it hunts for prey exhausted from the desert’s heat.
333	3	swablu	Swablu	Cotton Bird Pokémon	It constantly grooms its cotton-like wings. It takes a shower to clean itself if it becomes dirty.
334	3	altaria	Altaria	Humming Pokémon	If you hear a beautiful melody trilling deep among mountains far from people, it is ALTARIA’s humming.
335	3	zangoose	Zangoose	Cat Ferret Pokémon	If it comes across a SEVIPER, its fur bristles and it assumes its battle pose. Its sharp claws are its best weapon.
336	3	seviper	Seviper	Fang Snake Pokémon	It sharpens its swordlike tail on hard rocks. It hides in tall grass and strikes unwary prey with venomous fangs.
337	3	lunatone	Lunatone	Meteorite Pokémon	Its health ebbs and flows with the lunar cycle. It brims with power when exposed to the light of the full moon.
338	3	solrock	Solrock	Meteorite Pokémon	It absorbs solar energy during the day. Always expressionless, it can sense what its foe is thinking.
339	3	barboach	Barboach	Whiskers Pokémon	It probes muddy riverbeds with its two long whiskers. A slimy film protects its body.
340	3	whiscash	Whiscash	Whiskers Pokémon	It makes its nest at the bottom of swamps. It will eat anything - if it is alive, WHISCASH will eat it.
341	3	corphish	Corphish	Ruffian Pokémon	It came from overseas. It is a very hardy creature that will quickly proliferate, even in polluted streams.
342	3	crawdaunt	Crawdaunt	Rogue Pokémon	A rough customer that wildly flails its giant claws. It is said to be extremely hard to raise.
343	3	baltoy	Baltoy	Clay Doll Pokémon	It was discovered in ancient ruins. While moving, it constantly spins. It stands on one foot even when asleep.
344	3	claydol	Claydol	Clay Doll Pokémon	It appears to have been born from clay dolls made by ancient people. It uses telekinesis to float and move.
345	3	lileep	Lileep	Sea Lily Pokémon	It became extinct roughly 100 million years ago. It was regenerated from a fossil using advanced techniques.
346	3	cradily	Cradily	Barnacle Pokémon	It ensnares prey with its eight tentacles. It then melts the prey with a strong acid before feeding.
347	3	anorith	Anorith	Old Shrimp Pokémon	It is a kind of Pokémon progenitor. It uses its extending claws to catch prey hiding among rocks on the seafloor.
348	3	armaldo	Armaldo	Plate Pokémon	Protected by a hard shell, its body is very sturdy. It skewers prey with its claws to feed.
349	3	feebas	Feebas	Fish Pokémon	Ridiculed for its shabby appearance, it is ignored by researchers. It lives in ponds choked with weeds.
350	3	milotic	Milotic	Tender Pokémon	MILOTIC is breathtakingly beautiful. Those that see it are said to forget their combative spirits.
351	3	castform	Castform	Weather Pokémon	It has the ability to change its form into the sun, the rain, or a snow cloud, depending on the weather.
352	3	kecleon	Kecleon	Color Swap Pokémon	It changes body color to blend in with its surroundings. It also changes color if it is happy or sad.
353	3	shuppet	Shuppet	Puppet Pokémon	It loves to feed on feelings like envy and malice. Its upright horn catches the emotions of people.
354	3	banette	Banette	Marionette Pokémon	Strong feelings of hatred turned a puppet into a Pokémon. If it opens its mouth, its cursed energy escapes.
355	3	duskull	Duskull	Requiem Pokémon	Making itself invisible, it silently sneaks up to prey. It has the ability to slip through thick walls.
356	3	dusclops	Dusclops	Beckon Pokémon	Its body is entirely hollow. When it opens its mouth, it sucks everything in as if it were a black hole.
357	3	tropius	Tropius	Fruit Pokémon	It lives in tropical jungles. The bunch of fruit around its neck is delicious. The fruit grows twice a year.
358	3	chimecho	Chimecho	Wind Chime Pokémon	It travels by riding on winds. It cleverly uses its long tail to pluck nuts and berries, which it loves to eat.
359	3	absol	Absol	Disaster Pokémon	It appears when it senses an impending natural disaster. As a result, it was mistaken as a doom-bringer.
360	3	wynaut	Wynaut	Bright Pokémon	It tends to move in a pack with others. They cluster in a tight group to sleep in a cave.
361	3	snorunt	Snorunt	Snow Hat Pokémon	It is said that a home visited by a SNORUNT will prosper. It can withstand cold of minus 150 degrees Fahrenheit.
362	3	glalie	Glalie	Face Pokémon	It has a body of ice that won’t melt, even with fire. It can instantly freeze moisture in the atmosphere.
363	3	spheal	Spheal	Clap Pokémon	Its body is covered in fluffy fur. The fur keeps it from feeling cold while it is rolling on ice.
364	3	sealeo	Sealeo	Ball Roll Pokémon	It touches new things with its nose to test for smell and feel. It plays by spinning SPHEAL on its nose.
365	3	walrein	Walrein	Ice Break Pokémon	It swims through icy seas while shattering ice floes with its large tusks. It is protected by its thick blubber.
366	3	clamperl	Clamperl	Bivalve Pokémon	It is protected by a sturdy shell. Once in a lifetime, it makes a magnificent pearl.
367	3	huntail	Huntail	Deep Sea Pokémon	It lives deep in the sea where no light ever filters down. It lights up its small fishlike tail to attract prey.
368	3	gorebyss	Gorebyss	South Sea Pokémon	Its swimming form is exquisitely elegant. With its thin mouth, it feeds on seaweed that grows between rocks.
369	3	relicanth	Relicanth	Longevity Pokémon	It has remained unchanged for 100 million years. It was discovered during a deep-sea exploration.
370	3	luvdisc	Luvdisc	Rendezvous Pokémon	During the spawning season, countless LUVDISC congregate at coral reefs, turning the waters pink.
371	3	bagon	Bagon	Rock Head Pokémon	Its steel-hard head can shatter boulders. It longingly hopes for wings to grow so it can fly.
372	3	shelgon	Shelgon	Endurance Pokémon	Its armored body makes all attacks bounce off. The armor is too tough, however, making it heavy and somewhat sluggish.
373	3	salamence	Salamence	Dragon Pokémon	It becomes uncontrollable if it is enraged. It destroys everything with shredding claws and fire.
374	3	beldum	Beldum	Iron Ball Pokémon	It uses magnetic waves to converse with its kind. All the cells in its body are magnetic.
375	3	metang	Metang	Iron Claw Pokémon	It floats midair using magnetism. Its body is so tough, even a crash with a jet plane won’t leave a scratch.
376	3	metagross	Metagross	Iron Leg Pokémon	It is formed by two METANG fusing. Its four brains are said to be superior to a supercomputer.
377	3	regirock	Regirock	Rock Peak Pokémon	It is entirely composed of rocks with no sign of a brain or heart. It is a mystery even to modern scientists.
378	3	regice	Regice	Iceberg Pokémon	Research revealed that its body is made of the same kind of ice that is found at the South Pole.
379	3	registeel	Registeel	Iron Pokémon	It is sturdier than any kind of metal. It hardened due to pressure underground over tens of thousands of years.
380	3	latias	Latias	Eon Pokémon	It can telepathically communicate with people. It changes its appearance using its down that refracts light.
381	3	latios	Latios	Eon Pokémon	It has a docile temperament and dislikes fighting. Tucking in its forelegs, it can fly faster than a jet plane.
382	3	kyogre	Kyogre	Sea Basin Pokémon	This Pokémon is said to have expanded the sea by bringing heavy rains. It has the power to control water.
383	3	groudon	Groudon	Continent Pokémon	This legendary Pokémon is said to represent the land. It went to sleep after dueling KYOGRE.
384	3	rayquaza	Rayquaza	Sky High Pokémon	It has lived for hundreds of millions of years in the ozone layer. Its flying form looks like a meteor.
385	3	jirachi	Jirachi	Wish Pokémon	It is said to make any wish come true. It is awake for only seven days out of a thousand years.
386	3	deoxys	Deoxys	DNA Pokémon	This DEOXYS has transformed into its aggressive guise. It can fool enemies by altering its appearance.
387	4	turtwig	Turtwig	Tiny Leaf Pokémon	Photosynthesis occurs across its body under the sun. The shell on its back is actually hardened soil.
388	4	grotle	Grotle	Grove Pokémon	It lives along water in forests. In the daytime, it leaves the forest to sunbathe its treed shell.
389	4	torterra	Torterra	Continent Pokémon	Ancient people imagined that beneath the ground, a gigantic Torterra dwelled.
390	4	chimchar	Chimchar	Chimp Pokémon	Its fiery rear end is fueled by gas made in its belly. Even rain can’t extinguish the fire.
391	4	monferno	Monferno	Playful Pokémon	It skillfully controls the intensity of the fire on its tail to keep its foes at an ideal distance.
392	4	infernape	Infernape	Flame Pokémon	Its crown of fire is indicative of its fiery nature. It is beaten by none in terms of quickness.
393	4	piplup	Piplup	Penguin Pokémon	It doesn’t like to be taken care of. It’s difficult to bond with since it won’t listen to its Trainer.
394	4	prinplup	Prinplup	Penguin Pokémon	It lives alone, away from others. Apparently, every one of them believes it is the most important.
395	4	empoleon	Empoleon	Emperor Pokémon	It swims as fast as a jet boat. The edges of its wings are sharp and can slice apart drifting ice.
396	4	starly	Starly	Starling Pokémon	They flock in great numbers. Though small, they flap their wings with great power.
397	4	staravia	Staravia	Starling Pokémon	They maintain huge flocks, although fierce scuffles break out between various flocks.
398	4	staraptor	Staraptor	Predator Pokémon	The muscles in its wings and legs are strong. It can easily fly while gripping a small Pokémon.
399	4	bidoof	Bidoof	Plump Mouse Pokémon	With nerves of steel, nothing can perturb it. It is more agile and active than it appears.
400	4	bibarel	Bibarel	Beaver Pokémon	It busily makes its nest with stacks of branches and roots it has cut up with its sharp incisors.
401	4	kricketot	Kricketot	Cricket Pokémon	It chats with others using the sounds of its colliding antennae. These sounds are fall hallmarks.
402	4	kricketune	Kricketune	Cricket Pokémon	It crosses its knifelike arms in front of its chest when it cries. It can compose melodies ad lib.
403	4	shinx	Shinx	Flash Pokémon	The extension and contraction of its muscles generates electricity. It glows when in trouble.
404	4	luxio	Luxio	Spark Pokémon	Its claws loose electricity with enough amperage to cause fainting. They live in small groups.
405	4	luxray	Luxray	Gleam Eyes Pokémon	When its eyes gleam gold, it can spot hiding prey--even those taking shelter behind a wall.
406	4	budew	Budew	Bud Pokémon	When it feels the sun’s warm touch, it opens its bud to release pollen. It lives alongside clear pools.
407	4	roserade	Roserade	Bouquet Pokémon	Luring prey with a sweet scent, it uses poison whips on its arms to poison, bind, and finish off the prey.
408	4	cranidos	Cranidos	Head Butt Pokémon	It was resurrected from an iron ball-like fossil. It downs prey with its headbutts.
409	4	rampardos	Rampardos	Head Butt Pokémon	Its skull withstands impacts of any magnitude. As a result, its brain never gets the chance to grow.
410	4	shieldon	Shieldon	Shield Pokémon	It habitually polishes its face by rubbing it against tree trunks. It is weak to attacks from behind.
411	4	bastiodon	Bastiodon	Shield Pokémon	When they lined up side by side, no foe could break through. They shielded their young in that way.
412	4	burmy	Burmy	Bagworm Pokémon	To shelter itself from cold, wintry winds, it covers itself with a cloak made of twigs and leaves.
413	4	wormadam	Wormadam	Bagworm Pokémon	Its appearance changes depending on where it evolved. The materials on hand become a part of its body.
414	4	mothim	Mothim	Moth Pokémon	It loves the honey of flowers and steals honey collected by Combee.
415	4	combee	Combee	Tiny Bee Pokémon	The trio is together from birth. It constantly gathers honey from flowers to please Vespiquen.
416	4	vespiquen	Vespiquen	Beehive Pokémon	It houses its colony in cells in its body and releases various pheromones to make those grubs do its bidding.
417	4	pachirisu	Pachirisu	EleSquirrel Pokémon	It makes fur balls that crackle with static electricity. It stores them with berries in tree holes.
418	4	buizel	Buizel	Sea Weasel Pokémon	It swims by rotating its two tails like a screw. When it dives, its flotation sac collapses.
419	4	floatzel	Floatzel	Sea Weasel Pokémon	It floats using its well-developed flotation sac. It assists in the rescues of drowning people.
420	4	cherubi	Cherubi	Cherry Pokémon	Sunlight colors it red. When the small ball is drained of nutrients, it shrivels to herald evolution.
421	4	cherrim	Cherrim	Blossom Pokémon	During times of strong sunlight, its bud blooms, its petals open fully, and it becomes very active.
422	4	shellos	Shellos	Sea Slug Pokémon	Beware of pushing strongly on its squishy body, as it makes a mysterious purple fluid ooze out.
423	4	gastrodon	Gastrodon	Sea Slug Pokémon	When its natural enemy attacks, it oozes purple fluid and escapes.
424	4	ambipom	Ambipom	Long Tail Pokémon	They work in large colonies and make rings by linking their tails, apparently in friendship.
425	4	drifloon	Drifloon	Balloon Pokémon	A Pokémon formed by the spirits of people and Pokémon. It loves damp, humid seasons.
426	4	drifblim	Drifblim	Blimp Pokémon	It carries people and Pokémon when it flies. But since it only drifts, it can end up anywhere.
427	4	buneary	Buneary	Rabbit Pokémon	Its ears are always rolled up. They can be forcefully extended to shatter even a large boulder.
428	4	lopunny	Lopunny	Rabbit Pokémon	Extremely cautious, it quickly bounds off when it senses danger.
429	4	mismagius	Mismagius	Magical Pokémon	It chants incantations. While they usually torment targets, some chants bring happiness.
430	4	honchkrow	Honchkrow	Big Boss Pokémon	If one utters a deep cry, many Murkrow gather quickly. For this, it is called “Summoner of Night.”
431	4	glameow	Glameow	Catty Pokémon	It claws if displeased and purrs when affectionate. Its fickleness is very popular among some.
432	4	purugly	Purugly	Tiger Cat Pokémon	It would claim another Pokémon’s nest as its own if it finds a nest sufficiently comfortable.
433	4	chingling	Chingling	Bell Pokémon	Each time it hops, it makes a ringing sound. It deafens foes by emitting high-frequency cries.
434	4	stunky	Stunky	Skunk Pokémon	It sprays a foul fluid from its rear. Its stench spreads over a mile radius, driving Pokémon away.
435	4	skuntank	Skuntank	Skunk Pokémon	It sprays a vile-smelling fluid from the tip of its tail to attack. Its range is over 160 feet.
436	4	bronzor	Bronzor	Bronze Pokémon	Ancient people believed that the pattern on Bronzor’s back contained a mysterious power.
437	4	bronzong	Bronzong	Bronze Bell Pokémon	In ages past, this Pokémon was revered as a bringer of rain. It was found buried in the ground.
438	4	bonsly	Bonsly	Bonsai Pokémon	It prefers arid environments. It leaks water from its eyes to adjust its body’s fluid levels.
439	4	mime-jr	Mime Jr.	Mime Pokémon	In an attempt to confuse its enemy, it mimics the enemy’s movements. Then it wastes no time in making itself scarce!
440	4	happiny	Happiny	Playhouse Pokémon	It carries a round, egg-shaped rock in its belly pouch and gives the rock to its friends.
441	4	chatot	Chatot	Music Note Pokémon	It mimics the cries of other Pokémon to trick them into thinking it’s one of them. This way they won’t attack it.
442	4	spiritomb	Spiritomb	Forbidden Pokémon	A Pokémon that was formed by 108 spirits. It is bound to a fissure in an odd keystone.
443	4	gible	Gible	Land Shark Pokémon	It nests in horizontal holes warmed by geothermal heat. Foes who get too close can expect to be pounced on and bitten.
444	4	gabite	Gabite	Cave Pokémon	It loves sparkly things. It seeks treasures in caves and hoards the loot in its nest.
445	4	garchomp	Garchomp	Mach Pokémon	When it folds up its body and extends its wings, it looks like a jet plane. It flies at sonic speed.
446	4	munchlax	Munchlax	Big Eater Pokémon	It hides food under its long body hair. However, it forgets it has hidden the food.
447	4	riolu	Riolu	Emanation Pokémon	It uses the shapes of auras, which change according to emotion, to communicate with others.
448	4	lucario	Lucario	Aura Pokémon	By catching the aura emanating from others, it can read their thoughts and movements.
449	4	hippopotas	Hippopotas	Hippo Pokémon	It lives in arid places. Instead of perspiration, it expels grainy sand from its body.
450	4	hippowdon	Hippowdon	Heavyweight Pokémon	It brandishes its gaping mouth in a display of fearsome strength. It raises vast quantities of sand while attacking.
451	4	skorupi	Skorupi	Scorpion Pokémon	It grips prey with its tail claws and injects poison. It tenaciously hangs on until the poison takes.
452	4	drapion	Drapion	Ogre Scorpion Pokémon	It takes pride in its strength. Even though it can tear foes apart, it finishes them off with powerful poison.
453	4	croagunk	Croagunk	Toxic Mouth Pokémon	Its cheeks hold poison sacs. It tries to catch foes off guard to jab them with toxic fingers.
454	4	toxicroak	Toxicroak	Toxic Mouth Pokémon	It has a poison sac at its throat. When it croaks, the stored poison is churned for greater potency.
455	4	carnivine	Carnivine	Bug Catcher Pokémon	It attracts prey with its sweet-smelling saliva, then chomps down. It takes a whole day to eat prey.
456	4	finneon	Finneon	Wing Fish Pokémon	The line running down its side can store sunlight. It shines vividly at night.
457	4	lumineon	Lumineon	Neon Pokémon	It lives on the deep-sea floor. It attracts prey by flashing the patterns on its four tail fins.
458	4	mantyke	Mantyke	Kite Pokémon	The pattern on its back varies by region. It often swims in a school of Remoraid.
459	4	snover	Snover	Frost Tree Pokémon	During cold seasons, it migrates to the mountain’s lower reaches. It returns to the snow-covered summit in the spring.
460	4	abomasnow	Abomasnow	Frost Tree Pokémon	It blankets wide areas in snow by whipping up blizzards. It is also known as “The Ice Monster.”
461	4	weavile	Weavile	Sharp Claw Pokémon	It lives in snowy regions. It carves patterns in trees with its claws as a signal to others.
462	4	magnezone	Magnezone	Magnet Area Pokémon	Sometimes the magnetism emitted by Magnezone is too strong, making them attract each other so they cannot move.
463	4	lickilicky	Lickilicky	Licking Pokémon	It wraps things with its extensible tongue. Getting too close to it will leave you soaked with drool.
464	4	rhyperior	Rhyperior	Drill Pokémon	From holes in its palms, it fires out Geodude. Its carapace can withstand volcanic eruptions.
465	4	tangrowth	Tangrowth	Vine Pokémon	It ensnares prey by extending arms made of vines. Losing arms to predators does not trouble it.
466	4	electivire	Electivire	Thunderbolt Pokémon	As its electric charge amplifies, blue sparks begin to crackle between its horns.
467	4	magmortar	Magmortar	Blast Pokémon	It blasts fireballs of over 3,600 degrees Fahrenheit from the ends of its arms. It lives in volcanic craters.
468	4	togekiss	Togekiss	Jubilee Pokémon	As everyone knows, it visits peaceful regions, bringing them gifts of kindness and sweet blessings.
469	4	yanmega	Yanmega	Ogre Darner Pokémon	It prefers to battle by biting apart foes’ heads instantly while flying by at high speed.
470	4	leafeon	Leafeon	Verdant Pokémon	When you see Leafeon asleep in a patch of sunshine, you’ll know it is using photosynthesis to produce clean air.
471	4	glaceon	Glaceon	Fresh Snow Pokémon	By controlling its body heat, it can freeze the atmosphere around it to make a diamond-dust flurry.
472	4	gliscor	Gliscor	Fang Scorpion Pokémon	It observes prey while hanging inverted from branches. When the chance presents itself, it swoops!
473	4	mamoswine	Mamoswine	Twin Tusk Pokémon	A frozen Mamoswine was dug from ice dating back 10,000 years. This Pokémon has been around a long, long, long time.
474	4	porygon-z	Porygon-Z	Virtual Pokémon	Additional software was installed to make it a better Pokémon. It began acting oddly, however.
475	4	gallade	Gallade	Blade Pokémon	Because it can sense what its foe is thinking, its attacks burst out first, fast, and fierce.
476	4	probopass	Probopass	Compass Pokémon	It exudes strong magnetism from all over. It controls three small units called Mini-Noses.
477	4	dusknoir	Dusknoir	Gripper Pokémon	It is said to take lost spirits into its pliant body and guide them home.
478	4	froslass	Froslass	Snow Land Pokémon	It freezes foes with an icy breath nearly -60 degrees Fahrenheit. What seems to be its body is actually hollow.
479	4	rotom	Rotom	Plasma Pokémon	Research continues on this Pokémon, which could be the power source of a unique motor.
480	4	uxie	Uxie	Knowledge Pokémon	Known as “The Being of Knowledge.” It is said that it can wipe out the memory of those who see its eyes.
481	4	mesprit	Mesprit	Emotion Pokémon	Known as “The Being of Emotion.” It taught humans the nobility of sorrow, pain, and joy.
482	4	azelf	Azelf	Willpower Pokémon	Known as “The Being of Willpower.” It sleeps at the bottom of a lake to keep the world in balance.
483	4	dialga	Dialga	Temporal Pokémon	A Pokémon spoken of in legend. It is said that time began moving when Dialga was born.
484	4	palkia	Palkia	Spatial Pokémon	It is said to live in a gap in the spatial dimension parallel to ours. It appears in mythology.
485	4	heatran	Heatran	Lava Dome Pokémon	It dwells in volcanic caves. It digs in with its cross-shaped feet to crawl on ceilings and walls.
486	4	regigigas	Regigigas	Colossal Pokémon	It is said to have made Pokémon that look like itself from a special ice mountain, rocks, and magma.
487	4	giratina	Giratina	Renegade Pokémon	This Pokémon is said to live in a world on the reverse side of ours, where common knowledge is distorted and strange.
488	4	cresselia	Cresselia	Lunar Pokémon	Shiny particles are released from its wings like a veil. It is said to represent the crescent moon.
489	4	phione	Phione	Sea Drifter Pokémon	When the water warms, they inflate the flotation sac on their heads and drift languidly on the sea in packs.
490	4	manaphy	Manaphy	Seafaring Pokémon	It is born with a wondrous power that lets it bond with any kind of Pokémon.
491	4	darkrai	Darkrai	Pitch-Black Pokémon	It chases people and Pokémon from its territory by causing them to experience deep, nightmarish slumbers.
492	4	shaymin	Shaymin	Gratitude Pokémon	It can dissolve toxins in the air to instantly transform ruined land into a lush field of flowers.
493	4	arceus	Arceus	Alpha Pokémon	According to the legends of Sinnoh, this Pokémon emerged from an egg and shaped all there is in this world.
494	5	victini	Victini	Victory Pokémon	This Pokémon brings victory. It is said that Trainers with Victini always win, regardless of the type of encounter.
495	5	snivy	Snivy	Grass Snake Pokémon	Being exposed to sunlight makes its movements swifter. It uses vines more adeptly than its hands.
496	5	servine	Servine	Grass Snake Pokémon	It moves along the ground as if sliding. Its swift movements befuddle its foes, and it then attacks with a vine whip.
497	5	serperior	Serperior	Regal Pokémon	It only gives its all against strong opponents who are not fazed by the glare from Serperior’s noble eyes.
498	5	tepig	Tepig	Fire Pig Pokémon	It can deftly dodge its foe’s attacks while shooting fireballs from its nose. It roasts berries before it eats them.
499	5	pignite	Pignite	Fire Pig Pokémon	The more it eats, the more fuel it has to make the fire in its stomach stronger. This fills it with even more power.
500	5	emboar	Emboar	Mega Fire Pig Pokémon	It can throw a fire punch by setting its fists on fire with its fiery chin. It cares deeply about its friends.
501	5	oshawott	Oshawott	Sea Otter Pokémon	The scalchop on its stomach isn’t just used for battle--it can be used to break open hard berries as well.
502	5	dewott	Dewott	Discipline Pokémon	Strict training is how it learns its flowing double-scalchop technique.
503	5	samurott	Samurott	Formidable Pokémon	In the time it takes a foe to blink, it can draw and sheathe the seamitars attached to its front legs.
504	5	patrat	Patrat	Scout Pokémon	Using food stored in cheek pouches, they can keep watch for days. They use their tails to communicate with others.
505	5	watchog	Watchog	Lookout Pokémon	Using luminescent matter, it makes its eyes and body glow and stuns attacking opponents.
506	5	lillipup	Lillipup	Puppy Pokémon	The long hair around its face provides an amazing radar that lets it sense subtle changes in its surroundings.
507	5	herdier	Herdier	Loyal Dog Pokémon	This very loyal Pokémon helps Trainers, and it also takes care of other Pokémon.
508	5	stoutland	Stoutland	Big-Hearted Pokémon	It rescues people stranded by blizzards in the mountains. Its shaggy fur shields it from the cold.
509	5	purrloin	Purrloin	Devious Pokémon	Its cute act is a ruse. When victims let down their guard, they find their items taken. It attacks with sharp claws.
510	5	liepard	Liepard	Cruel Pokémon	Their beautiful form comes from the muscles they have developed. They run silently in the night.
511	5	pansage	Pansage	Grass Monkey Pokémon	It shares the leaf on its head with weary-looking Pokémon. These leaves are known to relieve stress.
512	5	simisage	Simisage	Thorn Monkey Pokémon	It attacks enemies with strikes of its thorn-covered tail. This Pokémon is wild tempered.
513	5	pansear	Pansear	High Temp Pokémon	Very intelligent, it roasts berries before eating them. It likes to help people.
514	5	simisear	Simisear	Ember Pokémon	A flame burns inside its body. It scatters embers from its head and tail to sear its opponents.
515	5	panpour	Panpour	Spray Pokémon	The water stored inside the tuft on its head is full of nutrients. It waters plants with it using its tail.
516	5	simipour	Simipour	Geyser Pokémon	The high-pressure water expelled from its tail is so powerful, it can destroy a concrete wall.
517	5	munna	Munna	Dream Eater Pokémon	This Pokémon appears before people and Pokémon who are having nightmares and eats those dreams.
518	5	musharna	Musharna	Drowsing Pokémon	The mist emanating from their foreheads is packed with the dreams of people and Pokémon.
519	5	pidove	Pidove	Tiny Pigeon Pokémon	This very forgetful Pokémon will wait for a new order from its Trainer even though it already has one.
520	5	tranquill	Tranquill	Wild Pigeon Pokémon	Many people believe that, deep in the forest where Tranquill live, there is a peaceful place where there is no war.
521	5	unfezant	Unfezant	Proud Pokémon	Males swing their head plumage to threaten opponents. The females’ flying abilities surpass those of the males.
522	5	blitzle	Blitzle	Electrified Pokémon	When thunderclouds cover the sky, it will appear. It can catch lightning with its mane and store the electricity.
523	5	zebstrika	Zebstrika	Thunderbolt Pokémon	When this ill-tempered Pokémon runs wild, it shoots lightning from its mane in all directions.
524	5	roggenrola	Roggenrola	Mantle Pokémon	Its ear is hexagonal in shape. Compressed underground, its body is as hard as steel.
525	5	boldore	Boldore	Ore Pokémon	Because its energy was too great to be contained, the energy leaked and formed orange crystals.
526	5	gigalith	Gigalith	Compressed Pokémon	The solar rays it absorbs are processed in its energy core and fired as a ball of light.
527	5	woobat	Woobat	Bat Pokémon	Its habitat is dark forests and caves. It emits ultrasonic waves from its nose to learn about its surroundings.
528	5	swoobat	Swoobat	Courting Pokémon	It shakes its tail vigorously when it emits ultrasonic waves strong enough to reduce concrete to rubble.
529	5	drilbur	Drilbur	Mole Pokémon	It makes its way swiftly through the soil by putting both claws together and rotating at high speed.
530	5	excadrill	Excadrill	Subterrene Pokémon	It can help in tunnel construction. Its drill has evolved into steel strong enough to bore through iron plates.
531	5	audino	Audino	Hearing Pokémon	Using the feelers on its ears, it can tell how someone is feeling or when an egg might hatch.
532	5	timburr	Timburr	Muscular Pokémon	These Pokémon appear at building sites and help out with construction. They always carry squared logs.
533	5	gurdurr	Gurdurr	Muscular Pokémon	With strengthened bodies, they skillfully wield steel beams to take down buildings.
534	5	conkeldurr	Conkeldurr	Muscular Pokémon	It is thought that Conkeldurr taught humans how to make concrete more than 2,000 years ago.
535	5	tympole	Tympole	Tadpole Pokémon	By vibrating its cheeks, it emits sound waves imperceptible to humans and warns others of danger.
536	5	palpitoad	Palpitoad	Vibration Pokémon	When they vibrate the bumps on their heads, they can make waves in water or earthquake-like vibrations on land.
537	5	seismitoad	Seismitoad	Vibration Pokémon	It increases the power of its punches by vibrating the bumps on its fists. It can turn a boulder to rubble with one punch.
538	5	throh	Throh	Judo Pokémon	When it tightens its belt, it becomes stronger. Wild Throh use vines to weave their own belts.
539	5	sawk	Sawk	Karate Pokémon	Desiring the strongest karate chop, they seclude themselves in mountains and train without sleeping.
540	5	sewaddle	Sewaddle	Sewing Pokémon	This Pokémon makes clothes for itself. It chews up leaves and sews them with sticky thread extruded from its mouth.
541	5	swadloon	Swadloon	Leaf-Wrapped Pokémon	Forests where Swadloon live have superb foliage because the nutrients they make from fallen leaves nourish the plant life.
542	5	leavanny	Leavanny	Nurturing Pokémon	Upon finding a small Pokémon, it weaves clothing for it from leaves by using the sticky silk secreted from its mouth.
543	5	venipede	Venipede	Centipede Pokémon	It discovers what is going on around it by using the feelers on its head and tail. It is brutally aggressive.
544	5	whirlipede	Whirlipede	Curlipede Pokémon	Protected by a hard shell, it spins its body like a wheel and crashes furiously into its enemies.
545	5	scolipede	Scolipede	Megapede Pokémon	It clasps its prey with the claws on its neck until it stops moving. Then it finishes it off with deadly poison.
546	5	cottonee	Cottonee	Cotton Puff Pokémon	When attacked, it escapes by shooting cotton from its body. The cotton serves as a decoy to distract the attacker.
547	5	whimsicott	Whimsicott	Windveiled Pokémon	They appear along with whirlwinds. They pull pranks, such as moving furniture and leaving balls of cotton in homes.
548	5	petilil	Petilil	Bulb Pokémon	The leaves on its head are very bitter. Eating one of these leaves is known to refresh a tired body.
549	5	lilligant	Lilligant	Flowering Pokémon	The fragrance of the garland on its head has a relaxing effect. It withers if a Trainer does not take good care of it.
550	5	basculin	Basculin	Hostile Pokémon	Red- and blue-striped Basculin are very violent and always fighting. They are also remarkably tasty.
551	5	sandile	Sandile	Desert Croc Pokémon	It moves along below the sand’s surface, except for its nose and eyes. A dark membrane shields its eyes from the sun.
552	5	krokorok	Krokorok	Desert Croc Pokémon	They live in groups of a few individuals. Protective membranes shield their eyes from sandstorms.
553	5	krookodile	Krookodile	Intimidation Pokémon	Very violent Pokémon, they try to clamp down on anything that moves in front of their eyes.
554	5	darumaka	Darumaka	Zen Charm Pokémon	Darumaka’s droppings are hot, so people used to put them in their clothes to keep themselves warm.
555	5	darmanitan	Darmanitan	Blazing Pokémon	When one is injured in a fierce battle, it hardens into a stone-like form. Then it meditates and sharpens its mind.
556	5	maractus	Maractus	Cactus Pokémon	It uses an up-tempo song and dance to drive away the bird Pokémon that prey on its flower seeds.
557	5	dwebble	Dwebble	Rock Inn Pokémon	It makes a hole in a suitable rock. If that rock breaks, the Pokémon remains agitated until it locates a replacement.
558	5	crustle	Crustle	Stone Home Pokémon	It possesses legs of enormous strength, enabling it to carry heavy slabs for many days, even when crossing arid land.
559	5	scraggy	Scraggy	Shedding Pokémon	Its skin has a rubbery elasticity, so it can reduce damage by defensively pulling its skin up to its neck.
560	5	scrafty	Scrafty	Hoodlum Pokémon	It pulls up its shed skin to protect itself while it kicks. The bigger the crest, the more respected it is.
561	5	sigilyph	Sigilyph	Avianoid Pokémon	The guardians of an ancient city, they use their psychic power to attack enemies that invade their territory.
562	5	yamask	Yamask	Spirit Pokémon	These Pokémon arose from the spirits of people interred in graves. Each retains memories of its former life.
563	5	cofagrigus	Cofagrigus	Coffin Pokémon	It has been said that they swallow those who get too close and turn them into mummies. They like to eat gold nuggets.
564	5	tirtouga	Tirtouga	Prototurtle Pokémon	About 100 million years ago, these Pokémon swam in oceans. It is thought they also went on land to attack prey.
565	5	carracosta	Carracosta	Prototurtle Pokémon	They can live both in the ocean and on land. A slap from one of them is enough to open a hole in the bottom of a tanker.
566	5	archen	Archen	First Bird Pokémon	Revived from a fossil, this Pokémon is thought to be the ancestor of all bird Pokémon.
567	5	archeops	Archeops	First Bird Pokémon	They are intelligent and will cooperate to catch prey. From the ground, they use a running start to take flight.
568	5	trubbish	Trubbish	Trash Bag Pokémon	The combination of garbage bags and industrial waste caused the chemical reaction that created this Pokémon.
569	5	garbodor	Garbodor	Trash Heap Pokémon	It clenches opponents with its left arm and finishes them off with foul-smelling poison gas belched from its mouth.
570	5	zorua	Zorua	Tricky Fox Pokémon	It changes so it looks just like its foe, tricks it, and then uses that opportunity to flee.
571	5	zoroark	Zoroark	Illusion Fox Pokémon	Each has the ability to fool a large group of people simultaneously. They protect their lair with illusory scenery.
572	5	minccino	Minccino	Chinchilla Pokémon	Minccino greet each other by grooming one another thoroughly with their tails.
573	5	cinccino	Cinccino	Scarf Pokémon	Their white fur feels amazing to touch. Their fur repels dust and prevents static electricity from building up.
574	5	gothita	Gothita	Fixation Pokémon	Their ribbonlike feelers increase their psychic power. They are always staring at something.
575	5	gothorita	Gothorita	Manipulate Pokémon	Starlight is the source of their power. At night, they mark star positions by using psychic power to float stones.
576	5	gothitelle	Gothitelle	Astral Body Pokémon	Starry skies thousands of light-years away are visible in the space distorted by their intense psychic power.
577	5	solosis	Solosis	Cell Pokémon	Because their bodies are enveloped in a special liquid, they are fine in any environment, no matter how severe.
578	5	duosion	Duosion	Mitosis Pokémon	Since they have two divided brains, at times they suddenly try to take two different actions at once.
579	5	reuniclus	Reuniclus	Multiplying Pokémon	They use psychic power to control their arms, which are made of a special liquid. They can crush boulders psychically.
580	5	ducklett	Ducklett	Water Bird Pokémon	When attacked, it uses its feathers to splash water, escaping under cover of the spray.
581	5	swanna	Swanna	White Bird Pokémon	Despite their elegant appearance, they can flap their wings strongly and fly for thousands of miles.
582	5	vanillite	Vanillite	Fresh Snow Pokémon	The temperature of their breath is -58 degrees Fahrenheit. They create snow crystals and make snow fall in the areas around them.
583	5	vanillish	Vanillish	Icy Snow Pokémon	They cool down the surrounding air and create ice particles, which they use to freeze their foes.
584	5	vanilluxe	Vanilluxe	Snowstorm Pokémon	If both heads get angry simultaneously, this Pokémon expels a blizzard, burying everything in snow.
585	5	deerling	Deerling	Season Pokémon	Their coloring changes according to the seasons and can be slightly affected by the temperature and humidity as well.
586	5	sawsbuck	Sawsbuck	Season Pokémon	They migrate according to the seasons. People can tell the season by looking at Sawsbuck’s horns.
587	5	emolga	Emolga	Sky Squirrel Pokémon	They live on treetops and glide using the inside of a cape-like membrane while discharging electricity.
588	5	karrablast	Karrablast	Clamping Pokémon	These mysterious Pokémon evolve when they receive electrical stimulation while they are in the same place as Shelmet.
589	5	escavalier	Escavalier	Cavalry Pokémon	Wearing the shell covering they stole from Shelmet, they defend themselves and attack with two lances.
590	5	foongus	Foongus	Mushroom Pokémon	It lures people in with its Poké Ball pattern, then releases poison spores. Why it resembles a Poké Ball is unknown.
591	5	amoonguss	Amoonguss	Mushroom Pokémon	They show off their Poké Ball caps to lure prey, but very few Pokémon are fooled by this.
592	5	frillish	Frillish	Floating Pokémon	They paralyze prey with poison, then drag them down to their lairs, five miles below the surface.
593	5	jellicent	Jellicent	Floating Pokémon	Its body is mostly seawater. It’s said there’s a castle of ships Jellicent have sunk on the seafloor.
594	5	alomomola	Alomomola	Caring Pokémon	Floating in the open sea is how they live. When they find a wounded Pokémon, they embrace it and bring it to shore.
595	5	joltik	Joltik	Attaching Pokémon	Since it can’t generate its own electricity, it sticks onto large-bodied Pokémon and absorbs static electricity.
596	5	galvantula	Galvantula	EleSpider Pokémon	They employ an electrically charged web to trap their prey. While it is immobilized by shock, they leisurely consume it.
597	5	ferroseed	Ferroseed	Thorn Seed Pokémon	When threatened, it attacks by shooting a barrage of spikes, which gives it a chance to escape by rolling away.
598	5	ferrothorn	Ferrothorn	Thorn Pod Pokémon	By swinging around its three spiky feelers and shooting spikes, it can obliterate an opponent.
599	5	klink	Klink	Gear Pokémon	Interlocking two bodies and spinning around generates the energy they need to live.
600	5	klang	Klang	Gear Pokémon	By changing the direction in which it rotates, it communicates its feelings to others. When angry, it rotates faster.
601	5	klinklang	Klinklang	Gear Pokémon	The gear with the red core is rotated at high speed for a rapid energy charge.
602	5	tynamo	Tynamo	EleFish Pokémon	While one alone doesn’t have much power, a chain of many Tynamo can be as powerful as lightning.
603	5	eelektrik	Eelektrik	EleFish Pokémon	It wraps itself around its prey and paralyzes it with electricity from the round spots on its sides. Then it chomps.
604	5	eelektross	Eelektross	EleFish Pokémon	With their sucker mouths, they suck in prey. Then they use their fangs to shock the prey with electricity.
605	5	elgyem	Elgyem	Cerebral Pokémon	It uses its strong psychic power to squeeze its opponent’s brain, causing unendurable headaches.
606	5	beheeyem	Beheeyem	Cerebral Pokémon	Apparently, it communicates by flashing its three fingers, but those patterns haven’t been decoded.
607	5	litwick	Litwick	Candle Pokémon	While shining a light and pretending to be a guide, it leeches off the life force of any who follow it.
608	5	lampent	Lampent	Lamp Pokémon	The spirits it absorbs fuel its baleful fire. It hangs around hospitals waiting for people to pass on.
609	5	chandelure	Chandelure	Luring Pokémon	Being consumed in Chandelure’s flame burns up the spirit, leaving the body behind.
610	5	axew	Axew	Tusk Pokémon	They use their tusks to crush the berries they eat. Repeated regrowth makes their tusks strong and sharp.
611	5	fraxure	Fraxure	Axe Jaw Pokémon	Their tusks can shatter rocks. Territory battles between Fraxure can be intensely violent.
612	5	haxorus	Haxorus	Axe Jaw Pokémon	They are kind but can be relentless when defending territory. They challenge foes with tusks that can cut steel.
613	5	cubchoo	Cubchoo	Chill Pokémon	Its nose is always running. It sniffs the snot back up because the mucus provides the raw material for its moves.
614	5	beartic	Beartic	Freezing Pokémon	They love the cold seas of the north. They create pathways across the ocean waters by freezing their own breath.
615	5	cryogonal	Cryogonal	Crystallizing Pokémon	They are born in snow clouds. They use chains made of ice crystals to capture prey.
616	5	shelmet	Shelmet	Snail Pokémon	When it and Karrablast are together, and both receive electrical stimulation, they both evolve.
617	5	accelgor	Accelgor	Shell Out Pokémon	Having removed its heavy shell, it becomes very light and can fight with ninja-like movements.
618	5	stunfisk	Stunfisk	Trap Pokémon	Its skin is very hard, so it is unhurt even if stepped on by sumo wrestlers. It smiles when transmitting electricity.
619	5	mienfoo	Mienfoo	Martial Arts Pokémon	It takes pride in the speed at which it can use moves. What it loses in power, it makes up for in quantity.
620	5	mienshao	Mienshao	Martial Arts Pokémon	It wields the fur on its arms like a whip. Its arm attacks come with such rapidity that they cannot even be seen.
621	5	druddigon	Druddigon	Cave Pokémon	It races through narrow caves, using its sharp claws to catch prey. The skin on its face is harder than a rock.
622	5	golett	Golett	Automaton Pokémon	The energy that burns inside it enables it to move, but no one has yet been able to identify this energy.
623	5	golurk	Golurk	Automaton Pokémon	It is said that Golurk were ordered to protect people and Pokémon by the ancient people who made them.
624	5	pawniard	Pawniard	Sharp Blade Pokémon	Blades comprise this Pokémon’s entire body. If battling dulls the blades, it sharpens them on stones by the river.
625	5	bisharp	Bisharp	Sword Blade Pokémon	This pitiless Pokémon commands a group of Pawniard to hound prey into immobility. It then moves in to finish the prey off.
626	5	bouffalant	Bouffalant	Bash Buffalo Pokémon	They charge wildly and headbutt everything. Their headbutts have enough destructive force to derail a train.
627	5	rufflet	Rufflet	Eaglet Pokémon	They crush berries with their talons. They bravely stand up to any opponent, no matter how strong it is.
628	5	braviary	Braviary	Valiant Pokémon	For the sake of its friends, this brave warrior of the sky will not stop battling, even if injured.
629	5	vullaby	Vullaby	Diapered Pokémon	Its wings are too tiny to allow it to fly. As the time approaches for it to evolve, it discards the bones it was wearing.
630	5	mandibuzz	Mandibuzz	Bone Vulture Pokémon	They fly in circles around the sky. When they spot prey, they attack and carry it back to their nest with ease.
631	5	heatmor	Heatmor	Anteater Pokémon	Using their very hot, flame-covered tongues, they burn through Durant’s steel bodies and consume their insides.
632	5	durant	Durant	Iron Ant Pokémon	Individuals each play different roles in driving Heatmor, their natural predator, away from their colony.
633	5	deino	Deino	Irate Pokémon	They cannot see, so they tackle and bite to learn about their surroundings. Their bodies are covered in wounds.
634	5	zweilous	Zweilous	Hostile Pokémon	The two heads do not get along. Whichever head eats more than the other gets to be the leader.
635	5	hydreigon	Hydreigon	Brutal Pokémon	The heads on their arms do not have brains. They use all three heads to consume and destroy everything.
636	5	larvesta	Larvesta	Torch Pokémon	Said to have been born from the sun, it spews fire from its horns and encases itself in a cocoon of fire when it evolves.
637	5	volcarona	Volcarona	Sun Pokémon	A sea of fire engulfs the surroundings of their battles, since they use their six wings to scatter their ember scales.
638	5	cobalion	Cobalion	Iron Will Pokémon	It has a body and heart of steel. Its glare is sufficient to make even an unruly Pokémon obey it.
639	5	terrakion	Terrakion	Cavern Pokémon	Its charge is strong enough to break through a giant castle wall in one blow. This Pokémon is spoken of in legends.
640	5	virizion	Virizion	Grassland Pokémon	Its head sprouts horns as sharp as blades. Using whirlwind-like movements, it confounds and swiftly cuts opponents.
641	5	tornadus	Tornadus	Cyclone Pokémon	The lower half of its body is wrapped in a cloud of energy. It zooms through the sky at 200 mph.
642	5	thundurus	Thundurus	Bolt Strike Pokémon	The spikes on its tail discharge immense bolts of lightning. It flies around the Unova region firing off lightning bolts.
643	5	reshiram	Reshiram	Vast White Pokémon	This legendary Pokémon can scorch the world with fire. It helps those who want to build a world of truth.
644	5	zekrom	Zekrom	Deep Black Pokémon	This legendary Pokémon can scorch the world with lightning. It assists those who want to build an ideal world.
645	5	landorus	Landorus	Abundance Pokémon	Lands visited by Landorus grant such bountiful crops that it has been hailed as “The Guardian of the Fields.”
646	5	kyurem	Kyurem	Boundary Pokémon	This legendary ice Pokémon waits for a hero to fill in the missing parts of its body with truth or ideals.
647	5	keldeo	Keldeo	Colt Pokémon	It crosses the world, running over the surfaces of oceans and rivers. It appears at scenic waterfronts.
648	5	meloetta	Meloetta	Melody Pokémon	The melodies sung by Meloetta have the power to make Pokémon that hear them happy or sad.
649	5	genesect	Genesect	Paleozoic Pokémon	This ancient bug Pokémon was altered by Team Plasma. They upgraded the cannon on its back.
650	6	chespin	Chespin	Spiny Nut Pokémon	The quills on its head are usually soft. When it flexes them, the points become so hard and sharp that they can pierce rock.
651	6	quilladin	Quilladin	Spiny Armor Pokémon	It relies on its sturdy shell to deflect predators’ attacks. It counterattacks with its sharp quills.
652	6	chesnaught	Chesnaught	Spiny Armor Pokémon	Its Tackle is forceful enough to flip a 50-ton tank. It shields its allies from danger with its own body.
653	6	fennekin	Fennekin	Fox Pokémon	Eating a twig fills it with energy, and its roomy ears give vent to air hotter than 390 degrees Fahrenheit.
654	6	braixen	Braixen	Fox Pokémon	It has a twig stuck in its tail. With friction from its tail fur, it sets the twig on fire and launches into battle.
655	6	delphox	Delphox	Fox Pokémon	It gazes into the flame at the tip of its branch to achieve a focused state, which allows it to see into the future.
656	6	froakie	Froakie	Bubble Frog Pokémon	It secretes flexible bubbles from its chest and back. The bubbles reduce the damage it would otherwise take when attacked.
657	6	frogadier	Frogadier	Bubble Frog Pokémon	It can throw bubble-covered pebbles with precise control, hitting empty cans up to a hundred feet away.
658	6	greninja	Greninja	Ninja Pokémon	It creates throwing stars out of compressed water. When it spins them and throws them at high speed, these stars can split metal in two.
659	6	bunnelby	Bunnelby	Digging Pokémon	They use their large ears to dig burrows. They will dig the whole night through.
660	6	diggersby	Diggersby	Digging Pokémon	With their powerful ears, they can heft boulders of a ton or more with ease. They can be a big help at construction sites.
661	6	fletchling	Fletchling	Tiny Robin Pokémon	These friendly Pokémon send signals to one another with beautiful chirps and tail-feather movements.
662	6	fletchinder	Fletchinder	Ember Pokémon	From its beak, it expels embers that set the tall grass on fire. Then it pounces on the bewildered prey that pop out of the grass.
663	6	talonflame	Talonflame	Scorching Pokémon	In the fever of an exciting battle, it showers embers from the gaps between its feathers and takes to the air.
664	6	scatterbug	Scatterbug	Scatterdust Pokémon	When under attack from bird Pokémon, it spews a poisonous black powder that causes paralysis on contact.
665	6	spewpa	Spewpa	Scatterdust Pokémon	It lives hidden within thicket shadows. When predators attack, it quickly bristles the fur covering its body in an effort to threaten them.
666	6	vivillon	Vivillon	Scale Pokémon	Vivillon with many different patterns are found all over the world. These patterns are affected by the climate of their habitat.
667	6	litleo	Litleo	Lion Cub Pokémon	The stronger the opponent it faces, the more heat surges from its mane and the more power flows through its body.
668	6	pyroar	Pyroar	Royal Pokémon	The male with the largest mane of fire is the leader of the pride.
669	6	flabebe	Flabébé	Single Bloom Pokémon	It draws out and controls the hidden power of flowers. The flower Flabébé holds is most likely part of its body.
670	6	floette	Floette	Single Bloom Pokémon	It flutters around fields of flowers and cares for flowers that are starting to wilt. It draws out the hidden power of flowers to battle.
671	6	florges	Florges	Garden Pokémon	It claims exquisite flower gardens as its territory, and it obtains power from basking in the energy emitted by flowering plants.
672	6	skiddo	Skiddo	Mount Pokémon	Thought to be one of the first Pokémon to live in harmony with humans, it has a placid disposition.
673	6	gogoat	Gogoat	Mount Pokémon	It can tell how its Trainer is feeling by subtle shifts in the grip on its horns. This empathic sense lets them run as if one being.
674	6	pancham	Pancham	Playful Pokémon	It does its best to be taken seriously by its enemies, but its glare is not sufficiently intimidating. Chewing on a leaf is its trademark.
675	6	pangoro	Pangoro	Daunting Pokémon	Although it possesses a violent temperament, it won’t put up with bullying. It uses the leaf in its mouth to sense the movements of its enemies.
676	6	furfrou	Furfrou	Poodle Pokémon	Trimming its fluffy fur not only makes it more elegant but also increases the swiftness of its movements.
677	6	espurr	Espurr	Restraint Pokémon	The organ that emits its intense psychic power is sheltered by its ears to keep power from leaking out.
678	6	meowstic	Meowstic	Constraint Pokémon	When in danger, it raises its ears and releases enough psychic power to grind a 10-ton truck into dust.
679	6	honedge	Honedge	Sword Pokémon	Apparently this Pokémon is born when a departed spirit inhabits a sword. It attaches itself to people and drinks their life force.
680	6	doublade	Doublade	Sword Pokémon	When Honedge evolves, it divides into two swords, which cooperate via telepathy to coordinate attacks and slash their enemies to ribbons.
681	6	aegislash	Aegislash	Royal Sword Pokémon	Generations of kings were attended by these Pokémon, which used their spectral power to manipulate and control people and Pokémon.
682	6	spritzee	Spritzee	Perfume Pokémon	It emits a scent that enraptures those who smell it. This fragrance changes depending on what it has eaten.
683	6	aromatisse	Aromatisse	Fragrance Pokémon	It devises various scents, pleasant and unpleasant, and emits scents that its enemies dislike in order to gain an edge in battle.
684	6	swirlix	Swirlix	Cotton Candy Pokémon	To entangle its opponents in battle, it extrudes white threads as sweet and sticky as cotton candy.
685	6	slurpuff	Slurpuff	Meringue Pokémon	It can distinguish the faintest of scents. It puts its sensitive sense of smell to use by helping pastry chefs in their work.
686	6	inkay	Inkay	Revolving Pokémon	Opponents who stare at the flashing of the light-emitting spots on its body become dazed and lose their will to fight.
687	6	malamar	Malamar	Overturning Pokémon	It wields the most compelling hypnotic powers of any Pokémon, and it forces others to do whatever it wants.
688	6	binacle	Binacle	Two-Handed Pokémon	Two Binacle live together on one rock. When they fight, one of them will move to a different rock.
689	6	barbaracle	Barbaracle	Collective Pokémon	When they evolve, two Binacle multiply into seven. They fight with the power of seven Binacle.
690	6	skrelp	Skrelp	Mock Kelp Pokémon	Camouflaged as rotten kelp, they spray liquid poison on prey that approaches unawares and then finish it off.
691	6	dragalge	Dragalge	Mock Kelp Pokémon	Their poison is strong enough to eat through the hull of a tanker, and they spit it indiscriminately at anything that enters their territory.
692	6	clauncher	Clauncher	Water Gun Pokémon	They knock down flying prey by firing compressed water from their massive claws like shooting a pistol.
693	6	clawitzer	Clawitzer	Howitzer Pokémon	Their enormous claws launch cannonballs of water powerful enough to pierce tanker hulls.
694	6	helioptile	Helioptile	Generator Pokémon	They make their home in deserts. They can generate their energy from basking in the sun, so eating food is not a requirement.
695	6	heliolisk	Heliolisk	Generator Pokémon	They flare their frills and generate energy. A single Heliolisk can generate sufficient electricity to power a skyscraper.
696	6	tyrunt	Tyrunt	Royal Heir Pokémon	This Pokémon was restored from a fossil. If something happens that it doesn’t like, it throws a tantrum and runs wild.
697	6	tyrantrum	Tyrantrum	Despot Pokémon	Thanks to its gargantuan jaws, which could shred thick metal plates as if they were paper, it was invincible in the ancient world it once inhabited.
698	6	amaura	Amaura	Tundra Pokémon	This ancient Pokémon was restored from part of its body that had been frozen in ice for over 100 million years.
699	6	aurorus	Aurorus	Tundra Pokémon	The diamond-shaped crystals on its body expel air as cold as -240 degrees Fahrenheit, surrounding its enemies and encasing them in ice.
700	6	sylveon	Sylveon	Intertwining Pokémon	It sends a soothing aura from its ribbonlike feelers to calm fights.
701	6	hawlucha	Hawlucha	Wrestling Pokémon	Although its body is small, its proficient fighting skills enable it to keep up with big bruisers like Machamp and Hariyama.
702	6	dedenne	Dedenne	Antenna Pokémon	Its whiskers serve as antennas. By sending and receiving electrical waves, it can communicate with others over vast distances.
703	6	carbink	Carbink	Jewel Pokémon	Born from the temperatures and pressures deep underground, it fires beams from the stone in its head.
704	6	goomy	Goomy	Soft Tissue Pokémon	The weakest Dragon-type Pokémon, it lives in damp, shady places, so its body doesn’t dry out.
705	6	sliggoo	Sliggoo	Soft Tissue Pokémon	It drives away opponents by excreting a sticky liquid that can dissolve anything. Its eyes devolved, so it can’t see anything.
706	6	goodra	Goodra	Dragon Pokémon	This very friendly Dragon-type Pokémon will hug its beloved Trainer, leaving that Trainer covered in sticky slime.
707	6	klefki	Klefki	Key Ring Pokémon	These key collectors threaten any attackers by fiercely jingling their keys at them.
708	6	phantump	Phantump	Stump Pokémon	These Pokémon are created when spirits possess rotten tree stumps. They prefer to live in abandoned forests.
709	6	trevenant	Trevenant	Elder Tree Pokémon	It can control trees at will. It will trap people who harm the forest, so they can never leave.
710	6	pumpkaboo	Pumpkaboo	Pumpkin Pokémon	The pumpkin body is inhabited by a spirit trapped in this world. As the sun sets, it becomes restless and active.
711	6	gourgeist	Gourgeist	Pumpkin Pokémon	Singing in eerie voices, they wander town streets on the night of the new moon. Anyone who hears their song is cursed.
712	6	bergmite	Bergmite	Ice Chunk Pokémon	It blocks opponents’ attacks with the ice that shields its body. It uses cold air to repair any cracks with new ice.
713	6	avalugg	Avalugg	Iceberg Pokémon	Its ice-covered body is as hard as steel. Its cumbersome frame crushes anything that stands in its way.
714	6	noibat	Noibat	Sound Wave Pokémon	They live in pitch-black caves. Their enormous ears can emit ultrasonic waves of 200,000 hertz.
715	6	noivern	Noivern	Sound Wave Pokémon	They fly around on moonless nights and attack careless prey. Nothing can beat them in a battle in the dark.
716	6	xerneas	Xerneas	Life Pokémon	Legends say it can share eternal life. It slept for a thousand years in the form of a tree before its revival.
717	6	yveltal	Yveltal	Destruction Pokémon	When this legendary Pokémon’s wings and tail feathers spread wide and glow red, it absorbs the life force of living creatures.
718	6	zygarde	Zygarde	Order Pokémon	When the Kalos region’s ecosystem falls into disarray, it appears and reveals its secret power.
719	6	diancie	Diancie	Jewel Pokémon	A sudden transformation of Carbink, its pink, glimmering body is said to be the loveliest sight in the whole world.
720	6	hoopa	Hoopa	Mischief Pokémon	This troublemaker sends anything and everything to faraway places using its loop, which can warp space.
721	6	volcanion	Volcanion	Steam Pokémon	It lets out billows of steam and disappears into the dense fog. It’s said to live in mountains where humans do not tread.
722	7	rowlet	Rowlet	Grass Quill Pokémon	This wary Pokémon uses photosynthesis to store up energy during the day, while becoming active at night.
723	7	dartrix	Dartrix	Blade Quill Pokémon	A bit of a dandy, it spends its free time preening its wings. Its preoccupation with any dirt on its plumage can leave it unable to battle.
724	7	decidueye	Decidueye	Arrow Quill Pokémon	It fires arrow quills from its wings with such precision, they can pierce a pebble at distances over a hundred yards.
725	7	litten	Litten	Fire Cat Pokémon	While grooming itself, it builds up fur inside its stomach. It sets the fur alight and spews fiery attacks, which change based on how it coughs.
726	7	torracat	Torracat	Fire Cat Pokémon	At its throat, it bears a bell of fire. The bell rings brightly whenever this Pokémon spits fire.
727	7	incineroar	Incineroar	Heel Pokémon	This Pokémon has a violent, selfish disposition. If it’s not in the mood to listen, it will ignore its Trainer’s orders with complete nonchalance.
728	7	popplio	Popplio	Sea Lion Pokémon	This Pokémon snorts body fluids from its nose, blowing balloons to smash into its foes. It’s famous for being a hard worker.
729	7	brionne	Brionne	Pop Star Pokémon	A skillful dancer, it creates a sequence of water balloons as it dances, and briskly bombards its enemies.
730	7	primarina	Primarina	Soloist Pokémon	It controls its water balloons with song. The melody is learned from others of its kind and is passed down from one generation to the next.
731	7	pikipek	Pikipek	Woodpecker Pokémon	It can peck at a rate of 16 times a second to drill holes in trees. It uses the holes for food storage and for nesting.
732	7	trumbeak	Trumbeak	Bugle Beak Pokémon	It eats berries and stores their seeds in its beak. When it encounters enemies or prey, it fires off all the seeds in a burst.
733	7	toucannon	Toucannon	Cannon Pokémon	When it battles, its beak heats up. The temperature can easily exceed 212 degrees Fahrenheit, causing severe burns when it hits.
734	7	yungoos	Yungoos	Loitering Pokémon	With its sharp fangs, it will bite anything. It did not originally live in Alola but was imported from another region.
735	7	gumshoos	Gumshoos	Stakeout Pokémon	When it finds a trace of its prey, it patiently stakes out the location...but it’s always snoozing by nightfall.
736	7	grubbin	Grubbin	Larva Pokémon	Its strong jaw enables it to scrape trees and slurp out the sap. It normally lives underground.
737	7	charjabug	Charjabug	Battery Pokémon	Its body is capable of storing electricity. On camping trips, people are grateful to have one around.
738	7	vikavolt	Vikavolt	Stag Beetle Pokémon	It zips around, on sharp lookout for an opening. It concentrates electrical energy within its large jaws and uses it to zap its enemies.
739	7	crabrawler	Crabrawler	Boxing Pokémon	While guarding its weak points with its pincers, it looks for an opening and unleashes punches. When it loses, it foams at the mouth and faints.
740	7	crabominable	Crabominable	Woolly Crab Pokémon	It aimed for the top but got lost and ended up on a snowy mountain. Being forced to endure the cold, this Pokémon evolved and grew fur.
741	7	oricorio	Oricorio	Dancing Pokémon	It beats its wings together to create fire. As it moves in the steps of its beautiful dance, it bathes opponents in intense flames.
742	7	cutiefly	Cutiefly	Bee Fly Pokémon	It feeds on the nectar and pollen of flowers. Because it’s able to sense auras, it can identify which flowers are about to bloom.
743	7	ribombee	Ribombee	Bee Fly Pokémon	It rolls up pollen into puffs. It makes many different varieties, some used as food and others used in battle.
744	7	rockruff	Rockruff	Puppy Pokémon	It’s considered to be a good Pokémon for beginners because of its friendliness, but its disposition grows rougher as it grows up.
745	7	lycanroc	Lycanroc	Wolf Pokémon	Its quick movements confuse its enemies. Well equipped with claws and fangs, it also uses the sharp rocks in its mane as weapons.
746	7	wishiwashi	Wishiwashi	Small Fry Pokémon	When it’s in trouble, its eyes moisten and begin to shine. The shining light attracts its comrades, and they stand together against their enemies.
747	7	mareanie	Mareanie	Brutal Star Pokémon	It plunges the poison spike on its head into its prey. When the prey has weakened, Mareanie deals the finishing blow with its 10 tentacles.
748	7	toxapex	Toxapex	Brutal Star Pokémon	Toxapex crawls along the ocean floor on its 12 legs. It leaves a trail of Corsola bits scattered in its wake.
749	7	mudbray	Mudbray	Donkey Pokémon	The mud stuck to Mudbray’s hooves enhances its grip and its powerful running gait.
750	7	mudsdale	Mudsdale	Draft Horse Pokémon	It spits a mud that provides resistance to both wind and rain, so the walls of old houses were often coated with it.
751	7	dewpider	Dewpider	Water Bubble Pokémon	It crawls onto the land in search of food. Its water bubble allows it to breathe and protects its soft head.
752	7	araquanid	Araquanid	Water Bubble Pokémon	It delivers headbutts with the water bubble on its head. Small Pokémon get sucked into the bubble, where they drown.
753	7	fomantis	Fomantis	Sickle Grass Pokémon	During the day, it sleeps and soaks up light. When night falls, it walks around looking for a safer place to sleep.
754	7	lurantis	Lurantis	Bloom Sickle Pokémon	It requires a lot of effort to maintain Lurantis’s vivid coloring, but some collectors enjoy this work and treat it as their hobby.
755	7	morelull	Morelull	Illuminating Pokémon	It scatters spores that flicker and glow. Anyone seeing these lights falls into a deep slumber.
756	7	shiinotic	Shiinotic	Illuminating Pokémon	Forests where Shiinotic live are treacherous to enter at night. People confused by its strange lights can never find their way home again.
757	7	salandit	Salandit	Toxic Lizard Pokémon	It burns its bodily fluids to create a poisonous gas. When its enemies become disoriented from inhaling the gas, it attacks them.
758	7	salazzle	Salazzle	Toxic Lizard Pokémon	For some reason, only females have been found. It creates a reverse harem of male Salandit that it lives with.
759	7	stufful	Stufful	Flailing Pokémon	Despite its adorable appearance, when it gets angry and flails about, its arms and legs could knock a pro wrestler sprawling.
760	7	bewear	Bewear	Strong Arm Pokémon	This immensely dangerous Pokémon possesses overwhelming physical strength. Its habitat is generally off-limits.
761	7	bounsweet	Bounsweet	Fruit Pokémon	A delectable aroma pours from its body. They are often swallowed whole by Toucannon lured by that wafting deliciousness.
762	7	steenee	Steenee	Fruit Pokémon	The sepals on its head developed to protect its body. These are quite hard, so even if pecked by bird Pokémon, this Pokémon is totally fine.
763	7	tsareena	Tsareena	Fruit Pokémon	Its long, striking legs aren’t just for show but to be used to kick with skill. In victory, it shows off by kicking the defeated, laughing boisterously.
764	7	comfey	Comfey	Posy Picker Pokémon	It attaches flowers to its highly nutritious vine. This revitalizes the flowers, and they give off an aromatic scent.
765	7	oranguru	Oranguru	Sage Pokémon	Known for its extreme intelligence, this Pokémon will look down on inexperienced Trainers, so it’s best suited to veteran Trainers.
766	7	passimian	Passimian	Teamwork Pokémon	They form groups of roughly 20 individuals. Their mutual bond is remarkable—they will never let down a comrade.
767	7	wimpod	Wimpod	Turn Tail Pokémon	This Pokémon is a coward. As it desperately dashes off, the flailing of its many legs leaves a sparkling clean path in its wake.
768	7	golisopod	Golisopod	Hard Scale Pokémon	With a flashing slash of its giant sharp claws, it cleaves seawater—or even air—right in two.
769	7	sandygast	Sandygast	Sand Heap Pokémon	Born from a sand mound playfully built by a child, this Pokémon embodies the grudges of the departed.
770	7	palossand	Palossand	Sand Castle Pokémon	Possessed people controlled by this Pokémon transformed its sand mound into a castle. As it evolved, its power to curse grew ever stronger.
771	7	pyukumuku	Pyukumuku	Sea Cucumber Pokémon	It lives in shallow seas, such as areas near a beach. It can eject its internal organs, which it uses to engulf its prey or battle enemies.
772	7	type-null	Type: Null	Synthetic Pokémon	The heavy control mask it wears suppresses its intrinsic capabilities. This Pokémon has some hidden special power.
773	7	silvally	Silvally	Synthetic Pokémon	Its trust in its partner is what awakens it. This Pokémon is capable of changing its type, a flexibility that is well displayed in battle.
774	7	minior	Minior	Meteor Pokémon	Originally making its home in the ozone layer, it hurtles to the ground when the shell enclosing its body grows too heavy.
775	7	komala	Komala	Drowsing Pokémon	It is born asleep, and it dies asleep. All its movements are apparently no more than the results of it tossing and turning in its dreams.
776	7	turtonator	Turtonator	Blast Turtle Pokémon	The shell on its back is chemically unstable and explodes violently if struck. The hole in its stomach is its weak point.
777	7	togedemaru	Togedemaru	Roly-Poly Pokémon	The spiny fur on its back is normally at rest. When this Pokémon becomes agitated, its fur stands on end and stabs into its attackers.
778	7	mimikyu	Mimikyu	Disguise Pokémon	Its actual appearance is unknown. A scholar who saw what was under its rag was overwhelmed by terror and died from the shock.
779	7	bruxish	Bruxish	Gnash Teeth Pokémon	When it unleashes its psychic power from the protuberance on its head, the grating sound of grinding teeth echoes through the area.
780	7	drampa	Drampa	Placid Pokémon	It has a compassionate personality, but if it is angered, it completely destroys its surroundings with its intense breath.
781	7	dhelmise	Dhelmise	Sea Creeper Pokémon	Swinging its massive anchor, it can KO Wailord in a single blow. What appears to be green seaweed is actually its body.
782	7	jangmo-o	Jangmo-o	Scaly Pokémon	It expresses its feelings by smacking its scales. Metallic sounds echo through the tall mountains where Jangmo-o lives.
783	7	hakamo-o	Hakamo-o	Scaly Pokémon	It leaps at its prey with a courageous shout. Its scaly punches tear its opponents to shreds.
784	7	kommo-o	Kommo-o	Scaly Pokémon	When it spots enemies, it threatens them by jingling the scales on its tail. Weak opponents will crack and flee in panic.
785	7	tapu-koko	Tapu Koko	Land Spirit Pokémon	This guardian deity of Melemele is brimming with curiosity. It summons thunderclouds and stores their lightning inside its body.
786	7	tapu-lele	Tapu Lele	Land Spirit Pokémon	This guardian deity of Akala is guilelessly cruel. The fragrant aroma of flowers is the source of its energy.
787	7	tapu-bulu	Tapu Bulu	Land Spirit Pokémon	It pulls large trees up by the roots and swings them around. It causes vegetation to grow, and then it absorbs energy from the growth.
788	7	tapu-fini	Tapu Fini	Land Spirit Pokémon	The dense fog it creates brings the downfall and destruction of its confused enemies. Ocean currents are the source of its energy.
789	7	cosmog	Cosmog	Nebula Pokémon	Its body is gaseous and frail. It slowly grows as it collects dust from the atmosphere.
790	7	cosmoem	Cosmoem	Protostar Pokémon	Motionless as if dead, its body is faintly warm to the touch. In the distant past, it was called the cocoon of the stars.
791	7	solgaleo	Solgaleo	Sunne Pokémon	It is said to live in another world. The intense light it radiates from the surface of its body can make the darkest of nights light up like midday.
792	7	lunala	Lunala	Moone Pokémon	It is said to be a female evolution of Cosmog. When its third eye activates, away it flies to another world.
793	7	nihilego	Nihilego	Parasite Pokémon	One of several mysterious Ultra Beasts. People on the street report observing those infested by it suddenly becoming violent.
794	7	buzzwole	Buzzwole	Swollen Pokémon	This Ultra Beast appeared from another world. It shows off its body, but whether that display is a boast or a threat remains unclear.
795	7	pheromosa	Pheromosa	Lissome Pokémon	One of the dangerous Ultra Beasts, it has been spotted running across the land at terrific speeds.
796	7	xurkitree	Xurkitree	Glowing Pokémon	One of the mysterious life-forms known as Ultra Beasts. Astonishing electric shocks emanate from its entire body, according to witnesses.
797	7	celesteela	Celesteela	Launch Pokémon	It appeared from the Ultra Wormhole. Witnesses observed it flying across the sky at high speed.
798	7	kartana	Kartana	Drawn Sword Pokémon	This Ultra Beast came from the Ultra Wormhole. It seems not to attack enemies on its own, but its sharp body is a dangerous weapon in itself.
799	7	guzzlord	Guzzlord	Junkivore Pokémon	It has gobbled mountains and swallowed whole buildings, according to reports. It’s one of the Ultra Beasts.
800	7	necrozma	Necrozma	Prism Pokémon	Reminiscent of the Ultra Beasts, this life-form, apparently asleep underground, is thought to have come from another world in ancient times.
801	7	magearna	Magearna	Artificial Pokémon	This artificial Pokémon, constructed more than 500 years ago, can understand human speech but cannot itself speak.
802	7	marshadow	Marshadow	Gloomdweller Pokémon	Able to conceal itself in shadows, it never appears before humans, so its very existence was the stuff of myth.
803	7	poipole	Poipole	Poison Pin Pokémon	This Ultra Beast is well enough liked to be chosen as a first partner in its own world.
804	7	naganadel	Naganadel	Poison Pin Pokémon	It stores hundreds of liters of poisonous liquid inside its body. It is one of the organisms known as UBs.
805	7	stakataka	Stakataka	Rampart Pokémon	It appeared from an Ultra Wormhole. Each one appears to be made up of many life-forms stacked one on top of each other.
806	7	blacephalon	Blacephalon	Fireworks Pokémon	It slithers toward people. Then, without warning, it triggers the explosion of its own head. It’s apparently one kind of Ultra Beast.
807	7	zeraora	Zeraora	Thunderclap Pokémon	It electrifies its claws and tears its opponents apart with them. Even if they dodge its attack, they’ll be electrocuted by the flying sparks.
808	7	meltan	Meltan	Hex Nut Pokémon	It melts particles of iron and other metals found in the subsoil, so it can absorb them into its body of molten steel.
809	7	melmetal	Melmetal	Hex Nut Pokémon	Revered long ago for its capacity to create iron from nothing, for some reason it has come back to life after 3,000 years.
"""#
}
