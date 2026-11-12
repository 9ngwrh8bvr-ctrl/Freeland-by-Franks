--!strict
-- Monster-Datenbank.
--
-- abilities[1] Grundangriff (Bindung 1)
-- abilities[2] Spezialfähigkeit, per Befehl (Bindung 2)
-- abilities[3] Unterstützung, automatisch (Bindung 3)
-- abilities[4] Einzigartige Fähigkeit, per Befehl (Bindung 4)
-- Bindung 5 schaltet ggf. Klassen frei (siehe Classes.luau).
--
-- traits (Erkundung):
--   Fliegen      – Flugpunkte erreichen
--   Schwimmen    – Unterwasser-/Flussübergänge
--   Klein        – enge Spalten erkunden (Beute)
--   Zerschmettern– Felsblöcke/Hindernisse zerstören
--   Runensicht   – verborgene Runen sehen
--   Leuchten     – dunkle Dungeons erhellen, Lichtsiegel öffnen
--   Wachstum     – verdorrte Bäume/Rankenbrücken wachsen lassen
--
-- model: Wenn in ReplicatedStorage.Assets.Monsters ein Model mit der ID
-- liegt, wird es verwendet. Sonst wird ein Platzhalter aus Teilen gebaut
-- (shape/size/colors).

export type Stage = { name: string, level: number, scale: number }
export type Species = {
	name: string,
	description: string,
	element: string,
	rarity: string,
	role: string,
	stages: { Stage },
	baseStats: { hp: number, atk: number, def: number, spd: number },
	abilities: { string },
	traits: { string },
	temper: string, -- "aggressive" | "neutral" | "shy"
	aggroRange: number,
	flying: boolean?,
	shape: string, -- "Ball" | "Block" | "Long" | "Tall"
	size: { number }, -- {x, y, z} in Studs bei Stufe 1
	capture: { capturable: boolean, requiresFlag: string?, requiresLevel: number?, note: string? },
	specialization: { bond: number, ability: string }?,
	isBoss: boolean?,
	loot: { { item: string, chance: number } },
	coins: number,
	xp: number,
}

local M: { [string]: Species } = {}

M.Moosling = {
	name = "Moosling",
	description = "Ein kleiner, freundlicher Waldbewohner, der Wunden mit Sporen heilt.",
	element = "Natur",
	rarity = "Gewoehnlich",
	role = "Heiler",
	stages = {
		{ name = "Moosling", level = 1, scale = 1 },
		{ name = "Moostroll", level = 16, scale = 1.3 },
		{ name = "Moosbehüter", level = 32, scale = 1.6 },
	},
	baseStats = { hp = 60, atk = 8, def = 6, spd = 14 },
	abilities = { "Rankenpeitsche", "Sporenheilung", "Moosschild", "Bluetenregen" },
	traits = { "Klein" },
	temper = "shy",
	aggroRange = 0,
	shape = "Ball",
	size = { 2.5, 2.5, 2.5 },
	capture = { capturable = true },
	loot = { { item = "Heiltrank", chance = 0.15 }, { item = "Lockfrucht", chance = 0.1 } },
	coins = 6,
	xp = 12,
}

M.Kieselkrabbe = {
	name = "Kieselkrabbe",
	description = "Robuste Krabbe mit Steinpanzer. Lenkt Gegner gern auf sich.",
	element = "Erde",
	rarity = "Gewoehnlich",
	role = "Verteidiger",
	stages = {
		{ name = "Kieselkrabbe", level = 1, scale = 1 },
		{ name = "Felskrabbe", level = 16, scale = 1.3 },
		{ name = "Bergpanzer", level = 32, scale = 1.6 },
	},
	baseStats = { hp = 75, atk = 8, def = 9, spd = 12 },
	abilities = { "Scherenzwick", "Panzerung", "Krabbenspott", "Felsenstoss" },
	traits = { "Klein" },
	temper = "neutral",
	aggroRange = 0,
	shape = "Block",
	size = { 3, 1.8, 2.5 },
	capture = { capturable = true },
	loot = { { item = "Heiltrank", chance = 0.12 }, { item = "Steinbrocken", chance = 0.3 } },
	coins = 6,
	xp = 12,
}

M.Funkenmaus = {
	name = "Funkenmaus",
	description = "Flinke Maus, deren Schweif Funken sprüht.",
	element = "Feuer",
	rarity = "Gewoehnlich",
	role = "Angreifer",
	stages = {
		{ name = "Funkenmaus", level = 1, scale = 1 },
		{ name = "Glutratte", level = 16, scale = 1.3 },
		{ name = "Flammennager", level = 32, scale = 1.6 },
	},
	baseStats = { hp = 55, atk = 11, def = 5, spd = 18 },
	abilities = { "Funkenbiss", "Glutfunke", "Hitzewelle", "Flammenschweif" },
	traits = { "Klein" },
	temper = "aggressive",
	aggroRange = 22,
	shape = "Long",
	size = { 1.6, 1.4, 2.6 },
	capture = { capturable = true },
	loot = { { item = "Glutbeere", chance = 0.15 } },
	coins = 7,
	xp = 13,
}

M.Brisenspatz = {
	name = "Brisenspatz",
	description = "Neugieriger Vogel, der Wind unter seinen Flügeln sammelt.",
	element = "Wind",
	rarity = "Gewoehnlich",
	role = "Späher",
	stages = {
		{ name = "Brisenspatz", level = 1, scale = 1 },
		{ name = "Sturmschwalbe", level = 16, scale = 1.3 },
		{ name = "Himmelsläufer", level = 32, scale = 1.6 },
	},
	baseStats = { hp = 50, atk = 10, def = 4, spd = 20 },
	abilities = { "Federstoss", "Windboe", "Aufwind", "Wirbelsturm" },
	traits = { "Klein" },
	temper = "shy",
	aggroRange = 0,
	flying = true,
	shape = "Ball",
	size = { 1.6, 1.6, 1.6 },
	capture = { capturable = true },
	loot = { { item = "Feder", chance = 0.3 } },
	coins = 6,
	xp = 12,
}

M.Gluehkaefer = {
	name = "Glühkäfer",
	description = "Sein Panzer leuchtet in dunklen Höhlen wie eine Laterne.",
	element = "Licht",
	rarity = "Ungewoehnlich",
	role = "Unterstützer",
	stages = {
		{ name = "Glühkäfer", level = 1, scale = 1 },
		{ name = "Lichtskarabäus", level = 16, scale = 1.3 },
		{ name = "Sonnenwächter", level = 32, scale = 1.6 },
	},
	baseStats = { hp = 55, atk = 9, def = 7, spd = 15 },
	abilities = { "Lichtstrahl", "Blendlicht", "Leuchtsegen", "Sonnenfunke" },
	traits = { "Leuchten" },
	temper = "neutral",
	aggroRange = 0,
	flying = true,
	shape = "Ball",
	size = { 1.8, 1.4, 2.2 },
	capture = { capturable = true },
	loot = { { item = "Leuchtstaub", chance = 0.3 } },
	coins = 10,
	xp = 18,
}

M.Feuerwolf = {
	name = "Feuerwolf",
	description = "Schneller Jäger mit brennender Mähne. Stärkt die Angriffskraft seines Rudels.",
	element = "Feuer",
	rarity = "Selten",
	role = "Angreifer",
	stages = {
		{ name = "Glutwelpe", level = 1, scale = 1 },
		{ name = "Feuerwolf", level = 16, scale = 1.25 },
		{ name = "Infernowolf", level = 32, scale = 1.5 },
	},
	baseStats = { hp = 75, atk = 14, def = 7, spd = 22 },
	abilities = { "Feuerbiss", "Flammensprint", "Glutgeheul", "InfernoAnsturm" },
	traits = {},
	temper = "aggressive",
	aggroRange = 30,
	shape = "Long",
	size = { 2.2, 2.6, 4.2 },
	capture = { capturable = true },
	specialization = { bond = 3, ability = "Glutklinge" },
	loot = { { item = "Glutbeere", chance = 0.3 }, { item = "Glutzahn", chance = 0.2 } },
	coins = 18,
	xp = 30,
}

M.Steingolem = {
	name = "Steingolem",
	description = "Langsam, aber nahezu unzerstörbar. Beschützt seinen Partner mit seinem Körper.",
	element = "Erde",
	rarity = "Selten",
	role = "Verteidiger",
	stages = {
		{ name = "Kieselgolem", level = 1, scale = 1 },
		{ name = "Steingolem", level = 16, scale = 1.25 },
		{ name = "Bergkoloss", level = 32, scale = 1.5 },
	},
	baseStats = { hp = 120, atk = 11, def = 14, spd = 11 },
	abilities = { "Steinfaust", "Herausforderung", "Steinhaut", "Erdbeben" },
	traits = { "Zerschmettern" },
	temper = "neutral",
	aggroRange = 0,
	shape = "Tall",
	size = { 3.5, 5, 2.5 },
	capture = { capturable = true },
	specialization = { bond = 3, ability = "Felsenwall" },
	loot = { { item = "Steinbrocken", chance = 0.5 } },
	coins = 18,
	xp = 30,
}

M.Windfalke = {
	name = "Windfalke",
	description = "Kreist hoch über dem Land und trägt seinen Partner zu fernen Klippen.",
	element = "Wind",
	rarity = "Selten",
	role = "Späher",
	stages = {
		{ name = "Windküken", level = 1, scale = 1 },
		{ name = "Windfalke", level = 16, scale = 1.25 },
		{ name = "Sturmadler", level = 32, scale = 1.5 },
	},
	baseStats = { hp = 65, atk = 14, def = 6, spd = 24 },
	abilities = { "Sturzflug", "Windklinge", "Jagdmarkierung", "Orkan" },
	traits = { "Fliegen" },
	temper = "shy",
	aggroRange = 0,
	flying = true,
	shape = "Ball",
	size = { 2.4, 2, 3 },
	capture = { capturable = true },
	specialization = { bond = 3, ability = "Falkenauge" },
	loot = { { item = "Feder", chance = 0.5 } },
	coins = 18,
	xp = 30,
}

M.Wasserdrache = {
	name = "Wasserdrache",
	description = "Elegant und weise. Heilt Verbündete und überschwemmt Gegnergruppen.",
	element = "Wasser",
	rarity = "Episch",
	role = "Heiler",
	stages = {
		{ name = "Quellnatter", level = 1, scale = 1 },
		{ name = "Wasserdrache", level = 16, scale = 1.25 },
		{ name = "Gezeitendrache", level = 32, scale = 1.5 },
	},
	baseStats = { hp = 90, atk = 13, def = 9, spd = 18 },
	abilities = { "Wasserstrahl", "Flutwelle", "HeilenderRegen", "Mahlstrom" },
	traits = { "Schwimmen" },
	temper = "neutral",
	aggroRange = 0,
	shape = "Long",
	size = { 2, 2, 6 },
	capture = { capturable = true },
	specialization = { bond = 3, ability = "Quellsegen" },
	loot = { { item = "Perle", chance = 0.4 } },
	coins = 35,
	xp = 55,
}

M.Schattenwesen = {
	name = "Schattenwesen",
	description = "Ein Wesen aus Zwielicht. Sieht verborgene Runen und schlägt aus dem Nichts zu.",
	element = "Schatten",
	rarity = "Episch",
	role = "Assassine",
	stages = {
		{ name = "Schattenfunke", level = 1, scale = 1 },
		{ name = "Schattenwesen", level = 16, scale = 1.25 },
		{ name = "Nachtgestalt", level = 32, scale = 1.5 },
	},
	baseStats = { hp = 65, atk = 17, def = 6, spd = 22 },
	abilities = { "Schattenkralle", "Tarnung", "Schwaechungsfluch", "Schattenhinrichtung" },
	traits = { "Runensicht" },
	temper = "aggressive",
	aggroRange = 25,
	shape = "Tall",
	size = { 2, 4, 1.5 },
	capture = { capturable = true },
	specialization = { bond = 3, ability = "Schattenschleier" },
	loot = { { item = "Schattenessenz", chance = 0.4 } },
	coins = 35,
	xp = 55,
}

M.Naturgeist = {
	name = "Naturgeist",
	description = "Hüter des Waldes. Lässt verdorrte Pflanzen neu erblühen.",
	element = "Natur",
	rarity = "Episch",
	role = "Heiler",
	stages = {
		{ name = "Waldfunke", level = 1, scale = 1 },
		{ name = "Naturgeist", level = 16, scale = 1.25 },
		{ name = "Hainwächter", level = 32, scale = 1.5 },
	},
	baseStats = { hp = 80, atk = 12, def = 9, spd = 17 },
	abilities = { "Dornenranke", "Wurzelgriff", "Lebensquell", "WaldesZorn" },
	traits = { "Wachstum" },
	temper = "shy",
	aggroRange = 0,
	flying = true,
	shape = "Tall",
	size = { 2, 3.5, 2 },
	capture = { capturable = true },
	specialization = { bond = 3, ability = "Heilsporen" },
	loot = { { item = "Lebenssamen", chance = 0.4 } },
	coins = 35,
	xp = 55,
}

M.UralterDrache = {
	name = "Uralter Drache",
	description = "Älter als Lindenhain selbst. Folgt nur dem, der die Drachenprüfung besteht.",
	element = "Drache",
	rarity = "Legendaer",
	role = "Angreifer",
	stages = {
		{ name = "Uralter Drache", level = 1, scale = 1 },
		{ name = "Uralter Drache", level = 16, scale = 1.15 },
		{ name = "Urdrache", level = 32, scale = 1.3 },
	},
	baseStats = { hp = 150, atk = 20, def = 14, spd = 20 },
	abilities = { "Drachenklaue", "Drachenodem", "Drachenschuppen", "Urzeitbruellen" },
	traits = { "Fliegen", "Zerschmettern" },
	temper = "aggressive",
	aggroRange = 35,
	flying = true,
	shape = "Long",
	size = { 5, 4.5, 9 },
	capture = {
		capturable = true,
		requiresFlag = "Drachenpruefung",
		requiresLevel = 30,
		note = "Nur nach bestandener Drachenprüfung (Quest) fangbar.",
	},
	specialization = { bond = 3, ability = "Drachenfeuer" },
	loot = { { item = "Drachenschuppe", chance = 1 } },
	coins = 200,
	xp = 400,
}

M.Glutkoloss = {
	name = "Glutkoloss",
	description = "Ein Koloss aus erstarrter Lava, der den Vulkanpass bewacht.",
	element = "Feuer",
	rarity = "Einzigartig",
	role = "Boss",
	stages = { { name = "Glutkoloss", level = 1, scale = 1 } },
	baseStats = { hp = 500, atk = 18, def = 14, spd = 12 },
	abilities = { "Glutschlag", "Magmawelle", "Feuerregen", "Ausbruch" },
	traits = {},
	temper = "aggressive",
	aggroRange = 40,
	shape = "Tall",
	size = { 7, 10, 5 },
	capture = { capturable = false, note = "Bossmonster – nicht fangbar." },
	isBoss = true,
	loot = {
		{ item = "Glutkern", chance = 1 },
		{ item = "Flammenschwert", chance = 0.25 },
		{ item = "Bindungsamulett", chance = 0.15 },
	},
	coins = 250,
	xp = 500,
}

return M
