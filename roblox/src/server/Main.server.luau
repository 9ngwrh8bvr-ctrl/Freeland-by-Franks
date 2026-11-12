--!strict
-- Einstiegspunkt des Servers: lädt alle Dienste in fester Reihenfolge.

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"DataService",
	"WorldService",
	"EntityService",
	"InventoryService",
	"ProgressionService",
	"QuestService",
	"ClassService",
	"CompanionService",
	"CombatService",
	"AIService",
	"SpawnService",
	"CaptureService",
	"ExplorationService",
	"ShopService",
	"CommunicationService",
}

local registry: { [string]: any } = {}
for _, name in ORDER do
	registry[name] = require(Services:WaitForChild(name) :: ModuleScript)
end
for _, name in ORDER do
	local s = registry[name]
	if s.Init then
		s:Init(registry)
	end
end
for _, name in ORDER do
	local s = registry[name]
	if s.Start then
		task.spawn(function()
			s:Start()
		end)
	end
end

print("[Freeland] Server gestartet.")
