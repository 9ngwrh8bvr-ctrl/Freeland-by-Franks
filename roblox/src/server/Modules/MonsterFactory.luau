--!strict
-- Baut Monster-Modelle. Liegt in ReplicatedStorage.Assets.Monsters ein
-- Model mit der Monster-ID (z. B. "Feuerwolf"), wird dieses verwendet –
-- so können echte 3D-Modelle aus Blender später einfach eingesetzt werden.
-- Sonst entsteht ein farbiger Platzhalter aus Bauteilen.
--
-- Anforderungen an eigene Modelle:
--   * Model mit PrimaryPart "HumanoidRootPart" und einem Humanoid
--   * optional: Animator im Humanoid + Animation-Objekte "Walk", "Attack", "Idle"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monsters = require(Shared.Config.Monsters)
local Elements = require(Shared.Config.Elements)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Formulas)

local MonsterFactory = {}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function newPart(name: string, shape: Enum.PartType?, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = true
	return p
end

local function buildPlaceholder(speciesId: string, scale: number): Model
	local sp = Monsters[speciesId]
	local el = Elements.List[sp.element] or Elements.List.Neutral
	local rarity = Rarities.List[sp.rarity]
	local sx, sy, sz = sp.size[1] * scale, sp.size[2] * scale, sp.size[3] * scale

	local model = Instance.new("Model")
	model.Name = speciesId

	local root = newPart("HumanoidRootPart", Enum.PartType.Block, Vector3.new(sx, sy, sz), el.color)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.Parent = model
	model.PrimaryPart = root

	local bodyColor = el.color
	local body: Part
	if sp.shape == "Ball" then
		body = newPart("Body", Enum.PartType.Ball, Vector3.new(math.max(sx, sz), sy, math.max(sx, sz)), bodyColor)
	else
		body = newPart("Body", Enum.PartType.Block, Vector3.new(sx, sy * (sp.shape == "Tall" and 0.75 or 1), sz), bodyColor)
	end
	body.CFrame = root.CFrame
	if sp.shape == "Tall" then
		body.CFrame = root.CFrame * CFrame.new(0, -sy * 0.125, 0)
	end
	body.Parent = model
	weld(root, body)

	-- Kopf
	local headSize = math.min(sx, sy, sz) * (sp.shape == "Tall" and 0.8 or 0.65)
	local head = newPart("Head", Enum.PartType.Ball, Vector3.new(headSize, headSize, headSize), bodyColor:Lerp(Color3.new(1, 1, 1), 0.15))
	if sp.shape == "Long" then
		head.CFrame = root.CFrame * CFrame.new(0, sy * 0.3, -sz * 0.5)
	elseif sp.shape == "Tall" then
		head.CFrame = root.CFrame * CFrame.new(0, sy * 0.45, 0)
	else
		head.CFrame = root.CFrame * CFrame.new(0, sy * 0.15, -math.max(sx, sz) * 0.35)
	end
	head.Parent = model
	weld(root, head)

	-- Augen
	for _, side in { -1, 1 } do
		local eye = newPart("Eye", Enum.PartType.Ball, Vector3.one * headSize * 0.28, Color3.new(1, 1, 1), Enum.Material.Neon)
		eye.CFrame = head.CFrame * CFrame.new(side * headSize * 0.22, headSize * 0.1, -headSize * 0.42)
		eye.Parent = model
		weld(root, eye)
		local pupil = newPart("Pupil", Enum.PartType.Ball, Vector3.one * headSize * 0.14, Color3.new(0.05, 0.05, 0.05))
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -headSize * 0.08)
		pupil.Parent = model
		weld(root, pupil)
	end

	-- Flügel für Flieger
	if sp.flying then
		for _, side in { -1, 1 } do
			local wing = newPart("Wing", Enum.PartType.Block, Vector3.new(sx * 0.9, 0.2 * scale, sz * 0.6), bodyColor:Lerp(Color3.new(1, 1, 1), 0.35))
			wing.CFrame = root.CFrame * CFrame.new(side * (sx * 0.5 + sx * 0.35), sy * 0.15, 0) * CFrame.Angles(0, 0, math.rad(side * 15))
			wing.Parent = model
			weld(root, wing)
		end
	end

	-- Seltenheits-Akzent
	if Rarities.rank(sp.rarity) >= 3 then
		local band = newPart("RarityBand", Enum.PartType.Block, Vector3.new(sx * 1.02, sy * 0.12, sz * 1.02), rarity.color, Enum.Material.Neon)
		band.CFrame = body.CFrame
		band.Parent = model
		weld(root, band)
	end
	if Rarities.rank(sp.rarity) >= 4 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(rarity.color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.25 * scale)
		sparkle.Rate = 6
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = body
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = (if sp.flying then 3 else 0) + 0.05
	humanoid.Parent = model
	return model
end

function MonsterFactory.build(speciesId: string, level: number): Model
	local sp = Monsters[speciesId]
	assert(sp, "Unbekanntes Monster " .. speciesId)
	local stage = sp.stages[Formulas.stageIndex(speciesId, level)]
	local scale = stage.scale

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Monsters")
	local template = folder and folder:FindFirstChild(speciesId)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		if scale ~= 1 then
			model:ScaleTo(scale)
		end
		if not model:FindFirstChildOfClass("Humanoid") then
			Instance.new("Humanoid").Parent = model
		end
		model.PrimaryPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart
	else
		model = buildPlaceholder(speciesId, scale)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid.WalkSpeed = sp.baseStats.spd

	-- Leuchten: Lichtquelle (auch für dunkle Dungeons)
	if table.find(sp.traits, "Leuchten") and model.PrimaryPart then
		local light = Instance.new("PointLight")
		light.Range = 28
		light.Brightness = 2.5
		light.Color = Color3.fromRGB(255, 240, 180)
		light.Shadows = true
		light.Parent = model.PrimaryPart
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Creatures"
		end
	end
	return model
end

function MonsterFactory.applyAura(model: Model, auraId: string)
	local old = model:FindFirstChild("CosmeticAura", true)
	if old then
		old:Destroy()
	end
	if auraId == "" then
		return
	end
	local colors = {
		AuraGold = Color3.fromRGB(255, 210, 80),
		AuraFrost = Color3.fromRGB(150, 220, 255),
		AuraSchatten = Color3.fromRGB(90, 40, 130),
	}
	local c = colors[auraId]
	if not c or not model.PrimaryPart then
		return
	end
	local p = Instance.new("ParticleEmitter")
	p.Name = "CosmeticAura"
	p.Color = ColorSequence.new(c)
	p.LightEmission = 0.8
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new(0.3)
	p.Rate = 14
	p.Lifetime = NumberRange.new(0.8, 1.2)
	p.Speed = NumberRange.new(0.5, 1.5)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Parent = model.PrimaryPart
end

return MonsterFactory
