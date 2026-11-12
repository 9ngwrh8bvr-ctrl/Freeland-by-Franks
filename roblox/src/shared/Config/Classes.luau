--!strict
-- Charakterklassen, Freischaltbedingungen und Skilltrees (Talente).
--
-- Grundklassen sind sofort verfügbar. Fortgeschrittene Klassen werden
-- über Monster freigeschaltet – nicht durch bloßes Fangen, sondern durch
-- Bindung, Entwicklungsstufe, Charakterlevel und eine Prüfungsquest.
--
-- Modifikator-Schlüssel (Talente, Ausrüstung, Klassen):
--   hpPct, atkPct, defPct, crit, healPct, cooldownPct,
--   companionAtkPct, companionHpPct, captureBonus, bondXpPct, coinPct

export type Requirement = { type: string, value: number?, species: string?, id: string? }
export type Talent = {
	id: string,
	name: string,
	description: string,
	maxRank: number,
	stat: string,
	perRank: number,
	requires: string?,
	requiresLevel: number?,
}
export type ClassDef = {
	name: string,
	description: string,
	playstyle: string,
	advanced: boolean,
	weapon: string,
	statMult: { hp: number, atk: number, def: number },
	baseCrit: number,
	extraCompanionSlots: number,
	companionMods: { [string]: number },
	abilities: { { id: string, level: number } }, -- [1] = Grundangriff
	requirements: { Requirement },
	unlockedBy: string?, -- Monster, das die Klasse freischaltet (Anzeige)
	talents: { Talent },
}

local C: { [string]: ClassDef } = {}

C.Krieger = {
	name = "Krieger",
	description = "Robuster Nahkämpfer mit Schwert und Schild.",
	playstyle = "Nahkampf",
	advanced = false,
	weapon = "Schwert",
	statMult = { hp = 1.25, atk = 1.0, def = 1.2 },
	baseCrit = 0.05,
	extraCompanionSlots = 0,
	companionMods = {},
	abilities = {
		{ id = "Schwerthieb", level = 1 },
		{ id = "Wirbelschlag", level = 1 },
		{ id = "Kampfschrei", level = 5 },
		{ id = "Schildwall", level = 12 },
	},
	requirements = {},
	talents = {
		{ id = "K_Zaehigkeit", name = "Zähigkeit", description = "+5 % Lebenspunkte pro Rang.", maxRank = 5, stat = "hpPct", perRank = 0.05 },
		{ id = "K_Klingenmeister", name = "Klingenmeister", description = "+4 % Angriff pro Rang.", maxRank = 5, stat = "atkPct", perRank = 0.04 },
		{ id = "K_Bollwerk", name = "Bollwerk", description = "+6 % Verteidigung pro Rang.", maxRank = 5, stat = "defPct", perRank = 0.06, requires = "K_Zaehigkeit", requiresLevel = 10 },
		{ id = "K_Kampfrausch", name = "Kampfrausch", description = "-4 % Abklingzeit pro Rang.", maxRank = 3, stat = "cooldownPct", perRank = 0.04, requires = "K_Klingenmeister", requiresLevel = 20 },
	},
}

C.Waldlaeufer = {
	name = "Waldläufer",
	description = "Bogenschütze, der aus der Distanz präzise und kritisch trifft.",
	playstyle = "Fernkampf",
	advanced = false,
	weapon = "Bogen",
	statMult = { hp = 0.95, atk = 1.1, def = 0.9 },
	baseCrit = 0.12,
	extraCompanionSlots = 0,
	companionMods = {},
	abilities = {
		{ id = "Pfeilschuss", level = 1 },
		{ id = "Mehrfachschuss", level = 1 },
		{ id = "Betaeubungspfeil", level = 5 },
		{ id = "Adlerblick", level = 12 },
	},
	requirements = {},
	talents = {
		{ id = "W_Scharfschuetze", name = "Scharfschütze", description = "+2 % kritische Trefferchance pro Rang.", maxRank = 5, stat = "crit", perRank = 0.02 },
		{ id = "W_Spannkraft", name = "Spannkraft", description = "+4 % Angriff pro Rang.", maxRank = 5, stat = "atkPct", perRank = 0.04 },
		{ id = "W_Faehrtenleser", name = "Fährtenleser", description = "+5 % Fangchance pro Rang.", maxRank = 3, stat = "captureBonus", perRank = 0.05, requiresLevel = 10 },
		{ id = "W_Schnellschuss", name = "Schnellschuss", description = "-5 % Abklingzeit pro Rang.", maxRank = 3, stat = "cooldownPct", perRank = 0.05, requires = "W_Spannkraft", requiresLevel = 20 },
	},
}

C.Magier = {
	name = "Magier",
	description = "Wirkt starke Flächenmagie und kontrolliert das Schlachtfeld.",
	playstyle = "Magie",
	advanced = false,
	weapon = "Stab",
	statMult = { hp = 0.85, atk = 1.2, def = 0.85 },
	baseCrit = 0.06,
	extraCompanionSlots = 0,
	companionMods = {},
	abilities = {
		{ id = "Arkanblitz", level = 1 },
		{ id = "Arkanexplosion", level = 1 },
		{ id = "Frostfessel", level = 5 },
		{ id = "Manaschild", level = 12 },
	},
	requirements = {},
	talents = {
		{ id = "M_Arkanwissen", name = "Arkanwissen", description = "+5 % Angriff pro Rang.", maxRank = 5, stat = "atkPct", perRank = 0.05 },
		{ id = "M_Konzentration", name = "Konzentration", description = "-4 % Abklingzeit pro Rang.", maxRank = 5, stat = "cooldownPct", perRank = 0.04 },
		{ id = "M_Lebensmagie", name = "Lebensmagie", description = "+8 % Heilung pro Rang.", maxRank = 3, stat = "healPct", perRank = 0.08, requiresLevel = 10 },
		{ id = "M_Elementbindung", name = "Elementbindung", description = "+10 % Bindungs-EP pro Rang.", maxRank = 3, stat = "bondXpPct", perRank = 0.1, requires = "M_Arkanwissen", requiresLevel = 15 },
	},
}

C.Bestienbaendiger = {
	name = "Bestienbändiger",
	description = "Kämpft an der Seite seiner Monster und macht sie stärker. +1 aktiver Gefährte.",
	playstyle = "Monstergefährten",
	advanced = false,
	weapon = "Peitsche",
	statMult = { hp = 1.0, atk = 0.8, def = 1.0 },
	baseCrit = 0.05,
	extraCompanionSlots = 1,
	companionMods = { companionAtkPct = 0.15, companionHpPct = 0.15 },
	abilities = {
		{ id = "Peitschenhieb", level = 1 },
		{ id = "Rudelruf", level = 1 },
		{ id = "Bindungsheilung", level = 5 },
		{ id = "WildesBand", level = 12 },
	},
	requirements = {},
	talents = {
		{ id = "B_Rudelfuehrer", name = "Rudelführer", description = "+5 % Gefährten-Angriff pro Rang.", maxRank = 5, stat = "companionAtkPct", perRank = 0.05 },
		{ id = "B_Fuersorge", name = "Fürsorge", description = "+6 % Gefährten-LP pro Rang.", maxRank = 5, stat = "companionHpPct", perRank = 0.06 },
		{ id = "B_Seelenband", name = "Seelenband", description = "+15 % Bindungs-EP pro Rang.", maxRank = 3, stat = "bondXpPct", perRank = 0.15, requiresLevel = 8 },
		{ id = "B_Bestienfluesterer", name = "Bestienflüsterer", description = "+6 % Fangchance pro Rang.", maxRank = 3, stat = "captureBonus", perRank = 0.06, requires = "B_Seelenband", requiresLevel = 15 },
	},
}

C.Flammenkrieger = {
	name = "Flammenkrieger",
	description = "Nahkämpfer, dessen Klinge mit dem Feuer des Wolfs brennt.",
	playstyle = "Nahkampf + Feuer",
	advanced = true,
	weapon = "Flammenschwert",
	statMult = { hp = 1.2, atk = 1.25, def = 1.1 },
	baseCrit = 0.08,
	extraCompanionSlots = 0,
	companionMods = {},
	abilities = {
		{ id = "Flammenklinge", level = 1 },
		{ id = "Feuerwirbel", level = 1 },
		{ id = "Glutruestung", level = 1 },
		{ id = "Phoenixschlag", level = 25 },
	},
	unlockedBy = "Feuerwolf",
	requirements = {
		{ type = "level", value = 20 },
		{ type = "bond", species = "Feuerwolf", value = 5 },
		{ type = "stage", species = "Feuerwolf", value = 2 },
		{ type = "quest", id = "Feuerprobe" },
	},
	talents = {
		{ id = "F_Glut", name = "Ewige Glut", description = "+5 % Angriff pro Rang.", maxRank = 5, stat = "atkPct", perRank = 0.05 },
		{ id = "F_Rudelfeuer", name = "Rudelfeuer", description = "+6 % Gefährten-Angriff pro Rang.", maxRank = 3, stat = "companionAtkPct", perRank = 0.06 },
		{ id = "F_Phoenix", name = "Phönixblut", description = "+6 % Lebenspunkte pro Rang.", maxRank = 5, stat = "hpPct", perRank = 0.06, requires = "F_Glut", requiresLevel = 30 },
	},
}

C.Schattenlaeufer = {
	name = "Schattenläufer",
	description = "Getarnter Assassine, der Schattenmagie und kritische Treffer meistert.",
	playstyle = "Tarnung + Kritische Treffer",
	advanced = true,
	weapon = "Dolche",
	statMult = { hp = 0.95, atk = 1.3, def = 0.9 },
	baseCrit = 0.18,
	extraCompanionSlots = 0,
	companionMods = {},
	abilities = {
		{ id = "Schattendolch", level = 1 },
		{ id = "Schattenschritt", level = 1 },
		{ id = "Schattenmantel", level = 1 },
		{ id = "Giftklinge", level = 25 },
	},
	unlockedBy = "Schattenwesen",
	requirements = {
		{ type = "level", value = 20 },
		{ type = "bond", species = "Schattenwesen", value = 5 },
		{ type = "quest", id = "Runenpfad" },
	},
	talents = {
		{ id = "S_Meuchler", name = "Meuchler", description = "+3 % kritische Trefferchance pro Rang.", maxRank = 5, stat = "crit", perRank = 0.03 },
		{ id = "S_Zwielicht", name = "Zwielicht", description = "-5 % Abklingzeit pro Rang.", maxRank = 3, stat = "cooldownPct", perRank = 0.05 },
		{ id = "S_Nachtklinge", name = "Nachtklinge", description = "+6 % Angriff pro Rang.", maxRank = 5, stat = "atkPct", perRank = 0.06, requires = "S_Meuchler", requiresLevel = 30 },
	},
}

C.Naturhueter = {
	name = "Naturhüter",
	description = "Heiler und Beschützer, der Mensch und Monster gleichermaßen stärkt.",
	playstyle = "Heilung + Unterstützung",
	advanced = true,
	weapon = "Lebensstab",
	statMult = { hp = 1.1, atk = 0.95, def = 1.1 },
	baseCrit = 0.05,
	extraCompanionSlots = 1,
	companionMods = { companionHpPct = 0.2 },
	abilities = {
		{ id = "Dornenpeitsche", level = 1 },
		{ id = "Regeneration", level = 1 },
		{ id = "Wurzelfessel", level = 1 },
		{ id = "Waldsegen", level = 25 },
	},
	unlockedBy = "Naturgeist",
	requirements = {
		{ type = "level", value = 20 },
		{ type = "bond", species = "Naturgeist", value = 5 },
		{ type = "quest", id = "Hainheilung" },
	},
	talents = {
		{ id = "N_Bluete", name = "Blüte", description = "+10 % Heilung pro Rang.", maxRank = 5, stat = "healPct", perRank = 0.1 },
		{ id = "N_Wurzeln", name = "Tiefe Wurzeln", description = "+6 % Gefährten-LP pro Rang.", maxRank = 5, stat = "companionHpPct", perRank = 0.06 },
		{ id = "N_Einklang", name = "Einklang", description = "+15 % Bindungs-EP pro Rang.", maxRank = 3, stat = "bondXpPct", perRank = 0.15, requires = "N_Bluete", requiresLevel = 30 },
	},
}

C.Drachenritter = {
	name = "Drachenritter",
	description = "Seltene Elite-Klasse. Nur wer die Bindung eines Uralten Drachen gewinnt, kann sie erlernen.",
	playstyle = "Drachenmagie + Nahkampf",
	advanced = true,
	weapon = "Drachenlanze",
	statMult = { hp = 1.35, atk = 1.35, def = 1.25 },
	baseCrit = 0.1,
	extraCompanionSlots = 0,
	companionMods = { companionAtkPct = 0.1 },
	abilities = {
		{ id = "Drachenlanze", level = 1 },
		{ id = "Drachenatem", level = 1 },
		{ id = "Schuppenpanzer", level = 1 },
		{ id = "Drachensturz", level = 40 },
	},
	unlockedBy = "UralterDrache",
	requirements = {
		{ type = "level", value = 40 },
		{ type = "bond", species = "UralterDrache", value = 4 },
		{ type = "quest", id = "Drachenschwur" },
	},
	talents = {
		{ id = "D_Drachenblut", name = "Drachenblut", description = "+6 % Lebenspunkte pro Rang.", maxRank = 5, stat = "hpPct", perRank = 0.06 },
		{ id = "D_Drachenzorn", name = "Drachenzorn", description = "+6 % Angriff pro Rang.", maxRank = 5, stat = "atkPct", perRank = 0.06 },
	},
}

-- Reihenfolge für die UI
local Order = {
	"Krieger",
	"Waldlaeufer",
	"Magier",
	"Bestienbaendiger",
	"Flammenkrieger",
	"Schattenlaeufer",
	"Naturhueter",
	"Drachenritter",
}

return { List = C, Order = Order, BaseClasses = { "Krieger", "Waldlaeufer", "Magier", "Bestienbaendiger" } }
