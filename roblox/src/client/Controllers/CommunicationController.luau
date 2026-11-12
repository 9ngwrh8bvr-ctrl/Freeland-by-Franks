--!strict
-- Kommunikation ohne Chat:
--   * Emoji-Rad: vordefinierte Emojis erscheinen über dem Kopf
--   * Richtungspfeile: Marker in der Welt setzen; für alle Spieler in der
--     Nähe zeigt ein Pfeil am Bildschirmrand in die Richtung des Markers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local Communication = require(Shared.Config.Communication)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Parent.UI.Kit)

local T = Kit.Theme
local player = Players.LocalPlayer
local emoteEvent = Net.event("Emote")
local pingEvent = Net.event("Ping")

local CommunicationController = {}

local wheel: Frame
local pingBar: Frame
local edgeLayer: Frame
local selectedPing = "hierher"
local activePings: { { part: BasePart, arrow: TextLabel, expires: number } } = {}
local markerFolder: Folder

------------------------------------------------------------------------
-- Emojis
------------------------------------------------------------------------
local function showEmote(who: Player, emojiId: string)
	local emoji = Communication.findEmoji(emojiId)
	local head = who.Character and who.Character:FindFirstChild("Head") :: BasePart?
	if not emoji or not head then
		return
	end
	local old = head:FindFirstChild("EmoteBubble")
	if old then
		old:Destroy()
	end
	local bb = Kit.new("BillboardGui", {
		Name = "EmoteBubble",
		Adornee = head,
		Size = UDim2.fromOffset(70, 70),
		StudsOffset = Vector3.new(0, 3.2, 0),
		MaxDistance = 120,
		Parent = head,
	})
	local label = Kit.new("TextLabel", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Text = emoji.glyph,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = bb,
	}, { Kit.corner(35) })
	label.Size = UDim2.fromScale(0.2, 0.2)
	label.Position = UDim2.fromScale(0.4, 0.4)
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }):Play()
	task.delay(GameConfig.EmoteDuration, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

local function buildWheel(gui: ScreenGui)
	wheel = Kit.new("Frame", {
		Name = "EmojiWheel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		Visible = false,
		Parent = gui,
	}, { Kit.corner(14), Kit.stroke(), Kit.padding(10) })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(58, 58), CellPadding = UDim2.fromOffset(6, 6), Parent = wheel })
	for i, e in Communication.Emojis do
		local b = Kit.button(e.glyph, function()
			if e.vip and not player:GetAttribute("Pass_VIP") then
				return
			end
			emoteEvent:FireServer(e.id)
			wheel.Visible = false
		end, { TextSize = 30, LayoutOrder = i, Parent = wheel })
		if e.vip then
			b.BackgroundColor3 = Color3.fromRGB(110, 85, 30)
			b.Text = e.glyph
			player:GetAttributeChangedSignal("Pass_VIP"):Connect(function()
				b.TextTransparency = if player:GetAttribute("Pass_VIP") then 0 else 0.6
			end)
			b.TextTransparency = if player:GetAttribute("Pass_VIP") then 0 else 0.6
		end
	end
end

function CommunicationController.toggleWheel()
	wheel.Visible = not wheel.Visible
	pingBar.Visible = false
	State.pingMode = false
end

------------------------------------------------------------------------
-- Richtungspfeile
------------------------------------------------------------------------
local function buildPingBar(gui: ScreenGui)
	pingBar = Kit.new("Frame", {
		Name = "PingBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = T.Panel,
		Visible = false,
		Parent = gui,
	}, { Kit.corner(14), Kit.stroke(), Kit.padding(8), Kit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })
	Kit.label("Wähle einen Pfeil und tippe dann auf eine Stelle in der Welt", 14, { TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(360, 0), Parent = pingBar })
	local row = Kit.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), Parent = pingBar }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local buttons = {}
	for i, p in Communication.Pings do
		local b = Kit.button(p.glyph .. "\n" .. p.label, function()
			selectedPing = p.id
			for id, btn in buttons do
				btn.BackgroundColor3 = if id == selectedPing then T.ButtonHi else T.Button
			end
		end, { Size = UDim2.fromOffset(70, 58), TextSize = 14, LayoutOrder = i, Parent = row })
		buttons[p.id] = b
	end
	buttons[selectedPing].BackgroundColor3 = T.ButtonHi
	edgeLayer = Kit.new("Frame", { Name = "PingArrows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
end

function CommunicationController.togglePing()
	State.pingMode = not State.pingMode
	pingBar.Visible = State.pingMode
	wheel.Visible = false
end

local function showPing(from: Player, pingId: string, position: Vector3)
	local def = Communication.findPing(pingId)
	if not def then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = def.color
	p.Transparency = 0.35
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.4, 6, 6)
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = markerFolder
	local bb = Kit.new("BillboardGui", {
		Size = UDim2.fromOffset(110, 90),
		StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
		AlwaysOnTop = true,
		Adornee = p,
		Parent = p,
	})
	Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Text = def.glyph,
		TextScaled = true,
		Parent = bb,
	})
	Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 30),
		Text = def.label .. "\n" .. from.DisplayName,
		TextColor3 = def.color,
		TextStrokeTransparency = 0.3,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Parent = bb,
	})
	local arrow = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		Text = "➤",
		TextColor3 = def.color,
		TextStrokeTransparency = 0.2,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		Visible = false,
		Parent = edgeLayer,
	})
	table.insert(activePings, { part = p, arrow = arrow, expires = os.clock() + GameConfig.PingDuration })
end

local function updateArrows()
	local cam = Workspace.CurrentCamera
	local vp = cam.ViewportSize
	local t = os.clock()
	for i = #activePings, 1, -1 do
		local ping = activePings[i]
		if t > ping.expires then
			ping.part:Destroy()
			ping.arrow:Destroy()
			table.remove(activePings, i)
			continue
		end
		local screen, onScreen = cam:WorldToViewportPoint(ping.part.Position)
		if onScreen then
			ping.arrow.Visible = false
		else
			-- Pfeil am Bildschirmrand Richtung Marker
			local center = vp / 2
			local dir = Vector2.new(screen.X, screen.Y) - center
			if screen.Z < 0 then
				dir = -dir
			end
			if dir.Magnitude < 1 then
				dir = Vector2.new(0, -1)
			end
			dir = dir.Unit
			local margin = 40
			local scaleX = (center.X - margin) / math.max(math.abs(dir.X), 1e-3)
			local scaleY = (center.Y - margin) / math.max(math.abs(dir.Y), 1e-3)
			local pos = center + dir * math.min(scaleX, scaleY)
			ping.arrow.Position = UDim2.fromOffset(pos.X, pos.Y)
			ping.arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
			ping.arrow.Visible = true
		end
	end
end

function CommunicationController.init(gui: ScreenGui)
	markerFolder = Instance.new("Folder")
	markerFolder.Name = "PingMarkers"
	markerFolder.Parent = Workspace
	buildWheel(gui)
	buildPingBar(gui)

	emoteEvent.OnClientEvent:Connect(function(who, emojiId)
		if typeof(who) == "Instance" and who:IsA("Player") and type(emojiId) == "string" then
			showEmote(who, emojiId)
		end
	end)
	pingEvent.OnClientEvent:Connect(function(from, pingId, position)
		if typeof(from) == "Instance" and from:IsA("Player") and type(pingId) == "string" and typeof(position) == "Vector3" then
			showPing(from, pingId, position)
		end
	end)

	-- Im Pfeil-Modus: Klick/Tippen in die Welt setzt den Marker
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not State.pingMode then
			return
		end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		local cam = Workspace.CurrentCamera
		local ray = cam:ViewportPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance, markerFolder }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * GameConfig.PingMaxDistance, params)
		if hit then
			pingEvent:FireServer(selectedPing, hit.Position)
			State.pingMode = false
			pingBar.Visible = false
		end
	end)

	RunService.RenderStepped:Connect(updateArrows)

	State.OpenPanel.Event:Connect(function(name)
		if name == "Emojis" then
			CommunicationController.toggleWheel()
		elseif name == "Pfeil" then
			CommunicationController.togglePing()
		end
	end)
end

return CommunicationController
