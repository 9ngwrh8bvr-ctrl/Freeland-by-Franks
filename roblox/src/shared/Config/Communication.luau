--!strict
-- Kommunikation OHNE Chat: nur vordefinierte Emojis und Richtungspfeile.
-- Es gibt keinerlei freie Texteingabe zwischen Spielern.

local Communication = {}

Communication.Emojis = {
	{ id = "hallo", glyph = "👋", label = "Hallo" },
	{ id = "ja", glyph = "👍", label = "Ja" },
	{ id = "nein", glyph = "👎", label = "Nein" },
	{ id = "danke", glyph = "🙏", label = "Danke" },
	{ id = "lachen", glyph = "😄", label = "Lachen" },
	{ id = "staunen", glyph = "😮", label = "Wow" },
	{ id = "traurig", glyph = "😢", label = "Traurig" },
	{ id = "herz", glyph = "❤️", label = "Herz" },
	{ id = "frage", glyph = "❓", label = "Frage" },
	{ id = "achtung", glyph = "❗", label = "Achtung" },
	{ id = "angriff", glyph = "⚔️", label = "Angriff" },
	{ id = "hilfe", glyph = "🆘", label = "Hilfe" },
	{ id = "heilen", glyph = "💚", label = "Heilung" },
	{ id = "folgen", glyph = "👣", label = "Folgt mir" },
	{ id = "warten", glyph = "✋", label = "Warten" },
	{ id = "feiern", glyph = "🎉", label = "Feiern" },
	-- VIP-Emojis (Game Pass)
	{ id = "krone", glyph = "👑", label = "Krone", vip = true },
	{ id = "drache", glyph = "🐲", label = "Drache", vip = true },
	{ id = "stern", glyph = "🌟", label = "Stern", vip = true },
}

-- Richtungspfeile / Marker: Der Spieler tippt auf eine Stelle in der Welt,
-- dort erscheint ein großer Pfeil. Für andere Spieler zeigt ein Pfeil am
-- Bildschirmrand die Richtung an.
Communication.Pings = {
	{ id = "hierher", glyph = "⬇️", label = "Hierher", color = Color3.fromRGB(80, 200, 255) },
	{ id = "gefahr", glyph = "⚠️", label = "Gefahr", color = Color3.fromRGB(255, 70, 60) },
	{ id = "angriff", glyph = "⚔️", label = "Angreifen", color = Color3.fromRGB(255, 150, 40) },
	{ id = "schatz", glyph = "💰", label = "Schatz", color = Color3.fromRGB(255, 215, 60) },
	{ id = "monster", glyph = "🐾", label = "Monster", color = Color3.fromRGB(170, 110, 255) },
}

function Communication.findEmoji(id: string)
	for _, e in Communication.Emojis do
		if e.id == id then
			return e
		end
	end
	return nil
end

function Communication.findPing(id: string)
	for _, p in Communication.Pings do
		if p.id == id then
			return p
		end
	end
	return nil
end

return Communication
