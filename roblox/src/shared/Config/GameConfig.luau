--!strict
-- Zentrale Spielkonstanten. Alle Balancing-Werte, die nicht zu einem
-- bestimmten Monster/Item gehören, stehen hier.

local GameConfig = {
	DataStoreName = "Freeland_PlayerData_v1",
	AutosaveInterval = 120, -- Sekunden

	MaxPlayerLevel = 50,
	MaxMonsterLevel = 50,
	MaxBondLevel = 5,

	-- Aktive Gefährten: Start 1, weitere Plätze durch Spielfortschritt.
	CompanionSlots = {
		{ level = 1, slots = 1 },
		{ level = 10, slots = 2 },
		{ level = 25, slots = 3 },
	},
	MaxActiveCompanions = 4, -- absolute Obergrenze (inkl. Klassenbonus)

	BaseStorage = 30, -- Monster im Gehege
	StorageUpgradeSize = 20,
	MaxStorage = 300,

	StartCoins = 150,
	StartItems = { Heiltrank = 3, Lockfrucht = 3 },
	StarterMonsters = { "Moosling", "Kieselkrabbe", "Funkenmaus" },

	-- Kampf
	CritMultiplier = 1.6,
	BaseCritChance = 0.05,
	OutOfCombatRegenDelay = 6, -- Sekunden ohne Schaden
	OutOfCombatRegenPct = 0.03, -- pro Sekunde
	CompanionExhaustTime = 45, -- Sekunden bis ein besiegter Gefährte wieder einsatzbereit ist
	CompanionTeleportDistance = 70,
	CompanionAssistRadius = 35,
	LeashDistance = 90,
	WildDamageMult = 0.7, -- wilde Monster verursachen etwas weniger Schaden

	-- Fangen (Vertrauensritual)
	CaptureHpThreshold = 0.35, -- Ritual erst unter 35 % HP möglich
	CaptureRitualDuration = 2.5,
	CaptureFailCooldown = 4,

	-- Bindung: EP-Quellen
	BondXp = {
		Kill = 4,
		BossKill = 60,
		ExploreGate = 30,
		Training = 15,
		Quest = 50,
	},
	TrainingCooldown = 45,

	-- Kommunikation (kein Chat!)
	EmoteCooldown = 1.5,
	EmoteDuration = 3.5,
	PingCooldown = 2,
	PingDuration = 9,
	PingMaxDistance = 400, -- maximale Entfernung des Markers zum Spieler
	PingMaxActive = 3,
	PingVisibleRange = 600,

	-- Wirtschaft
	SellValueFactor = 0.3,
}

return GameConfig
