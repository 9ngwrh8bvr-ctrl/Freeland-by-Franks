--!strict
-- Spielerdaten: Laden, Speichern (DataStore mit Sitzungssperre), Autosave
-- und das Senden von Profil-Snapshots an den Client.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TableUtil = require(Shared.Util.TableUtil)
local Net = require(Shared.Net)

local SESSION_LOCK_TIMEOUT = 600 -- Sekunden, danach gilt eine fremde Sperre als verwaist
local MAX_PURCHASE_HISTORY = 100

local TEMPLATE = {
	version = 1,
	level = 1,
	xp = 0,
	coins = GameConfig.StartCoins,
	gems = 0,
	classId = "Krieger",
	unlockedClasses = { Krieger = true, Waldlaeufer = true, Magier = true, Bestienbaendiger = true },
	talents = {}, -- [classId] = { [talentId] = rang }
	specialization = "", -- gewählte Spezialisierungsfähigkeit
	monsters = {}, -- [uid] = MonsterRecord
	activeTeam = {}, -- { uid }
	inventory = TableUtil.deepCopy(GameConfig.StartItems),
	equipment = {}, -- { weapon = itemId, armor = itemId, amulet = itemId }
	cosmetics = {}, -- [itemId] = true
	activeAura = "",
	storageUpgrades = 0,
	quests = { active = {}, completed = {}, progress = {} },
	flags = {},
	gates = {}, -- dauerhaft entdeckte Erkundungsorte
	stats = { kills = 0, captures = 0, bosses = 0 },
	starterChosen = false,
	purchaseHistory = {},
}

-- Diese Tabellen werden bei Datenmigration nicht mit Vorlagenwerten aufgefüllt
-- (sonst bekäme ein Spieler z. B. verbrauchte Startgegenstände zurück).
local MAP_KEYS = {
	inventory = true,
	unlockedClasses = true,
	monsters = true,
	cosmetics = true,
	flags = true,
	gates = true,
	talents = true,
	equipment = true,
}

type Profile = {
	data: any,
	canSave: boolean,
	dirty: boolean,
	passes: { [string]: boolean },
	released: boolean,
}

local DataService = {}
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, any) -> () } = {}
local removingCallbacks: { (Player, any) -> () } = {}
local store: DataStore? = nil
local profileUpdated: RemoteEvent

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function probeStore()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if not ok then
		warn("[DataService] DataStore nicht verfügbar – Spielstände werden NICHT gespeichert.", ds)
		return
	end
	local probeOk, err = pcall(function()
		return (ds :: DataStore):GetAsync("_probe")
	end)
	if not probeOk then
		warn(
			"[DataService] DataStore-Zugriff fehlgeschlagen (in Studio: Game Settings → Security → "
				.. "'Enable Studio Access to API Services' aktivieren). Speichern deaktiviert.",
			err
		)
		return
	end
	store = ds :: DataStore
end

local function loadData(player: Player): (any?, boolean)
	if not store then
		return TableUtil.deepCopy(TEMPLATE), false
	end
	local ds = store :: DataStore
	for attempt = 1, 6 do
		local ok, result = pcall(function()
			return ds:UpdateAsync(key(player), function(old)
				local data = old or TableUtil.deepCopy(TEMPLATE)
				local lock = data._lock
				if
					lock
					and lock.jobId ~= game.JobId
					and os.time() - (lock.time or 0) < SESSION_LOCK_TIMEOUT
					and attempt < 6
				then
					return nil -- anderer Server hält die Sperre noch → abbrechen, später erneut
				end
				data._lock = { jobId = game.JobId, time = os.time() }
				return data
			end)
		end)
		if ok and type(result) == "table" and result._lock and result._lock.jobId == game.JobId then
			return result, true
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(attempt * 1.5)
	end
	return nil, false
end

local function saveData(player: Player, release: boolean): boolean
	local prof = profiles[player]
	if not prof or not prof.canSave or not store then
		return true
	end
	local ds = store :: DataStore
	local snapshot = TableUtil.deepCopy(prof.data)
	local ok, err = pcall(function()
		ds:UpdateAsync(key(player), function(old)
			if old and old._lock and old._lock.jobId ~= game.JobId then
				-- Sperre verloren (anderer Server hat übernommen): nicht überschreiben
				return nil
			end
			snapshot._lock = if release then nil else { jobId = game.JobId, time = os.time() }
			return snapshot
		end)
	end)
	if not ok then
		warn("[DataService] Speichern fehlgeschlagen für", player.Name, err)
	end
	return ok
end

local function buildSnapshot(prof: Profile)
	local d = prof.data
	local snap = TableUtil.deepCopy(d)
	snap._lock = nil
	snap.purchaseHistory = nil
	snap.passes = TableUtil.deepCopy(prof.passes)
	snap.serverTime = os.time()
	return snap
end

function DataService:Init(_services)
	profileUpdated = Net.event("ProfileUpdated")
	probeStore()
end

function DataService:Start()
	local function onPlayerAdded(player: Player)
		local data, canSave = loadData(player)
		if not data then
			player:Kick("Deine Spieldaten konnten nicht geladen werden. Bitte versuche es gleich noch einmal.")
			return
		end
		if not player.Parent then
			return
		end
		TableUtil.reconcile(data, TEMPLATE, MAP_KEYS)
		profiles[player] = { data = data, canSave = canSave, dirty = true, passes = {}, released = false }
		for _, cb in loadedCallbacks do
			task.spawn(cb, player, data)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end

	Players.PlayerRemoving:Connect(function(player)
		local prof = profiles[player]
		if not prof then
			return
		end
		for _, cb in removingCallbacks do
			pcall(cb, player, prof.data)
		end
		saveData(player, true)
		prof.released = true
		profiles[player] = nil
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveData(player, true)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in profiles do
				task.spawn(saveData, player, false)
			end
		end
	end)

	-- Snapshots gebündelt senden
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player, prof in profiles do
				if prof.dirty then
					prof.dirty = false
					profileUpdated:FireClient(player, buildSnapshot(prof))
				end
			end
		end
	end)
end

function DataService:Get(player: Player): any?
	local prof = profiles[player]
	return prof and prof.data
end

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService:OnLoaded(cb: (Player, any) -> ())
	table.insert(loadedCallbacks, cb)
	for player, prof in profiles do
		task.spawn(cb, player, prof.data)
	end
end

function DataService:OnRemoving(cb: (Player, any) -> ())
	table.insert(removingCallbacks, cb)
end

function DataService:MarkDirty(player: Player)
	local prof = profiles[player]
	if prof then
		prof.dirty = true
	end
end

function DataService:SaveNow(player: Player): boolean
	return saveData(player, false)
end

function DataService:SetPass(player: Player, passKey: string, owned: boolean)
	local prof = profiles[player]
	if prof then
		prof.passes[passKey] = owned
		prof.dirty = true
		player:SetAttribute("Pass_" .. passKey, owned)
	end
end

function DataService:HasPass(player: Player, passKey: string): boolean
	local prof = profiles[player]
	return prof ~= nil and prof.passes[passKey] == true
end

-- Kaufhistorie für sichere, einmalige Gutschrift von Robux-Käufen
function DataService:HasPurchase(player: Player, purchaseId: string): boolean
	local d = self:Get(player)
	if not d then
		return false
	end
	return table.find(d.purchaseHistory, purchaseId) ~= nil
end

function DataService:RecordPurchase(player: Player, purchaseId: string)
	local d = self:Get(player)
	if not d then
		return
	end
	table.insert(d.purchaseHistory, purchaseId)
	while #d.purchaseHistory > MAX_PURCHASE_HISTORY do
		table.remove(d.purchaseHistory, 1)
	end
end

return DataService
