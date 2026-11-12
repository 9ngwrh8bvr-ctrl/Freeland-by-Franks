--!strict
-- Kommunikation zwischen Spielern NUR über vordefinierte Emojis und
-- Richtungspfeile (Marker in der Welt). Es gibt keinen Text-Chat und keinen
-- Sprach-Chat. Der Server prüft jede Nachricht gegen die erlaubte Liste.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Communication = require(Shared.Config.Communication)
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)

local CommunicationService = {}
local S: any
local emoteLimiter = RateLimiter.new(GameConfig.EmoteCooldown)
local pingLimiter = RateLimiter.new(GameConfig.PingCooldown)
local activePings: { [Player]: { number } } = {}

function CommunicationService:Init(services)
	S = services
end

-- Zusätzliche Absicherung: alle Text-Kanäle entfernen und Eingaben ablehnen.
local function disableTextChat()
	pcall(function()
		for _, d in TextChatService:GetDescendants() do
			if d:IsA("TextChannel") then
				d:Destroy()
			end
		end
		TextChatService.DescendantAdded:Connect(function(d)
			if d:IsA("TextChannel") then
				task.defer(function()
					d:Destroy()
				end)
			end
		end)
	end)
end

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

function CommunicationService:Start()
	disableTextChat()

	local emoteEvent = Net.event("Emote")
	emoteEvent.OnServerEvent:Connect(function(player, emojiId)
		if type(emojiId) ~= "string" or not emoteLimiter:check(player) then
			return
		end
		local emoji = Communication.findEmoji(emojiId)
		if not emoji then
			return
		end
		if (emoji :: any).vip and not S.DataService:HasPass(player, "VIP") then
			return
		end
		emoteEvent:FireAllClients(player, emojiId)
	end)

	local pingEvent = Net.event("Ping")
	pingEvent.OnServerEvent:Connect(function(player, pingId, position)
		if type(pingId) ~= "string" or typeof(position) ~= "Vector3" then
			return
		end
		if not Communication.findPing(pingId) or not isFiniteVector(position) then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - position).Magnitude > GameConfig.PingMaxDistance then
			return
		end
		-- max. gleichzeitige Marker pro Spieler
		local list = activePings[player] or {}
		activePings[player] = list
		local t = os.clock()
		for i = #list, 1, -1 do
			if list[i] <= t then
				table.remove(list, i)
			end
		end
		if #list >= GameConfig.PingMaxActive or not pingLimiter:check(player) then
			return
		end
		table.insert(list, t + GameConfig.PingDuration)
		for _, other in Players:GetPlayers() do
			local oc = other.Character
			local or_ = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
			if or_ and (or_.Position - position).Magnitude <= GameConfig.PingVisibleRange then
				pingEvent:FireClient(other, player, pingId, position)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		activePings[p] = nil
		emoteLimiter:clear(p)
		pingLimiter:clear(p)
	end)
end

return CommunicationService
