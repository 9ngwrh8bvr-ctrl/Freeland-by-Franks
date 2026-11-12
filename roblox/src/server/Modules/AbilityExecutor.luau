--!strict
-- Führt Fähigkeiten aus – für Spieler, Gefährten und wilde Monster gleich.
-- Heilung und Schilde: power = Prozent der max. Lebenspunkte des Ziels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Config.Abilities)

local AbilityExecutor = {}
local ES: any = nil

function AbilityExecutor.init(entityService: any)
	ES = entityService
end

function AbilityExecutor.needsTarget(abilityId: string): boolean
	local def = Abilities[abilityId]
	if not def then
		return false
	end
	local k = def.kind
	return k == "Damage" or k == "Stun" or k == "Debuff" or k == "Dash" or (k == "Area" and not def.selfCentered)
end

function AbilityExecutor.isReady(source: any, abilityId: string): boolean
	return (source.cooldowns[abilityId] or 0) <= os.clock()
end

function AbilityExecutor.range(abilityId: string): number
	local def = Abilities[abilityId]
	if not def then
		return 0
	end
	if def.range then
		return def.range
	end
	if def.selfCentered and def.radius then
		return def.radius * 0.8
	end
	return 8
end

local function face(source: any, pos: Vector3)
	if source.kind == "Player" then
		return -- Spieler steuern ihre Blickrichtung selbst
	end
	local from = source.root.Position
	local flat = Vector3.new(pos.X, from.Y, pos.Z)
	if (flat - from).Magnitude > 0.1 then
		source.root.CFrame = CFrame.lookAt(from, flat)
	end
end

local function allies(source: any, radius: number): { any }
	return ES:InRadius(source.root.Position, radius, function(o)
		return o.team == source.team
	end)
end

export type ExecOpts = { rangeTolerance: number? }

function AbilityExecutor.execute(source: any, abilityId: string, target: any?, opts: ExecOpts?): (boolean, string?)
	local def = Abilities[abilityId]
	if not def then
		return false, "Unbekannte Fähigkeit"
	end
	if source.dead then
		return false, "tot"
	end
	if ES:IsStunned(source) then
		return false, "Betäubt"
	end
	local t = os.clock()
	if (source.cooldowns[abilityId] or 0) > t then
		return false, "Abklingzeit"
	end
	local tolerance = if opts and opts.rangeTolerance then opts.rangeTolerance else 0

	if AbilityExecutor.needsTarget(abilityId) then
		if not target or not ES:IsAlive(target) or not ES:Hostile(source, target) then
			return false, "Kein Ziel"
		end
		if ES:Distance(source, target) > AbilityExecutor.range(abilityId) + tolerance then
			return false, "Zu weit entfernt"
		end
	end

	local cdPct = math.clamp(source.mods.cooldownPct or 0, 0, 0.5)
	source.cooldowns[abilityId] = t + def.cooldown * (1 - cdPct)

	local fxPos: Vector3? = nil
	local kind = def.kind
	local tgt = target :: any

	if kind == "Damage" then
		face(source, tgt.root.Position)
		ES:DealDamage(source, tgt, def.power or 10, { element = def.element, executeBonus = def.executeBonus })
	elseif kind == "Area" then
		local center = if def.selfCentered or not tgt then source.root.Position else tgt.root.Position
		if tgt then
			face(source, tgt.root.Position)
		end
		fxPos = center
		for _, e in ES:InRadius(center, def.radius or 8, function(o)
			return ES:Hostile(source, o)
		end) do
			ES:DealDamage(source, e, def.power or 10, { element = def.element })
		end
	elseif kind == "Heal" then
		for _, e in allies(source, def.radius or 20) do
			ES:Heal(source, e, e.maxHp * (def.power or 20) / 100)
		end
	elseif kind == "Buff" then
		local list = if def.targets == "allies" then allies(source, def.radius or 25) else { source }
		for _, e in list do
			ES:AddBuff(e, def.stat or "atk", def.amount or 0.2, def.duration or 8, abilityId)
		end
	elseif kind == "Debuff" then
		face(source, tgt.root.Position)
		if def.power and def.power > 0 then
			ES:DealDamage(source, tgt, def.power, { element = def.element })
		end
		ES:AddBuff(tgt, def.stat or "def", -(def.amount or 0.2), def.duration or 8, abilityId)
	elseif kind == "Taunt" then
		ES:Taunt(source, def.radius or 12, def.duration or 5)
	elseif kind == "Stealth" then
		ES:SetStealth(source, def.duration or 3)
	elseif kind == "Shield" then
		local list = if def.targets == "allies" then allies(source, def.radius or 25) else { source }
		for _, e in list do
			ES:AddShield(e, e.maxHp * (def.power or 30) / 100, def.duration or 8)
		end
	elseif kind == "Stun" then
		face(source, tgt.root.Position)
		if def.power and def.power > 0 then
			ES:DealDamage(source, tgt, def.power, { element = def.element })
		end
		if ES:IsAlive(tgt) then
			ES:Stun(tgt, def.duration or 1.5)
		end
	elseif kind == "Dash" then
		local tp = tgt.root.Position
		local from = source.root.Position
		local dir = (Vector3.new(tp.X, from.Y, tp.Z) - from)
		dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
		local dest = tp - dir * (ES:Radius(tgt) + ES:Radius(source) + 1)
		local cf = CFrame.lookAt(Vector3.new(dest.X, from.Y, dest.Z), Vector3.new(tp.X, from.Y, tp.Z))
		source.model:PivotTo(cf)
		ES:DealDamage(source, tgt, def.power or 30, { element = def.element })
	end

	ES:Fx(abilityId, source, tgt, fxPos)
	return true, nil
end

return AbilityExecutor
