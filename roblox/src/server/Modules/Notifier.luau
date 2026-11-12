--!strict
-- Kurze Hinweise an einen Spieler. Texte kommen ausschließlich vom Server
-- (keine Spielertexte → kein Chat).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local notifyEvent = Net.event("Notify")

local Notifier = {}

-- kind: "info" | "good" | "bad" | "epic"
function Notifier.send(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "info")
end

return Notifier
