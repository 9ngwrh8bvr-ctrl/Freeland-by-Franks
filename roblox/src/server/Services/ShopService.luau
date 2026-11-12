--!strict
-- Shop: Münz- und Edelstein-Shop, Verkaufen, Robux-Käufe (Game Passes und
-- Developer Products) mit sicherer, einmaliger Gutschrift.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Shop = require(Shared.Config.Shop)
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Notifier = require(script.Parent.Parent.Modules.Notifier)

local ShopService = {}
local S: any
local limiter = RateLimiter.new(0.25)

function ShopService:Init(services)
	S = services
end

------------------------------------------------------------------------
-- Ingame-Währungen
------------------------------------------------------------------------
function ShopService:Buy(player: Player, listName: string, key: string): (boolean, string?)
	local d = S.DataService:Get(player)
	if not d then
		return false
	end
	local list = if listName == "coin" then Shop.CoinShop elseif listName == "gem" then Shop.GemShop else nil
	if not list then
		return false, "Unbekannter Shop"
	end
	local entry = Shop.findEntry(list, key)
	if not entry then
		return false, "Unbekannter Artikel"
	end
	-- Kosmetik nicht doppelt kaufen
	if entry.item and Items[entry.item] and Items[entry.item].category == "cosmetic" and d.cosmetics[entry.item] then
		return false, "Bereits freigeschaltet"
	end
	if entry.effect == "storage" then
		local cap = GameConfig.BaseStorage + d.storageUpgrades * GameConfig.StorageUpgradeSize
		if cap >= GameConfig.MaxStorage then
			return false, "Gehege bereits maximal erweitert"
		end
	end
	local paid = if listName == "coin"
		then S.InventoryService:SpendCoins(player, entry.price)
		else S.InventoryService:SpendGems(player, entry.price)
	if not paid then
		return false, if listName == "coin" then "Nicht genug Münzen" else "Nicht genug Edelsteine"
	end
	if entry.item then
		S.InventoryService:AddItem(player, entry.item, entry.amount or 1)
	elseif entry.effect == "storage" then
		d.storageUpgrades += 1
	end
	S.DataService:MarkDirty(player)
	return true
end

function ShopService:Sell(player: Player, itemId: string, amount: number): (boolean, string?)
	local d = S.DataService:Get(player)
	local item = Items[itemId]
	if not d or not item or not item.sellValue then
		return false, "Nicht verkaufbar"
	end
	amount = math.clamp(math.floor(amount), 1, 999)
	if (d.inventory[itemId] or 0) < amount then
		return false, "Nicht genug"
	end
	-- ausgerüstetes letztes Exemplar schützen
	for _, eq in d.equipment do
		if eq == itemId and d.inventory[itemId] - amount < 1 then
			return false, "Lege das Teil zuerst ab"
		end
	end
	S.InventoryService:RemoveItem(player, itemId, amount)
	S.InventoryService:AddCoins(player, item.sellValue * amount, false)
	return true
end

------------------------------------------------------------------------
-- Robux
------------------------------------------------------------------------
local function passKeyById(id: number): string?
	for key, pass in Shop.GamePasses do
		if pass.id == id and id ~= 0 then
			return key
		end
	end
	return nil
end

local function productById(id: number): any?
	for _, p in Shop.Products do
		if p.id == id and id ~= 0 then
			return p
		end
	end
	return nil
end

local function checkPasses(player: Player)
	for key, pass in Shop.GamePasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok then
				S.DataService:SetPass(player, key, owns)
			end
		end
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not S.DataService:IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if S.DataService:HasPurchase(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productById(receipt.ProductId)
	if not product then
		warn("[ShopService] Unbekanntes Produkt", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local grant = product.grant
	if grant.gems then
		S.InventoryService:AddGems(player, grant.gems)
	end
	if grant.items then
		for itemId, n in grant.items do
			S.InventoryService:AddItem(player, itemId, n)
		end
	end
	S.DataService:RecordPurchase(player, purchaseId)
	-- erst nach erfolgreichem Speichern bestätigen
	if not S.DataService:SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Notifier.send(player, ("🛒 Danke für deinen Kauf: %s!"):format(product.name), "epic")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService:Start()
	Net.func("ShopRequest").OnServerInvoke = function(player, action, a, b)
		if not limiter:check(player) or type(action) ~= "string" then
			return false, "Zu schnell"
		end
		if action == "buy" and type(a) == "string" and type(b) == "string" then
			return self:Buy(player, a, b)
		elseif action == "sell" and type(a) == "string" and type(b) == "number" then
			return self:Sell(player, a, b)
		elseif action == "refreshPasses" then
			checkPasses(player)
			return true
		end
		return false, "Ungültige Anfrage"
	end

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local key = passKeyById(passId)
			if key then
				S.DataService:SetPass(player, key, true)
				Notifier.send(player, ("👑 %s ist jetzt aktiv!"):format(Shop.GamePasses[key].name), "epic")
				S.CompanionService:Sync(player)
			end
		end
	end)

	S.DataService:OnLoaded(function(player)
		checkPasses(player)
	end)
end

return ShopService
