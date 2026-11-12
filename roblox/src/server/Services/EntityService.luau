--!strict
-- Verwaltet alle Kampfteilnehmer (Spieler, Gefährten, wilde Monster):
-- Lebenspunkte, Schaden, Heilung, Buffs/Debuffs, Schilde, Tarnung, Tod.
-- Die gesamte Kampflogik läuft auf dem Server (Schutz vor Exploits).

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Monsters = require(Shared.Config.Monsters)
local Elements = require(Shared.Config.Elements)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)
local MonsterFactory = require(script.Parent.Parent.Modules.MonsterFactory)

export type Buff = { stat: string, amount: number, expires: number, key: string }
export type Entity = {
	id: number,
	kind: string, -- "Player" | "Companion" | "Wild"
	team: string, -- "Players" | "Wild"
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	player: Player?, -- bei kind == "Player"
	owner: Player?, -- bei kind == "Companion"
	uid: string?, -- Monster-Record (Gefährte)
	speciesId: string?,
	level: number,
	element: string,
	stats: Formulas.Stats,
	mods: { [string]: number },
	hp: number,
	maxHp: number,
	dead: boolean,
	buffs: { Buff },
	shield: number,
	shieldUntil: number,
	stunnedUntil: number,
	stealthUntil: number,
	tauntTarget: Entity?,
	tauntUntil: number,
	cooldowns: { [string]: number },
	lastDamaged: number,
	lastAttack: number,
	threat: { [Entity]: number },
	damagedBy: { [Player]: boolean },
	companionsInvolved: { [Player]: { [string]: boolean } },
	target: Entity?,
	isBoss: boolean,
	zone: BasePart?,
	spawnPos: Vector3,
	-- frei nutzbar von KI/Diensten
	state: { [string]: any },
}

local EntityService = {}
local entities: { [number]: Entity } = {}
local byModel: { [Model]: Entity } = {}
local playerEntities: { [Player]: Entity } = {}
local nextId = 0
local deathCallbacks: { (Entity, Entity?) -> () } = {}
local damageCallbacks: { (Entity, Entity?, number) -> () } = {}
local spawnCallbacks: { (Entity) -> () } = {}
local folder: Folder
local damageEvent: RemoteEvent
local fxEvent: RemoteEvent
local S: any

local function now(): number
	return os.clock()
end

local function setupCollisionGroups()
	for _, g in { "Creatures", "Players" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(g)
		end)
	end
	PhysicsService:CollisionGroupSetCollidable("Creatures", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Creatures", "Creatures", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
end

local function syncHp(e: Entity)
	if e.kind == "Player" then
		e.humanoid.MaxHealth = e.maxHp
		e.humanoid.Health = math.max(e.hp, 0)
	else
		e.model:SetAttribute("HP", math.max(0, math.floor(e.hp)))
		e.model:SetAttribute("MaxHP", e.maxHp)
	end
end

local function fireNear(event: RemoteEvent, pos: Vector3, radius: number, ...)
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - pos).Magnitude <= radius then
			event:FireClient(p, ...)
		end
	end
end

local function newEntity(kind: string, team: string, model: Model, root: BasePart, humanoid: Humanoid): Entity
	nextId += 1
	local e: Entity = {
		id = nextId,
		kind = kind,
		team = team,
		model = model,
		root = root,
		humanoid = humanoid,
		player = nil,
		owner = nil,
		uid = nil,
		speciesId = nil,
		level = 1,
		element = "Neutral",
		stats = { hp = 100, atk = 10, def = 5, spd = 16, crit = 0.05 },
		mods = {},
		hp = 100,
		maxHp = 100,
		dead = false,
		buffs = {},
		shield = 0,
		shieldUntil = 0,
		stunnedUntil = 0,
		stealthUntil = 0,
		tauntTarget = nil,
		tauntUntil = 0,
		cooldowns = {},
		lastDamaged = 0,
		lastAttack = 0,
		threat = {},
		damagedBy = {},
		companionsInvolved = {},
		target = nil,
		isBoss = false,
		zone = nil,
		spawnPos = root.Position,
		state = {},
	}
	entities[e.id] = e
	byModel[model] = e
	model:SetAttribute("EntityId", e.id)
	model:SetAttribute("Kind", kind)
	return e
end

------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------
function EntityService:Init(services)
	S = services
	setupCollisionGroups()
	local f = Workspace:FindFirstChild("Entities")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Entities"
		f.Parent = Workspace
	end
	folder = f :: Folder
	damageEvent = Net.event("DamageNumber")
	fxEvent = Net.event("AbilityFx")
end

function EntityService:Start()
	local function onCharacter(player: Player, character: Model)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = "Players"
			end
		end
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = "Players"
			end
		end)
		-- auf Profil warten
		while player.Parent and not S.DataService:IsLoaded(player) do
			task.wait(0.2)
		end
		if player.Parent and player.Character == character then
			self:RegisterPlayer(player, character)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(c)
			onCharacter(player, c)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local e = playerEntities[p]
		if e then
			self:Remove(e)
		end
	end)

	-- Regeneration außerhalb des Kampfes + Aufräumen abgelaufener Effekte
	task.spawn(function()
		while true do
			task.wait(0.5)
			local t = now()
			for _, e in entities do
				if e.dead then
					continue
				end
				for i = #e.buffs, 1, -1 do
					if e.buffs[i].expires <= t then
						table.remove(e.buffs, i)
					end
				end
				if e.shield > 0 and e.shieldUntil <= t then
					e.shield = 0
					e.model:SetAttribute("Shield", 0)
				end
				if e.stealthUntil > 0 and e.stealthUntil <= t then
					self:SetStealth(e, 0)
				end
				if e.kind == "Player" and e.stunnedUntil > 0 and e.stunnedUntil <= t then
					e.stunnedUntil = 0
					e.humanoid.WalkSpeed = 16
				end
				if e.kind ~= "Wild" and e.hp < e.maxHp and t - e.lastDamaged > GameConfig.OutOfCombatRegenDelay then
					e.hp = math.min(e.maxHp, e.hp + e.maxHp * GameConfig.OutOfCombatRegenPct * 0.5)
					syncHp(e)
				end
			end
		end
	end)
end

function EntityService:RegisterPlayer(player: Player, character: Model): Entity?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return nil
	end
	local old = playerEntities[player]
	if old then
		self:Remove(old)
	end
	local e = newEntity("Player", "Players", character, root, humanoid)
	e.player = player
	playerEntities[player] = e
	self:RefreshPlayer(player, true)
	humanoid.Died:Connect(function()
		if not e.dead then
			e.dead = true
			for _, cb in deathCallbacks do
				task.spawn(cb, e, nil)
			end
		end
	end)
	humanoid.HealthChanged:Connect(function(h)
		-- externe Änderungen (z. B. Fallen) übernehmen
		if not e.dead and math.abs(h - e.hp) > 1 then
			e.hp = h
		end
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil and entities[e.id] then
			self:Remove(e)
		end
	end)
	for _, cb in spawnCallbacks do
		task.spawn(cb, e)
	end
	return e
end

-- Werte des Spielers aus dem Profil neu berechnen (Level, Klasse, Ausrüstung, Talente)
function EntityService:RefreshPlayer(player: Player, fullHeal: boolean?)
	local e = playerEntities[player]
	local profile = S.DataService:Get(player)
	if not e or not profile then
		return
	end
	local ratio = if e.maxHp > 0 then e.hp / e.maxHp else 1
	e.stats = Formulas.playerStats(profile)
	e.mods = Formulas.aggregateMods(profile)
	e.level = profile.level
	e.maxHp = e.stats.hp
	e.hp = if fullHeal then e.maxHp else math.max(1, math.floor(e.maxHp * ratio))
	syncHp(e)
	player:SetAttribute("Level", profile.level)
	player:SetAttribute("ClassId", profile.classId)
end

export type SpawnOptions = {
	speciesId: string,
	level: number,
	kind: string, -- "Wild" | "Companion"
	position: Vector3,
	owner: Player?,
	uid: string?,
	bondXp: number?,
	potential: number?,
	mods: { [string]: number }?,
	zone: BasePart?,
	displayName: string?,
}

function EntityService:SpawnMonster(opts: SpawnOptions): Entity
	local sp = Monsters[opts.speciesId]
	local model = MonsterFactory.build(opts.speciesId, opts.level)
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	model:PivotTo(CFrame.new(opts.position + Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight + 0.5, 0)))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local team = if opts.kind == "Wild" then "Wild" else "Players"
	local e = newEntity(opts.kind, team, model, root, humanoid)
	e.speciesId = opts.speciesId
	e.level = opts.level
	e.element = sp.element
	e.owner = opts.owner
	e.uid = opts.uid
	e.zone = opts.zone
	e.isBoss = sp.isBoss == true
	e.stats = Formulas.monsterStats(opts.speciesId, opts.level, opts.bondXp or 0, opts.potential, opts.mods)
	e.maxHp = e.stats.hp
	e.hp = e.maxHp
	e.spawnPos = root.Position
	if opts.owner then
		local ownerMods = S.DataService:Get(opts.owner)
		e.mods = if ownerMods then Formulas.aggregateMods(ownerMods) else {}
	end

	model:SetAttribute("SpeciesId", opts.speciesId)
	model:SetAttribute("DisplayName", opts.displayName or Formulas.stageName(opts.speciesId, opts.level))
	model:SetAttribute("Level", opts.level)
	model:SetAttribute("Element", sp.element)
	model:SetAttribute("Rarity", sp.rarity)
	model:SetAttribute("Boss", e.isBoss)
	model:SetAttribute("OwnerUserId", if opts.owner then opts.owner.UserId else 0)
	model:SetAttribute("Uid", opts.uid or "")
	syncHp(e)
	humanoid.WalkSpeed = e.stats.spd

	for _, cb in spawnCallbacks do
		task.spawn(cb, e)
	end
	return e
end

function EntityService:Remove(e: Entity)
	if not entities[e.id] then
		return
	end
	entities[e.id] = nil
	byModel[e.model] = nil
	if e.player and playerEntities[e.player] == e then
		playerEntities[e.player] = nil
	end
	if e.kind ~= "Player" then
		e.model:Destroy()
	end
	-- Referenzen in Bedrohungslisten entfernen
	for _, other in entities do
		other.threat[e] = nil
		if other.target == e then
			other.target = nil
		end
		if other.tauntTarget == e then
			other.tauntTarget = nil
		end
	end
end

------------------------------------------------------------------------
-- Abfragen
------------------------------------------------------------------------
function EntityService:Get(id: number): Entity?
	return entities[id]
end

function EntityService:FromModel(model: Instance?): Entity?
	if not model then
		return nil
	end
	local inst: Instance? = model
	while inst and inst ~= Workspace do
		if inst:IsA("Model") then
			local e = byModel[inst]
			if e then
				return e
			end
		end
		inst = inst.Parent
	end
	return nil
end

function EntityService:ForPlayer(player: Player): Entity?
	return playerEntities[player]
end

function EntityService:All(): { [number]: Entity }
	return entities
end

function EntityService:IsAlive(e: Entity?): boolean
	return e ~= nil and not e.dead and entities[e.id] ~= nil
end

function EntityService:Position(e: Entity): Vector3
	return e.root.Position
end

function EntityService:Radius(e: Entity): number
	if e.kind == "Player" then
		return 1.5
	end
	return math.max(e.root.Size.X, e.root.Size.Z) / 2
end

function EntityService:Distance(a: Entity, b: Entity): number
	return math.max(0, (a.root.Position - b.root.Position).Magnitude - self:Radius(a) - self:Radius(b))
end

function EntityService:Hostile(a: Entity, b: Entity): boolean
	return a.team ~= b.team
end

function EntityService:InRadius(pos: Vector3, radius: number, filter: ((Entity) -> boolean)?): { Entity }
	local out = {}
	for _, e in entities do
		if not e.dead and (e.root.Position - pos).Magnitude - self:Radius(e) <= radius then
			if not filter or filter(e) then
				table.insert(out, e)
			end
		end
	end
	return out
end

function EntityService:Nearest(pos: Vector3, radius: number, filter: ((Entity) -> boolean)?): Entity?
	local best, bestD = nil, radius
	for _, e in entities do
		if not e.dead then
			local d = (e.root.Position - pos).Magnitude - self:Radius(e)
			if d <= bestD and (not filter or filter(e)) then
				best, bestD = e, d
			end
		end
	end
	return best
end

function EntityService:IsStealthed(e: Entity): boolean
	return e.stealthUntil > now()
end

function EntityService:IsStunned(e: Entity): boolean
	return e.stunnedUntil > now()
end

-- Verantwortlicher Spieler (Spieler selbst oder Besitzer des Gefährten)
function EntityService:ResponsiblePlayer(e: Entity?): Player?
	if not e then
		return nil
	end
	return e.player or e.owner
end

------------------------------------------------------------------------
-- Werte & Effekte
------------------------------------------------------------------------
function EntityService:GetStat(e: Entity, stat: string): number
	local base = (e.stats :: any)[stat] or 0
	local add = 0
	local t = now()
	for _, b in e.buffs do
		if b.stat == stat and b.expires > t then
			add += b.amount
		end
	end
	if stat == "crit" then
		return base + add
	end
	return base * math.max(0.2, 1 + add)
end

function EntityService:AddBuff(e: Entity, stat: string, amount: number, duration: number, key: string)
	for i, b in e.buffs do
		if b.key == key then
			table.remove(e.buffs, i)
			break
		end
	end
	table.insert(e.buffs, { stat = stat, amount = amount, expires = now() + duration, key = key })
end

function EntityService:AddShield(e: Entity, amount: number, duration: number)
	e.shield = math.max(e.shield, amount)
	e.shieldUntil = now() + duration
	e.model:SetAttribute("Shield", e.shield)
end

function EntityService:Stun(e: Entity, duration: number)
	if e.isBoss then
		duration *= 0.4 -- Bosse sind widerstandsfähiger
	end
	e.stunnedUntil = now() + duration
	if e.kind == "Player" then
		e.humanoid.WalkSpeed = 0
	else
		e.humanoid:MoveTo(e.root.Position)
	end
end

function EntityService:SetStealth(e: Entity, duration: number)
	if duration > 0 then
		e.stealthUntil = now() + duration
		e.model:SetAttribute("Stealthed", true)
		-- Gegner verlieren das Ziel
		for _, other in entities do
			if other.target == e then
				other.target = nil
			end
			other.threat[e] = nil
		end
	else
		e.stealthUntil = 0
		e.model:SetAttribute("Stealthed", false)
	end
end

function EntityService:Taunt(source: Entity, radius: number, duration: number)
	for _, e in self:InRadius(source.root.Position, radius, function(o)
		return self:Hostile(o, source)
	end) do
		e.tauntTarget = source
		e.tauntUntil = now() + duration
		e.threat[source] = (e.threat[source] or 0) + 200
	end
end

------------------------------------------------------------------------
-- Schaden & Heilung
------------------------------------------------------------------------
export type DamageOpts = { element: string?, executeBonus: number?, forceCrit: boolean? }

function EntityService:DealDamage(source: Entity, target: Entity, power: number, opts: DamageOpts?): number
	if target.dead or source.dead then
		return 0
	end
	local o = opts or {}
	local element = o.element
	if (element == nil or element == "Neutral") and source.kind ~= "Player" then
		element = source.element
	end
	local crit = o.forceCrit == true or math.random() < self:GetStat(source, "crit")
	if self:IsStealthed(source) then
		crit = true
		self:SetStealth(source, 0)
	end
	local mult = Elements.multiplier(element, target.element)
	local dmg = Formulas.damage(power, self:GetStat(source, "atk"), self:GetStat(target, "def"), mult, crit, 0.9 + math.random() * 0.2)
	if source.kind == "Wild" then
		dmg = math.max(1, math.floor(dmg * GameConfig.WildDamageMult))
	end
	if o.executeBonus and target.hp / target.maxHp < 0.3 then
		dmg = math.floor(dmg * (1 + o.executeBonus))
	end

	-- Schild
	if target.shield > 0 then
		local absorbed = math.min(target.shield, dmg)
		target.shield -= absorbed
		dmg -= absorbed
		target.model:SetAttribute("Shield", target.shield)
	end

	target.hp -= dmg
	target.lastDamaged = now()
	source.lastAttack = now()
	if source.kind == "Player" or source.kind == "Companion" then
		source.lastDamaged = math.max(source.lastDamaged, now() - GameConfig.OutOfCombatRegenDelay + 2)
	end

	-- Bedrohung & Belohnungs-Anrecht
	if target.kind == "Wild" then
		target.threat[source] = (target.threat[source] or 0) + dmg
		local responsible = self:ResponsiblePlayer(source)
		if responsible then
			target.damagedBy[responsible] = true
			if source.kind == "Companion" and source.uid then
				target.companionsInvolved[responsible] = target.companionsInvolved[responsible] or {}
				target.companionsInvolved[responsible][source.uid] = true
			end
		end
	end

	syncHp(target)
	fireNear(damageEvent, target.root.Position, 150, target.model, dmg, if crit then "crit" else "dmg", mult)

	for _, cb in damageCallbacks do
		task.spawn(cb, target, source, dmg)
	end
	if target.hp <= 0 then
		self:Kill(target, source)
	end
	return dmg
end

function EntityService:Heal(source: Entity?, target: Entity, amount: number)
	if target.dead then
		return
	end
	local healMult = 1
	if source then
		healMult += source.mods.healPct or 0
	end
	local value = math.floor(amount * healMult)
	target.hp = math.min(target.maxHp, target.hp + value)
	syncHp(target)
	fireNear(damageEvent, target.root.Position, 150, target.model, value, "heal", 1)
end

function EntityService:SetFullHp(e: Entity)
	e.hp = e.maxHp
	syncHp(e)
end

function EntityService:Kill(e: Entity, killer: Entity?)
	if e.dead then
		return
	end
	e.dead = true
	e.hp = 0
	syncHp(e)
	for _, cb in deathCallbacks do
		task.spawn(cb, e, killer)
	end
	if e.kind == "Player" then
		e.humanoid.Health = 0
	else
		e.humanoid:MoveTo(e.root.Position)
		for _, d in e.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		task.delay(0.6, function()
			self:Remove(e)
		end)
	end
end

function EntityService:Fx(abilityId: string, source: Entity, target: Entity?, position: Vector3?)
	fireNear(
		fxEvent,
		source.root.Position,
		250,
		abilityId,
		source.model,
		if target then target.model else nil,
		position or (if target then target.root.Position else source.root.Position)
	)
end

------------------------------------------------------------------------
-- Ereignisse
------------------------------------------------------------------------
function EntityService:OnDeath(cb: (Entity, Entity?) -> ())
	table.insert(deathCallbacks, cb)
end

function EntityService:OnDamaged(cb: (Entity, Entity?, number) -> ())
	table.insert(damageCallbacks, cb)
end

function EntityService:OnSpawned(cb: (Entity) -> ())
	table.insert(spawnCallbacks, cb)
end

function EntityService:FireNear(event: RemoteEvent, pos: Vector3, radius: number, ...)
	fireNear(event, pos, radius, ...)
end

return EntityService
