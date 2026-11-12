--!strict
-- Währungen, Gegenstände, Verbrauchsgüter und Ausrüstung.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Shop = require(Shared.Config.Shop)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)
local RateLimiter = require(Shared.Util.RateLimiter)
local Notifier = require(script.Parent.Parent.Modules.Notifier)

local InventoryService = {}
local S: any
local limiter = RateLimiter.new(0.25)

function InventoryService:Init(services)
	S = services
end

function InventoryService:Start()
	Net.func("UseItem").OnServerInvoke = function(player, itemId, uid)
		if not limiter:check(player) then
			return false
		end
		if type(itemId) ~= "string" or (uid ~= nil and type(uid) ~= "string") then
			return false
		end
		return self:UseItem(player, itemId, uid)
	end
	Net.func("EquipItem").OnServerInvoke = function(player, itemId, unequipSlot)
		if not limiter:check(player) then
			return false
		end
		if unequipSlot ~= nil then
			if type(unequipSlot) ~= "string" then
				return false
			end
			return self:Unequip(player, unequipSlot)
		end
		if type(itemId) ~= "string" then
			return false
		end
		return self:Equip(player, itemId)
	end
end

------------------------------------------------------------------------
-- Gegenstände
------------------------------------------------------------------------
function InventoryService:Count(player: Player, itemId: string): number
	local d = S.DataService:Get(player)
	return d and (d.inventory[itemId] or 0) or 0
end

function InventoryService:AddItem(player: Player, itemId: string, amount: number?)
	local d = S.DataService:Get(player)
	local item = Items[itemId]
	if not d or not item then
		return
	end
	local n = amount or 1
	if item.category == "cosmetic" then
		d.cosmetics[itemId] = true
	else
		d.inventory[itemId] = (d.inventory[itemId] or 0) + n
	end
	S.DataService:MarkDirty(player)
end

function InventoryService:RemoveItem(player: Player, itemId: string, amount: number?): boolean
	local d = S.DataService:Get(player)
	local n = amount or 1
	if not d or (d.inventory[itemId] or 0) < n then
		return false
	end
	d.inventory[itemId] -= n
	if d.inventory[itemId] <= 0 then
		d.inventory[itemId] = nil
		-- ausgerüstetes Teil ablegen, falls das letzte Exemplar weg ist
		for slot, id in d.equipment do
			if id == itemId then
				d.equipment[slot] = nil
				S.EntityService:RefreshPlayer(player)
			end
		end
	end
	S.DataService:MarkDirty(player)
	return true
end

------------------------------------------------------------------------
-- Währungen
------------------------------------------------------------------------
function InventoryService:AddCoins(player: Player, amount: number, applyBonus: boolean?): number
	local d = S.DataService:Get(player)
	if not d then
		return 0
	end
	local value = amount
	if applyBonus then
		local mult = 1 + (Formulas.aggregateMods(d).coinPct or 0)
		if S.DataService:HasPass(player, "VIP") then
			mult += Shop.VipCoinBonus
		end
		value = math.floor(amount * mult + 0.5)
	end
	d.coins += value
	S.DataService:MarkDirty(player)
	return value
end

function InventoryService:SpendCoins(player: Player, amount: number): boolean
	local d = S.DataService:Get(player)
	if not d or d.coins < amount or amount < 0 then
		return false
	end
	d.coins -= amount
	S.DataService:MarkDirty(player)
	return true
end

function InventoryService:AddGems(player: Player, amount: number)
	local d = S.DataService:Get(player)
	if not d then
		return
	end
	d.gems += amount
	S.DataService:MarkDirty(player)
end

function InventoryService:SpendGems(player: Player, amount: number): boolean
	local d = S.DataService:Get(player)
	if not d or d.gems < amount or amount < 0 then
		return false
	end
	d.gems -= amount
	S.DataService:MarkDirty(player)
	return true
end

------------------------------------------------------------------------
-- Benutzen
------------------------------------------------------------------------
function InventoryService:UseItem(player: Player, itemId: string, uid: string?): boolean
	local d = S.DataService:Get(player)
	local item = Items[itemId]
	if not d or not item or item.category ~= "consumable" or self:Count(player, itemId) < 1 then
		return false
	end
	local effect = item.effect
	if effect == "healPct" then
		local e = S.EntityService:ForPlayer(player)
		if not e or e.dead or e.hp >= e.maxHp then
			Notifier.send(player, "Du hast bereits volle Lebenspunkte.", "bad")
			return false
		end
		S.EntityService:Heal(nil, e, e.maxHp * (item.value or 0.4))
	elseif effect == "bondXp" then
		if not uid or not d.monsters[uid] then
			return false
		end
		S.ProgressionService:AddBondXp(player, uid, item.value or 50, "Snack")
	elseif effect == "revive" then
		local rec = uid and d.monsters[uid]
		if not rec or (rec.exhaustedUntil or 0) <= os.time() then
			Notifier.send(player, "Dieses Monster ist nicht erschöpft.", "bad")
			return false
		end
		rec.exhaustedUntil = 0
		Notifier.send(player, "Dein Gefährte ist wieder bereit!", "good")
	else
		return false
	end
	self:RemoveItem(player, itemId, 1)
	return true
end

function InventoryService:Equip(player: Player, itemId: string): boolean
	local d = S.DataService:Get(player)
	local item = Items[itemId]
	if not d or not item or item.category ~= "equipment" or not item.slot then
		return false
	end
	if self:Count(player, itemId) < 1 then
		return false
	end
	if item.requiredLevel and d.level < item.requiredLevel then
		Notifier.send(player, ("Benötigt Level %d."):format(item.requiredLevel), "bad")
		return false
	end
	d.equipment[item.slot] = itemId
	S.DataService:MarkDirty(player)
	S.EntityService:RefreshPlayer(player)
	S.CompanionService:RefreshAll(player)
	return true
end

function InventoryService:Unequip(player: Player, slot: string): boolean
	local d = S.DataService:Get(player)
	if not d or d.equipment[slot] == nil then
		return false
	end
	d.equipment[slot] = nil
	S.DataService:MarkDirty(player)
	S.EntityService:RefreshPlayer(player)
	S.CompanionService:RefreshAll(player)
	return true
end

return InventoryService
