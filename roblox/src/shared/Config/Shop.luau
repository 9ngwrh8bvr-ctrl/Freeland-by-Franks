--!strict
-- Shop-Konfiguration.
--
-- Währungen:
--   Münzen     – im Spiel verdient (Monster besiegen, Quests, Verkaufen)
--   Edelsteine – Premiumwährung, per Robux kaufbar, in kleinen Mengen auch erspielbar
--
-- WICHTIG – Robux-Artikel einrichten:
--   1. Spiel in Roblox veröffentlichen.
--   2. Creator Dashboard → dein Spiel → Monetarisierung →
--      Game Passes bzw. Developer Products anlegen.
--   3. Die dort angezeigte ID hier bei `id` eintragen.
--   Solange id = 0 ist, zeigt der Shop "Bald verfügbar" an.
--
-- Fairness-Regeln (bewusst gewählt):
--   * Keine bezahlten Zufallsboxen / Lootboxen.
--   * Robux kaufen Komfort, Kosmetik und Zeitersparnis – keine exklusiven Monster
--     und keine Klassen.

export type ShopEntry = {
	key: string,
	item: string?, -- Item-ID aus Items.luau
	amount: number?,
	price: number,
	effect: string?, -- Sonderwirkung statt Item, z. B. "storage"
	value: number?,
	name: string?,
	description: string?,
	icon: string?,
}

local Shop = {}

Shop.CoinShop = {
	{ key = "c_heiltrank", item = "Heiltrank", amount = 1, price = 25 },
	{ key = "c_heiltrank5", item = "Heiltrank", amount = 5, price = 110 },
	{ key = "c_grosserheiltrank", item = "GrosserHeiltrank", amount = 1, price = 70 },
	{ key = "c_lockfrucht", item = "Lockfrucht", amount = 3, price = 45 },
	{ key = "c_glutbeere", item = "Glutbeere", amount = 2, price = 60 },
	{ key = "c_tauperle", item = "Tauperle", amount = 2, price = 60 },
	{ key = "c_schattenmotte", item = "Schattenmotte", amount = 2, price = 80 },
	{ key = "c_bindungssnack", item = "Bindungssnack", amount = 1, price = 90 },
	{ key = "c_wiederbelebung", item = "Wiederbelebungskraut", amount = 1, price = 60 },
	{ key = "c_eisenklinge", item = "Eisenklinge", amount = 1, price = 150 },
	{ key = "c_lederruestung", item = "Lederruestung", amount = 1, price = 130 },
	{ key = "c_stahlklinge", item = "Stahlklinge", amount = 1, price = 750 },
	{ key = "c_eisenruestung", item = "Eisenruestung", amount = 1, price = 700 },
	{ key = "c_tieramulett", item = "Tieramulett", amount = 1, price = 450 },
} :: { ShopEntry }

Shop.GemShop = {
	{ key = "g_goldfrucht", item = "Goldfrucht", amount = 3, price = 40 },
	{ key = "g_bindungssnack", item = "Bindungssnack", amount = 5, price = 60 },
	{ key = "g_wiederbelebung", item = "Wiederbelebungskraut", amount = 5, price = 35 },
	{
		key = "g_gehege",
		effect = "storage",
		value = 20,
		price = 80,
		name = "Gehege-Erweiterung",
		description = "+20 Plätze für Monster.",
		icon = "🏡",
	},
	{ key = "g_auragold", item = "AuraGold", amount = 1, price = 150 },
	{ key = "g_aurafrost", item = "AuraFrost", amount = 1, price = 150 },
	{ key = "g_auraschatten", item = "AuraSchatten", amount = 1, price = 150 },
} :: { ShopEntry }

-- Game Passes (einmaliger Kauf, dauerhaft)
Shop.GamePasses = {
	VIP = {
		id = 0,
		name = "VIP-Abenteurer",
		description = "+15 % Münzen, exklusive VIP-Emojis und goldener Namensrahmen.",
		icon = "👑",
		robuxHint = 199,
	},
	GrossesGehege = {
		id = 0,
		name = "Großes Gehege",
		description = "+100 Plätze für deine Monstersammlung.",
		icon = "🏰",
		robuxHint = 149,
	},
	DoppelteBindung = {
		id = 0,
		name = "Doppelte Bindung",
		description = "Deine Monster sammeln doppelt so viele Bindungs-EP.",
		icon = "💞",
		robuxHint = 249,
	},
}
Shop.GamePassOrder = { "VIP", "GrossesGehege", "DoppelteBindung" }

-- Developer Products (mehrfach kaufbar)
Shop.Products = {
	Gems100 = {
		id = 0,
		name = "100 Edelsteine",
		icon = "💎",
		robuxHint = 49,
		grant = { gems = 100 },
	},
	Gems550 = {
		id = 0,
		name = "550 Edelsteine",
		icon = "💎",
		robuxHint = 199,
		grant = { gems = 550 },
	},
	Gems1200 = {
		id = 0,
		name = "1200 Edelsteine",
		icon = "💎",
		robuxHint = 399,
		grant = { gems = 1200 },
	},
	Abenteurerpaket = {
		id = 0,
		name = "Abenteurerpaket",
		icon = "🎒",
		robuxHint = 149,
		grant = { gems = 150, items = { GrosserHeiltrank = 5, Goldfrucht = 5 } },
	},
}
Shop.ProductOrder = { "Gems100", "Gems550", "Gems1200", "Abenteurerpaket" }

Shop.VipCoinBonus = 0.15
Shop.GrossesGehegeBonus = 100

function Shop.findEntry(list: { ShopEntry }, key: string): ShopEntry?
	for _, e in list do
		if e.key == key then
			return e
		end
	end
	return nil
end

return Shop
