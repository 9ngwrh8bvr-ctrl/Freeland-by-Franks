--!strict
-- Menüfenster: Monster, Klasse (Klassen/Talente/Spezialisierung), Quests,
-- Tasche (Inventar/Ausrüstung), Shop (Münzen/Edelsteine/Robux), Starterwahl.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local Monsters = require(Shared.Config.Monsters)
local Abilities = require(Shared.Config.Abilities)
local Elements = require(Shared.Config.Elements)
local Rarities = require(Shared.Config.Rarities)
local Items = require(Shared.Config.Items)
local Shop = require(Shared.Config.Shop)
local ClassesModule = require(Shared.Config.Classes)
local QuestsModule = require(Shared.Config.Quests)
local Formulas = require(Shared.Formulas)
local TableUtil = require(Shared.Util.TableUtil)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Parent.UI.Kit)

local T = Kit.Theme
local Classes = ClassesModule.List
local Quests = QuestsModule.List
local player = Players.LocalPlayer

local PanelController = {}

type Window = { win: Frame, content: ScrollingFrame, tabs: Frame, render: (ScrollingFrame, any) -> (), tab: string? }
local windows: { [string]: Window } = {}
local openName: string? = nil
local toast: (string, string) -> () = function(_text: string, _kind: string) end

local function call(remote: string, ...): (boolean, string?)
	local ok, a, b = pcall(function(...)
		return Net.func(remote):InvokeServer(...)
	end, ...)
	if not ok then
		return false, "Verbindungsfehler"
	end
	if a == false and type(b) == "string" then
		toast(b, "bad")
	end
	return a, b
end

local function rerender()
	if openName then
		local w = windows[openName]
		if w and State.profile then
			Kit.clear(w.content)
			w.render(w.content, State.profile)
		end
	end
end

local function close()
	if openName and windows[openName] then
		windows[openName].win.Visible = false
	end
	openName = nil
end

local function open(name: string)
	if openName == name then
		close()
		return
	end
	close()
	local w = windows[name]
	if not w then
		return
	end
	openName = name
	w.win.Visible = true
	rerender()
end

local function setTabs(w: Window, names: { string })
	Kit.clear(w.tabs)
	w.tab = w.tab or names[1]
	for i, n in names do
		Kit.button(n, function()
			w.tab = n
			setTabs(w, names)
			rerender()
		end, {
			Size = UDim2.fromOffset(150, 34),
			LayoutOrder = i,
			BackgroundColor3 = if w.tab == n then T.ButtonHi else T.Button,
			Parent = w.tabs,
		})
	end
end

local function row(parent: Instance): Frame
	return Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}, { Kit.list(Enum.FillDirection.Horizontal, 6) })
end

local function small(text: string, fn: () -> (), parent: Instance, color: Color3?): TextButton
	return Kit.button(text, fn, {
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 14,
		BackgroundColor3 = color or T.Button,
		Parent = parent,
	})
end

------------------------------------------------------------------------
-- Monster
------------------------------------------------------------------------
local releaseConfirm: string? = nil

local function renderMonsters(c: ScrollingFrame, p: any)
	local slots = Formulas.activeSlots(p)
	local cap = Formulas.storageCap(p, p.passes and p.passes.GrossesGehege)
	Kit.label(
		("Aktive Gefährten: <b>%d / %d</b>     Gehege: <b>%d / %d</b>\nNeue Plätze durch Level 10 und 25 (Bestienbändiger +1)."):format(
			#p.activeTeam,
			slots,
			TableUtil.count(p.monsters),
			cap
		),
		15,
		{ LayoutOrder = 0, Parent = c }
	)

	-- Auren (Kosmetik)
	if next(p.cosmetics) then
		local r = row(c)
		r.LayoutOrder = 1
		Kit.label("Aura:", 14, { Size = UDim2.fromOffset(50, 32), AutomaticSize = Enum.AutomaticSize.None, Parent = r })
		small("Keine", function()
			call("ManageMonsters", "setAura", "")
		end, r, if p.activeAura == "" then T.ButtonHi else nil)
		for id in p.cosmetics do
			local it = Items[id]
			if it then
				small(it.icon .. " " .. it.name, function()
					call("ManageMonsters", "setAura", id)
				end, r, if p.activeAura == id then T.ButtonHi else nil)
			end
		end
	end

	local list = {}
	for uid, rec in p.monsters do
		table.insert(list, rec)
		rec.uid = uid
	end
	table.sort(list, function(a, b)
		local aa, ba = table.find(p.activeTeam, a.uid) ~= nil, table.find(p.activeTeam, b.uid) ~= nil
		if aa ~= ba then
			return aa
		end
		local ra, rb = Rarities.rank(Monsters[a.species].rarity), Rarities.rank(Monsters[b.species].rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.level > b.level
	end)

	for i, rec in list do
		local sp = Monsters[rec.species]
		local rarity = Rarities.List[sp.rarity]
		local el = Elements.List[sp.element]
		local active = table.find(p.activeTeam, rec.uid) ~= nil
		local bond = Formulas.bondLevel(rec.bondXp)
		local stats = Formulas.monsterStats(rec.species, rec.level, rec.bondXp, rec.potential, Formulas.aggregateMods(p))
		local card = Kit.card()
		card.LayoutOrder = 10 + i
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		if active then
			Kit.stroke(T.Good, 2).Parent = card
		end
		Kit.label(
			("%s <b>%s</b>  <font color=\"#%s\">%s</font>  •  %s  •  Lv %d  •  Stufe %d/3"):format(
				el.icon,
				Formulas.stageName(rec.species, rec.level),
				rarity.color:ToHex(),
				rarity.name,
				sp.role,
				rec.level,
				Formulas.stageIndex(rec.species, rec.level)
			),
			16,
			{ Parent = card }
		)
		local bondBar, setBond = Kit.bar(T.Bond, 12)
		bondBar.Parent = card
		setBond(Formulas.bondProgress(rec.bondXp), ("💞 Bindung %d/5 – %s"):format(bond, Formulas.BondPerks[bond]))
		local abil = {}
		for slot, id in sp.abilities do
			local def = Abilities[id]
			local need = if slot == 3 then 3 elseif slot == 4 then 4 elseif slot == 2 then 2 else 1
			table.insert(abil, (if bond >= need then "✅ " else "🔒 ") .. def.name)
		end
		local traits = if #sp.traits > 0 then table.concat(sp.traits, ", ") else "–"
		local extra = ""
		if sp.specialization then
			extra = ("\nSpezialisierung bei Bindung %d: <b>%s</b>"):format(sp.specialization.bond, Abilities[sp.specialization.ability].name)
		end
		for _, cid in ClassesModule.Order do
			if Classes[cid].unlockedBy == rec.species then
				extra ..= ("\nKann die Klasse <b>%s</b> freischalten."):format(Classes[cid].name)
			end
		end
		Kit.label(
			("❤ %d   ⚔ %d   🛡 %d     Erkundung: %s\nFähigkeiten: %s%s"):format(stats.hp, stats.atk, stats.def, traits, table.concat(abil, "  "), extra),
			14,
			{ TextColor3 = T.Muted, Parent = card }
		)
		local exhausted = (rec.exhaustedUntil or 0) - State.serverTime()
		if exhausted > 0 then
			Kit.label(("💤 Erschöpft – noch %d s (Rastplatz oder Wiederbelebungskraut)"):format(exhausted), 14, { TextColor3 = T.Bad, Parent = card })
		end
		local r = row(card)
		small(if active then "Aus dem Team" else "Ins Team", function()
			call("ManageMonsters", "toggleActive", rec.uid)
		end, r, if active then nil else Color3.fromRGB(50, 110, 60))
		if (p.inventory.Bindungssnack or 0) > 0 then
			small(("🍪 Snack (%d)"):format(p.inventory.Bindungssnack), function()
				call("UseItem", "Bindungssnack", rec.uid)
			end, r)
		end
		if exhausted > 0 and (p.inventory.Wiederbelebungskraut or 0) > 0 then
			small("🌱 Wiederbeleben", function()
				call("UseItem", "Wiederbelebungskraut", rec.uid)
			end, r)
		end
		small(if releaseConfirm == rec.uid then "Wirklich freilassen?" else "Freilassen", function()
			if releaseConfirm == rec.uid then
				releaseConfirm = nil
				call("ManageMonsters", "release", rec.uid)
			else
				releaseConfirm = rec.uid
				rerender()
			end
		end, r, Color3.fromRGB(110, 50, 50))
	end
	if #list == 0 then
		Kit.label("Du hast noch keine Monster. Schwäche ein wildes Monster und halte [E] für das Vertrauensritual.", 15, { LayoutOrder = 5, Parent = c })
	end
end

------------------------------------------------------------------------
-- Klasse
------------------------------------------------------------------------
local function renderClasses(c: ScrollingFrame, p: any)
	for i, id in ClassesModule.Order do
		local cls = Classes[id]
		local card = Kit.card()
		card.LayoutOrder = i
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		local unlocked = p.unlockedClasses[id] == true
		local isActive = p.classId == id
		if isActive then
			Kit.stroke(T.Gold, 2).Parent = card
		end
		Kit.label(("<b>%s</b>%s  •  %s"):format(cls.name, if cls.advanced then " ⭐" else "", cls.playstyle), 17, { Parent = card })
		local abil = {}
		for _, a in cls.abilities do
			table.insert(abil, ("%s (Lv %d)"):format(Abilities[a.id].name, a.level))
		end
		Kit.label(cls.description .. "\nFähigkeiten: " .. table.concat(abil, ", "), 14, { TextColor3 = T.Muted, Parent = card })
		if not unlocked then
			local ok, reqs = Formulas.classRequirements(p, id)
			local lines = {}
			if cls.unlockedBy then
				table.insert(lines, ("Wird durch <b>%s</b> freigeschaltet:"):format(Monsters[cls.unlockedBy].name))
			end
			for _, r in reqs do
				table.insert(lines, (if r.ok then "✅ " else "❌ ") .. r.text)
			end
			Kit.label(table.concat(lines, "\n"), 14, { Parent = card })
			if ok then
				small("🔓 Freischalten", function()
					call("ManageClass", "unlock", id)
				end, card, Color3.fromRGB(120, 90, 30))
			end
		elseif not isActive then
			small("Klasse wechseln", function()
				call("ManageClass", "switch", id)
			end, card, Color3.fromRGB(50, 110, 60))
		else
			Kit.label("✅ Aktive Klasse", 14, { TextColor3 = T.Good, Parent = card })
		end
	end
end

local function renderTalents(c: ScrollingFrame, p: any)
	local cls = Classes[p.classId]
	local ranks = p.talents[p.classId] or {}
	local spent = 0
	for _, r in ranks do
		spent += r
	end
	local left = (p.level - 1) - spent
	Kit.label(("Skilltree <b>%s</b> – freie Punkte: <b>%d</b> (1 Punkt pro Level)"):format(cls.name, left), 16, { LayoutOrder = 0, Parent = c })
	for i, t in cls.talents do
		local card = Kit.card()
		card.LayoutOrder = i
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		local r = ranks[t.id] or 0
		local req = {}
		if t.requiresLevel then
			table.insert(req, "Level " .. t.requiresLevel)
		end
		if t.requires then
			for _, o in cls.talents do
				if o.id == t.requires then
					table.insert(req, o.name)
				end
			end
		end
		Kit.label(("<b>%s</b>  %d/%d\n%s%s"):format(t.name, r, t.maxRank, t.description, if #req > 0 then "\nBenötigt: " .. table.concat(req, ", ") else ""), 14, { Parent = card })
		if r < t.maxRank and left > 0 then
			small("+ Punkt", function()
				call("ManageClass", "talent", t.id)
			end, card, Color3.fromRGB(70, 60, 130))
		end
	end
	small("Talente zurücksetzen (100 🪙)", function()
		call("ManageClass", "resetTalents")
	end, c, Color3.fromRGB(110, 50, 50)).LayoutOrder = 100
end

local function renderSpecs(c: ScrollingFrame, p: any)
	Kit.label(
		"Spezialisierungen erhältst du durch Bindung (Stufe 3) mit seltenen Monstern. Die gewählte Spezialisierung liegt auf Taste [5] – unabhängig von deiner Klasse.",
		15,
		{ LayoutOrder = 0, Parent = c }
	)
	local specs = Formulas.specializations(p)
	for i, id in specs do
		local def = Abilities[id]
		local card = Kit.card()
		card.LayoutOrder = i
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		Kit.label(("<b>%s</b>\n%s"):format(def.name, def.description), 14, { Parent = card })
		if p.specialization == id then
			Kit.label("✅ Ausgewählt", 14, { TextColor3 = T.Good, Parent = card })
		else
			small("Auswählen", function()
				call("ManageClass", "setSpec", id)
			end, card)
		end
	end
	if #specs == 0 then
		local hints = {}
		for _, sp in Monsters do
			if sp.specialization then
				table.insert(hints, ("• %s → %s"):format(sp.name, Abilities[sp.specialization.ability].name))
			end
		end
		table.sort(hints)
		Kit.label("Noch keine Spezialisierung.\n" .. table.concat(hints, "\n"), 14, { TextColor3 = T.Muted, LayoutOrder = 1, Parent = c })
	end
end

------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------
local function renderQuests(c: ScrollingFrame, p: any)
	local order = 0
	for _, id in QuestsModule.Order do
		local q = Quests[id]
		local active = p.quests.active[id]
		local done = p.quests.completed[id]
		if not active and not done then
			continue
		end
		order += 1
		local card = Kit.card()
		card.LayoutOrder = if done then 100 + order else order
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		Kit.label(("%s <b>%s</b>  [%s]"):format(if done then "✅" else "📜", q.name, q.category), 16, { Parent = card })
		if active then
			Kit.label(q.description, 14, { TextColor3 = T.Muted, Parent = card })
			local prog = p.quests.progress[id] or {}
			for i, obj in q.objectives do
				local n = prog[i] or 0
				local need = obj.count or 1
				Kit.label(("%s %s (%d/%d)"):format(if n >= need then "☑" else "☐", obj.text, math.min(n, need), need), 14, { Parent = card })
			end
		end
	end
	-- Hinweise auf gesperrte Klassenprüfungen
	local hints = {}
	for _, id in QuestsModule.Order do
		local q = Quests[id]
		if not p.quests.active[id] and not p.quests.completed[id] then
			local pr = q.prereq
			local parts = {}
			if pr.level then
				table.insert(parts, "Level " .. pr.level)
			end
			if pr.bond then
				table.insert(parts, ("%s Bindung %d"):format(Monsters[pr.bond.species].name, pr.bond.value))
			end
			if pr.hasSpecies then
				table.insert(parts, Monsters[pr.hasSpecies].name .. " gefangen")
			end
			if pr.quest then
				table.insert(parts, "nach „" .. Quests[pr.quest].name .. "“")
			end
			table.insert(hints, ("🔒 %s – %s"):format(q.name, table.concat(parts, ", ")))
		end
	end
	if #hints > 0 then
		Kit.label("<b>Noch gesperrt:</b>\n" .. table.concat(hints, "\n"), 14, { TextColor3 = T.Muted, LayoutOrder = 99, Parent = c })
	end
end

------------------------------------------------------------------------
-- Tasche
------------------------------------------------------------------------
local function renderBag(c: ScrollingFrame, p: any)
	local stats = Formulas.playerStats(p)
	Kit.label(("❤ %d   ⚔ %d   🛡 %d   🎯 %d %% krit.   •   🪙 %d   💎 %d"):format(stats.hp, stats.atk, stats.def, math.floor(stats.crit * 100), p.coins, p.gems), 15, { LayoutOrder = 0, Parent = c })
	local eq = row(c)
	eq.LayoutOrder = 1
	for _, slot in { "weapon", "armor", "amulet" } do
		local id = p.equipment[slot]
		local name = if slot == "weapon" then "Waffe" elseif slot == "armor" then "Rüstung" else "Amulett"
		small(("%s: %s"):format(name, if id and Items[id] then Items[id].icon .. " " .. Items[id].name .. " ✕" else "–"), function()
			if id then
				call("EquipItem", nil, slot)
			end
		end, eq)
	end
	local cats = { consumable = "Verbrauchsgüter", lure = "Köder (werden beim Ritual automatisch genutzt)", equipment = "Ausrüstung", material = "Materialien" }
	local order = 2
	for _, cat in { "consumable", "lure", "equipment", "material" } do
		local entries = {}
		for id, n in p.inventory do
			local it = Items[id]
			if it and it.category == cat and n > 0 then
				table.insert(entries, { id = id, n = n, it = it })
			end
		end
		if #entries == 0 then
			continue
		end
		table.sort(entries, function(a, b)
			return a.it.name < b.it.name
		end)
		order += 1
		Kit.label("<b>" .. cats[cat] .. "</b>", 16, { TextColor3 = T.Gold, LayoutOrder = order, Parent = c })
		for _, e in entries do
			order += 1
			local card = Kit.card()
			card.LayoutOrder = order
			card.Parent = c
			Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
			Kit.label(("%s <b>%s</b> ×%d – %s"):format(e.it.icon, e.it.name, e.n, e.it.description), 14, { Parent = card })
			local r = row(card)
			if cat == "consumable" and not e.it.needsMonster then
				small("Benutzen", function()
					call("UseItem", e.id)
				end, r)
			elseif cat == "equipment" then
				small("Ausrüsten", function()
					call("EquipItem", e.id)
				end, r)
			end
			if e.it.sellValue then
				small(("Verkaufen (%d 🪙)"):format(e.it.sellValue), function()
					call("ShopRequest", "sell", e.id, 1)
				end, r)
				if e.n > 1 then
					small(("Alle (%d 🪙)"):format(e.it.sellValue * e.n), function()
						call("ShopRequest", "sell", e.id, e.n)
					end, r)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Shop
------------------------------------------------------------------------
local function shopList(c: ScrollingFrame, p: any, list: { any }, currency: string)
	local symbol = if currency == "coin" then "🪙" else "💎"
	Kit.label(("Dein Guthaben: 🪙 %d   💎 %d"):format(p.coins, p.gems), 15, { LayoutOrder = 0, Parent = c })
	for i, entry in list do
		local it = entry.item and Items[entry.item]
		local name = if it then it.name else entry.name
		local icon = if it then it.icon else entry.icon or "🛍️"
		local desc = if it then it.description else entry.description or ""
		local owned = it and it.category == "cosmetic" and p.cosmetics[entry.item]
		local card = Kit.card()
		card.LayoutOrder = i
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		Kit.label(("%s <b>%s</b>%s – %s"):format(icon, name or "?", if (entry.amount or 1) > 1 then " ×" .. entry.amount else "", desc), 14, { Parent = card })
		if owned then
			Kit.label("✅ Besitzt du bereits", 14, { TextColor3 = T.Good, Parent = card })
		else
			small(("Kaufen – %d %s"):format(entry.price, symbol), function()
				local ok = call("ShopRequest", "buy", currency, entry.key)
				if ok then
					toast(("Gekauft: %s"):format(name or "?"), "good")
				end
			end, card, Color3.fromRGB(50, 110, 60))
		end
	end
end

local function renderRobux(c: ScrollingFrame, p: any)
	Kit.label("Robux-Käufe sind freiwillig. Es gibt keine Zufallsboxen – du weißt immer genau, was du bekommst.", 14, { TextColor3 = T.Muted, LayoutOrder = 0, Parent = c })
	local order = 0
	Kit.label("<b>Game Passes (dauerhaft)</b>", 16, { TextColor3 = T.Gold, LayoutOrder = 1, Parent = c })
	for _, key in Shop.GamePassOrder do
		local pass = Shop.GamePasses[key]
		order += 1
		local card = Kit.card()
		card.LayoutOrder = 1 + order
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		Kit.label(("%s <b>%s</b> – %s"):format(pass.icon, pass.name, pass.description), 14, { Parent = card })
		if p.passes and p.passes[key] then
			Kit.label("✅ Aktiv", 14, { TextColor3 = T.Good, Parent = card })
		elseif pass.id == 0 then
			Kit.label("Bald verfügbar", 14, { TextColor3 = T.Muted, Parent = card })
		else
			small(("Kaufen – ca. %d R$"):format(pass.robuxHint), function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end, card, Color3.fromRGB(40, 120, 60))
		end
	end
	Kit.label("<b>Edelsteine & Pakete</b>", 16, { TextColor3 = T.Gold, LayoutOrder = 50, Parent = c })
	for i, key in Shop.ProductOrder do
		local prod = Shop.Products[key]
		local card = Kit.card()
		card.LayoutOrder = 50 + i
		card.Parent = c
		Kit.list(Enum.FillDirection.Vertical, 4).Parent = card
		local parts = {}
		if prod.grant.gems then
			table.insert(parts, prod.grant.gems .. " 💎")
		end
		for itemId, n in prod.grant.items or {} do
			table.insert(parts, ("%d× %s"):format(n, Items[itemId].name))
		end
		Kit.label(("%s <b>%s</b> – %s"):format(prod.icon, prod.name, table.concat(parts, ", ")), 14, { Parent = card })
		if prod.id == 0 then
			Kit.label("Bald verfügbar", 14, { TextColor3 = T.Muted, Parent = card })
		else
			small(("Kaufen – ca. %d R$"):format(prod.robuxHint), function()
				MarketplaceService:PromptProductPurchase(player, prod.id)
			end, card, Color3.fromRGB(40, 120, 60))
		end
	end
end

------------------------------------------------------------------------
-- Starterwahl
------------------------------------------------------------------------
local starterGui: Frame

local function buildStarter(gui: ScreenGui)
	starterGui = Kit.new("Frame", {
		Name = "Starter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.75),
		BackgroundColor3 = T.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { Kit.corner(16), Kit.stroke(T.Gold, 2), Kit.padding(16), Kit.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center), Kit.new("UISizeConstraint", { MaxSize = Vector2.new(820, 520) }) })
	Kit.label("Willkommen in Lindenhain!", 28, { Font = T.Title, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Center, Parent = starterGui })
	Kit.label("Wähle deinen ersten Gefährten. Er begleitet dich, kämpft an deiner Seite und wächst mit dir.", 16, { TextXAlignment = Enum.TextXAlignment.Center, Parent = starterGui })
	local r = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = starterGui }, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	for i, id in GameConfig.StarterMonsters do
		local sp = Monsters[id]
		local el = Elements.List[sp.element]
		local card = Kit.new("Frame", {
			BackgroundColor3 = T.Panel2,
			Size = UDim2.new(0.31, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = r,
		}, { Kit.corner(12), Kit.padding(10), Kit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center), Kit.stroke(el.color, 2) })
		Kit.label(el.icon, 40, { TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		Kit.label(("<b>%s</b>\n%s • %s"):format(sp.name, sp.element, sp.role), 16, { TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		Kit.label(sp.description, 13, { TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		Kit.button("Wählen", function()
			local ok = call("ChooseStarter", id)
			if ok then
				starterGui.Visible = false
			end
		end, { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(50, 110, 60), Parent = card })
	end
end

------------------------------------------------------------------------
function PanelController.init(gui: ScreenGui, toastFn: (string, string) -> ())
	toast = toastFn
	local function addWindow(name: string, title: string, render: (ScrollingFrame, any) -> (), tabs: { string }?)
		local win, content, tabFrame = Kit.window(gui, title, close)
		local w: Window = { win = win, content = content, tabs = tabFrame, render = render, tab = nil }
		windows[name] = w
		if tabs then
			setTabs(w, tabs)
			w.render = function(c, p)
				render(c, p)
			end
		else
			content.Position = UDim2.fromOffset(12, 52)
			content.Size = UDim2.new(1, -24, 1, -64)
		end
		return w
	end

	addWindow("Monster", "🐾 Deine Monster", renderMonsters)
	local classWin: Window
	classWin = addWindow("Klasse", "⚔️ Klasse & Skilltree", function(c, p)
		local tab = classWin.tab
		if tab == "Talente" then
			renderTalents(c, p)
		elseif tab == "Spezialisierung" then
			renderSpecs(c, p)
		else
			renderClasses(c, p)
		end
	end, { "Klassen", "Talente", "Spezialisierung" })
	addWindow("Quests", "📜 Quests", renderQuests)
	addWindow("Tasche", "🎒 Tasche & Ausrüstung", renderBag)
	local shopWin: Window
	shopWin = addWindow("Shop", "🛒 Shop", function(c, p)
		local tab = shopWin.tab
		if tab == "Edelsteine" then
			shopList(c, p, Shop.GemShop, "gem")
		elseif tab == "Robux" then
			renderRobux(c, p)
		else
			shopList(c, p, Shop.CoinShop, "coin")
		end
	end, { "Münzen", "Edelsteine", "Robux" })

	buildStarter(gui)

	State.OpenPanel.Event:Connect(function(name)
		if name and windows[name] then
			open(name)
		end
	end)
	State.Changed.Event:Connect(function(p)
		starterGui.Visible = not p.starterChosen
		rerender()
	end)
	if State.profile then
		starterGui.Visible = not State.profile.starterChosen
	end
end

return PanelController
