--!strict
-- Monstergefährten: Beschwören, Folgen, Kampf-KI, Befehle, Erschöpfung,
-- Team-Verwaltung und Starterwahl.
--
-- Befehle (vom Spieler):
--   mode    – "Verteidigen" (Standard), "Angriff", "Passiv"
--   focus   – alle Gefährten greifen das gewählte Ziel an
--   ability – Spezialfähigkeit (Bindung 2) oder Einzigartige Fähigkeit (Bindung 4)
--   recall  – Gefährten zurückrufen (Ziel vergessen, zum Spieler teleportieren)

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Monsters = require(Shared.Config.Monsters)
local Abilities = require(Shared.Config.Abilities)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)
local TableUtil = require(Shared.Util.TableUtil)
local RateLimiter = require(Shared.Util.RateLimiter)
local Notifier = require(script.Parent.Parent.Modules.Notifier)
local AbilityExecutor = require(script.Parent.Parent.Modules.AbilityExecutor)
local MonsterFactory = require(script.Parent.Parent.Modules.MonsterFactory)

local MODES = { Verteidigen = true, Angriff = true, Passiv = true }
local TICK = 0.25

local CompanionService = {}
local S: any
local ES: any
local summoned: { [Player]: { [string]: any } } = {}
local modes: { [Player]: string } = {}
local focus: { [Player]: any } = {}
local commandLimiter = RateLimiter.new(0.2)
local manageLimiter = RateLimiter.new(0.2)

function CompanionService:Init(services)
	S = services
	ES = services.EntityService
	AbilityExecutor.init(ES)
end

------------------------------------------------------------------------
-- Monster-Records
------------------------------------------------------------------------
function CompanionService:CreateRecord(player: Player, speciesId: string, level: number): string?
	local d = S.DataService:Get(player)
	if not d or not Monsters[speciesId] then
		return nil
	end
	local uid = HttpService:GenerateGUID(false)
	d.monsters[uid] = {
		uid = uid,
		species = speciesId,
		level = math.clamp(level, 1, GameConfig.MaxMonsterLevel),
		xp = 0,
		bondXp = 0,
		potential = math.floor((0.92 + math.random() * 0.16) * 100) / 100,
		caughtAt = os.time(),
		exhaustedUntil = 0,
	}
	-- automatisch ins Team, falls Platz frei
	if #d.activeTeam < Formulas.activeSlots(d) then
		table.insert(d.activeTeam, uid)
	end
	S.DataService:MarkDirty(player)
	return uid
end

function CompanionService:StorageUsed(player: Player): number
	local d = S.DataService:Get(player)
	return d and TableUtil.count(d.monsters) or 0
end

function CompanionService:StorageCap(player: Player): number
	local d = S.DataService:Get(player)
	if not d then
		return 0
	end
	return Formulas.storageCap(d, S.DataService:HasPass(player, "GrossesGehege"))
end

------------------------------------------------------------------------
-- Beschwören
------------------------------------------------------------------------
function CompanionService:GetSummoned(player: Player): { [string]: any }
	return summoned[player] or {}
end

function CompanionService:GetSummonedWithTrait(player: Player, trait: string, maxDist: number?): any?
	local pe = ES:ForPlayer(player)
	for _, ce in self:GetSummoned(player) do
		local sp = Monsters[ce.speciesId]
		if sp and table.find(sp.traits, trait) and not ce.dead then
			if not pe or not maxDist or (ce.root.Position - pe.root.Position).Magnitude <= maxDist then
				return ce
			end
		end
	end
	return nil
end

function CompanionService:Summon(player: Player, uid: string): any?
	local d = S.DataService:Get(player)
	local rec = d and d.monsters[uid]
	local pe = ES:ForPlayer(player)
	if not rec or not pe or pe.dead then
		return nil
	end
	summoned[player] = summoned[player] or {}
	if summoned[player][uid] then
		return summoned[player][uid]
	end
	local index = (table.find(d.activeTeam, uid) or 1)
	local offset = pe.root.CFrame * CFrame.new((index - 1.5) * 4, 0, 5)
	local e = ES:SpawnMonster({
		speciesId = rec.species,
		level = rec.level,
		kind = "Companion",
		position = offset.Position,
		owner = player,
		uid = uid,
		bondXp = rec.bondXp,
		potential = rec.potential,
		mods = Formulas.aggregateMods(d),
	})
	e.state.slot = index
	summoned[player][uid] = e
	if d.activeAura and d.activeAura ~= "" then
		MonsterFactory.applyAura(e.model, d.activeAura)
	end
	return e
end

function CompanionService:Dismiss(player: Player, uid: string)
	local list = summoned[player]
	local e = list and list[uid]
	if e then
		list[uid] = nil
		ES:Remove(e)
	end
end

function CompanionService:DismissAll(player: Player)
	for uid in self:GetSummoned(player) do
		self:Dismiss(player, uid)
	end
end

-- Werte nach Level-/Bindungs-/Talentänderung neu berechnen
function CompanionService:Refresh(player: Player, uid: string)
	local d = S.DataService:Get(player)
	local e = self:GetSummoned(player)[uid]
	local rec = d and d.monsters[uid]
	if not e or not rec then
		return
	end
	local stageNow = Formulas.stageIndex(rec.species, rec.level)
	local stageBefore = Formulas.stageIndex(rec.species, e.level)
	if stageNow ~= stageBefore then
		-- neues Modell für neue Entwicklungsstufe
		self:Dismiss(player, uid)
		self:Summon(player, uid)
		return
	end
	local ratio = e.hp / e.maxHp
	e.level = rec.level
	e.stats = Formulas.monsterStats(rec.species, rec.level, rec.bondXp, rec.potential, Formulas.aggregateMods(d))
	e.mods = Formulas.aggregateMods(d)
	e.maxHp = e.stats.hp
	e.hp = math.max(1, math.floor(e.maxHp * ratio))
	e.humanoid.WalkSpeed = e.stats.spd
	e.model:SetAttribute("Level", rec.level)
	e.model:SetAttribute("DisplayName", Formulas.stageName(rec.species, rec.level))
	e.model:SetAttribute("HP", math.floor(e.hp))
	e.model:SetAttribute("MaxHP", e.maxHp)
end

function CompanionService:RefreshAll(player: Player)
	for uid in self:GetSummoned(player) do
		self:Refresh(player, uid)
	end
end

-- Aktives Team mit beschworenen Gefährten abgleichen
function CompanionService:Sync(player: Player)
	local d = S.DataService:Get(player)
	local pe = ES:ForPlayer(player)
	if not d then
		return
	end
	local list = summoned[player] or {}
	summoned[player] = list
	local slots = Formulas.activeSlots(d)
	-- Team auf erlaubte Größe kürzen (z. B. nach Klassenwechsel)
	while #d.activeTeam > slots do
		table.remove(d.activeTeam)
		S.DataService:MarkDirty(player)
	end
	for uid in list do
		if not table.find(d.activeTeam, uid) or not d.monsters[uid] then
			self:Dismiss(player, uid)
		end
	end
	if not pe or pe.dead then
		self:DismissAll(player)
		return
	end
	for _, uid in d.activeTeam do
		local rec = d.monsters[uid]
		if rec and not list[uid] and (rec.exhaustedUntil or 0) <= os.time() then
			self:Summon(player, uid)
		end
	end
end

------------------------------------------------------------------------
-- KI der Gefährten
------------------------------------------------------------------------
local function pickTarget(player: Player, pe: any): any?
	local f = focus[player]
	if f and ES:IsAlive(f) and (f.root.Position - pe.root.Position).Magnitude < GameConfig.CompanionAssistRadius * 2 then
		return f
	end
	focus[player] = nil
	local mode = modes[player] or "Verteidigen"
	if mode == "Passiv" then
		return nil
	end
	local ownerPos = pe.root.Position
	if mode == "Angriff" then
		return ES:Nearest(ownerPos, GameConfig.CompanionAssistRadius, function(o)
			return o.kind == "Wild" and not ES:IsStealthed(o)
		end)
	end
	-- Verteidigen: Ziel des Spielers oder Gegner, die das Team angreifen
	if pe.target and ES:IsAlive(pe.target) and (pe.target.root.Position - ownerPos).Magnitude < GameConfig.CompanionAssistRadius * 1.5 then
		return pe.target
	end
	local team = summoned[player] or {}
	return ES:Nearest(ownerPos, GameConfig.CompanionAssistRadius, function(o)
		if o.kind ~= "Wild" or not o.target then
			return false
		end
		if o.target == pe then
			return true
		end
		for _, c in team do
			if o.target == c then
				return true
			end
		end
		return false
	end)
end

-- Bindung 3: automatische Unterstützung
local function trySupport(ce: any, pe: any, target: any?, bond: number)
	if bond < 3 then
		return
	end
	local sp = Monsters[ce.speciesId]
	local id = sp.abilities[3]
	local def = Abilities[id]
	if not def or not AbilityExecutor.isReady(ce, id) then
		return
	end
	local kind = def.kind
	local use = false
	if kind == "Heal" then
		use = pe.hp / pe.maxHp < 0.6 or ce.hp / ce.maxHp < 0.5
	elseif kind == "Shield" then
		use = target ~= nil and pe.hp / pe.maxHp < 0.85
	elseif kind == "Taunt" then
		use = target ~= nil and target.target == pe
	elseif kind == "Buff" or kind == "Stealth" then
		use = target ~= nil
	else
		use = target ~= nil and ES:Distance(ce, target) <= AbilityExecutor.range(id)
	end
	if use then
		AbilityExecutor.execute(ce, id, target)
	end
end

local function companionTick(player: Player, ce: any)
	if ce.dead or ES:IsStunned(ce) then
		return
	end
	local pe = ES:ForPlayer(player)
	if not pe or pe.dead then
		return
	end
	local d = S.DataService:Get(player)
	local rec = d and d.monsters[ce.uid]
	if not rec then
		return
	end
	local bond = Formulas.bondLevel(rec.bondXp)
	local sp = Monsters[ce.speciesId]
	local ownerPos = pe.root.Position
	local myPos = ce.root.Position

	-- zu weit weg → zum Spieler teleportieren
	if (myPos - ownerPos).Magnitude > GameConfig.CompanionTeleportDistance then
		ce.model:PivotTo(pe.root.CFrame * CFrame.new(0, 2, 5))
		ce.target = nil
		return
	end

	-- befohlene Fähigkeit, die noch auf Reichweite wartet
	local pending = ce.state.pending
	if pending then
		if os.clock() > pending.expires or not ES:IsAlive(pending.target) then
			ce.state.pending = nil
		elseif ES:Distance(ce, pending.target) <= AbilityExecutor.range(pending.id) then
			AbilityExecutor.execute(ce, pending.id, pending.target)
			ce.state.pending = nil
			return
		else
			ce.humanoid:MoveTo(pending.target.root.Position)
			return
		end
	end

	local target = pickTarget(player, pe)
	ce.target = target
	trySupport(ce, pe, target, bond)

	if target then
		local basic = sp.abilities[1]
		local range = AbilityExecutor.range(basic)
		if ES:Distance(ce, target) <= range then
			ce.humanoid:MoveTo(myPos)
			if AbilityExecutor.isReady(ce, basic) then
				AbilityExecutor.execute(ce, basic, target)
			end
		else
			local tp = target.root.Position
			local dir = (myPos - tp)
			local stop = tp + (if dir.Magnitude > 0.1 then dir.Unit else Vector3.zero) * math.max(1, range * 0.7)
			ce.humanoid:MoveTo(stop)
		end
	else
		-- folgen: Formation hinter dem Spieler
		local slot = ce.state.slot or 1
		local goal = (pe.root.CFrame * CFrame.new((slot - 1.5) * 5, 0, 6)).Position
		if (goal - myPos).Magnitude > 4 then
			ce.humanoid:MoveTo(goal)
			ce.humanoid.WalkSpeed = math.max(ce.stats.spd, pe.humanoid.WalkSpeed + 4)
		end
	end
end

------------------------------------------------------------------------
-- Befehle
------------------------------------------------------------------------
function CompanionService:Command(player: Player, cmd: string, arg: any)
	local pe = ES:ForPlayer(player)
	local d = S.DataService:Get(player)
	if not pe or not d then
		return
	end
	if cmd == "mode" then
		if type(arg) == "string" and MODES[arg] then
			modes[player] = arg
			player:SetAttribute("CompanionMode", arg)
		end
	elseif cmd == "focus" then
		local target = if typeof(arg) == "Instance" then ES:FromModel(arg) else nil
		if target and target.kind == "Wild" and (target.root.Position - pe.root.Position).Magnitude < 120 then
			focus[player] = target
			pe.target = target
		end
	elseif cmd == "recall" then
		focus[player] = nil
		pe.target = nil
		for _, ce in self:GetSummoned(player) do
			ce.target = nil
			ce.state.pending = nil
			ce.model:PivotTo(pe.root.CFrame * CFrame.new(0, 2, 5))
		end
	elseif cmd == "ability" then
		-- arg = { slot = 2 | 4, uid = string? }
		if type(arg) ~= "table" then
			return
		end
		local slot = arg.slot
		if slot ~= 2 and slot ~= 4 then
			return
		end
		local used = false
		for uid, ce in self:GetSummoned(player) do
			if arg.uid ~= nil and arg.uid ~= uid then
				continue
			end
			local rec = d.monsters[uid]
			if not rec or Formulas.bondLevel(rec.bondXp) < slot then
				continue
			end
			local id = Monsters[ce.speciesId].abilities[slot]
			if not AbilityExecutor.isReady(ce, id) then
				continue
			end
			local target = focus[player] or pe.target or ce.target
			if not (target and ES:IsAlive(target)) then
				target = ES:Nearest(ce.root.Position, 40, function(o)
					return o.kind == "Wild" and not ES:IsStealthed(o)
				end)
			end
			if AbilityExecutor.needsTarget(id) then
				if not target then
					continue
				end
				if ES:Distance(ce, target) > AbilityExecutor.range(id) then
					ce.state.pending = { id = id, target = target, expires = os.clock() + 4 }
					used = true
					continue
				end
			end
			local ok = AbilityExecutor.execute(ce, id, target)
			used = used or ok
		end
		if not used then
			Notifier.send(player, if slot == 2 then "Keine Spezialfähigkeit bereit (Bindung 2 nötig)." else "Keine einzigartige Fähigkeit bereit (Bindung 4 nötig).", "bad")
		end
	end
end

------------------------------------------------------------------------
-- Team-Verwaltung (Monster-Menü)
------------------------------------------------------------------------
function CompanionService:Manage(player: Player, action: string, arg: any): (boolean, string?)
	local d = S.DataService:Get(player)
	if not d then
		return false
	end
	if action == "toggleActive" then
		if type(arg) ~= "string" or not d.monsters[arg] then
			return false, "Unbekanntes Monster"
		end
		local idx = table.find(d.activeTeam, arg)
		if idx then
			table.remove(d.activeTeam, idx)
		else
			if #d.activeTeam >= Formulas.activeSlots(d) then
				return false, "Alle Gefährtenplätze belegt"
			end
			table.insert(d.activeTeam, arg)
		end
		-- Slots neu nummerieren
		for i, uid in d.activeTeam do
			local ce = self:GetSummoned(player)[uid]
			if ce then
				ce.state.slot = i
			end
		end
		S.DataService:MarkDirty(player)
		self:Sync(player)
		return true
	elseif action == "release" then
		if type(arg) ~= "string" or not d.monsters[arg] then
			return false, "Unbekanntes Monster"
		end
		if TableUtil.count(d.monsters) <= 1 then
			return false, "Du kannst dein letztes Monster nicht freilassen"
		end
		local rec = d.monsters[arg]
		local idx = table.find(d.activeTeam, arg)
		if idx then
			table.remove(d.activeTeam, idx)
		end
		d.monsters[arg] = nil
		self:Dismiss(player, arg)
		S.InventoryService:AddCoins(player, 5 * rec.level, false)
		S.DataService:MarkDirty(player)
		return true
	elseif action == "setAura" then
		if type(arg) ~= "string" or (arg ~= "" and not d.cosmetics[arg]) then
			return false, "Aura nicht freigeschaltet"
		end
		d.activeAura = arg
		for _, ce in self:GetSummoned(player) do
			MonsterFactory.applyAura(ce.model, arg)
		end
		S.DataService:MarkDirty(player)
		return true
	end
	return false, "Unbekannte Aktion"
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------
function CompanionService:Start()
	Net.event("CompanionCommand").OnServerEvent:Connect(function(player, cmd, arg)
		if type(cmd) ~= "string" or not commandLimiter:check(player) then
			return
		end
		self:Command(player, cmd, arg)
	end)

	Net.func("ManageMonsters").OnServerInvoke = function(player, action, arg)
		if type(action) ~= "string" or not manageLimiter:check(player) then
			return false, "Zu schnell"
		end
		return self:Manage(player, action, arg)
	end

	Net.func("ChooseStarter").OnServerInvoke = function(player, speciesId)
		local d = S.DataService:Get(player)
		if not d or d.starterChosen or type(speciesId) ~= "string" then
			return false
		end
		if not table.find(GameConfig.StarterMonsters, speciesId) then
			return false
		end
		d.starterChosen = true
		local uid = self:CreateRecord(player, speciesId, 3)
		if uid then
			d.monsters[uid].bondXp = 30
		end
		Notifier.send(player, ("%s ist jetzt dein Gefährte!"):format(Monsters[speciesId].name), "epic")
		self:Sync(player)
		return true
	end

	ES:OnDeath(function(e)
		if e.kind == "Companion" and e.owner and e.uid then
			local player = e.owner
			local d = S.DataService:Get(player)
			local rec = d and d.monsters[e.uid]
			if rec then
				rec.exhaustedUntil = os.time() + GameConfig.CompanionExhaustTime
				S.DataService:MarkDirty(player)
				Notifier.send(
					player,
					("%s ist erschöpft und erholt sich (%d s)."):format(Formulas.stageName(rec.species, rec.level), GameConfig.CompanionExhaustTime),
					"bad"
				)
			end
			local list = summoned[player]
			if list then
				list[e.uid] = nil
			end
		elseif e.kind == "Player" and e.player then
			self:DismissAll(e.player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:DismissAll(player)
		summoned[player] = nil
		modes[player] = nil
		focus[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("CompanionMode", "Verteidigen")
	end)

	-- Team-Abgleich
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if S.DataService:IsLoaded(player) then
					self:Sync(player)
				end
			end
		end
	end)

	-- KI-Schleife
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, list in summoned do
				for _, ce in list do
					local ok, err = pcall(companionTick, player, ce)
					if not ok then
						warn("[CompanionService]", err)
					end
				end
			end
		end
	end)
end

return CompanionService
