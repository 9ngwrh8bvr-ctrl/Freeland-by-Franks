--!strict
-- Seltenheitsstufen. captureMod verringert die Fangchance,
-- statMult erhöht die Grundwerte.

local Rarities = {}

Rarities.Order = { "Gewoehnlich", "Ungewoehnlich", "Selten", "Episch", "Legendaer", "Einzigartig" }

Rarities.List = {
	Gewoehnlich = {
		name = "Gewöhnlich",
		color = Color3.fromRGB(190, 190, 190),
		statMult = 1.0,
		captureMod = 1.0,
		xpMult = 1.0,
		coinMult = 1.0,
	},
	Ungewoehnlich = {
		name = "Ungewöhnlich",
		color = Color3.fromRGB(90, 210, 90),
		statMult = 1.1,
		captureMod = 0.8,
		xpMult = 1.3,
		coinMult = 1.3,
	},
	Selten = {
		name = "Selten",
		color = Color3.fromRGB(70, 140, 255),
		statMult = 1.25,
		captureMod = 0.55,
		xpMult = 1.8,
		coinMult = 1.8,
	},
	Episch = {
		name = "Episch",
		color = Color3.fromRGB(180, 90, 255),
		statMult = 1.45,
		captureMod = 0.35,
		xpMult = 2.5,
		coinMult = 2.5,
	},
	Legendaer = {
		name = "Legendär",
		color = Color3.fromRGB(255, 180, 40),
		statMult = 1.8,
		captureMod = 0.15,
		xpMult = 5,
		coinMult = 5,
	},
	Einzigartig = {
		name = "Einzigartig",
		color = Color3.fromRGB(255, 70, 70),
		statMult = 2.2,
		captureMod = 0,
		xpMult = 8,
		coinMult = 8,
	},
}

function Rarities.rank(id: string): number
	for i, r in Rarities.Order do
		if r == id then
			return i
		end
	end
	return 1
end

return Rarities
