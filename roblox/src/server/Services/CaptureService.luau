--!strict
-- Fangen über das "Vertrauensritual" (eigene Mechanik, kein Werfen von
-- Fanggegenständen): Monster schwächen, dann nahe herangehen und die
-- Ritual-Taste gedrückt halten. Köder im Inventar erhöhen die Chance.
-- Legendäre Monster brauchen zusätzlich eine bestandene Prüfung (Quest-Flag).
-- Bossmonster sind nicht fangbar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Monsters = require(Shared.Config.Monsters)
local Items = require(Shared.Config.Items)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)
local Notifier = require(script.Parent.Parent.Modules.Notifier)

local CaptureService = {}
local S: any
local ES: any
local cooldown: { [Player]: number } = {}
local resultEvent: RemoteEvent

function CaptureService:Init(services)
	S = services
	ES = services.EntityService
	resultEvent = Net.event("CaptureResult")
end

-- Bester Köder im Inventar für dieses Element
local function bestLure(player: Player, element: string): (string?, number)
	local d = S.DataService:Get(player)
	if not d then
		return nil, 0
	end
	local best, bonus = nil, 0
	for itemId, count in d.inventory do
		local it = Items[itemId]
		if count > 0 and it and it.category == "lure" then
			local b = 0
			if it.lureElement == nil or it.lureElement == element then
				b = it.captureBonus or 0
			end
			if b > bonus then
				best, bonus = itemId, b
			end
		end
	end
	return best, bonus
end

function CaptureService:Attempt(player: Player, e: any)
	local d = S.DataService:Get(player)
	local pe = ES:ForPlayer(player)
	if not d or not pe or pe.dead or not ES:IsAlive(e) or e.kind ~= "Wild" then
		return
	end
	local sp = Monsters[e.speciesId]
	if not sp.capture.capturable then
		Notifier.send(player, ("%s lässt sich nicht fangen."):format(sp.name), "bad")
		return
	end
	if (cooldown[player] or 0) > os.clock() then
		return
	end
	if (pe.root.Position - e.root.Position).Magnitude > 18 then
		return
	end
	local hpPct = e.hp / e.maxHp
	if hpPct > GameConfig.CaptureHpThreshold then
		Notifier.send(player, "Das Monster ist noch zu stark. Schwäche es zuerst!", "bad")
		return
	end
	if sp.capture.requiresFlag and not d.flags[sp.capture.requiresFlag] then
		Notifier.send(player, sp.capture.note or "Du musst zuerst eine Prüfung bestehen.", "bad")
		return
	end
	if sp.capture.requiresLevel and d.level < sp.capture.requiresLevel then
		Notifier.send(player, ("Benötigt Charakterlevel %d."):format(sp.capture.requiresLevel), "bad")
		return
	end
	if S.CompanionService:StorageUsed(player) >= S.CompanionService:StorageCap(player) then
		Notifier.send(player, "Dein Gehege ist voll! Lass Monster frei oder erweitere es im Shop.", "bad")
		return
	end

	local lure, lureBonus = bestLure(player, sp.element)
	if lure then
		S.InventoryService:RemoveItem(player, lure, 1)
	end
	local talentBonus = Formulas.aggregateMods(d).captureBonus or 0
	local chance = Formulas.captureChance(e.speciesId, hpPct, e.level - d.level, lureBonus, talentBonus)

	if math.random() < chance then
		local level = e.level
		local name = Formulas.stageName(e.speciesId, level)
		local pos = e.root.Position
		ES:Remove(e)
		local uid = S.CompanionService:CreateRecord(player, e.speciesId, level)
		d.stats.captures += 1
		S.ProgressionService:AddPlayerXp(player, sp.xp * 0.5)
		S.QuestService:Event(player, "capture", { species = e.speciesId })
		Notifier.send(player, ("🤝 %s vertraut dir jetzt! (Chance war %d %%)"):format(name, math.floor(chance * 100)), "epic")
		resultEvent:FireClient(player, true, pos, e.speciesId, uid)
	else
		cooldown[player] = os.clock() + GameConfig.CaptureFailCooldown
		e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.15)
		e.model:SetAttribute("HP", math.floor(e.hp))
		e.threat[pe] = (e.threat[pe] or 0) + 50
		Notifier.send(player, ("Das Ritual misslang (Chance %d %%). Versuche es erneut!"):format(math.floor(chance * 100)), "bad")
		resultEvent:FireClient(player, false, e.root.Position, e.speciesId, nil)
		self:UpdatePrompt(e)
	end
end

function CaptureService:UpdatePrompt(e: any)
	local prompt = e.root:FindFirstChild("CapturePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = not e.dead and e.hp / e.maxHp <= GameConfig.CaptureHpThreshold
	end
end

function CaptureService:Start()
	ES:OnSpawned(function(e)
		if e.kind ~= "Wild" then
			return
		end
		local sp = Monsters[e.speciesId]
		if not sp.capture.capturable then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CapturePrompt"
		prompt.ActionText = "Vertrauensritual"
		prompt.ObjectText = Formulas.stageName(e.speciesId, e.level)
		prompt.HoldDuration = GameConfig.CaptureRitualDuration
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Enabled = false
		prompt.Parent = e.root
		prompt.Triggered:Connect(function(player)
			self:Attempt(player, e)
		end)
		e.model:SetAttribute("Capturable", true)
	end)
	ES:OnDamaged(function(e)
		if e.kind == "Wild" then
			self:UpdatePrompt(e)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		cooldown[p] = nil
	end)
end

return CaptureService
