-- Testlauf außerhalb von Roblox (Datenprüfung + Formeln + Syntax aller Dateien).
-- Ausführen im Ordner roblox/:
--   cargo run --release --manifest-path tools/luaurun/Cargo.toml -- tests/run_tests.luau

------------------------------------------------------------------------
-- Minimale Roblox-Nachbildung für reine Module
------------------------------------------------------------------------
local function color3(r, g, b)
	return {
		R = r,
		G = g,
		B = b,
		ToHex = function()
			return "ffffff"
		end,
		Lerp = function(self)
			return self
		end,
	}
end
Color3 = {
	fromRGB = function(r, g, b)
		return color3(r / 255, g / 255, b / 255)
	end,
	new = color3,
}

local cache = {}
local makeNode

local function customRequire(n)
	assert(type(n) == "table" and n.__file, "require: kein Modul " .. tostring(n and n.__path))
	if cache[n.__file] ~= nil then
		return cache[n.__file]
	end
	local src = assert(read_file(n.__file), "fehlt: " .. n.__file)
	-- selene: allow(global_usage)
	local env = setmetatable({ script = n, require = customRequire }, { __index = _G })
	local result = load_module(src, n.__file, env)
	cache[n.__file] = result
	return result
end

makeNode = function(path, name, parent, file)
	local node = { __path = path, __file = file, Name = name, Parent = parent }
	return setmetatable(node, {
		__index = function(t, k)
			local base = if file then parent.__path else path
			if file then
				-- Kind eines Skripts: nur über Parent erreichbar
				error("Kein Kind '" .. tostring(k) .. "' in " .. file)
			end
			local f = path .. "/" .. k .. ".luau"
			local child
			if read_file(f) then
				child = makeNode(path .. "/" .. k, k, t, f)
			elseif is_dir(path .. "/" .. k) then
				child = makeNode(path .. "/" .. k, k, t, nil)
			else
				error("Nicht gefunden: " .. base .. "/" .. tostring(k))
			end
			rawset(t, k, child)
			return child
		end,
	})
end

local Shared = makeNode("src/shared", "Shared", nil, nil)

------------------------------------------------------------------------
-- Mini-Testframework
------------------------------------------------------------------------
local passed, failed = 0, 0
local function check(cond, msg)
	if cond then
		passed += 1
	else
		failed += 1
		print("❌ " .. msg)
	end
end

------------------------------------------------------------------------
-- 1) Syntax aller Luau-Dateien
------------------------------------------------------------------------
local function walk(dir, out)
	for _, name in list_dir(dir) do
		local p = dir .. "/" .. name
		if is_dir(p) then
			walk(p, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, p)
		end
	end
	return out
end
local files = walk("src", {})
for _, f in files do
	local err = compile_check(read_file(f), f)
	check(err == nil, "Syntaxfehler: " .. tostring(err))
end
print(("Syntax geprüft: %d Dateien"):format(#files))

------------------------------------------------------------------------
-- 2) Datenkonsistenz
------------------------------------------------------------------------
local Monsters = customRequire(Shared.Config.Monsters)
local Abilities = customRequire(Shared.Config.Abilities)
local Items = customRequire(Shared.Config.Items)
local Elements = customRequire(Shared.Config.Elements)
local Rarities = customRequire(Shared.Config.Rarities)
local ClassesModule = customRequire(Shared.Config.Classes)
local QuestsModule = customRequire(Shared.Config.Quests)
local Shop = customRequire(Shared.Config.Shop)
local GameConfig = customRequire(Shared.Config.GameConfig)
local Communication = customRequire(Shared.Config.Communication)
local Formulas = customRequire(Shared.Formulas)

local VALID_KINDS = { Damage = 1, Area = 1, Heal = 1, Buff = 1, Debuff = 1, Taunt = 1, Stealth = 1, Shield = 1, Stun = 1, Dash = 1 }
local VALID_TRAITS = { Fliegen = 1, Schwimmen = 1, Klein = 1, Zerschmettern = 1, Runensicht = 1, Leuchten = 1, Wachstum = 1 }

for id, a in Abilities do
	check(VALID_KINDS[a.kind] ~= nil, "Fähigkeit " .. id .. ": unbekannte Art " .. tostring(a.kind))
	check(Elements.List[a.element] ~= nil, "Fähigkeit " .. id .. ": unbekanntes Element")
	check(a.cooldown and a.cooldown > 0, "Fähigkeit " .. id .. ": Abklingzeit fehlt")
	if a.kind == "Buff" or a.kind == "Debuff" then
		check(a.stat ~= nil and a.amount ~= nil and a.duration ~= nil, "Fähigkeit " .. id .. ": Buff-Werte fehlen")
	end
end

for id, sp in Monsters do
	check(Elements.List[sp.element] ~= nil, id .. ": Element")
	check(Rarities.List[sp.rarity] ~= nil, id .. ": Seltenheit")
	check(#sp.abilities == 4, id .. ": braucht 4 Fähigkeiten")
	for _, ab in sp.abilities do
		check(Abilities[ab] ~= nil, id .. ": Fähigkeit fehlt " .. ab)
	end
	for _, tr in sp.traits do
		check(VALID_TRAITS[tr] ~= nil, id .. ": unbekannte Erkundungsfähigkeit " .. tr)
	end
	for _, drop in sp.loot do
		check(Items[drop.item] ~= nil, id .. ": Beute-Item fehlt " .. drop.item)
	end
	if sp.specialization then
		check(Abilities[sp.specialization.ability] ~= nil, id .. ": Spezialisierung fehlt")
	end
	check(#sp.stages >= 1 and sp.stages[1].level == 1, id .. ": Stufe 1 muss bei Level 1 beginnen")
	check(#sp.size == 3, id .. ": size braucht 3 Werte")
	if sp.isBoss then
		check(not sp.capture.capturable, id .. ": Bosse sollen nicht fangbar sein")
	end
end
check(Monsters.UralterDrache.capture.requiresFlag ~= nil, "Legendärer Drache braucht besondere Fangbedingung")

-- jede Erkundungsfähigkeit muss durch ein fangbares Monster verfügbar sein
for trait in VALID_TRAITS do
	local found = false
	for _, sp in Monsters do
		if sp.capture.capturable and table.find(sp.traits, trait) then
			found = true
		end
	end
	check(found, "Kein fangbares Monster mit " .. trait)
end

for id, cls in ClassesModule.List do
	check(table.find(ClassesModule.Order, id) ~= nil, "Klasse nicht in Order: " .. id)
	check(#cls.abilities == 4, id .. ": braucht 4 Fähigkeiten")
	for _, a in cls.abilities do
		check(Abilities[a.id] ~= nil, id .. ": Fähigkeit fehlt " .. a.id)
	end
	check(cls.abilities[1].level == 1, id .. ": Grundangriff ab Level 1")
	local talentIds = {}
	for _, t in cls.talents do
		talentIds[t.id] = true
	end
	for _, t in cls.talents do
		if t.requires then
			check(talentIds[t.requires] ~= nil, id .. ": Talent-Voraussetzung fehlt " .. t.requires)
		end
	end
	for _, r in cls.requirements do
		if r.species then
			check(Monsters[r.species] ~= nil, id .. ": Monster fehlt " .. r.species)
		end
		if r.type == "quest" then
			check(QuestsModule.List[r.id] ~= nil, id .. ": Quest fehlt " .. tostring(r.id))
		end
	end
	if cls.advanced then
		check(#cls.requirements >= 3, id .. ": fortgeschrittene Klassen brauchen mehrere Bedingungen")
		check(cls.unlockedBy ~= nil and Monsters[cls.unlockedBy] ~= nil, id .. ": unlockedBy fehlt")
	end
end

for id, q in QuestsModule.List do
	check(table.find(QuestsModule.Order, id) ~= nil, "Quest nicht in Order: " .. id)
	if q.prereq.quest then
		check(QuestsModule.List[q.prereq.quest] ~= nil, id .. ": Vorquest fehlt")
	end
	if q.prereq.bond then
		check(Monsters[q.prereq.bond.species] ~= nil, id .. ": Monster fehlt")
	end
	for _, obj in q.objectives do
		if obj.species then
			check(Monsters[obj.species] ~= nil, id .. ": Monster fehlt " .. obj.species)
		end
		if obj.withCompanion then
			check(Monsters[obj.withCompanion] ~= nil, id .. ": Gefährte fehlt")
		end
		if obj.trait then
			check(VALID_TRAITS[obj.trait] ~= nil, id .. ": Fähigkeit fehlt")
		end
	end
	for itemId in q.rewards.items or {} do
		check(Items[itemId] ~= nil, id .. ": Belohnung fehlt " .. itemId)
	end
end
check(QuestsModule.List.Drachenpruefung.rewards.flag == Monsters.UralterDrache.capture.requiresFlag, "Drachenprüfung muss das Fang-Flag setzen")

for _, list in { Shop.CoinShop, Shop.GemShop } do
	local keys = {}
	for _, e in list do
		check(not keys[e.key], "Shop-Schlüssel doppelt: " .. e.key)
		keys[e.key] = true
		check(e.price > 0, "Preis muss > 0 sein: " .. e.key)
		check(e.item == nil or Items[e.item] ~= nil, "Shop-Item fehlt: " .. tostring(e.item))
		check(e.item ~= nil or e.effect ~= nil, "Shop-Eintrag ohne Wirkung: " .. e.key)
	end
end
for key, p in Shop.Products do
	for itemId in p.grant.items or {} do
		check(Items[itemId] ~= nil, "Produkt " .. key .. ": Item fehlt")
	end
end
for _, s in GameConfig.StarterMonsters do
	check(Monsters[s] ~= nil and Monsters[s].rarity == "Gewoehnlich", "Starter muss gewöhnlich sein: " .. s)
end
for id in GameConfig.StartItems do
	check(Items[id] ~= nil, "Startitem fehlt " .. id)
end
local emojiIds = {}
for _, e in Communication.Emojis do
	check(not emojiIds[e.id], "Emoji doppelt " .. e.id)
	emojiIds[e.id] = true
end

------------------------------------------------------------------------
-- 3) Formeln
------------------------------------------------------------------------
check(Formulas.bondLevel(0) == 1, "Bindung startet bei 1")
check(Formulas.bondLevel(99) == 1 and Formulas.bondLevel(100) == 2, "Bindungsstufe 2 bei 100")
check(Formulas.bondLevel(99999) == 5, "Bindung max 5")
check(Formulas.bondProgress(200) > 0 and Formulas.bondProgress(200) < 1, "Bindungsfortschritt")
check(Formulas.stageIndex("Feuerwolf", 1) == 1 and Formulas.stageIndex("Feuerwolf", 16) == 2 and Formulas.stageIndex("Feuerwolf", 40) == 3, "Entwicklungsstufen")
check(Formulas.stageName("Feuerwolf", 20) == "Feuerwolf", "Stufenname")

local low = Formulas.monsterStats("Feuerwolf", 5, 0, 1)
local high = Formulas.monsterStats("Feuerwolf", 20, 1200, 1)
check(high.hp > low.hp and high.atk > low.atk, "Monster werden mit Level/Bindung stärker")
local buffed = Formulas.monsterStats("Feuerwolf", 5, 0, 1, { companionAtkPct = 0.2 })
check(buffed.atk > low.atk, "Gefährten-Boni wirken")

local elementStrong = Formulas.damage(20, 30, 20, Elements.multiplier("Wasser", "Feuer"), false, 1)
local elementWeak = Formulas.damage(20, 30, 20, Elements.multiplier("Feuer", "Wasser"), false, 1)
check(elementStrong > elementWeak, "Elementvorteil wirkt")
check(Formulas.damage(20, 30, 20, 1, true, 1) > Formulas.damage(20, 30, 20, 1, false, 1), "Kritische Treffer")
check(Elements.multiplier("Licht", "Schatten") == 1.5 and Elements.multiplier("Schatten", "Licht") == 1.5, "Licht/Schatten gegenseitig stark")

local c1 = Formulas.captureChance("Moosling", 0.3, 0, 0, 0)
local c2 = Formulas.captureChance("Moosling", 0.05, 0, 0, 0)
local c3 = Formulas.captureChance("Moosling", 0.3, 0, 0.25, 0)
local cl = Formulas.captureChance("UralterDrache", 0.1, 0, 0, 0)
check(c2 > c1, "Weniger LP = höhere Fangchance")
check(c3 > c1, "Köder erhöhen Fangchance")
check(cl < c1, "Legendäre sind schwerer zu fangen")
check(Formulas.captureChance("Glutkoloss", 0.01, 0, 1, 1) == 0, "Bosse nicht fangbar")

local profile = {
	level = 20,
	classId = "Bestienbaendiger",
	talents = {},
	equipment = {},
	monsters = {
		a = { species = "Feuerwolf", level = 16, bondXp = 1200 },
		b = { species = "Moosling", level = 3, bondXp = 0 },
	},
	quests = { completed = {}, active = {}, progress = {} },
}
check(Formulas.activeSlots(profile) == 3, "Slots: Level 20 = 2 + Bestienbändiger 1")
profile.classId = "Krieger"
check(Formulas.activeSlots(profile) == 2, "Slots: Level 20 Krieger = 2")
local ok, reqs = Formulas.classRequirements(profile, "Flammenkrieger")
check(not ok and #reqs == 4, "Flammenkrieger braucht noch die Prüfung")
profile.quests.completed.Feuerprobe = true
ok = Formulas.classRequirements(profile, "Flammenkrieger")
check(ok, "Flammenkrieger freischaltbar nach Bindung 5 + Stufe 2 + Prüfung + Level 20")
check(table.find(Formulas.specializations(profile), "Glutklinge") ~= nil, "Feuer-Spezialisierung durch Feuerwolf")
check(#Formulas.unlockedAbilities(profile) == 4, "Krieger Lv 20 hat alle 4 Fähigkeiten")

local ps1 = Formulas.playerStats({ level = 1, classId = "Krieger", talents = {}, equipment = {} })
local ps2 = Formulas.playerStats({ level = 1, classId = "Krieger", talents = {}, equipment = { weapon = "Stahlklinge" } })
check(ps2.atk > ps1.atk, "Ausrüstung erhöht Angriff")
local ps3 = Formulas.playerStats({ level = 1, classId = "Krieger", talents = { Krieger = { K_Klingenmeister = 5 } }, equipment = {} })
check(ps3.atk > ps1.atk, "Talente erhöhen Angriff")

-- Balancing-Plausibilität: Spieler Lv 1 gegen Moosling Lv 2
local m = Formulas.monsterStats("Moosling", 2, 0, 1)
local hit = Formulas.damage(14, ps1.atk, m.def, 1, false, 1)
local hitsToKill = math.ceil(m.hp / hit)
check(hitsToKill >= 2 and hitsToKill <= 6, ("Lv1 braucht %d Treffer für Moosling (soll 2–6)"):format(hitsToKill))
local bossStats = Formulas.monsterStats("Glutkoloss", 15, 0, 1)
print(("Info: Glutkoloss Lv15 hat %d LP, Krieger Lv1 %d LP, Moosling Lv2 %d LP (%d Treffer)"):format(bossStats.hp, ps1.hp, m.hp, hitsToKill))

-- Datenmigration darf verbrauchte Startgegenstände nicht zurückgeben
local TableUtil = customRequire(Shared.Util.TableUtil)
local saved = { inventory = { Lockfrucht = 1 }, quests = { active = {} } }
TableUtil.reconcile(saved, { inventory = { Heiltrank = 3 }, quests = { active = {}, completed = {} }, coins = 5 }, { inventory = true })
check(saved.inventory.Heiltrank == nil, "Inventar wird nicht aufgefüllt")
check(saved.quests.completed ~= nil and saved.coins == 5, "Neue Felder werden ergänzt")

------------------------------------------------------------------------
print(("\n%d bestanden, %d fehlgeschlagen"):format(passed, failed))
if failed > 0 then
	error("Tests fehlgeschlagen")
end
