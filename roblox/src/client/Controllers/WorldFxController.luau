--!strict
-- Anzeigen in der Welt: Namens-/LP-Leisten über Monstern, Zielmarkierung,
-- Schadenszahlen, Fähigkeitseffekte, Fang-Effekte, Tarnung.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Abilities = require(Shared.Config.Abilities)
local Elements = require(Shared.Config.Elements)
local Rarities = require(Shared.Config.Rarities)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Parent.UI.Kit)

local T = Kit.Theme
local player = Players.LocalPlayer
local fxFolder: Folder

local WorldFxController = {}

------------------------------------------------------------------------
-- Leisten über Monstern
------------------------------------------------------------------------
local function setupEntity(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	local isMine = model:GetAttribute("OwnerUserId") == player.UserId
	local kind = model:GetAttribute("Kind")
	local bb = Kit.new("BillboardGui", {
		Name = "Bar",
		Adornee = root,
		Size = UDim2.fromOffset(150, 40),
		StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 2.2, 0),
		MaxDistance = 110,
		LightInfluence = 0,
		Parent = model,
	})
	local rarity = Rarities.List[model:GetAttribute("Rarity") or "Gewoehnlich"]
	local el = Elements.List[model:GetAttribute("Element") or "Neutral"]
	local name = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = T.FontBold,
		TextSize = 14,
		TextStrokeTransparency = 0.4,
		TextColor3 = if isMine then T.Good else (rarity and rarity.color or T.Text),
		Parent = bb,
	})
	local barBg = Kit.new("Frame", {
		Position = UDim2.new(0.1, 0, 0, 22),
		Size = UDim2.new(0.8, 0, 0, 8),
		BackgroundColor3 = Color3.fromRGB(20, 16, 26),
		Parent = bb,
	}, { Kit.corner(4) })
	local fill = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if kind == "Wild" then T.Hp else T.Good,
		Parent = barBg,
	}, { Kit.corner(4) })
	local shield = Kit.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(140, 200, 255),
		BackgroundTransparency = 0.2,
		Parent = barBg,
	}, { Kit.corner(4) })

	local function refresh()
		local hp, max = model:GetAttribute("HP") or 0, model:GetAttribute("MaxHP") or 1
		fill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
		shield.Size = UDim2.fromScale(math.clamp((model:GetAttribute("Shield") or 0) / max, 0, 1), 1)
		local prefix = if model:GetAttribute("Boss") then "👹 " elseif isMine then "💚 " else ""
		name.Text = ("%s%s %s Lv %d"):format(prefix, el and el.icon or "", model:GetAttribute("DisplayName") or "?", model:GetAttribute("Level") or 1)
		if kind == "Wild" and model:GetAttribute("Capturable") and hp / max <= 0.35 and hp > 0 then
			fill.BackgroundColor3 = T.Gold
		end
	end
	refresh()
	model:GetAttributeChangedSignal("HP"):Connect(refresh)
	model:GetAttributeChangedSignal("MaxHP"):Connect(refresh)
	model:GetAttributeChangedSignal("Shield"):Connect(refresh)
	model:GetAttributeChangedSignal("Level"):Connect(refresh)
	model:GetAttributeChangedSignal("DisplayName"):Connect(refresh)
	model:GetAttributeChangedSignal("Stealthed"):Connect(function()
		local hidden = model:GetAttribute("Stealthed") == true
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.LocalTransparencyModifier = if hidden then 0.75 else 0
			end
		end
	end)
end

------------------------------------------------------------------------
-- Effekte
------------------------------------------------------------------------
local function fadePart(p: BasePart, duration: number, grow: Vector3?)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	task.delay(duration + 0.05, function()
		p:Destroy()
	end)
end

local function burst(pos: Vector3, color: Color3, radius: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.35
	p.Size = Vector3.one * 1
	p.Position = pos
	fadePart(p, 0.45, Vector3.one * radius * 2)
end

local function beam(from: Vector3, to: Vector3, color: Color3)
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local p = Instance.new("Part")
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.35, 0.35, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Transparency = 0.1
	fadePart(p, 0.25)
end

local function damageNumber(model: Instance, amount: number, kind: string, mult: number)
	if not model or not model:IsA("Model") or not model.PrimaryPart then
		return
	end
	local root = model.PrimaryPart
	local color = if kind == "heal" then T.Good elseif kind == "crit" then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(255, 255, 255)
	local text = if kind == "heal" then "+" .. amount else tostring(amount)
	if kind == "crit" then
		text ..= "!"
	end
	if mult > 1.01 then
		text ..= " ▲"
	elseif mult < 0.99 then
		text ..= " ▼"
	end
	local anchor = Instance.new("Part")
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = root.Position + Vector3.new(math.random(-10, 10) / 10, root.Size.Y / 2 + 1, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Parent = fxFolder
	local bb = Kit.new("BillboardGui", { Size = UDim2.fromOffset(120, 40), AlwaysOnTop = true, Adornee = anchor, Parent = anchor })
	local label = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		Font = Enum.Font.GothamBlack,
		TextSize = if kind == "crit" then 28 else 20,
		Parent = bb,
	})
	TweenService:Create(anchor, TweenInfo.new(0.9), { Position = anchor.Position + Vector3.new(0, 3.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

local function abilityFx(abilityId: string, source: Instance?, target: Instance?, pos: Vector3?)
	local def = Abilities[abilityId]
	if not def then
		return
	end
	local el = Elements.List[def.element] or Elements.List.Neutral
	local color = el.color
	local srcPos = if source and source:IsA("Model") and source.PrimaryPart then source.PrimaryPart.Position else pos
	local tgtPos = if target and target:IsA("Model") and target.PrimaryPart then target.PrimaryPart.Position else pos
	local kind = def.kind
	if kind == "Damage" or kind == "Stun" or kind == "Debuff" then
		if srcPos and tgtPos then
			beam(srcPos, tgtPos, color)
			burst(tgtPos, color, 1.5)
		end
	elseif kind == "Area" then
		if pos then
			burst(pos, color, def.radius or 8)
		end
	elseif kind == "Heal" then
		if srcPos then
			burst(srcPos, Color3.fromRGB(120, 255, 140), def.radius or 15)
		end
	elseif kind == "Buff" or kind == "Taunt" then
		if srcPos then
			burst(srcPos, if kind == "Taunt" then Color3.fromRGB(255, 80, 60) else Color3.fromRGB(255, 220, 90), def.radius or 6)
		end
	elseif kind == "Shield" then
		if srcPos then
			burst(srcPos, Color3.fromRGB(140, 200, 255), 5)
		end
	elseif kind == "Dash" then
		if srcPos and tgtPos then
			beam(tgtPos, srcPos, color)
			burst(tgtPos, color, 3)
		end
	elseif kind == "Stealth" then
		if srcPos then
			burst(srcPos, Color3.fromRGB(80, 40, 120), 4)
		end
	end
end

------------------------------------------------------------------------
-- Zielmarkierung
------------------------------------------------------------------------
local highlight: Highlight

local function onTarget(model: Model?)
	highlight.Adornee = model
	highlight.Enabled = model ~= nil
end

function WorldFxController.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFx"
	fxFolder.Parent = Workspace

	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 80, 60)
	highlight.Enabled = false
	highlight.Parent = fxFolder
	State.TargetChanged.Event:Connect(onTarget)

	local entities = Workspace:WaitForChild("Entities")
	entities.ChildAdded:Connect(function(m)
		task.spawn(setupEntity, m)
	end)
	for _, m in entities:GetChildren() do
		task.spawn(setupEntity, m)
	end

	Net.event("DamageNumber").OnClientEvent:Connect(damageNumber)
	Net.event("AbilityFx").OnClientEvent:Connect(abilityFx)
	Net.event("CaptureResult").OnClientEvent:Connect(function(success, pos)
		if typeof(pos) ~= "Vector3" then
			return
		end
		if success then
			for i = 1, 3 do
				task.delay(i * 0.12, function()
					burst(pos, Color3.fromRGB(255, 230, 120), 3 + i * 2)
				end)
			end
		else
			burst(pos, Color3.fromRGB(255, 70, 70), 4)
		end
	end)
end

return WorldFxController
