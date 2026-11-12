--!strict
-- Erfahrung, Level, Monsterentwicklung, Bindung und Belohnungen für Siege.
-- Hier laufen Charakter- und Monsterentwicklung zusammen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Monsters = require(Shared.Config.Monsters)
local Rarities = require(Shared.Config.Rarities)
local Abilities = require(Shared.Config.Abilities)
local Formulas = require(Shared.Formulas)
local Notifier = require(script.Parent.Parent.Modules.Notifier)

local ProgressionService = {}
local S: any

function ProgressionService:Init(services)
	S = services
end

function ProgressionService:Start()
	S.EntityService:OnDeath(function(e, killer)
		if e.kind == "Wild" then
			self:RewardWildDefeat(e, killer)
		end
	end)
end

------------------------------------------------------------------------
-- Charakter
------------------------------------------------------------------------
function ProgressionService:AddPlayerXp(player: Player, amount: number)
	local d = S.DataService:Get(player)
	if not d or amount <= 0 then
		return
	end
	if d.level >= GameConfig.MaxPlayerLevel then
		return
	end
	d.xp += math.floor(amount)
	local leveled = false
	while d.level < GameConfig.MaxPlayerLevel and d.xp >= Formulas.xpToNext(d.level) do
		d.xp -= Formulas.xpToNext(d.level)
		d.level += 1
		leveled = true
		Notifier.send(player, ("⬆️ Level %d erreicht! +1 Talentpunkt"):format(d.level), "epic")
		for _, step in GameConfig.CompanionSlots do
			if step.level == d.level then
				Notifier.send(player, ("Neuer Gefährtenplatz! Jetzt %d aktive Gefährten."):format(Formulas.activeSlots(d)), "epic")
			end
		end
	end
	if d.level >= GameConfig.MaxPlayerLevel then
		d.xp = 0
	end
	S.DataService:MarkDirty(player)
	if leveled then
		S.EntityService:RefreshPlayer(player, true)
		S.QuestService:Refresh(player)
		S.ClassService:CheckUnlockable(player)
	end
end

------------------------------------------------------------------------
-- Monster
------------------------------------------------------------------------
function ProgressionService:AddMonsterXp(player: Player, uid: string, amount: number)
	local d = S.DataService:Get(player)
	local rec = d and d.monsters[uid]
	if not rec or amount <= 0 then
		return
	end
	if rec.level >= GameConfig.MaxMonsterLevel then
		return
	end
	local oldStage = Formulas.stageIndex(rec.species, rec.level)
	rec.xp = (rec.xp or 0) + math.floor(amount)
	local leveled = false
	while rec.level < GameConfig.MaxMonsterLevel and rec.xp >= Formulas.monsterXpToNext(rec.level) do
		rec.xp -= Formulas.monsterXpToNext(rec.level)
		rec.level += 1
		leveled = true
	end
	if leveled then
		local newStage = Formulas.stageIndex(rec.species, rec.level)
		if newStage > oldStage then
			local sp = Monsters[rec.species]
			Notifier.send(
				player,
				("✨ %s hat sich zu %s entwickelt!"):format(sp.stages[oldStage].name, sp.stages[newStage].name),
				"epic"
			)
			S.ClassService:CheckUnlockable(player)
		end
		S.CompanionService:Refresh(player, uid)
	end
	S.DataService:MarkDirty(player)
end

function ProgressionService:AddBondXp(player: Player, uid: string, amount: number, _reason: string?)
	local d = S.DataService:Get(player)
	local rec = d and d.monsters[uid]
	if not rec or amount <= 0 then
		return
	end
	local mult = 1 + (Formulas.aggregateMods(d).bondXpPct or 0)
	if S.DataService:HasPass(player, "DoppelteBindung") then
		mult *= 2
	end
	local before = Formulas.bondLevel(rec.bondXp or 0)
	local cap = Formulas.BondThresholds[GameConfig.MaxBondLevel]
	rec.bondXp = math.min(cap, (rec.bondXp or 0) + math.floor(amount * mult))
	local after = Formulas.bondLevel(rec.bondXp)
	if after > before then
		local sp = Monsters[rec.species]
		local name = Formulas.stageName(rec.species, rec.level)
		Notifier.send(player, ("💞 Bindung mit %s: Stufe %d – %s"):format(name, after, Formulas.BondPerks[after]), "epic")
		if sp.specialization and before < sp.specialization.bond and after >= sp.specialization.bond then
			local ab = Abilities[sp.specialization.ability]
			Notifier.send(player, ("Neue Spezialisierung: %s! (Klassenmenü)"):format(ab and ab.name or "?"), "epic")
		end
		S.CompanionService:Refresh(player, uid)
		S.QuestService:Refresh(player)
		S.ClassService:CheckUnlockable(player)
	end
	S.DataService:MarkDirty(player)
end

------------------------------------------------------------------------
-- Siege über wilde Monster
------------------------------------------------------------------------
function ProgressionService:RewardWildDefeat(e: any, _killer: any)
	local sp = Monsters[e.speciesId]
	if not sp then
		return
	end
	local rarity = Rarities.List[sp.rarity]
	for player in e.damagedBy do
		if not player.Parent then
			continue
		end
		local d = S.DataService:Get(player)
		if not d then
			continue
		end
		local levelFactor = 1 + 0.12 * (e.level - 1)
		local penalty = if d.level > e.level + 8 then 0.25 else 1
		local xp = sp.xp * rarity.xpMult * levelFactor * penalty
		self:AddPlayerXp(player, xp)

		local coins = S.InventoryService:AddCoins(player, math.max(1, math.floor(sp.coins * levelFactor * penalty)), true)
		for _, drop in sp.loot do
			if math.random() < drop.chance then
				S.InventoryService:AddItem(player, drop.item, 1)
			end
		end
		if e.isBoss then
			S.InventoryService:AddGems(player, 5)
			d.stats.bosses += 1
			Notifier.send(player, ("🏆 %s besiegt! +%d Münzen, +5 Edelsteine"):format(sp.name, coins), "epic")
		elseif math.random() < 0.02 then
			S.InventoryService:AddGems(player, 1)
			Notifier.send(player, "💎 Du hast einen Edelstein gefunden!", "good")
		end
		d.stats.kills += 1

		-- Gefährten: EP + Bindung (gemeinsame Kämpfe / Bosskämpfe)
		local companionSpecies: { [string]: boolean } = {}
		local summoned = S.CompanionService:GetSummoned(player)
		local involved = e.companionsInvolved[player] or {}
		for uid, ce in summoned do
			local near = (ce.root.Position - e.root.Position).Magnitude < 90
			if near or involved[uid] then
				self:AddMonsterXp(player, uid, xp * 0.8)
				self:AddBondXp(player, uid, if e.isBoss then GameConfig.BondXp.BossKill else GameConfig.BondXp.Kill, "Kampf")
				if ce.speciesId then
					companionSpecies[ce.speciesId] = true
				end
			end
		end

		S.QuestService:Event(player, "defeat", {
			species = e.speciesId,
			element = sp.element,
			boss = e.isBoss,
			companions = companionSpecies,
		})
		S.DataService:MarkDirty(player)
	end
end

return ProgressionService
