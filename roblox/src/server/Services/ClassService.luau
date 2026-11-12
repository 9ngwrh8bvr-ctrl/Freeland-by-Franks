--!strict
-- Klassen wechseln/freischalten, Talente (Skilltree) und Spezialisierungen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassesModule = require(Shared.Config.Classes)
local Abilities = require(Shared.Config.Abilities)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Notifier = require(script.Parent.Parent.Modules.Notifier)

local Classes = ClassesModule.List
local TALENT_RESET_COST = 100
local COMBAT_LOCK = 5 -- Sekunden nach Schaden kein Klassenwechsel

local ClassService = {}
local S: any
local limiter = RateLimiter.new(0.3)
local announced: { [Player]: { [string]: boolean } } = {}

function ClassService:Init(services)
	S = services
end

function ClassService:Start()
	Net.func("ManageClass").OnServerInvoke = function(player, action, arg)
		if not limiter:check(player) or type(action) ~= "string" then
			return false, "Zu schnell"
		end
		if arg ~= nil and type(arg) ~= "string" then
			return false, "Ungültig"
		end
		if action == "switch" then
			return self:Switch(player, arg)
		elseif action == "unlock" then
			return self:Unlock(player, arg)
		elseif action == "talent" then
			return self:SpendTalent(player, arg)
		elseif action == "resetTalents" then
			return self:ResetTalents(player)
		elseif action == "setSpec" then
			return self:SetSpecialization(player, arg)
		end
		return false, "Unbekannte Aktion"
	end
	S.DataService:OnLoaded(function(player)
		announced[player] = {}
		self:CheckUnlockable(player)
	end)
	S.DataService:OnRemoving(function(player)
		announced[player] = nil
	end)
end

function ClassService:TalentPointsLeft(d: any, classId: string): number
	local spent = 0
	for _, r in d.talents[classId] or {} do
		spent += r
	end
	return (d.level - 1) - spent
end

function ClassService:Switch(player: Player, classId: string?): (boolean, string?)
	local d = S.DataService:Get(player)
	if not d or not classId or not Classes[classId] then
		return false, "Unbekannte Klasse"
	end
	if not d.unlockedClasses[classId] then
		return false, "Klasse noch nicht freigeschaltet"
	end
	local e = S.EntityService:ForPlayer(player)
	if e and os.clock() - e.lastDamaged < COMBAT_LOCK then
		return false, "Nicht während des Kampfes"
	end
	d.classId = classId
	S.DataService:MarkDirty(player)
	S.EntityService:RefreshPlayer(player)
	S.CompanionService:RefreshAll(player)
	Notifier.send(player, ("Klasse gewechselt: %s"):format(Classes[classId].name), "good")
	return true
end

function ClassService:Unlock(player: Player, classId: string?): (boolean, string?)
	local d = S.DataService:Get(player)
	if not d or not classId or not Classes[classId] then
		return false, "Unbekannte Klasse"
	end
	if d.unlockedClasses[classId] then
		return true
	end
	local ok = Formulas.classRequirements(d, classId)
	if not ok then
		return false, "Voraussetzungen nicht erfüllt"
	end
	d.unlockedClasses[classId] = true
	S.DataService:MarkDirty(player)
	Notifier.send(player, ("🏅 Neue Klasse freigeschaltet: %s!"):format(Classes[classId].name), "epic")
	return true
end

-- Meldet, wenn eine Klasse freischaltbar geworden ist
function ClassService:CheckUnlockable(player: Player)
	local d = S.DataService:Get(player)
	if not d then
		return
	end
	local seen = announced[player] or {}
	announced[player] = seen
	for _, id in ClassesModule.Order do
		if not d.unlockedClasses[id] and not seen[id] and Formulas.classRequirements(d, id) then
			seen[id] = true
			Notifier.send(player, ("🔓 Klasse %s kann freigeschaltet werden! (Klassenmenü)"):format(Classes[id].name), "epic")
		end
	end
end

function ClassService:SpendTalent(player: Player, talentId: string?): (boolean, string?)
	local d = S.DataService:Get(player)
	if not d or not talentId then
		return false, "Ungültig"
	end
	local cls = Classes[d.classId]
	local talent = nil
	for _, t in cls.talents do
		if t.id == talentId then
			talent = t
		end
	end
	if not talent then
		return false, "Talent gehört nicht zur aktuellen Klasse"
	end
	if self:TalentPointsLeft(d, d.classId) <= 0 then
		return false, "Keine Talentpunkte"
	end
	d.talents[d.classId] = d.talents[d.classId] or {}
	local ranks = d.talents[d.classId]
	if (ranks[talent.id] or 0) >= talent.maxRank then
		return false, "Maximaler Rang"
	end
	if talent.requiresLevel and d.level < talent.requiresLevel then
		return false, ("Benötigt Level %d"):format(talent.requiresLevel)
	end
	if talent.requires and (ranks[talent.requires] or 0) < 1 then
		return false, "Vorheriges Talent benötigt"
	end
	ranks[talent.id] = (ranks[talent.id] or 0) + 1
	S.DataService:MarkDirty(player)
	S.EntityService:RefreshPlayer(player)
	S.CompanionService:RefreshAll(player)
	return true
end

function ClassService:ResetTalents(player: Player): (boolean, string?)
	local d = S.DataService:Get(player)
	if not d then
		return false
	end
	if not S.InventoryService:SpendCoins(player, TALENT_RESET_COST) then
		return false, ("Benötigt %d Münzen"):format(TALENT_RESET_COST)
	end
	d.talents[d.classId] = {}
	S.DataService:MarkDirty(player)
	S.EntityService:RefreshPlayer(player)
	S.CompanionService:RefreshAll(player)
	return true
end

function ClassService:SetSpecialization(player: Player, abilityId: string?): (boolean, string?)
	local d = S.DataService:Get(player)
	if not d then
		return false
	end
	if abilityId == nil or abilityId == "" then
		d.specialization = ""
		S.DataService:MarkDirty(player)
		return true
	end
	if not Abilities[abilityId] or not table.find(Formulas.specializations(d), abilityId) then
		return false, "Spezialisierung nicht freigeschaltet"
	end
	d.specialization = abilityId
	S.DataService:MarkDirty(player)
	return true
end

return ClassService
