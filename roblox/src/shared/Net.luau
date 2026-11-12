--!strict
-- Netzwerk: alle RemoteEvents/RemoteFunctions an einem Ort.
-- Der Server legt sie an, der Client wartet darauf.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"ProfileUpdated", -- S→C  Profil-Snapshot
	"Notify", -- S→C  Hinweis (Text vom Server, kein Spielertext)
	"DamageNumber", -- S→C  Schadens-/Heilzahl
	"AbilityFx", -- S→C  Effekt abspielen
	"CombatAction", -- C→S  Angriff/Fähigkeit
	"CompanionCommand", -- C→S  Befehle an Gefährten
	"Emote", -- C→S / S→C Emoji
	"Ping", -- C→S / S→C Richtungspfeil
	"GateOpened", -- S→C  Erkundungstor lokal öffnen
	"CaptureResult", -- S→C
}

local FUNCTIONS = {
	"ChooseStarter",
	"ManageMonsters",
	"ManageClass",
	"ShopRequest",
	"UseItem",
	"EquipItem",
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
