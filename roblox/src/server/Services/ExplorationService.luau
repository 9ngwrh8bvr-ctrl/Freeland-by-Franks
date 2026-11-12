--!strict
-- Erkundung mit Monsterfähigkeiten, Trainingsplätze und Rastplätze.
--
-- Erkundungstore: Part mit Tag "ExploreGate" und Attributen
--   GateId       (string) – eindeutig
--   Trait        (string) – benötigte Fähigkeit ("" = keine), siehe Monsters.luau
--   Action       (string) – "Open" | "Teleport" | "Loot" | "Light" | "Grow"
--   Reward       (string) – optional, z. B. "coins:80,Heiltrank:2,gems:5"
--   RequiresGate (string) – optional, Tor muss in dieser Sitzung geöffnet sein
--   Label        (string) – optional, Text am Prompt
--   Für Teleport: ObjectValue "Target" als Kind des Parts (Ziel-Part)
--   Für Light:    ObjectValue "Lights" → Ordner mit Lichtern (lokal eingeschaltet)
--
-- Trainingsplatz: Tag "TrainingSpot"   – Bindungs- und Monster-EP
-- Rastplatz:      Tag "RestSpot"       – heilt Spieler und Gefährten

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Monsters = require(Shared.Config.Monsters)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Notifier = require(script.Parent.Parent.Modules.Notifier)

local TRAIT_RANGE = 45 -- Gefährte mit der Fähigkeit muss in der Nähe sein

local TRAIT_VERB = {
	Fliegen = "Fliegen",
	Schwimmen = "Tauchen",
	Klein = "Spalt erkunden",
	Zerschmettern = "Zerschmettern",
	Runensicht = "Rune lesen",
	Leuchten = "Erhellen",
	Wachstum = "Erblühen lassen",
}

local ExplorationService = {}
local S: any
local opened: { [Player]: { [string]: boolean } } = {}
local lastTraining: { [Player]: number } = {}
local gateEvent: RemoteEvent

function ExplorationService:Init(services)
	S = services
	gateEvent = Net.event("GateOpened")
end

local function speciesWithTrait(trait: string): string
	local names = {}
	for _, sp in Monsters do
		if table.find(sp.traits, trait) and sp.capture.capturable then
			table.insert(names, sp.name)
		end
	end
	table.sort(names)
	return table.concat(names, ", ")
end

local function grantReward(player: Player, reward: string)
	local parts = {}
	for _, entry in string.split(reward, ",") do
		local kv = string.split(entry, ":")
		local k, n = kv[1], tonumber(kv[2]) or 1
		if k == "coins" then
			S.InventoryService:AddCoins(player, n, true)
			table.insert(parts, ("%d Münzen"):format(n))
		elseif k == "gems" then
			S.InventoryService:AddGems(player, n)
			table.insert(parts, ("%d Edelsteine"):format(n))
		elseif Items[k] then
			S.InventoryService:AddItem(player, k, n)
			table.insert(parts, ("%d× %s"):format(n, Items[k].name))
		end
	end
	if #parts > 0 then
		Notifier.send(player, "🎁 Gefunden: " .. table.concat(parts, ", "), "good")
	end
end

function ExplorationService:UseGate(player: Player, gate: BasePart)
	local d = S.DataService:Get(player)
	local pe = S.EntityService:ForPlayer(player)
	if not d or not pe or pe.dead then
		return
	end
	if (pe.root.Position - gate.Position).Magnitude > 25 + gate.Size.Magnitude / 2 then
		return
	end
	local gateId = gate:GetAttribute("GateId") or gate:GetFullName()
	local trait = gate:GetAttribute("Trait") or ""
	local action = gate:GetAttribute("Action") or "Open"
	local requiresGate = gate:GetAttribute("RequiresGate")
	local sessionOpened = opened[player] or {}
	opened[player] = sessionOpened

	if requiresGate and requiresGate ~= "" and not sessionOpened[requiresGate] and not d.gates[requiresGate] then
		Notifier.send(player, "Der Weg hierher ist noch versperrt.", "bad")
		return
	end

	local companion = nil
	if trait ~= "" then
		companion = S.CompanionService:GetSummonedWithTrait(player, trait, TRAIT_RANGE)
		if not companion then
			Notifier.send(
				player,
				("Hier brauchst du einen Gefährten mit „%s“ (z. B. %s)."):format(trait, speciesWithTrait(trait)),
				"bad"
			)
			return
		end
	end

	local firstTime = not d.gates[gateId]

	if action == "Teleport" then
		local targetRef = gate:FindFirstChild("Target") :: ObjectValue?
		local target = targetRef and targetRef.Value :: BasePart?
		if target then
			pe.model:PivotTo(target.CFrame + Vector3.new(0, 4, 0))
			for _, ce in S.CompanionService:GetSummoned(player) do
				ce.model:PivotTo(target.CFrame * CFrame.new(math.random(-4, 4), 4, 4))
			end
		end
	elseif action == "Loot" then
		if not firstTime then
			Notifier.send(player, "Hier hast du schon alles gefunden.", "info")
			return
		end
	end

	sessionOpened[gateId] = true
	gateEvent:FireClient(player, gate, action)

	if firstTime then
		d.gates[gateId] = true
		local reward = gate:GetAttribute("Reward")
		if reward and reward ~= "" then
			grantReward(player, reward)
		end
		if companion and companion.uid then
			S.ProgressionService:AddBondXp(player, companion.uid, GameConfig.BondXp.ExploreGate, "Erkundung")
			S.ProgressionService:AddMonsterXp(player, companion.uid, 40)
		end
		if trait ~= "" then
			S.QuestService:Event(player, "useTrait", { trait = trait })
		end
		S.ProgressionService:AddPlayerXp(player, 40)
		S.DataService:MarkDirty(player)
	end
end

function ExplorationService:Train(player: Player)
	local t = os.clock()
	if (lastTraining[player] or -math.huge) + GameConfig.TrainingCooldown > t then
		local left = math.ceil(lastTraining[player] + GameConfig.TrainingCooldown - t)
		Notifier.send(player, ("Deine Gefährten brauchen noch %d s Pause."):format(left), "info")
		return
	end
	local summoned = S.CompanionService:GetSummoned(player)
	if next(summoned) == nil then
		Notifier.send(player, "Du hast keinen Gefährten dabei.", "bad")
		return
	end
	lastTraining[player] = t
	for uid in summoned do
		S.ProgressionService:AddBondXp(player, uid, GameConfig.BondXp.Training, "Training")
		S.ProgressionService:AddMonsterXp(player, uid, 25)
	end
	S.QuestService:Event(player, "train", {})
	Notifier.send(player, "🏋️ Training abgeschlossen! Bindung gestärkt.", "good")
end

function ExplorationService:Rest(player: Player)
	local d = S.DataService:Get(player)
	local pe = S.EntityService:ForPlayer(player)
	if not d or not pe then
		return
	end
	S.EntityService:SetFullHp(pe)
	for _, rec in d.monsters do
		rec.exhaustedUntil = 0
	end
	for _, ce in S.CompanionService:GetSummoned(player) do
		S.EntityService:SetFullHp(ce)
	end
	S.DataService:MarkDirty(player)
	Notifier.send(player, "🔥 Ausgeruht! Alle Gefährten sind wieder fit.", "good")
end

local function makePrompt(part: BasePart, action: string, object: string, hold: number): ProximityPrompt
	local existing = part:FindFirstChild("ExplorePrompt") :: ProximityPrompt?
	if existing then
		return existing
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExplorePrompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function ExplorationService:Start()
	local function setupGate(gate: Instance)
		if not gate:IsA("BasePart") then
			return
		end
		local trait = gate:GetAttribute("Trait") or ""
		local label = gate:GetAttribute("Label")
		local actionText = if trait ~= "" then (TRAIT_VERB[trait] or trait) else (label or "Benutzen")
		local prompt = makePrompt(gate, actionText, label or (if trait ~= "" then "Benötigt: " .. trait else ""), 0.6)
		prompt.Triggered:Connect(function(player)
			self:UseGate(player, gate)
		end)
	end
	for _, g in CollectionService:GetTagged("ExploreGate") do
		setupGate(g)
	end
	CollectionService:GetInstanceAddedSignal("ExploreGate"):Connect(setupGate)

	local function setupTraining(part: Instance)
		if part:IsA("BasePart") then
			makePrompt(part, "Trainieren", "Trainingsplatz", 1).Triggered:Connect(function(player)
				self:Train(player)
			end)
		end
	end
	for _, p in CollectionService:GetTagged("TrainingSpot") do
		setupTraining(p)
	end
	CollectionService:GetInstanceAddedSignal("TrainingSpot"):Connect(setupTraining)

	local function setupRest(part: Instance)
		if part:IsA("BasePart") then
			makePrompt(part, "Ausruhen", "Rastplatz", 1).Triggered:Connect(function(player)
				self:Rest(player)
			end)
		end
	end
	for _, p in CollectionService:GetTagged("RestSpot") do
		setupRest(p)
	end
	CollectionService:GetInstanceAddedSignal("RestSpot"):Connect(setupRest)

	Players.PlayerRemoving:Connect(function(p)
		opened[p] = nil
		lastTraining[p] = nil
	end)
end

return ExplorationService
