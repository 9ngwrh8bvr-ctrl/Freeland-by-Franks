--!strict
-- Spawnt wilde Monster in Zonen.
--
-- Eine Zone ist ein Part mit dem CollectionService-Tag "MonsterSpawnZone"
-- und diesen Attributen:
--   Species  (string)  – Komma-Liste, z. B. "Moosling,Funkenmaus"
--   MinLevel (number)
--   MaxLevel (number)
--   MaxCount (number)  – gleichzeitig lebende Monster
--   Respawn  (number)  – Sekunden zwischen zwei Spawns
-- Monster spawnen nur, wenn ein Spieler in der Nähe ist (Leistung).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monsters = require(Shared.Config.Monsters)
local Rarities = require(Shared.Config.Rarities)

local ACTIVE_RANGE = 320 -- Spieler-Nähe, damit eine Zone aktiv ist
local DESPAWN_RANGE = 450
local RARITY_WEIGHT = {
	Gewoehnlich = 60,
	Ungewoehnlich = 25,
	Selten = 10,
	Episch = 4,
	Legendaer = 1,
	Einzigartig = 1,
}

local SpawnService = {}
local ES: any
local zoneState: { [BasePart]: { lastSpawn: number } } = {}

function SpawnService:Init(services)
	ES = services.EntityService
end

local function playerNear(pos: Vector3, range: number): boolean
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - pos).Magnitude <= range then
			return true
		end
	end
	return false
end

local function pickSpecies(list: { string }): string?
	local total = 0
	for _, id in list do
		local sp = Monsters[id]
		if sp then
			total += RARITY_WEIGHT[sp.rarity] or 1
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for _, id in list do
		local sp = Monsters[id]
		if sp then
			roll -= RARITY_WEIGHT[sp.rarity] or 1
			if roll <= 0 then
				return id
			end
		end
	end
	return list[#list]
end

local function groundPoint(zone: BasePart): Vector3
	local size = zone.Size
	local local_ = Vector3.new((math.random() - 0.5) * size.X, 0, (math.random() - 0.5) * size.Z)
	local top = zone.CFrame:PointToWorldSpace(local_) + Vector3.new(0, 60, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace:FindFirstChild("Entities") :: Instance, zone }
	local hit = Workspace:Raycast(top, Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else zone.Position
end

local function countAlive(zone: BasePart): number
	local n = 0
	for _, e in ES:All() do
		if e.zone == zone and not e.dead then
			n += 1
		end
	end
	return n
end

local function zoneTick(zone: BasePart)
	local st = zoneState[zone]
	if not st then
		st = { lastSpawn = -math.huge }
		zoneState[zone] = st
	end
	if not playerNear(zone.Position, ACTIVE_RANGE + zone.Size.Magnitude / 2) then
		return
	end
	local maxCount = zone:GetAttribute("MaxCount") or 5
	local respawn = zone:GetAttribute("Respawn") or 10
	if countAlive(zone) >= maxCount or os.clock() - st.lastSpawn < respawn then
		return
	end
	local list = string.split(zone:GetAttribute("Species") or "", ",")
	for i, s in list do
		list[i] = string.gsub(s, "%s", "")
	end
	local speciesId = pickSpecies(list)
	if not speciesId then
		return
	end
	local minL = zone:GetAttribute("MinLevel") or 1
	local maxL = zone:GetAttribute("MaxLevel") or minL
	st.lastSpawn = os.clock()
	local level = math.random(minL, math.max(minL, maxL))
	if Rarities.rank(Monsters[speciesId].rarity) >= 5 then
		level = maxL
	end
	ES:SpawnMonster({
		speciesId = speciesId,
		level = level,
		kind = "Wild",
		position = groundPoint(zone),
		zone = zone,
	})
end

function SpawnService:Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, zone in CollectionService:GetTagged("MonsterSpawnZone") do
				if zone:IsA("BasePart") then
					local ok, err = pcall(zoneTick, zone)
					if not ok then
						warn("[SpawnService]", err)
					end
				end
			end
			-- Monster ohne Spieler in der Nähe entfernen (Leistung)
			for _, e in ES:All() do
				if e.kind == "Wild" and not e.target and not playerNear(e.root.Position, DESPAWN_RANGE) then
					ES:Remove(e)
				end
			end
		end
	end)
end

return SpawnService
