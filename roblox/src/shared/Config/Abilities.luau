--!strict
-- Alle Fähigkeiten (Spieler, Klassen, Monster, Bosse) an einem Ort.
--
-- kind:
--   Damage  – Einzelziel-Schaden
--   Area    – Flächenschaden um das Ziel (oder um sich selbst, selfCentered)
--   Heal    – heilt Verbündete im Radius (Besitzer + Gefährten)
--   Buff    – erhöht einen Wert (stat) um amount (Anteil) für duration
--   Debuff  – senkt einen Wert des Ziels
--   Taunt   – Gegner im Radius greifen den Anwender an
--   Stealth – Anwender wird unsichtbar für Gegner, nächster Treffer kritisch
--   Shield  – Schadensschild für Anwender/Verbündete
--   Stun    – Ziel ist betäubt (optional mit Schaden)
--   Dash    – Sprung zum Ziel mit Schaden
--
-- targets: "enemy" | "self" | "allies"

export type Ability = {
	name: string,
	element: string,
	kind: string,
	power: number?,
	cooldown: number,
	range: number?,
	radius: number?,
	duration: number?,
	stat: string?,
	amount: number?,
	targets: string?,
	selfCentered: boolean?,
	executeBonus: number?, -- Zusatzschaden gegen Ziele unter 30 % HP
	description: string,
}

local A: { [string]: Ability } = {}

local function add(id: string, def: Ability)
	A[id] = def
end

------------------------------------------------------------------------
-- Klassen-Fähigkeiten
------------------------------------------------------------------------
-- Krieger
add("Schwerthieb", { name = "Schwerthieb", element = "Neutral", kind = "Damage", power = 14, cooldown = 0.8, range = 8, description = "Schneller Schwertangriff." })
add("Wirbelschlag", { name = "Wirbelschlag", element = "Neutral", kind = "Area", power = 30, cooldown = 7, radius = 10, selfCentered = true, description = "Trifft alle Gegner in der Nähe." })
add("Kampfschrei", { name = "Kampfschrei", element = "Neutral", kind = "Buff", stat = "atk", amount = 0.3, duration = 8, cooldown = 18, targets = "allies", radius = 25, description = "+30 % Angriff für dich und deine Gefährten." })
add("Schildwall", { name = "Schildwall", element = "Neutral", kind = "Shield", power = 50, duration = 8, cooldown = 20, targets = "self", description = "Absorbiert Schaden." })
-- Waldläufer
add("Pfeilschuss", { name = "Pfeilschuss", element = "Neutral", kind = "Damage", power = 12, cooldown = 0.8, range = 45, description = "Präziser Fernschuss." })
add("Mehrfachschuss", { name = "Mehrfachschuss", element = "Neutral", kind = "Area", power = 28, cooldown = 7, range = 45, radius = 8, description = "Pfeilregen auf das Ziel." })
add("Betaeubungspfeil", { name = "Betäubungspfeil", element = "Neutral", kind = "Stun", power = 20, duration = 2, cooldown = 14, range = 45, description = "Betäubt das Ziel." })
add("Adlerblick", { name = "Adlerblick", element = "Neutral", kind = "Buff", stat = "crit", amount = 0.25, duration = 10, cooldown = 20, targets = "self", description = "+25 % kritische Trefferchance." })
-- Magier
add("Arkanblitz", { name = "Arkanblitz", element = "Neutral", kind = "Damage", power = 14, cooldown = 1.0, range = 40, description = "Magisches Geschoss." })
add("Arkanexplosion", { name = "Arkanexplosion", element = "Neutral", kind = "Area", power = 35, cooldown = 8, range = 40, radius = 10, description = "Explosion am Ziel." })
add("Frostfessel", { name = "Frostfessel", element = "Wasser", kind = "Stun", power = 15, duration = 2.5, cooldown = 14, range = 35, description = "Friert das Ziel ein." })
add("Manaschild", { name = "Manaschild", element = "Neutral", kind = "Shield", power = 60, duration = 8, cooldown = 22, targets = "self", description = "Magischer Schutzschild." })
-- Bestienbändiger
add("Peitschenhieb", { name = "Peitschenhieb", element = "Neutral", kind = "Damage", power = 12, cooldown = 0.9, range = 14, description = "Peitschenangriff mit Reichweite." })
add("Rudelruf", { name = "Rudelruf", element = "Neutral", kind = "Buff", stat = "atk", amount = 0.35, duration = 10, cooldown = 18, targets = "allies", radius = 40, description = "+35 % Angriff für alle Gefährten." })
add("Bindungsheilung", { name = "Bindungsheilung", element = "Natur", kind = "Heal", power = 40, cooldown = 14, radius = 40, targets = "allies", description = "Heilt dich und deine Gefährten." })
add("WildesBand", { name = "Wildes Band", element = "Neutral", kind = "Buff", stat = "def", amount = 0.4, duration = 10, cooldown = 22, targets = "allies", radius = 40, description = "+40 % Verteidigung für das Team." })
-- Flammenkrieger
add("Flammenklinge", { name = "Flammenklinge", element = "Feuer", kind = "Damage", power = 20, cooldown = 0.8, range = 9, description = "Brennender Schwerthieb." })
add("Feuerwirbel", { name = "Feuerwirbel", element = "Feuer", kind = "Area", power = 50, cooldown = 7, radius = 12, selfCentered = true, description = "Flammenkreis um dich." })
add("Glutruestung", { name = "Glutrüstung", element = "Feuer", kind = "Shield", power = 70, duration = 8, cooldown = 18, targets = "self", description = "Rüstung aus Glut." })
add("Phoenixschlag", { name = "Phönixschlag", element = "Feuer", kind = "Dash", power = 90, cooldown = 20, range = 30, description = "Flammensprung zum Ziel." })
-- Schattenläufer
add("Schattendolch", { name = "Schattendolch", element = "Schatten", kind = "Damage", power = 18, cooldown = 0.6, range = 8, description = "Schneller Dolchstoß." })
add("Schattenschritt", { name = "Schattenschritt", element = "Schatten", kind = "Dash", power = 50, cooldown = 8, range = 30, description = "Teleport hinter das Ziel." })
add("Schattenmantel", { name = "Schattenmantel", element = "Schatten", kind = "Stealth", duration = 4, cooldown = 16, description = "Unsichtbar, nächster Treffer kritisch." })
add("Giftklinge", { name = "Giftklinge", element = "Schatten", kind = "Debuff", power = 30, stat = "def", amount = 0.35, duration = 10, cooldown = 12, range = 9, description = "Schaden und -35 % Verteidigung." })
-- Naturhüter
add("Dornenpeitsche", { name = "Dornenpeitsche", element = "Natur", kind = "Damage", power = 15, cooldown = 0.9, range = 30, description = "Dornige Ranke." })
add("Regeneration", { name = "Regeneration", element = "Natur", kind = "Heal", power = 50, cooldown = 12, radius = 30, targets = "allies", description = "Starke Gruppenheilung." })
add("Wurzelfessel", { name = "Wurzelfessel", element = "Natur", kind = "Stun", power = 15, duration = 2.5, cooldown = 14, range = 30, description = "Wurzeln halten das Ziel fest." })
add("Waldsegen", { name = "Waldsegen", element = "Natur", kind = "Buff", stat = "def", amount = 0.35, duration = 10, cooldown = 20, targets = "allies", radius = 40, description = "+35 % Verteidigung für das Team." })
-- Drachenritter
add("Drachenlanze", { name = "Drachenlanze", element = "Drache", kind = "Damage", power = 24, cooldown = 0.9, range = 12, description = "Mächtiger Lanzenstoß." })
add("Drachenatem", { name = "Drachenatem", element = "Drache", kind = "Area", power = 70, cooldown = 9, range = 20, radius = 12, description = "Drachenfeuer auf das Ziel." })
add("Schuppenpanzer", { name = "Schuppenpanzer", element = "Drache", kind = "Shield", power = 80, duration = 8, cooldown = 20, targets = "allies", radius = 40, description = "Schild für das ganze Team." })
add("Drachensturz", { name = "Drachensturz", element = "Drache", kind = "Dash", power = 120, cooldown = 22, range = 35, description = "Sturzangriff aus der Luft." })

------------------------------------------------------------------------
-- Spezialisierungen (durch Monsterbindung freigeschaltet, 4. Slot)
------------------------------------------------------------------------
add("Glutklinge", { name = "Glutklinge", element = "Feuer", kind = "Damage", power = 35, cooldown = 6, range = 9, description = "Feuer-Spezialisierung (Feuerwolf)." })
add("Schattenschleier", { name = "Schattenschleier", element = "Schatten", kind = "Stealth", duration = 3, cooldown = 18, description = "Schattenmagie (Schattenwesen)." })
add("Heilsporen", { name = "Heilsporen", element = "Natur", kind = "Heal", power = 35, cooldown = 14, radius = 25, targets = "allies", description = "Naturmagie (Naturgeist)." })
add("Drachenfeuer", { name = "Drachenfeuer", element = "Drache", kind = "Area", power = 60, cooldown = 12, range = 20, radius = 10, description = "Drachenmagie (Uralter Drache)." })
add("Felsenwall", { name = "Felsenwall", element = "Erde", kind = "Shield", power = 45, duration = 8, cooldown = 18, targets = "self", description = "Erdmagie (Steingolem)." })
add("Falkenauge", { name = "Falkenauge", element = "Wind", kind = "Debuff", stat = "def", amount = 0.25, duration = 10, cooldown = 14, range = 50, description = "Markiert das Ziel (Windfalke)." })
add("Quellsegen", { name = "Quellsegen", element = "Wasser", kind = "Heal", power = 30, cooldown = 12, radius = 25, targets = "allies", description = "Wassermagie (Wasserdrache)." })

------------------------------------------------------------------------
-- Monster-Fähigkeiten: [1] Grundangriff, [2] Spezial, [3] Unterstützung, [4] Einzigartig
------------------------------------------------------------------------
-- Moosling
add("Rankenpeitsche", { name = "Rankenpeitsche", element = "Natur", kind = "Damage", power = 12, cooldown = 1.2, range = 9, description = "Peitscht mit Ranken." })
add("Sporenheilung", { name = "Sporenheilung", element = "Natur", kind = "Heal", power = 25, cooldown = 12, radius = 18, targets = "allies", description = "Heilt Verbündete." })
add("Moosschild", { name = "Moosschild", element = "Natur", kind = "Shield", power = 20, duration = 6, cooldown = 18, targets = "allies", radius = 18, description = "Kleiner Schild für das Team." })
add("Bluetenregen", { name = "Blütenregen", element = "Natur", kind = "Heal", power = 50, cooldown = 30, radius = 22, targets = "allies", description = "Großer Heilregen." })
-- Kieselkrabbe
add("Scherenzwick", { name = "Scherenzwick", element = "Erde", kind = "Damage", power = 11, cooldown = 1.3, range = 7, description = "Kneift kräftig zu." })
add("Panzerung", { name = "Panzerung", element = "Erde", kind = "Buff", stat = "def", amount = 0.5, duration = 8, cooldown = 14, targets = "self", description = "+50 % Verteidigung." })
add("Krabbenspott", { name = "Krabbenspott", element = "Erde", kind = "Taunt", radius = 12, duration = 5, cooldown = 15, description = "Lockt Gegner an." })
add("Felsenstoss", { name = "Felsenstoß", element = "Erde", kind = "Stun", power = 30, duration = 2, cooldown = 20, range = 8, description = "Betäubender Stoß." })
-- Funkenmaus
add("Funkenbiss", { name = "Funkenbiss", element = "Feuer", kind = "Damage", power = 13, cooldown = 1.0, range = 7, description = "Funkensprühender Biss." })
add("Glutfunke", { name = "Glutfunke", element = "Feuer", kind = "Damage", power = 30, cooldown = 8, range = 25, description = "Schießt einen Glutfunken." })
add("Hitzewelle", { name = "Hitzewelle", element = "Feuer", kind = "Area", power = 18, cooldown = 14, radius = 10, selfCentered = true, description = "Hitze um sich herum." })
add("Flammenschweif", { name = "Flammenschweif", element = "Feuer", kind = "Dash", power = 40, cooldown = 16, range = 25, description = "Brennender Sprung." })
-- Brisenspatz
add("Federstoss", { name = "Federstoß", element = "Wind", kind = "Damage", power = 10, cooldown = 0.9, range = 18, description = "Wirft Federn." })
add("Windboe", { name = "Windböe", element = "Wind", kind = "Area", power = 20, cooldown = 10, range = 20, radius = 8, description = "Windstoß auf das Ziel." })
add("Aufwind", { name = "Aufwind", element = "Wind", kind = "Buff", stat = "atk", amount = 0.15, duration = 10, cooldown = 20, targets = "allies", radius = 25, description = "+15 % Angriff fürs Team." })
add("Wirbelsturm", { name = "Wirbelsturm", element = "Wind", kind = "Area", power = 40, cooldown = 25, range = 20, radius = 12, description = "Kleiner Tornado." })
-- Glühkäfer
add("Lichtstrahl", { name = "Lichtstrahl", element = "Licht", kind = "Damage", power = 11, cooldown = 1.2, range = 20, description = "Gebündeltes Licht." })
add("Blendlicht", { name = "Blendlicht", element = "Licht", kind = "Stun", power = 5, duration = 1.5, cooldown = 14, range = 20, description = "Blendet das Ziel." })
add("Leuchtsegen", { name = "Leuchtsegen", element = "Licht", kind = "Heal", power = 20, cooldown = 15, radius = 18, targets = "allies", description = "Sanftes Heillicht." })
add("Sonnenfunke", { name = "Sonnenfunke", element = "Licht", kind = "Area", power = 45, cooldown = 28, range = 20, radius = 10, description = "Explodierendes Licht." })
-- Feuerwolf
add("Feuerbiss", { name = "Feuerbiss", element = "Feuer", kind = "Damage", power = 16, cooldown = 1.0, range = 8, description = "Schneller Feuerbiss." })
add("Flammensprint", { name = "Flammensprint", element = "Feuer", kind = "Dash", power = 45, cooldown = 10, range = 30, description = "Springt brennend zum Ziel." })
add("Glutgeheul", { name = "Glutgeheul", element = "Feuer", kind = "Buff", stat = "atk", amount = 0.25, duration = 10, cooldown = 22, targets = "allies", radius = 30, description = "+25 % Angriff fürs Team." })
add("InfernoAnsturm", { name = "Inferno-Ansturm", element = "Feuer", kind = "Area", power = 80, cooldown = 30, range = 14, radius = 14, description = "Verheerende Feuerwalze." })
-- Steingolem
add("Steinfaust", { name = "Steinfaust", element = "Erde", kind = "Damage", power = 15, cooldown = 1.5, range = 8, description = "Schwerer Faustschlag." })
add("Herausforderung", { name = "Herausforderung", element = "Erde", kind = "Taunt", radius = 18, duration = 6, cooldown = 14, description = "Zieht alle Gegner auf sich." })
add("Steinhaut", { name = "Steinhaut", element = "Erde", kind = "Shield", power = 60, duration = 8, cooldown = 20, targets = "allies", radius = 25, description = "Steinschild für das Team." })
add("Erdbeben", { name = "Erdbeben", element = "Erde", kind = "Area", power = 60, cooldown = 28, radius = 16, selfCentered = true, description = "Erschüttert den Boden." })
-- Windfalke
add("Sturzflug", { name = "Sturzflug", element = "Wind", kind = "Damage", power = 17, cooldown = 1.1, range = 22, description = "Angriff aus der Luft." })
add("Windklinge", { name = "Windklinge", element = "Wind", kind = "Damage", power = 42, cooldown = 8, range = 30, description = "Schneidende Windklinge." })
add("Jagdmarkierung", { name = "Jagdmarkierung", element = "Wind", kind = "Debuff", stat = "def", amount = 0.3, duration = 10, cooldown = 16, range = 40, description = "-30 % Verteidigung am Ziel." })
add("Orkan", { name = "Orkan", element = "Wind", kind = "Area", power = 70, cooldown = 30, range = 25, radius = 14, description = "Gewaltiger Sturm." })
-- Wasserdrache
add("Wasserstrahl", { name = "Wasserstrahl", element = "Wasser", kind = "Damage", power = 16, cooldown = 1.2, range = 22, description = "Druckvoller Strahl." })
add("Flutwelle", { name = "Flutwelle", element = "Wasser", kind = "Area", power = 45, cooldown = 12, range = 22, radius = 14, description = "Flächenangriff." })
add("HeilenderRegen", { name = "Heilender Regen", element = "Wasser", kind = "Heal", power = 45, cooldown = 16, radius = 25, targets = "allies", description = "Heilt das ganze Team." })
add("Mahlstrom", { name = "Mahlstrom", element = "Wasser", kind = "Area", power = 95, cooldown = 32, range = 22, radius = 16, description = "Reißender Strudel." })
-- Schattenwesen
add("Schattenkralle", { name = "Schattenkralle", element = "Schatten", kind = "Damage", power = 18, cooldown = 1.0, range = 8, description = "Kralle aus Schatten." })
add("Tarnung", { name = "Tarnung", element = "Schatten", kind = "Stealth", duration = 4, cooldown = 14, description = "Verschwindet, nächster Treffer kritisch." })
add("Schwaechungsfluch", { name = "Schwächungsfluch", element = "Schatten", kind = "Debuff", stat = "atk", amount = 0.3, duration = 10, cooldown = 16, range = 25, description = "-30 % Angriff am Ziel." })
add("Schattenhinrichtung", { name = "Schattenhinrichtung", element = "Schatten", kind = "Damage", power = 140, executeBonus = 1.0, cooldown = 30, range = 10, description = "Doppelter Schaden gegen geschwächte Ziele." })
-- Naturgeist
add("Dornenranke", { name = "Dornenranke", element = "Natur", kind = "Damage", power = 15, cooldown = 1.2, range = 18, description = "Dornige Ranke." })
add("Wurzelgriff", { name = "Wurzelgriff", element = "Natur", kind = "Stun", power = 15, duration = 2.5, cooldown = 14, range = 20, description = "Hält das Ziel fest." })
add("Lebensquell", { name = "Lebensquell", element = "Natur", kind = "Heal", power = 50, cooldown = 15, radius = 25, targets = "allies", description = "Starke Teamheilung." })
add("WaldesZorn", { name = "Waldes Zorn", element = "Natur", kind = "Area", power = 85, cooldown = 30, range = 20, radius = 16, description = "Der Wald schlägt zurück." })
-- Uralter Drache
add("Drachenklaue", { name = "Drachenklaue", element = "Drache", kind = "Damage", power = 24, cooldown = 1.2, range = 10, description = "Uralte Klaue." })
add("Drachenodem", { name = "Drachenodem", element = "Drache", kind = "Area", power = 70, cooldown = 10, range = 20, radius = 14, description = "Odem des Drachen." })
add("Drachenschuppen", { name = "Drachenschuppen", element = "Drache", kind = "Shield", power = 80, duration = 8, cooldown = 20, targets = "allies", radius = 30, description = "Schuppenschild fürs Team." })
add("Urzeitbruellen", { name = "Urzeitbrüllen", element = "Drache", kind = "Area", power = 160, cooldown = 35, radius = 20, selfCentered = true, description = "Erschüttert alles im Umkreis." })
-- Boss: Glutkoloss
add("Glutschlag", { name = "Glutschlag", element = "Feuer", kind = "Damage", power = 30, cooldown = 1.6, range = 12, description = "Glühender Schlag." })
add("Magmawelle", { name = "Magmawelle", element = "Feuer", kind = "Area", power = 55, cooldown = 8, radius = 16, selfCentered = true, description = "Magma breitet sich aus." })
add("Feuerregen", { name = "Feuerregen", element = "Feuer", kind = "Area", power = 45, cooldown = 12, range = 40, radius = 12, description = "Feuer fällt vom Himmel." })
add("Ausbruch", { name = "Ausbruch", element = "Feuer", kind = "Area", power = 110, cooldown = 25, radius = 22, selfCentered = true, description = "Vulkanischer Ausbruch." })

return A
