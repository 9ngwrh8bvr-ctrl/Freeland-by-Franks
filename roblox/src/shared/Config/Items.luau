--!strict
-- Gegenstände: Verbrauchsgüter, Köder, Materialien, Ausrüstung, Kosmetik.

export type Item = {
	name: string,
	description: string,
	category: string, -- "consumable" | "lure" | "material" | "equipment" | "cosmetic"
	icon: string,
	sellValue: number?,
	-- Verbrauchsgüter
	effect: string?, -- "healPct" | "bondXp" | "revive" | "storage"
	value: number?,
	needsMonster: boolean?,
	-- Köder (Vertrauensritual)
	captureBonus: number?,
	lureElement: string?,
	-- Ausrüstung
	slot: string?, -- "weapon" | "armor" | "amulet"
	stats: { [string]: number }?,
	requiredLevel: number?,
}

local I: { [string]: Item } = {}

-- Verbrauchsgüter
I.Heiltrank = { name = "Heiltrank", description = "Heilt 40 % deiner Lebenspunkte.", category = "consumable", icon = "🧪", effect = "healPct", value = 0.4, sellValue = 8 }
I.GrosserHeiltrank = { name = "Großer Heiltrank", description = "Heilt 80 % deiner Lebenspunkte.", category = "consumable", icon = "⚗️", effect = "healPct", value = 0.8, sellValue = 20 }
I.Bindungssnack = { name = "Bindungssnack", description = "+60 Bindungs-EP für ein Monster.", category = "consumable", icon = "🍪", effect = "bondXp", value = 60, needsMonster = true, sellValue = 10 }
I.Wiederbelebungskraut = { name = "Wiederbelebungskraut", description = "Macht einen erschöpften Gefährten sofort wieder einsatzbereit.", category = "consumable", icon = "🌱", effect = "revive", value = 1, needsMonster = true, sellValue = 10 }

-- Köder: werden beim Vertrauensritual automatisch verwendet (bester passender zuerst)
I.Lockfrucht = { name = "Lockfrucht", description = "+10 % Fangchance bei jedem Monster.", category = "lure", icon = "🍎", captureBonus = 0.1, sellValue = 4 }
I.Glutbeere = { name = "Glutbeere", description = "+25 % Fangchance bei Feuer-Monstern.", category = "lure", icon = "🍒", captureBonus = 0.25, lureElement = "Feuer", sellValue = 6 }
I.Tauperle = { name = "Tauperle", description = "+25 % Fangchance bei Wasser-Monstern.", category = "lure", icon = "🫧", captureBonus = 0.25, lureElement = "Wasser", sellValue = 6 }
I.Schattenmotte = { name = "Schattenmotte", description = "+25 % Fangchance bei Schatten-Monstern.", category = "lure", icon = "🦋", captureBonus = 0.25, lureElement = "Schatten", sellValue = 8 }
I.Goldfrucht = { name = "Goldene Lockfrucht", description = "+30 % Fangchance bei jedem Monster.", category = "lure", icon = "🍯", captureBonus = 0.3, sellValue = 15 }

-- Materialien (verkaufbar, später Handwerk)
I.Steinbrocken = { name = "Steinbrocken", description = "Material.", category = "material", icon = "🪨", sellValue = 3 }
I.Feder = { name = "Feder", description = "Material.", category = "material", icon = "🪶", sellValue = 3 }
I.Leuchtstaub = { name = "Leuchtstaub", description = "Material.", category = "material", icon = "✨", sellValue = 6 }
I.Perle = { name = "Perle", description = "Material.", category = "material", icon = "🦪", sellValue = 12 }
I.Schattenessenz = { name = "Schattenessenz", description = "Material.", category = "material", icon = "🌑", sellValue = 12 }
I.Lebenssamen = { name = "Lebenssamen", description = "Material.", category = "material", icon = "🌰", sellValue = 12 }
I.Glutzahn = { name = "Glutzahn", description = "Material.", category = "material", icon = "🦷", sellValue = 8 }
I.Glutkern = { name = "Glutkern", description = "Herz des Glutkolosses.", category = "material", icon = "🔴", sellValue = 60 }
I.Drachenschuppe = { name = "Drachenschuppe", description = "Uraltes Material.", category = "material", icon = "🐉", sellValue = 150 }

-- Ausrüstung
I.Eisenklinge = { name = "Eisenwaffe", description = "+5 Angriff.", category = "equipment", icon = "🗡️", slot = "weapon", stats = { atk = 5 }, sellValue = 40 }
I.Stahlklinge = { name = "Stahlwaffe", description = "+12 Angriff.", category = "equipment", icon = "⚔️", slot = "weapon", stats = { atk = 12 }, requiredLevel = 10, sellValue = 180 }
I.Flammenschwert = { name = "Flammenschwert", description = "+22 Angriff, +5 % krit. Chance.", category = "equipment", icon = "🔥", slot = "weapon", stats = { atk = 22, crit = 0.05 }, requiredLevel = 15, sellValue = 400 }
I.Lederruestung = { name = "Lederrüstung", description = "+4 Verteidigung, +20 LP.", category = "equipment", icon = "🦺", slot = "armor", stats = { def = 4, hp = 20 }, sellValue = 35 }
I.Eisenruestung = { name = "Eisenrüstung", description = "+10 Verteidigung, +50 LP.", category = "equipment", icon = "🛡️", slot = "armor", stats = { def = 10, hp = 50 }, requiredLevel = 10, sellValue = 170 }
I.Tieramulett = { name = "Tieramulett", description = "+10 % LP für Gefährten.", category = "equipment", icon = "📿", slot = "amulet", stats = { companionHpPct = 0.1 }, sellValue = 120 }
I.Bindungsamulett = { name = "Bindungsamulett", description = "+10 % Gefährten-Angriff, +20 % Bindungs-EP.", category = "equipment", icon = "💠", slot = "amulet", stats = { companionAtkPct = 0.1, bondXpPct = 0.2 }, requiredLevel = 12, sellValue = 300 }

-- Kosmetik (keine Spielvorteile)
I.AuraGold = { name = "Goldene Aura", description = "Goldenes Leuchten für deine Gefährten.", category = "cosmetic", icon = "🌟" }
I.AuraFrost = { name = "Frost-Aura", description = "Eisiger Glanz für deine Gefährten.", category = "cosmetic", icon = "❄️" }
I.AuraSchatten = { name = "Schatten-Aura", description = "Dunkler Nebel für deine Gefährten.", category = "cosmetic", icon = "🌫️" }

return I
