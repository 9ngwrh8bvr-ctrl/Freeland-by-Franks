--!strict
-- Quests. Zielarten:
--   capture    { species?, count }
--   defeat     { species?, element?, boss?, withCompanion?, count }
--   useTrait   { trait?, count }          – Erkundungsfähigkeit eines Gefährten einsetzen
--   train      { count }                  – am Trainingsplatz trainieren
--   reachLevel { value }
--   bond       { species, value }
--
-- Voraussetzungen (prereq): level, hasSpecies, bond {species, value}, quest
-- Belohnungen: coins, gems, xp, items, bondXp (an aktive Gefährten), flag

export type Objective = {
	type: string,
	count: number?,
	value: number?,
	species: string?,
	element: string?,
	boss: boolean?,
	withCompanion: string?,
	trait: string?,
	text: string,
}
export type Quest = {
	name: string,
	description: string,
	category: string, -- "Haupt" | "Neben" | "Klasse"
	prereq: { level: number?, hasSpecies: string?, bond: { species: string, value: number }?, quest: string? },
	objectives: { Objective },
	rewards: {
		coins: number?,
		gems: number?,
		xp: number?,
		items: { [string]: number }?,
		bondXp: number?,
		flag: string?,
	},
}

local Q: { [string]: Quest } = {}

Q.ErsteSchritte = {
	name = "Erste Schritte",
	description = "Schwäche ein wildes Monster und gewinne sein Vertrauen mit dem Ritual.",
	category = "Haupt",
	prereq = {},
	objectives = { { type = "capture", count = 1, text = "Fange 1 Monster" } },
	rewards = { coins = 100, xp = 80, items = { Lockfrucht = 3 } },
}

Q.GemeinsamStark = {
	name = "Gemeinsam stark",
	description = "Kämpfe Seite an Seite mit deinen Gefährten.",
	category = "Haupt",
	prereq = { quest = "ErsteSchritte" },
	objectives = { { type = "defeat", count = 10, text = "Besiege 10 Monster" } },
	rewards = { coins = 150, xp = 150, bondXp = 40 },
}

Q.Erkunder = {
	name = "Verborgene Pfade",
	description = "Nutze die Fähigkeiten deiner Monster, um die Welt zu erkunden.",
	category = "Haupt",
	prereq = { quest = "GemeinsamStark" },
	objectives = { { type = "useTrait", count = 3, text = "Setze 3× eine Erkundungsfähigkeit ein" } },
	rewards = { coins = 200, xp = 250, items = { Bindungssnack = 2 }, gems = 10 },
}

Q.Glutkoloss = {
	name = "Der Glutkoloss",
	description = "Am Vulkanpass wacht ein Koloss aus Lava. Besiege ihn mit deinem Team.",
	category = "Haupt",
	prereq = { level = 12, quest = "Erkunder" },
	objectives = { { type = "defeat", species = "Glutkoloss", count = 1, text = "Besiege den Glutkoloss" } },
	rewards = { coins = 600, xp = 800, gems = 25, bondXp = 100 },
}

Q.Trainingseifer = {
	name = "Trainingseifer",
	description = "Trainiere mit deinen Gefährten am Trainingsplatz.",
	category = "Neben",
	prereq = { level = 3 },
	objectives = { { type = "train", count = 5, text = "Trainiere 5×" } },
	rewards = { coins = 120, xp = 120, items = { Bindungssnack = 1 } },
}

-- Klassenprüfungen ----------------------------------------------------------
Q.Feuerprobe = {
	name = "Feuerprobe",
	description = "Beweise, dass du und dein Feuerwolf als Einheit kämpfen. Schaltet (mit Bindung 5) den Flammenkrieger frei.",
	category = "Klasse",
	prereq = { level = 18, bond = { species = "Feuerwolf", value = 4 } },
	objectives = {
		{ type = "defeat", element = "Natur", withCompanion = "Feuerwolf", count = 15, text = "Besiege 15 Natur-Monster mit deinem Feuerwolf" },
		{ type = "defeat", species = "Glutkoloss", withCompanion = "Feuerwolf", count = 1, text = "Besiege den Glutkoloss mit deinem Feuerwolf" },
	},
	rewards = { xp = 1000, bondXp = 150, flag = "Feuerprobe" },
}

Q.Runenpfad = {
	name = "Der Runenpfad",
	description = "Folge den verborgenen Runen, die nur Schattenwesen sehen. Schaltet (mit Bindung 5) den Schattenläufer frei.",
	category = "Klasse",
	prereq = { level = 18, bond = { species = "Schattenwesen", value = 4 } },
	objectives = {
		{ type = "useTrait", trait = "Runensicht", count = 3, text = "Entschlüssele 3 verborgene Runen" },
		{ type = "defeat", withCompanion = "Schattenwesen", count = 20, text = "Besiege 20 Monster mit deinem Schattenwesen" },
	},
	rewards = { xp = 1000, bondXp = 150, flag = "Runenpfad" },
}

Q.Hainheilung = {
	name = "Heilung des Hains",
	description = "Lass mit deinem Naturgeist verdorrte Bäume neu erblühen. Schaltet (mit Bindung 5) den Naturhüter frei.",
	category = "Klasse",
	prereq = { level = 18, bond = { species = "Naturgeist", value = 4 } },
	objectives = {
		{ type = "useTrait", trait = "Wachstum", count = 3, text = "Lass 3 verdorrte Bäume erblühen" },
		{ type = "train", count = 5, text = "Trainiere 5× am Trainingsplatz" },
	},
	rewards = { xp = 1000, bondXp = 150, flag = "Hainheilung" },
}

Q.Drachenpruefung = {
	name = "Die Drachenprüfung",
	description = "Der Uralte Drache folgt nur einem würdigen Abenteurer. Besteht du die Prüfung, kannst du ihn mit dem Ritual gewinnen.",
	category = "Haupt",
	prereq = { level = 30, quest = "Glutkoloss" },
	objectives = {
		{ type = "defeat", species = "Glutkoloss", count = 3, text = "Besiege den Glutkoloss 3×" },
		{ type = "defeat", count = 60, text = "Besiege 60 Monster" },
		{ type = "useTrait", trait = "Fliegen", count = 1, text = "Erreiche den Drachenhorst (Fliegen)" },
	},
	rewards = { xp = 2500, gems = 50, flag = "Drachenpruefung" },
}

Q.Drachenschwur = {
	name = "Der Drachenschwur",
	description = "Schwöre deinem Drachen Treue. Schaltet (mit Bindung 4) den Drachenritter frei.",
	category = "Klasse",
	prereq = { level = 38, hasSpecies = "UralterDrache" },
	objectives = {
		{ type = "defeat", withCompanion = "UralterDrache", count = 30, text = "Besiege 30 Monster mit deinem Drachen" },
		{ type = "defeat", species = "Glutkoloss", withCompanion = "UralterDrache", count = 1, text = "Besiege den Glutkoloss mit deinem Drachen" },
	},
	rewards = { xp = 4000, bondXp = 300, flag = "Drachenschwur" },
}

local Order = {
	"ErsteSchritte",
	"GemeinsamStark",
	"Erkunder",
	"Trainingseifer",
	"Glutkoloss",
	"Feuerprobe",
	"Runenpfad",
	"Hainheilung",
	"Drachenpruefung",
	"Drachenschwur",
}

return { List = Q, Order = Order }
