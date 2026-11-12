--!strict
-- Baut eine Test-Welt, falls im Workspace noch kein Ordner "Map" existiert.
-- So ist das Spiel sofort in Roblox Studio spielbar. Sobald du eine eigene
-- Karte baust (Ordner "Map"), wird diese Test-Welt nicht mehr erzeugt.
--
-- Die Test-Welt zeigt, wie man Zonen und Tore per Tag + Attributen anlegt:
--   MonsterSpawnZone, ExploreGate, TrainingSpot, RestSpot, HiddenRune

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldService = {}
local map: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or map
	return p
end

local function zone(name: string, pos: Vector3, size: Vector3, species: string, minL: number, maxL: number, count: number, respawn: number): Part
	local z = part({
		Name = "Zone_" .. name,
		Position = pos,
		Size = size,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	z:SetAttribute("Species", species)
	z:SetAttribute("MinLevel", minL)
	z:SetAttribute("MaxLevel", maxL)
	z:SetAttribute("MaxCount", count)
	z:SetAttribute("Respawn", respawn)
	CollectionService:AddTag(z, "MonsterSpawnZone")
	return z
end

local function gate(props: { [string]: any }, attrs: { [string]: any }): Part
	local g = part(props)
	for k, v in attrs do
		g:SetAttribute(k, v)
	end
	CollectionService:AddTag(g, "ExploreGate")
	return g
end

local function link(from: Instance, name: string, target: Instance)
	local ov = Instance.new("ObjectValue")
	ov.Name = name
	ov.Value = target
	ov.Parent = from
end

local function sign(at: Vector3, text: string)
	local post = part({ Name = "Schild", Position = at, Size = Vector3.new(0.6, 6, 0.6), Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Wood })
	local board = part({ Name = "Tafel", Position = at + Vector3.new(0, 3.5, 0), Size = Vector3.new(7, 2.4, 0.4), Color = Color3.fromRGB(140, 105, 65), Material = Enum.Material.Wood })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Cartoon
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.Text = text
	label.Parent = gui
	local back = gui:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = board
	post.Name = "Schild_" .. text
end

local function tree(at: Vector3, scale: number?)
	local s = scale or 1
	part({ Name = "Stamm", Position = at + Vector3.new(0, 5 * s, 0), Size = Vector3.new(2 * s, 10 * s, 2 * s), Color = Color3.fromRGB(105, 75, 45), Material = Enum.Material.Wood })
	part({ Name = "Krone", Shape = Enum.PartType.Ball, Position = at + Vector3.new(0, 12 * s, 0), Size = Vector3.one * 9 * s, Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass })
end

local function chest(at: Vector3, gateId: string, reward: string, requiresGate: string?): Part
	local c = gate({
		Name = "Truhe_" .. gateId,
		Position = at + Vector3.new(0, 1, 0),
		Size = Vector3.new(3, 2, 2),
		Color = Color3.fromRGB(170, 120, 40),
		Material = Enum.Material.Wood,
	}, { GateId = gateId, Trait = "", Action = "Loot", Reward = reward, Label = "Truhe öffnen", RequiresGate = requiresGate or "" })
	return c
end

local function buildWorld()
	map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	-- Standard-Baseplate von Studio entfernen (eigener Boden folgt)
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 130)

	-- Boden
	part({ Name = "Boden", Position = Vector3.new(0, -1, 0), Size = Vector3.new(900, 2, 900), Color = Color3.fromRGB(95, 160, 80), Material = Enum.Material.Grass })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(230, 200, 120)
	spawn.Material = Enum.Material.Cobblestone
	spawn.Duration = 0
	spawn.Parent = map

	---------------------------------------------------------------------
	-- Dorf Lindenhain
	---------------------------------------------------------------------
	part({ Name = "Dorfplatz", Position = Vector3.new(0, 0.05, 0), Size = Vector3.new(60, 0.2, 60), Color = Color3.fromRGB(180, 170, 150), Material = Enum.Material.Cobblestone })
	local rest = part({ Name = "Lagerfeuer", Position = Vector3.new(14, 0.8, 10), Size = Vector3.new(4, 1.5, 4), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon })
	local fire = Instance.new("Fire")
	fire.Parent = rest
	CollectionService:AddTag(rest, "RestSpot")
	local dummy = part({ Name = "Trainingspuppe", Position = Vector3.new(-14, 3, 10), Size = Vector3.new(2.5, 6, 2.5), Color = Color3.fromRGB(190, 160, 110), Material = Enum.Material.Fabric })
	CollectionService:AddTag(dummy, "TrainingSpot")
	sign(Vector3.new(0, 3, -26), "↑ Wiesen")
	sign(Vector3.new(26, 3, 0), "→ Wald")
	sign(Vector3.new(-26, 3, 0), "← Felsen")
	sign(Vector3.new(0, 3, 26), "↓ Sumpf")
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		part({ Name = "Haus", Position = Vector3.new(math.cos(a) * 24, 4, math.sin(a) * 24), Size = Vector3.new(10, 8, 10), Color = Color3.fromRGB(220, 200, 170), Material = Enum.Material.Brick })
		part({ Name = "Dach", Position = Vector3.new(math.cos(a) * 24, 9, math.sin(a) * 24), Size = Vector3.new(11, 2, 11), Color = Color3.fromRGB(150, 60, 50), Material = Enum.Material.Slate })
	end

	---------------------------------------------------------------------
	-- Zonen
	---------------------------------------------------------------------
	zone("Wiesen", Vector3.new(0, 1, -110), Vector3.new(140, 2, 90), "Moosling,Kieselkrabbe,Funkenmaus,Brisenspatz", 1, 5, 10, 6)
	zone("Wald", Vector3.new(170, 1, 0), Vector3.new(110, 2, 140), "Moosling,Gluehkaefer,Feuerwolf,Naturgeist,Funkenmaus", 5, 12, 9, 8)
	zone("Felsen", Vector3.new(-170, 1, 0), Vector3.new(110, 2, 140), "Kieselkrabbe,Steingolem,Windfalke,Brisenspatz", 6, 14, 9, 8)
	zone("Sumpf", Vector3.new(0, 1, 180), Vector3.new(150, 2, 100), "Schattenwesen,Wasserdrache,Gluehkaefer,Funkenmaus", 10, 20, 9, 10)
	zone("Vulkanhang", Vector3.new(0, 1, -280), Vector3.new(140, 2, 70), "Funkenmaus,Feuerwolf", 12, 20, 7, 9)

	for i = 1, 14 do
		tree(Vector3.new(130 + (i % 4) * 25 + math.random(-5, 5), 0, -60 + math.floor(i / 4) * 35 + math.random(-5, 5)), 1 + math.random() * 0.4)
	end
	for i = 1, 10 do
		part({ Name = "Fels", Position = Vector3.new(-130 - (i % 4) * 25, 3, -60 + math.floor(i / 4) * 40), Size = Vector3.new(8, 6 + i % 3 * 3, 8), Color = Color3.fromRGB(130, 125, 120), Material = Enum.Material.Slate })
	end
	part({ Name = "Sumpfwasser", Position = Vector3.new(0, 0.1, 180), Size = Vector3.new(150, 0.2, 100), Color = Color3.fromRGB(60, 80, 70), Material = Enum.Material.Mud })

	-- Boss-Arena am Vulkanpass
	part({ Name = "Vulkanboden", Position = Vector3.new(0, 0.1, -360), Size = Vector3.new(90, 0.2, 90), Color = Color3.fromRGB(60, 40, 35), Material = Enum.Material.Basalt })
	for i = 1, 8 do
		local a = i * math.pi / 4
		part({ Name = "Lavasaeule", Position = Vector3.new(math.cos(a) * 42, 6, -360 + math.sin(a) * 42), Size = Vector3.new(4, 12, 4), Color = Color3.fromRGB(255, 90, 30), Material = Enum.Material.Neon })
	end
	zone("Glutkoloss", Vector3.new(0, 1, -360), Vector3.new(10, 2, 10), "Glutkoloss", 15, 15, 1, 180)
	sign(Vector3.new(0, 3, -310), "⚠ Glutkoloss")

	---------------------------------------------------------------------
	-- Erkundung mit Monsterfähigkeiten
	---------------------------------------------------------------------
	-- 1) Zerschmettern: Felsblock versperrt eine Nische mit Truhe
	part({ Name = "Nischenwand", Position = Vector3.new(-60, 6, -40), Size = Vector3.new(2, 12, 16), Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate })
	part({ Name = "Nischenwand", Position = Vector3.new(-50, 6, -48), Size = Vector3.new(20, 12, 2), Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate })
	part({ Name = "Nischenwand", Position = Vector3.new(-50, 6, -32), Size = Vector3.new(20, 12, 2), Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate })
	gate({ Name = "Felsblock", Position = Vector3.new(-40, 5, -40), Size = Vector3.new(4, 10, 14), Color = Color3.fromRGB(100, 95, 90), Material = Enum.Material.Rock }, { GateId = "fels1", Trait = "Zerschmettern", Action = "Open" })
	chest(Vector3.new(-54, 0, -40), "truhe_fels1", "coins:120,Heiltrank:2", "fels1")

	-- 2) Fliegen: hohe Klippe mit Truhe
	local pillar = part({ Name = "Klippe", Position = Vector3.new(70, 30, 70), Size = Vector3.new(24, 60, 24), Color = Color3.fromRGB(140, 130, 115), Material = Enum.Material.Sandstone })
	local landing = part({ Name = "Klippenplateau", Position = Vector3.new(70, 60.5, 70), Size = Vector3.new(24, 1, 24), Color = Color3.fromRGB(100, 160, 80), Material = Enum.Material.Grass })
	local flyGate = gate({ Name = "Flugpunkt", Position = Vector3.new(70, 1.5, 55), Size = Vector3.new(6, 3, 2), Color = Color3.fromRGB(170, 240, 220), Material = Enum.Material.Neon, Transparency = 0.4 }, { GateId = "flug1", Trait = "Fliegen", Action = "Teleport" })
	link(flyGate, "Target", landing)
	local down = gate({ Name = "Abstieg", Position = Vector3.new(70, 62, 62), Size = Vector3.new(4, 2, 2), Color = Color3.fromRGB(200, 200, 200), Transparency = 0.5 }, { GateId = "abstieg1", Trait = "", Action = "Teleport", Label = "Hinabsteigen" })
	link(down, "Target", part({ Name = "AbstiegZiel", Position = Vector3.new(70, 1, 50), Size = Vector3.new(4, 1, 4), Transparency = 1, CanCollide = false }))
	chest(Vector3.new(74, 61, 74), "truhe_klippe", "coins:200,gems:5,Bindungssnack:1")
	pillar.Name = "Klippe"

	-- 3) Schwimmen: Unterwasser-Grotte (unter der Erde)
	local pool = gate({ Name = "Teich", Position = Vector3.new(-40, 0.2, 60), Size = Vector3.new(16, 0.4, 16), Color = Color3.fromRGB(50, 120, 220), Material = Enum.Material.Glass, Transparency = 0.3 }, { GateId = "tauchen1", Trait = "Schwimmen", Action = "Teleport" })
	local grottoFloor = part({ Name = "GrottenBoden", Position = Vector3.new(-40, -60, 60), Size = Vector3.new(30, 1, 30), Color = Color3.fromRGB(40, 70, 110), Material = Enum.Material.Slate })
	part({ Name = "GrottenDecke", Position = Vector3.new(-40, -46, 60), Size = Vector3.new(30, 1, 30), Color = Color3.fromRGB(40, 70, 110), Material = Enum.Material.Slate })
	for _, w in { { 15, 0 }, { -15, 0 }, { 0, 15 }, { 0, -15 } } do
		part({ Name = "GrottenWand", Position = Vector3.new(-40 + w[1], -53, 60 + w[2]), Size = Vector3.new(if w[1] == 0 then 30 else 1, 14, if w[2] == 0 then 30 else 1), Color = Color3.fromRGB(40, 70, 110), Material = Enum.Material.Slate })
	end
	local glow = Instance.new("PointLight")
	glow.Range = 30
	glow.Color = Color3.fromRGB(100, 180, 255)
	glow.Parent = grottoFloor
	link(pool, "Target", grottoFloor)
	chest(Vector3.new(-45, -59.5, 65), "truhe_grotte", "coins:150,Tauperle:3,Perle:1")
	local up = gate({ Name = "Auftauchen", Position = Vector3.new(-35, -58, 55), Size = Vector3.new(4, 3, 4), Color = Color3.fromRGB(90, 160, 255), Material = Enum.Material.Neon, Transparency = 0.5 }, { GateId = "auftauchen1", Trait = "", Action = "Teleport", Label = "Auftauchen" })
	link(up, "Target", part({ Name = "TeichUfer", Position = Vector3.new(-40, 1, 72), Size = Vector3.new(4, 1, 4), Transparency = 1, CanCollide = false }))

	-- 4) Leuchten: dunkle Höhle mit Lichtsiegel
	local caveCenter = Vector3.new(-170, 0, -150)
	part({ Name = "HoehlenDecke", Position = caveCenter + Vector3.new(0, 14, 0), Size = Vector3.new(40, 2, 40), Color = Color3.fromRGB(50, 45, 45), Material = Enum.Material.Slate })
	part({ Name = "HoehlenWand", Position = caveCenter + Vector3.new(0, 7, -20), Size = Vector3.new(40, 14, 2), Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Slate })
	part({ Name = "HoehlenWand", Position = caveCenter + Vector3.new(-20, 7, 0), Size = Vector3.new(2, 14, 40), Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Slate })
	part({ Name = "HoehlenWand", Position = caveCenter + Vector3.new(20, 7, 0), Size = Vector3.new(2, 14, 40), Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Slate })
	part({ Name = "HoehlenWand", Position = caveCenter + Vector3.new(-12, 7, 20), Size = Vector3.new(16, 14, 2), Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Slate })
	part({ Name = "HoehlenWand", Position = caveCenter + Vector3.new(12, 7, 20), Size = Vector3.new(16, 14, 2), Color = Color3.fromRGB(60, 55, 55), Material = Enum.Material.Slate })
	local lights = Instance.new("Folder")
	lights.Name = "HoehlenLichter"
	lights.Parent = map
	for i = 1, 4 do
		local lamp = part({ Name = "Kristall", Parent = lights, Position = caveCenter + Vector3.new((i % 2 == 0 and 12 or -12), 3, (i <= 2 and 10 or -10)), Size = Vector3.new(1.5, 3, 1.5), Color = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Glass })
		local l = Instance.new("PointLight")
		l.Range = 24
		l.Brightness = 3
		l.Enabled = false
		l.Parent = lamp
	end
	local seal = gate({ Name = "Lichtsiegel", Position = caveCenter + Vector3.new(0, 7, 20), Size = Vector3.new(8, 14, 1), Color = Color3.fromRGB(20, 15, 25), Material = Enum.Material.Neon, Transparency = 0.1 }, { GateId = "licht1", Trait = "Leuchten", Action = "Light" })
	link(seal, "Lights", lights)
	chest(caveCenter + Vector3.new(0, 0, -14), "truhe_hoehle", "coins:180,Leuchtstaub:3,GrosserHeiltrank:1", "licht1")

	-- 5) Klein: Felsspalt
	part({ Name = "Felswand", Position = Vector3.new(-110, 8, 60), Size = Vector3.new(4, 16, 30), Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate })
	gate({ Name = "Felsspalt", Position = Vector3.new(-107.8, 2, 60), Size = Vector3.new(0.4, 4, 1.5), Color = Color3.fromRGB(20, 20, 20) }, { GateId = "spalt1", Trait = "Klein", Action = "Loot", Reward = "coins:90,Lockfrucht:3,Steinbrocken:2" })

	-- 6) Wachstum: drei verdorrte Bäume im Wald
	for i, pos in { Vector3.new(130, 0, 50), Vector3.new(160, 0, 70), Vector3.new(195, 0, 45) } do
		gate({ Name = "VerdorrterBaum", Position = pos + Vector3.new(0, 5, 0), Size = Vector3.new(2.5, 10, 2.5), Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.Wood }, { GateId = "baum" .. i, Trait = "Wachstum", Action = "Grow", Reward = "coins:60,Lebenssamen:1" })
	end

	-- 7) Runensicht: drei verborgene Runen im Sumpf (nur mit Schattenwesen sichtbar)
	for i, pos in { Vector3.new(-40, 0, 170), Vector3.new(30, 0, 200), Vector3.new(55, 0, 150) } do
		local rune = gate({ Name = "VerborgeneRune", Position = pos + Vector3.new(0, 2, 0), Size = Vector3.new(3, 4, 0.5), Color = Color3.fromRGB(170, 90, 255), Material = Enum.Material.Neon, Transparency = 1 }, { GateId = "rune" .. i, Trait = "Runensicht", Action = "Loot", Reward = "coins:80,Schattenessenz:1" })
		CollectionService:AddTag(rune, "HiddenRune")
	end

	-- 8) Drachenhorst: nur fliegend erreichbar, Uralter Drache
	part({ Name = "Drachenberg", Position = Vector3.new(260, 40, -260), Size = Vector3.new(70, 80, 70), Color = Color3.fromRGB(110, 95, 90), Material = Enum.Material.Basalt })
	local horst = part({ Name = "Drachenhorst", Position = Vector3.new(260, 80.5, -260), Size = Vector3.new(70, 1, 70), Color = Color3.fromRGB(90, 70, 60), Material = Enum.Material.Ground })
	local dragonGate = gate({ Name = "Drachenflugpunkt", Position = Vector3.new(220, 1.5, -230), Size = Vector3.new(6, 3, 2), Color = Color3.fromRGB(220, 60, 90), Material = Enum.Material.Neon, Transparency = 0.4 }, { GateId = "drachenhorst", Trait = "Fliegen", Action = "Teleport" })
	link(dragonGate, "Target", horst)
	local dragonDown = gate({ Name = "HorstAbstieg", Position = Vector3.new(232, 82, -232), Size = Vector3.new(4, 2, 2), Color = Color3.fromRGB(200, 200, 200), Transparency = 0.5 }, { GateId = "horstab", Trait = "", Action = "Teleport", Label = "Hinabsteigen" })
	link(dragonDown, "Target", part({ Name = "HorstAbstiegZiel", Position = Vector3.new(215, 1, -225), Size = Vector3.new(4, 1, 4), Transparency = 1, CanCollide = false }))
	zone("Drachenhorst", Vector3.new(270, 82, -270), Vector3.new(20, 2, 20), "UralterDrache", 35, 35, 1, 600)
	sign(Vector3.new(212, 3, -222), "Drachenhorst")
end

function WorldService:Init(_services)
	if not Workspace:FindFirstChild("Map") then
		buildWorld()
	end
end

return WorldService
