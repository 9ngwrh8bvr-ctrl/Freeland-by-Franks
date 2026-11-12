--!strict
-- Erkundung auf dem Client:
--   * geöffnete Tore lokal öffnen (jeder Spieler braucht eigene Monsterfähigkeiten)
--   * verborgene Runen nur sichtbar, wenn ein eigener Gefährte "Runensicht" hat

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Monsters = require(Shared.Config.Monsters)

local player = Players.LocalPlayer

local ExplorationController = {}

local function hasSummonedTrait(trait: string): boolean
	local folder = Workspace:FindFirstChild("Entities")
	if not folder then
		return false
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("OwnerUserId") == player.UserId then
			local sp = Monsters[m:GetAttribute("SpeciesId") or ""]
			if sp and table.find(sp.traits, trait) then
				return true
			end
		end
	end
	return false
end

local function onGateOpened(gate: Instance, action: string)
	if not gate or not gate:IsA("BasePart") then
		return
	end
	if action == "Open" then
		gate.CanCollide = false
		TweenService:Create(gate, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	elseif action == "Light" then
		gate.CanCollide = false
		TweenService:Create(gate, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		local ref = gate:FindFirstChild("Lights") :: ObjectValue?
		if ref and ref.Value then
			for _, d in ref.Value:GetDescendants() do
				if d:IsA("Light") then
					d.Enabled = true
				elseif d:IsA("BasePart") then
					d.Material = Enum.Material.Neon
				end
			end
		end
		local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	elseif action == "Grow" then
		TweenService:Create(gate, TweenInfo.new(1), { Color = Color3.fromRGB(80, 170, 80) }):Play()
		local crown = Instance.new("Part")
		crown.Shape = Enum.PartType.Ball
		crown.Anchored = true
		crown.CanCollide = false
		crown.Material = Enum.Material.Grass
		crown.Color = Color3.fromRGB(90, 190, 90)
		crown.Size = Vector3.one * 1
		crown.Position = gate.Position + Vector3.new(0, gate.Size.Y / 2 + 2, 0)
		crown.Parent = gate
		TweenService:Create(crown, TweenInfo.new(1.2, Enum.EasingStyle.Back), { Size = Vector3.one * 8 }):Play()
	end
end

function ExplorationController.init()
	Net.event("GateOpened").OnClientEvent:Connect(onGateOpened)

	-- verborgene Runen ein-/ausblenden
	task.spawn(function()
		while true do
			task.wait(0.75)
			local visible = hasSummonedTrait("Runensicht")
			for _, rune in CollectionService:GetTagged("HiddenRune") do
				if rune:IsA("BasePart") then
					rune.LocalTransparencyModifier = 0
					rune.Transparency = if visible then 0.15 else 1
					local prompt = rune:FindFirstChildOfClass("ProximityPrompt")
					if prompt then
						prompt.Enabled = visible
					end
				end
			end
		end
	end)
end

return ExplorationController
