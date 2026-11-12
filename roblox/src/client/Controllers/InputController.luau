--!strict
-- Eingaben: Tastatur/Maus, Touch (über HUD-Knöpfe) und Gamepad.
-- Zielauswahl: Monster anklicken/antippen oder automatisch das nächste.
--
-- Tastenbelegung (PC):
--   Linksklick auf Monster  Ziel wählen      1      Grundangriff
--   2 / 3 / 4               Fähigkeiten       5      Spezialisierung
--   Tab                     nächstes Ziel     Q      Gefährten: Fokus aufs Ziel
--   F                       Gefährten-Spezial V      Gefährten: Einzigartig
--   G                       Modus wechseln    R      Gefährten zurückrufen
--   T                       Emoji-Rad         Z      Richtungspfeil setzen

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Abilities = require(Shared.Config.Abilities)
local Formulas = require(Shared.Formulas)
local State = require(script.Parent.Parent.State)

local player = Players.LocalPlayer
local combatEvent = Net.event("CombatAction")
local commandEvent = Net.event("CompanionCommand")

local MODES = { "Verteidigen", "Angriff", "Passiv" }

local InputController = {}
InputController.localCooldowns = {} :: { [string]: number }
InputController.ModeChanged = Instance.new("BindableEvent")

local function entitiesFolder(): Folder?
	return Workspace:FindFirstChild("Entities") :: Folder?
end

local function myRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isHostile(model: Model): boolean
	return model:GetAttribute("Kind") == "Wild" and (model:GetAttribute("HP") or 0) > 0
end

function InputController.nearestHostile(maxDist: number): Model?
	local root = myRoot()
	local folder = entitiesFolder()
	if not root or not folder then
		return nil
	end
	local best, bestD = nil, maxDist
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and isHostile(m) and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

function InputController.cycleTarget()
	local root = myRoot()
	local folder = entitiesFolder()
	if not root or not folder then
		return
	end
	local list = {}
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and isHostile(m) and m.PrimaryPart and (m.PrimaryPart.Position - root.Position).Magnitude < 60 then
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b)
		return (a.PrimaryPart.Position - root.Position).Magnitude < (b.PrimaryPart.Position - root.Position).Magnitude
	end)
	if #list == 0 then
		State.setTarget(nil)
		return
	end
	local idx = table.find(list, State.target :: any) or 0
	State.setTarget(list[(idx % #list) + 1])
end

local function currentTarget(range: number): Model?
	local t = State.target
	if t and t.Parent and isHostile(t) then
		return t
	end
	local n = InputController.nearestHostile(range + 6)
	State.setTarget(n)
	return n
end

function InputController.abilityForSlot(slot: any): string?
	local p = State.profile
	if not p then
		return nil
	end
	if slot == "spec" then
		return if p.specialization ~= "" then p.specialization else nil
	end
	return Formulas.unlockedAbilities(p)[slot]
end

function InputController.useAbility(slot: any)
	local id = InputController.abilityForSlot(slot)
	if not id then
		return
	end
	local def = Abilities[id]
	local now = os.clock()
	if (InputController.localCooldowns[id] or 0) > now then
		return
	end
	local target = currentTarget(def.range or 10)
	combatEvent:FireServer(slot, target)
	InputController.localCooldowns[id] = now + def.cooldown * 0.95
end

function InputController.companionAbility(slot: number)
	commandEvent:FireServer("ability", { slot = slot })
end

function InputController.focus()
	local t = currentTarget(40)
	if t then
		commandEvent:FireServer("focus", t)
	end
end

function InputController.cycleMode()
	local current = player:GetAttribute("CompanionMode") or "Verteidigen"
	local idx = table.find(MODES, current) or 1
	local nextMode = MODES[(idx % #MODES) + 1]
	commandEvent:FireServer("mode", nextMode)
	InputController.ModeChanged:Fire(nextMode)
end

function InputController.recall()
	commandEvent:FireServer("recall")
end

function InputController.init(handlers: { emoteWheel: () -> (), ping: () -> () })
	-- Klick/Tippen auf ein Monster wählt es als Ziel
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and not State.pingMode then
			local cam = Workspace.CurrentCamera
			local pos = input.Position
			local ray = cam:ViewportPointToRay(pos.X, pos.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			local folder = entitiesFolder()
			if folder then
				params.FilterDescendantsInstances = { folder }
				local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
				if hit then
					local model = hit.Instance:FindFirstAncestorOfClass("Model")
					while model and model.Parent ~= folder do
						model = model:FindFirstAncestorOfClass("Model")
					end
					if model and isHostile(model) then
						State.setTarget(model)
					end
				end
			end
		end
		if t ~= Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				InputController.useAbility(1)
			elseif input.KeyCode == Enum.KeyCode.ButtonX then
				InputController.useAbility(2)
			elseif input.KeyCode == Enum.KeyCode.ButtonY then
				InputController.useAbility(3)
			elseif input.KeyCode == Enum.KeyCode.ButtonB then
				InputController.companionAbility(2)
			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
				InputController.cycleTarget()
			elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
				InputController.focus()
			end
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.One then
			InputController.useAbility(1)
		elseif k == Enum.KeyCode.Two then
			InputController.useAbility(2)
		elseif k == Enum.KeyCode.Three then
			InputController.useAbility(3)
		elseif k == Enum.KeyCode.Four then
			InputController.useAbility(4)
		elseif k == Enum.KeyCode.Five then
			InputController.useAbility("spec")
		elseif k == Enum.KeyCode.Tab then
			InputController.cycleTarget()
		elseif k == Enum.KeyCode.Q then
			InputController.focus()
		elseif k == Enum.KeyCode.F then
			InputController.companionAbility(2)
		elseif k == Enum.KeyCode.V then
			InputController.companionAbility(4)
		elseif k == Enum.KeyCode.G then
			InputController.cycleMode()
		elseif k == Enum.KeyCode.R then
			InputController.recall()
		elseif k == Enum.KeyCode.T then
			handlers.emoteWheel()
		elseif k == Enum.KeyCode.Z then
			handlers.ping()
		end
	end)

	-- Ziel verwerfen, wenn es verschwindet oder zu weit weg ist
	task.spawn(function()
		while true do
			task.wait(0.5)
			local t = State.target
			local root = myRoot()
			if t then
				if not t.Parent or not isHostile(t) or (root and t.PrimaryPart and (t.PrimaryPart.Position - root.Position).Magnitude > 120) then
					State.setTarget(nil)
				end
			end
		end
	end)
end

return InputController
