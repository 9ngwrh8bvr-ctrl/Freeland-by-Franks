--!strict
-- Reine Rechenfunktionen (keine Roblox-Seiteneffekte). Werden von Server
-- UND Client benutzt, damit Anzeige und Spiellogik identisch rechnen.
-- Können außerhalb von Roblox getestet werden (siehe roblox/tests).

local Config = script.Parent.Config
local GameConfig = require(Config.GameConfig)
local Monsters = require(Config.Monsters)
local Rarities = require(Config.Rarities)
local ClassesModule = require(Config.Classes)
local Items = require(Config.Items)
local Elements = require(Config.Elements)

local Classes = ClassesModule.List

local Formulas = {}

------------------------------------------------------------------------
-- Level & Bindung
------------------------------------------------------------------------
function Formulas.xpToNext(level: number): number
	return math.floor(60 * level ^ 1.6)
end

function Formulas.monsterXpToNext(level: number): number
	return math.floor(40 * level ^ 1.5)
end

-- Kumulierte Bindungs-EP für Stufe 1..5
Formulas.BondThresholds = { 0, 100, 300, 650, 1200 }

function Formulas.bondLevel(bondXp: number): number
	local lvl = 1
	for i, need in Formulas.BondThresholds do
		if bondXp >= need then
			lvl = i
		end
	end
	return math.min(lvl, GameConfig.MaxBondLevel)
end

-- Fortschritt zur nächsten Bindungsstufe (0..1), 1 bei Maximum
function Formulas.bondProgress(bondXp: number): number
	local lvl = Formulas.bondLevel(bondXp)
	if lvl >= GameConfig.MaxBondLevel then
		return 1
	end
	local a = Formulas.BondThresholds[lvl]
	local b = Formulas.BondThresholds[lvl + 1]
	return (bondXp - a) / (b - a)
end

Formulas.BondPerks = {
	[1] = "Grundangriffe",
	[2] = "Erste Spezialfähigkeit (Befehl)",
	[3] = "Verbesserte Kampfunterstützung + Spezialisierung",
	[4] = "Einzigartige Fähigkeit (Befehl)",
	[5] = "Klassen- und Skillfreischaltung",
}

------------------------------------------------------------------------
-- Entwicklung (Stufen)
------------------------------------------------------------------------
function Formulas.stageIndex(speciesId: string, level: number): number
	local sp = Monsters[speciesId]
	if not sp then
		return 1
	end
	local idx = 1
	for i, st in sp.stages do
		if level >= st.level then
			idx = i
		end
	end
	return idx
end

function Formulas.stageName(speciesId: string, level: number): string
	local sp = Monsters[speciesId]
	if not sp then
		return speciesId
	end
	return sp.stages[Formulas.stageIndex(speciesId, level)].name
end

local STAGE_MULT = { 1, 1.25, 1.5 }

------------------------------------------------------------------------
-- Modifikatoren (Talente + Ausrüstung + Klasse)
------------------------------------------------------------------------
export type Mods = { [string]: number }

function Formulas.aggregateMods(profile: any): Mods
	local mods: Mods = {}
	local function addMod(k: string, v: number)
		mods[k] = (mods[k] or 0) + v
	end
	local cls = Classes[profile.classId]
	if cls then
		for k, v in cls.companionMods do
			addMod(k, v)
		end
		local ranks = profile.talents and profile.talents[profile.classId] or {}
		for _, t in cls.talents do
			local r = ranks[t.id]
			if r and r > 0 then
				addMod(t.stat, t.perRank * r)
			end
		end
	end
	if profile.equipment then
		for _, itemId in profile.equipment do
			local it = Items[itemId]
			if it and it.stats then
				for k, v in it.stats do
					if k ~= "atk" and k ~= "def" and k ~= "hp" then
						addMod(k, v)
					end
				end
			end
		end
	end
	return mods
end

------------------------------------------------------------------------
-- Werte
------------------------------------------------------------------------
export type Stats = { hp: number, atk: number, def: number, spd: number, crit: number }

function Formulas.monsterStats(speciesId: string, level: number, bondXp: number, potential: number?, mods: Mods?): Stats
	local sp = Monsters[speciesId]
	assert(sp, "Unbekanntes Monster: " .. tostring(speciesId))
	local rarity = Rarities.List[sp.rarity]
	local stage = Formulas.stageIndex(speciesId, level)
	local bond = Formulas.bondLevel(bondXp)
	local m = mods or {}
	local mult = rarity.statMult * STAGE_MULT[stage] * (1 + 0.08 * (level - 1)) * (potential or 1) * (1 + 0.04 * (bond - 1))
	return {
		hp = math.floor(sp.baseStats.hp * mult * (1 + (m.companionHpPct or 0))),
		atk = math.floor(sp.baseStats.atk * mult * (1 + (m.companionAtkPct or 0))),
		def = math.floor(sp.baseStats.def * mult),
		spd = sp.baseStats.spd,
		crit = GameConfig.BaseCritChance + (bond >= 3 and 0.05 or 0),
	}
end

function Formulas.playerStats(profile: any): Stats
	local cls = Classes[profile.classId] or Classes.Krieger
	local level = profile.level or 1
	local mods = Formulas.aggregateMods(profile)
	local hp = 100 + 14 * (level - 1)
	local atk = 10 + 2.2 * (level - 1)
	local def = 5 + 1.6 * (level - 1)
	local crit = cls.baseCrit
	if profile.equipment then
		for _, itemId in profile.equipment do
			local it = Items[itemId]
			if it and it.stats then
				hp += it.stats.hp or 0
				atk += it.stats.atk or 0
				def += it.stats.def or 0
			end
		end
	end
	return {
		hp = math.floor(hp * cls.statMult.hp * (1 + (mods.hpPct or 0))),
		atk = math.floor(atk * cls.statMult.atk * (1 + (mods.atkPct or 0))),
		def = math.floor(def * cls.statMult.def * (1 + (mods.defPct or 0))),
		spd = 16,
		crit = crit + (mods.crit or 0),
	}
end

function Formulas.activeSlots(profile: any): number
	local slots = 1
	for _, step in GameConfig.CompanionSlots do
		if (profile.level or 1) >= step.level then
			slots = step.slots
		end
	end
	local cls = Classes[profile.classId]
	if cls then
		slots += cls.extraCompanionSlots
	end
	return math.min(slots, GameConfig.MaxActiveCompanions)
end

function Formulas.storageCap(profile: any, hasBigPen: boolean?): number
	local cap = GameConfig.BaseStorage + (profile.storageUpgrades or 0) * GameConfig.StorageUpgradeSize
	if hasBigPen then
		cap += 100
	end
	return math.min(cap, GameConfig.MaxStorage + 100)
end

function Formulas.unlockedAbilities(profile: any): { string }
	local cls = Classes[profile.classId] or Classes.Krieger
	local list = {}
	for _, a in cls.abilities do
		if (profile.level or 1) >= a.level then
			table.insert(list, a.id)
		end
	end
	return list
end

-- Spezialisierungen, die der Spieler durch Monsterbindung besitzt
function Formulas.specializations(profile: any): { string }
	local seen: { [string]: boolean } = {}
	local list = {}
	for _, rec in profile.monsters or {} do
		local sp = Monsters[rec.species]
		if sp and sp.specialization and Formulas.bondLevel(rec.bondXp or 0) >= sp.specialization.bond then
			local id = sp.specialization.ability
			if not seen[id] then
				seen[id] = true
				table.insert(list, id)
			end
		end
	end
	table.sort(list)
	return list
end

------------------------------------------------------------------------
-- Kampf
------------------------------------------------------------------------
function Formulas.damage(power: number, atk: number, def: number, elementMult: number, crit: boolean, roll: number?): number
	local ratio = atk / (atk + def * 1.2)
	local dmg = power * (0.5 + ratio * 1.5) * (1 + atk / 60) * elementMult
	if crit then
		dmg *= GameConfig.CritMultiplier
	end
	dmg *= roll or 1
	return math.max(1, math.floor(dmg + 0.5))
end

function Formulas.elementMultiplier(attacker: string?, defender: string?): number
	return Elements.multiplier(attacker, defender)
end

------------------------------------------------------------------------
-- Fangen (Vertrauensritual)
------------------------------------------------------------------------
function Formulas.captureChance(speciesId: string, hpPct: number, levelDiff: number, lureBonus: number, talentBonus: number): number
	local sp = Monsters[speciesId]
	if not sp or not sp.capture.capturable then
		return 0
	end
	local mod = Rarities.List[sp.rarity].captureMod
	if mod <= 0 then
		return 0
	end
	local hpFactor = math.clamp(1 - hpPct, 0, 1)
	local chance = 0.5 * mod * (0.5 + hpFactor) + lureBonus + talentBonus - math.max(0, levelDiff) * 0.02
	return math.clamp(chance, 0.02, 0.95)
end

------------------------------------------------------------------------
-- Voraussetzungen (Klassen, Quests)
------------------------------------------------------------------------
function Formulas.bestBond(profile: any, speciesId: string): number
	local best = 0
	for _, rec in profile.monsters or {} do
		if rec.species == speciesId then
			best = math.max(best, Formulas.bondLevel(rec.bondXp or 0))
		end
	end
	return best
end

function Formulas.bestStage(profile: any, speciesId: string): number
	local best = 0
	for _, rec in profile.monsters or {} do
		if rec.species == speciesId then
			best = math.max(best, Formulas.stageIndex(speciesId, rec.level or 1))
		end
	end
	return best
end

function Formulas.ownsSpecies(profile: any, speciesId: string): boolean
	for _, rec in profile.monsters or {} do
		if rec.species == speciesId then
			return true
		end
	end
	return false
end

function Formulas.checkRequirement(profile: any, req: any): (boolean, string)
	local function spName(id: string): string
		local sp = Monsters[id]
		return sp and sp.name or id
	end
	if req.type == "level" then
		return (profile.level or 1) >= req.value, ("Charakterlevel %d"):format(req.value)
	elseif req.type == "bond" then
		return Formulas.bestBond(profile, req.species) >= req.value,
			("%s mit Bindungsstufe %d"):format(spName(req.species), req.value)
	elseif req.type == "stage" then
		return Formulas.bestStage(profile, req.species) >= req.value,
			("%s auf Entwicklungsstufe %d"):format(spName(req.species), req.value)
	elseif req.type == "quest" then
		local done = profile.quests and profile.quests.completed and profile.quests.completed[req.id] == true
		return done, ("Prüfung abgeschlossen: %s"):format(req.id)
	elseif req.type == "species" then
		return Formulas.ownsSpecies(profile, req.species), ("%s gefangen"):format(spName(req.species))
	end
	return false, "Unbekannte Bedingung"
end

function Formulas.classRequirements(profile: any, classId: string): (boolean, { { text: string, ok: boolean } })
	local cls = Classes[classId]
	local list = {}
	local all = true
	if not cls then
		return false, list
	end
	for _, req in cls.requirements do
		local ok, text = Formulas.checkRequirement(profile, req)
		table.insert(list, { text = text, ok = ok })
		all = all and ok
	end
	return all, list
end

function Formulas.questAvailable(profile: any, quest: any): boolean
	local p = quest.prereq
	if p.level and (profile.level or 1) < p.level then
		return false
	end
	if p.quest and not (profile.quests.completed[p.quest]) then
		return false
	end
	if p.hasSpecies and not Formulas.ownsSpecies(profile, p.hasSpecies) then
		return false
	end
	if p.bond and Formulas.bestBond(profile, p.bond.species) < p.bond.value then
		return false
	end
	return true
end

return Formulas
