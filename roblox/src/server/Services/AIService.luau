--!strict
-- KI der wilden Monster und Bosse: Umherstreifen, Angriff (je nach Temperament),
-- Bedrohungsliste, Spott, Rückkehr zum Revier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Monsters = require(Shared.Config.Monsters)
local Abilities = require(Shared.Config.Abilities)
local AbilityExecutor = require(script.Parent.Parent.Modules.AbilityExecutor)

local TICK = 0.3

local AIService = {}
local ES: any

function AIService:Init(services)
	ES = services.EntityService
end

local function chooseTarget(e: any): any?
	local t = os.clock()
	if e.tauntTarget and e.tauntUntil > t and ES:IsAlive(e.tauntTarget) then
		return e.tauntTarget
	end
	local best, bestThreat = nil, 0
	for other, threat in e.threat do
		if
			not ES:IsAlive(other)
			or ES:IsStealthed(other)
			or (other.root.Position - e.spawnPos).Magnitude > GameConfig.LeashDistance + 25
		then
			e.threat[other] = nil
		elseif threat > bestThreat then
			best, bestThreat = other, threat
		end
	end
	if best then
		return best
	end
	local sp = Monsters[e.speciesId]
	if sp.temper == "aggressive" and sp.aggroRange > 0 then
		local found = ES:Nearest(e.root.Position, sp.aggroRange, function(o)
			return o.team == "Players" and not ES:IsStealthed(o)
		end)
		if found then
			e.threat[found] = 1
		end
		return found
	end
	return nil
end

-- Spezialfähigkeiten: wilde Monster nutzen [2] und [3], ab Level 20 und Bosse auch [4]
local function trySpecial(e: any, target: any): boolean
	local sp = Monsters[e.speciesId]
	local maxSlot = if e.isBoss or e.level >= 20 then 4 else 3
	for slot = 2, maxSlot do
		local id = sp.abilities[slot]
		local def = Abilities[id]
		if def and AbilityExecutor.isReady(e, id) then
			local use
			if def.kind == "Heal" then
				use = e.hp / e.maxHp < 0.5
			elseif def.kind == "Buff" or def.kind == "Shield" or def.kind == "Stealth" or def.kind == "Taunt" then
				use = true
			else
				use = ES:Distance(e, target) <= AbilityExecutor.range(id)
			end
			if use and math.random() < 0.6 then
				local ok = AbilityExecutor.execute(e, id, target)
				if ok then
					return true
				end
			end
		end
	end
	return false
end

local function tick(e: any)
	if e.dead or ES:IsStunned(e) then
		return
	end
	local st = e.state
	local pos = e.root.Position

	-- Rückkehr ins Revier
	if st.returning then
		if (pos - e.spawnPos).Magnitude < 6 then
			st.returning = false
			ES:SetFullHp(e)
		else
			e.humanoid:MoveTo(e.spawnPos)
			return
		end
	end
	if (pos - e.spawnPos).Magnitude > GameConfig.LeashDistance then
		st.returning = true
		e.threat = {}
		e.target = nil
		e.damagedBy = {}
		e.companionsInvolved = {}
		ES:SetFullHp(e)
		-- weit weg oder heruntergefallen (z. B. vom Drachenhorst) → zurückteleportieren
		if math.abs(pos.Y - e.spawnPos.Y) > 8 or (pos - e.spawnPos).Magnitude > GameConfig.LeashDistance * 1.4 then
			e.model:PivotTo(CFrame.new(e.spawnPos))
		end
		local prompt = e.root:FindFirstChild("CapturePrompt") :: ProximityPrompt?
		if prompt then
			prompt.Enabled = false
		end
		e.humanoid:MoveTo(e.spawnPos)
		return
	end

	local target = chooseTarget(e)
	e.target = target
	if target then
		if trySpecial(e, target) then
			return
		end
		local basic = Monsters[e.speciesId].abilities[1]
		local range = AbilityExecutor.range(basic)
		if ES:Distance(e, target) <= range then
			e.humanoid:MoveTo(pos)
			AbilityExecutor.execute(e, basic, target)
		else
			e.humanoid:MoveTo(target.root.Position)
		end
		return
	end

	-- Umherstreifen
	local t = os.clock()
	if not st.nextWander or t >= st.nextWander then
		st.nextWander = t + 4 + math.random() * 5
		local angle = math.random() * math.pi * 2
		local r = math.random() * 16
		e.humanoid:MoveTo(e.spawnPos + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
	end
end

function AIService:Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, e in ES:All() do
				if e.kind == "Wild" then
					local ok, err = pcall(tick, e)
					if not ok then
						warn("[AIService]", err)
					end
				end
			end
		end
	end)
end

return AIService
