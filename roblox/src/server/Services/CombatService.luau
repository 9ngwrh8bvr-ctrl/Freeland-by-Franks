--!strict
-- Angriffe und Fähigkeiten des Spielers (vom Client angefordert,
-- vollständig auf dem Server geprüft).
--
-- CombatAction(slot, targetModel?)
--   slot 1..4  – Klassenfähigkeiten (1 = Grundangriff)
--   slot "spec" – Spezialisierung (durch Monsterbindung)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local AbilityExecutor = require(script.Parent.Parent.Modules.AbilityExecutor)

local RANGE_TOLERANCE = 4 -- Ausgleich für Netzwerk-Verzögerung

local CombatService = {}
local S: any
local ES: any
local limiter = RateLimiter.new(0.1)

function CombatService:Init(services)
	S = services
	ES = services.EntityService
end

function CombatService:ResolveAbility(player: Player, slot: any): string?
	local d = S.DataService:Get(player)
	if not d then
		return nil
	end
	if slot == "spec" then
		if d.specialization ~= "" and table.find(Formulas.specializations(d), d.specialization) then
			return d.specialization
		end
		return nil
	end
	if type(slot) ~= "number" then
		return nil
	end
	local unlocked = Formulas.unlockedAbilities(d)
	return unlocked[slot]
end

function CombatService:Start()
	Net.event("CombatAction").OnServerEvent:Connect(function(player, slot, targetModel)
		if not limiter:check(player) then
			return
		end
		local pe = ES:ForPlayer(player)
		if not pe or pe.dead then
			return
		end
		local abilityId = self:ResolveAbility(player, slot)
		if not abilityId then
			return
		end
		local target = nil
		if typeof(targetModel) == "Instance" then
			target = ES:FromModel(targetModel)
		end
		if AbilityExecutor.needsTarget(abilityId) then
			if not (target and ES:Hostile(pe, target)) then
				-- automatisch nächstes Ziel in Reichweite
				target = ES:Nearest(pe.root.Position, AbilityExecutor.range(abilityId) + RANGE_TOLERANCE, function(o)
					return o.kind == "Wild"
				end)
			end
			if not target then
				return
			end
		end
		local ok = AbilityExecutor.execute(pe, abilityId, target, { rangeTolerance = RANGE_TOLERANCE })
		if ok and target and target.kind == "Wild" then
			pe.target = target
		end
	end)
end

return CombatService
