--!strict
-- Einstiegspunkt des Clients.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

------------------------------------------------------------------------
-- Kein Chat: Chatfenster, Eingabezeile und Sprechblasen aus.
-- Rucksack aus (Tasten 1–5 sind Fähigkeiten).
------------------------------------------------------------------------
local function disableCoreUi()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
	pcall(function()
		local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if window then
			window.Enabled = false
		end
		local input = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if input then
			input.Enabled = false
		end
		local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
		if bubbles then
			bubbles.Enabled = false
		end
	end)
end
task.spawn(disableCoreUi)

------------------------------------------------------------------------
-- Oberfläche
------------------------------------------------------------------------
local Controllers = script.Parent:WaitForChild("Controllers")
local Kit = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local Input = require(Controllers:WaitForChild("InputController"))
local Hud = require(Controllers:WaitForChild("HudController"))
local Panels = require(Controllers:WaitForChild("PanelController"))
local Communication = require(Controllers:WaitForChild("CommunicationController"))
local WorldFx = require(Controllers:WaitForChild("WorldFxController"))
local Exploration = require(Controllers:WaitForChild("ExplorationController"))

local gui = Kit.new("ScreenGui", {
	Name = "FreelandUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Skalierung für kleine Bildschirme (Handy)
local scale = Instance.new("UIScale")
scale.Parent = gui
local function rescale()
	local vp = Workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(vp.X / 1100, vp.Y / 720), 0.55, 1)
end
rescale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

Input.init({
	emoteWheel = Communication.toggleWheel,
	ping = Communication.togglePing,
})
Hud.init(gui, Input)
Panels.init(gui, Hud.toast)
Communication.init(gui)
WorldFx.init()
Exploration.init()
