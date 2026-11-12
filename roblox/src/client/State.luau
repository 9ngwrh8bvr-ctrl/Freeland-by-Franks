--!strict
-- Gemeinsamer Client-Zustand: Profil-Snapshot vom Server, aktuelles Ziel,
-- geöffnetes Fenster.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local State = {
	profile = nil :: any,
	target = nil :: Model?,
	timeOffset = 0,
	pingMode = false,
	Changed = Instance.new("BindableEvent"), -- (profile)
	TargetChanged = Instance.new("BindableEvent"), -- (model?)
	OpenPanel = Instance.new("BindableEvent"), -- (name?)
}

Net.event("ProfileUpdated").OnClientEvent:Connect(function(profile)
	State.profile = profile
	if profile.serverTime then
		State.timeOffset = profile.serverTime - os.time()
	end
	State.Changed:Fire(profile)
end)

function State.serverTime(): number
	return os.time() + State.timeOffset
end

function State.setTarget(model: Model?)
	if State.target ~= model then
		State.target = model
		State.TargetChanged:Fire(model)
	end
end

return State
