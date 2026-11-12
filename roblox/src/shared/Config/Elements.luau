--!strict
-- Elemente und ihre Stärken/Schwächen.
-- Regel: Steht B in Strong[A], macht A gegen B 1,5-fachen Schaden
-- und B gegen A nur 0,67-fachen Schaden.

local Elements = {}

Elements.List = {
	Neutral = { name = "Neutral", color = Color3.fromRGB(200, 200, 200), icon = "⚪" },
	Feuer = { name = "Feuer", color = Color3.fromRGB(255, 110, 40), icon = "🔥" },
	Wasser = { name = "Wasser", color = Color3.fromRGB(60, 150, 255), icon = "💧" },
	Erde = { name = "Erde", color = Color3.fromRGB(150, 110, 70), icon = "🪨" },
	Wind = { name = "Wind", color = Color3.fromRGB(170, 240, 220), icon = "🌪️" },
	Natur = { name = "Natur", color = Color3.fromRGB(90, 200, 90), icon = "🌿" },
	Licht = { name = "Licht", color = Color3.fromRGB(255, 240, 150), icon = "✨" },
	Schatten = { name = "Schatten", color = Color3.fromRGB(120, 70, 170), icon = "🌑" },
	Drache = { name = "Drache", color = Color3.fromRGB(220, 60, 90), icon = "🐉" },
}

Elements.Strong = {
	Neutral = {},
	Feuer = { Natur = true },
	Wasser = { Feuer = true, Erde = true },
	Erde = { Feuer = true, Wind = true },
	Wind = { Natur = true },
	Natur = { Wasser = true, Erde = true },
	Licht = { Schatten = true },
	Schatten = { Licht = true },
	Drache = { Drache = true },
} :: { [string]: { [string]: boolean } }

Elements.StrongMultiplier = 1.5
Elements.WeakMultiplier = 0.67

function Elements.multiplier(attacker: string?, defender: string?): number
	if not attacker or not defender then
		return 1
	end
	local strong = Elements.Strong[attacker]
	if strong and strong[defender] then
		return Elements.StrongMultiplier
	end
	local reverse = Elements.Strong[defender]
	if reverse and reverse[attacker] then
		return Elements.WeakMultiplier
	end
	return 1
end

return Elements
