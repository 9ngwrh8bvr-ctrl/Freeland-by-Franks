--!strict
-- HUD: Lebens-/EP-Balken, Währungen, Gefährten-Karten, Ziel-Anzeige,
-- Hinweise, Menü-Knöpfe und Aktionsknöpfe (auch für Touch).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Abilities = require(Shared.Config.Abilities)
local Monsters = require(Shared.Config.Monsters)
local Elements = require(Shared.Config.Elements)
local Rarities = require(Shared.Config.Rarities)
local ClassesModule = require(Shared.Config.Classes)
local Formulas = require(Shared.Formulas)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Parent.UI.Kit)

local T = Kit.Theme
local player = Players.LocalPlayer

local HudController = {}

local refs: { [string]: any } = {}
local actionButtons: { { button: TextButton, overlay: Frame, slot: any, kind: string } } = {}

local function short(text: string, n: number): string
	if #text <= n then
		return text
	end
	return string.sub(text, 1, n - 1) .. "…"
end

local function toast(text: string, kind: string)
	local colors = { info = T.Panel2, good = Color3.fromRGB(40, 90, 50), bad = Color3.fromRGB(110, 40, 40), epic = Color3.fromRGB(100, 70, 20) }
	local f = Kit.new("Frame", {
		BackgroundColor3 = colors[kind] or T.Panel2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = refs.toasts,
	}, { Kit.corner(8), Kit.padding(8), Kit.stroke(if kind == "epic" then T.Gold else T.Border, 1) })
	Kit.label(text, 16, { TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
	local items = {}
	for _, c in refs.toasts:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items > 5 then
		items[1]:Destroy()
	end
	task.delay(if kind == "epic" then 6 else 4, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end
HudController.toast = toast

local function buildStats(gui: ScreenGui)
	local frame = Kit.new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { Kit.corner(12), Kit.stroke(), Kit.padding(10), Kit.list(Enum.FillDirection.Vertical, 5) })
	refs.title = Kit.label("", 17, { Font = T.FontBold, LayoutOrder = 1, Parent = frame })
	local hp, setHp = Kit.bar(T.Hp, 18)
	hp.LayoutOrder = 2
	hp.Parent = frame
	refs.setHp = setHp
	local xp, setXp = Kit.bar(T.Xp, 12)
	xp.LayoutOrder = 3
	xp.Parent = frame
	refs.setXp = setXp
	refs.currency = Kit.label("", 16, { LayoutOrder = 4, Parent = frame })

	refs.companions = Kit.new("Frame", {
		Name = "Companions",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = frame,
	}, { Kit.list(Enum.FillDirection.Vertical, 4) })
end

local function buildTarget(gui: ScreenGui)
	local frame = Kit.new("Frame", {
		Name = "Target",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { Kit.corner(10), Kit.stroke(), Kit.padding(8), Kit.list(Enum.FillDirection.Vertical, 4) })
	refs.targetFrame = frame
	refs.targetName = Kit.label("", 16, { Font = T.FontBold, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = frame })
	local bar, set = Kit.bar(T.Hp, 14)
	bar.LayoutOrder = 2
	bar.Parent = frame
	refs.setTargetHp = set
	refs.targetHint = Kit.label("", 13, { TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = frame })

	refs.toasts = Kit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center), Kit.new("UISizeConstraint", { MaxSize = Vector2.new(420, 400) }) })
end

local function buildMenu(gui: ScreenGui)
	local frame = Kit.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	local entries = {
		{ "🐾", "Monster" },
		{ "⚔️", "Klasse" },
		{ "📜", "Quests" },
		{ "🎒", "Tasche" },
		{ "🛒", "Shop" },
		{ "😀", "Emojis" },
		{ "📍", "Pfeil" },
	}
	for i, e in entries do
		Kit.button(e[1], function()
			State.OpenPanel:Fire(e[2])
		end, { Size = UDim2.fromOffset(52, 52), TextSize = 26, LayoutOrder = i, Parent = frame })
	end
end

local function actionButton(parent: Instance, pos: UDim2, size: number, slot: any, kind: string, onPress: () -> ())
	local b = Kit.button("", onPress, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		TextSize = 12,
		TextWrapped = true,
		BackgroundColor3 = if kind == "companion" then Color3.fromRGB(60, 80, 70) else T.Button,
		Parent = parent,
	})
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	local overlay = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 2,
		Parent = b,
	}, { Kit.corner(size // 2) })
	table.insert(actionButtons, { button = b, overlay = overlay, slot = slot, kind = kind })
	return b
end

local function buildActions(gui: ScreenGui, Input: any)
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local frame = Kit.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 1),
		-- auf Touch-Geräten über dem Sprung-Knopf von Roblox
		Position = if isTouch then UDim2.new(1, -10, 1, -150) else UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(330, 230),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- Spieler-Fähigkeiten (Bogen um den großen Angriffsknopf)
	actionButton(frame, UDim2.new(1, -60, 1, -60), 96, 1, "player", function()
		Input.useAbility(1)
	end)
	actionButton(frame, UDim2.new(1, -165, 1, -45), 64, 2, "player", function()
		Input.useAbility(2)
	end)
	actionButton(frame, UDim2.new(1, -150, 1, -125), 64, 3, "player", function()
		Input.useAbility(3)
	end)
	actionButton(frame, UDim2.new(1, -80, 1, -170), 64, 4, "player", function()
		Input.useAbility(4)
	end)
	actionButton(frame, UDim2.new(1, -235, 1, -110), 58, "spec", "player", function()
		Input.useAbility("spec")
	end)
	-- Gefährten-Befehle (obere Reihe)
	local cmds = {
		{ text = "🐾✨\nSpezial", fn = function()
			Input.companionAbility(2)
		end, slot = "c2" },
		{ text = "🐾🌟\nEinzigartig", fn = function()
			Input.companionAbility(4)
		end, slot = "c4" },
		{ text = "🎯\nFokus", fn = Input.focus, slot = "focus" },
		{ text = "🛡️\nModus", fn = Input.cycleMode, slot = "mode" },
		{ text = "↩️\nZurück", fn = Input.recall, slot = "recall" },
	}
	for i, c in cmds do
		local b = actionButton(frame, UDim2.new(1, -290 + (i - 1) * 62, 1, -205), 56, c.slot, "companion", c.fn)
		b.Text = c.text
		b.TextSize = 11
	end
	-- Zielwechsel (für Touch wichtig)
	Kit.button("⟳ Ziel", Input.cycleTarget, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -250, 1, -10),
		Size = UDim2.fromOffset(70, 34),
		TextSize = 13,
		Parent = frame,
	})
	refs.modeChanged = Input.ModeChanged
end

local function refreshProfile(p: any)
	local cls = ClassesModule.List[p.classId]
	refs.title.Text = ("%s  •  Lv %d %s"):format(player.DisplayName, p.level, cls and cls.name or "")
	local need = Formulas.xpToNext(p.level)
	refs.setXp(p.xp / need, ("EP %d / %d"):format(p.xp, need))
	refs.currency.Text = ("🪙 %d     💎 %d"):format(p.coins, p.gems)

	-- Beschriftung der Aktionsknöpfe
	local unlocked = Formulas.unlockedAbilities(p)
	for _, ab in actionButtons do
		if ab.kind == "player" then
			local id = if ab.slot == "spec" then (if p.specialization ~= "" then p.specialization else nil) else unlocked[ab.slot]
			local def = id and Abilities[id]
			local key = if ab.slot == "spec" then "5" else tostring(ab.slot)
			if def then
				ab.button.Text = short(def.name, 14) .. (if UserInputService.KeyboardEnabled then "\n[" .. key .. "]" else "")
				ab.button.Visible = true
			else
				ab.button.Text = if ab.slot == "spec" then "Spez.\n–" else "🔒"
				ab.button.Visible = ab.slot ~= "spec"
			end
		end
	end

	-- Gefährten-Karten
	Kit.clear(refs.companions)
	refs.companionBars = {}
	for i, uid in p.activeTeam do
		local rec = p.monsters[uid]
		if rec then
			local sp = Monsters[rec.species]
			local card = Kit.new("Frame", {
				BackgroundColor3 = T.Panel2,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = i,
				Parent = refs.companions,
			}, { Kit.corner(8), Kit.padding(6), Kit.list(Enum.FillDirection.Vertical, 3) })
			local el = Elements.List[sp.element]
			local bond = Formulas.bondLevel(rec.bondXp)
			Kit.label(
				("%s <b>%s</b>  Lv %d   💞%d"):format(el.icon, Formulas.stageName(rec.species, rec.level), rec.level, bond),
				14,
				{ TextColor3 = Rarities.List[sp.rarity].color, Parent = card }
			)
			local bar, set = Kit.bar(T.Good, 10)
			bar.Parent = card
			refs.companionBars[uid] = { set = set, rec = rec }
		end
	end
end

local function findCompanionModel(uid: string): Model?
	local folder = Workspace:FindFirstChild("Entities")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("Uid") == uid and m:GetAttribute("OwnerUserId") == player.UserId then
			return m :: Model
		end
	end
	return nil
end

local accum = 0
local function update(dt: number, Input: any)
	accum += dt
	if accum < 0.1 then
		return
	end
	accum = 0
	-- eigene LP
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		refs.setHp(hum.Health / math.max(1, hum.MaxHealth), ("❤ %d / %d"):format(math.floor(hum.Health), math.floor(hum.MaxHealth)))
	end
	-- Gefährten
	if refs.companionBars then
		for uid, info in refs.companionBars do
			local m = findCompanionModel(uid)
			local exhausted = (info.rec.exhaustedUntil or 0) - State.serverTime()
			if m then
				local hp, max = m:GetAttribute("HP") or 0, m:GetAttribute("MaxHP") or 1
				info.set(hp / max, ("%d / %d"):format(hp, max))
			elseif exhausted > 0 then
				info.set(0, ("💤 erschöpft %d s"):format(exhausted))
			else
				info.set(0, "…")
			end
		end
	end
	-- Ziel
	local t = State.target
	if t and t.Parent then
		refs.targetFrame.Visible = true
		local hp, max = t:GetAttribute("HP") or 0, t:GetAttribute("MaxHP") or 1
		local rarity = Rarities.List[t:GetAttribute("Rarity") or "Gewoehnlich"]
		local el = Elements.List[t:GetAttribute("Element") or "Neutral"]
		refs.targetName.Text = ("%s %s  Lv %d"):format(el and el.icon or "", t:GetAttribute("DisplayName") or "?", t:GetAttribute("Level") or 1)
		refs.targetName.TextColor3 = rarity and rarity.color or T.Text
		refs.setTargetHp(hp / max, ("%d / %d"):format(hp, max))
		local sp = Monsters[t:GetAttribute("SpeciesId") or ""]
		if t:GetAttribute("Boss") then
			refs.targetHint.Text = "Bossmonster – nicht fangbar"
		elseif sp and hp / max <= 0.35 then
			refs.targetHint.Text = "🤝 Geschwächt! Halte [E] für das Vertrauensritual"
		elseif sp then
			refs.targetHint.Text = ("%s – unter 35 %% LP fangbar"):format(rarity and rarity.name or "")
		else
			refs.targetHint.Text = ""
		end
	else
		refs.targetFrame.Visible = false
	end
	-- Abklingzeiten
	local now = os.clock()
	for _, ab in actionButtons do
		if ab.kind == "player" then
			local id = Input.abilityForSlot(ab.slot)
			local def = id and Abilities[id]
			local left = id and ((Input.localCooldowns[id] or 0) - now) or 0
			local ratio = if def and left > 0 then left / def.cooldown else 0
			ab.overlay.Size = UDim2.fromScale(1, math.clamp(ratio, 0, 1))
		elseif ab.slot == "mode" then
			local mode = player:GetAttribute("CompanionMode") or "Verteidigen"
			local icon = if mode == "Angriff" then "⚔️" elseif mode == "Passiv" then "💤" else "🛡️"
			ab.button.Text = icon .. "\n" .. mode
		end
	end
end

function HudController.init(gui: ScreenGui, Input: any)
	buildStats(gui)
	buildTarget(gui)
	buildMenu(gui)
	buildActions(gui, Input)

	State.Changed.Event:Connect(refreshProfile)
	if State.profile then
		refreshProfile(State.profile)
	end
	Net.event("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			toast(text, if type(kind) == "string" then kind else "info")
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		update(dt, Input)
	end)
end

return HudController
