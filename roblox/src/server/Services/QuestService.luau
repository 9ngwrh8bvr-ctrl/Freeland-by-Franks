--!strict
-- Quests: werden automatisch angenommen, sobald die Voraussetzungen erfüllt
-- sind, und automatisch abgeschlossen, sobald alle Ziele erreicht sind.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestsModule = require(Shared.Config.Quests)
local Formulas = require(Shared.Formulas)
local Notifier = require(script.Parent.Parent.Modules.Notifier)

local Quests = QuestsModule.List

local QuestService = {}
local S: any

function QuestService:Init(services)
	S = services
end

function QuestService:Start()
	S.DataService:OnLoaded(function(player)
		self:Refresh(player)
	end)
end

local function objectiveDone(d: any, questId: string, idx: number, obj: any): boolean
	if obj.type == "reachLevel" then
		return d.level >= (obj.value or 1)
	elseif obj.type == "bond" then
		return Formulas.bestBond(d, obj.species) >= (obj.value or 1)
	end
	local prog = d.quests.progress[questId]
	return prog ~= nil and (prog[idx] or 0) >= (obj.count or 1)
end

local function matches(obj: any, eventType: string, payload: any): boolean
	if obj.type ~= eventType then
		return false
	end
	if eventType == "capture" then
		return obj.species == nil or obj.species == payload.species
	elseif eventType == "defeat" then
		if obj.species and obj.species ~= payload.species then
			return false
		end
		if obj.element and obj.element ~= payload.element then
			return false
		end
		if obj.boss and not payload.boss then
			return false
		end
		if obj.withCompanion and not (payload.companions and payload.companions[obj.withCompanion]) then
			return false
		end
		return true
	elseif eventType == "useTrait" then
		return obj.trait == nil or obj.trait == payload.trait
	elseif eventType == "train" then
		return true
	end
	return false
end

function QuestService:Refresh(player: Player)
	local d = S.DataService:Get(player)
	if not d then
		return
	end
	for _, id in QuestsModule.Order do
		local q = Quests[id]
		if not d.quests.completed[id] and not d.quests.active[id] and Formulas.questAvailable(d, q) then
			d.quests.active[id] = true
			local prog = {}
			for i in q.objectives do
				prog[i] = 0
			end
			d.quests.progress[id] = prog
			Notifier.send(player, ("📜 Neue Quest: %s"):format(q.name), "good")
		end
	end
	for id in d.quests.active do
		self:CheckComplete(player, id)
	end
	S.DataService:MarkDirty(player)
end

function QuestService:Event(player: Player, eventType: string, payload: any)
	local d = S.DataService:Get(player)
	if not d then
		return
	end
	local changed = false
	for id in d.quests.active do
		local q = Quests[id]
		local prog = d.quests.progress[id]
		if not q or not prog then
			continue
		end
		for i, obj in q.objectives do
			if matches(obj, eventType, payload or {}) and (prog[i] or 0) < (obj.count or 1) then
				prog[i] = (prog[i] or 0) + 1
				changed = true
			end
		end
	end
	if changed then
		for id in d.quests.active do
			self:CheckComplete(player, id)
		end
		S.DataService:MarkDirty(player)
	end
end

function QuestService:CheckComplete(player: Player, id: string)
	local d = S.DataService:Get(player)
	local q = Quests[id]
	if not d or not q or not d.quests.active[id] then
		return
	end
	for i, obj in q.objectives do
		if not objectiveDone(d, id, i, obj) then
			return
		end
	end
	d.quests.active[id] = nil
	d.quests.completed[id] = true
	d.quests.progress[id] = nil
	Notifier.send(player, ("✅ Quest abgeschlossen: %s"):format(q.name), "epic")

	local r = q.rewards
	if r.coins then
		S.InventoryService:AddCoins(player, r.coins, false)
	end
	if r.gems then
		S.InventoryService:AddGems(player, r.gems)
	end
	if r.items then
		for itemId, n in r.items do
			S.InventoryService:AddItem(player, itemId, n)
		end
	end
	if r.flag then
		d.flags[r.flag] = true
	end
	if r.bondXp then
		local summoned = S.CompanionService:GetSummoned(player)
		local any = false
		for uid in summoned do
			S.ProgressionService:AddBondXp(player, uid, r.bondXp, "Quest")
			any = true
		end
		if not any and d.activeTeam[1] then
			S.ProgressionService:AddBondXp(player, d.activeTeam[1], r.bondXp, "Quest")
		end
	end
	if r.xp then
		S.ProgressionService:AddPlayerXp(player, r.xp)
	end
	S.DataService:MarkDirty(player)
	task.defer(function()
		self:Refresh(player)
		S.ClassService:CheckUnlockable(player)
	end)
end

return QuestService
