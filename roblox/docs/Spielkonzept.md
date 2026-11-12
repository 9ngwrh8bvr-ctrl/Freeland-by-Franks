# Spielkonzept – Roblox-Fassung

Dieses Dokument überträgt das verbindliche Spielkonzept (Monstergefährten-System) auf Roblox.
Die Unreal-spezifischen Teile (GAS, Niagara, C++) wurden durch eigene Luau-Systeme ersetzt.
Spielerisch gilt das Konzept unverändert.

## Grundentscheidungen

| Thema | Entscheidung |
|---|---|
| Plattform | Roblox (PC, Handy, Tablet, Konsole) |
| Spieler | Mehrspieler, kooperativ (kein PvP) |
| Kommunikation | **kein Text-/Sprach-Chat**, nur vordefinierte **Emojis** und **Richtungspfeile** |
| Kamera / Kampf | Third-Person, Echtzeit, Zielauswahl per Klick/Tippen |
| Grafik | stilisiert; Platzhaltermodelle bis zu den echten Modellen |
| Geld verdienen | kostenlos spielbar; Game Passes + Edelsteine; **keine Lootboxen**, keine kaufbaren Monster oder Klassen |
| Fangmechanik | **Vertrauensritual**: Monster unter 35 % LP schwächen, nahe herangehen, Taste halten; Köder erhöhen die Chance (kein Werfen von Fanggegenständen) |

## Monster (Startumfang: 13)

| Monster | Element | Seltenheit | Rolle | Erkundung | Besonderes |
|---|---|---|---|---|---|
| Moosling | Natur | Gewöhnlich | Heiler | Klein | Starter |
| Kieselkrabbe | Erde | Gewöhnlich | Verteidiger | Klein | Starter |
| Funkenmaus | Feuer | Gewöhnlich | Angreifer | Klein | Starter |
| Brisenspatz | Wind | Gewöhnlich | Späher | Klein | |
| Glühkäfer | Licht | Ungewöhnlich | Unterstützer | Leuchten | |
| Feuerwolf | Feuer | Selten | Angreifer | – | Feuer-Spezialisierung → **Flammenkrieger** |
| Steingolem | Erde | Selten | Verteidiger | Zerschmettern | Erd-Spezialisierung |
| Windfalke | Wind | Selten | Späher | Fliegen | Markierung |
| Wasserdrache | Wasser | Episch | Heiler/Fläche | Schwimmen | Wassermagie |
| Schattenwesen | Schatten | Episch | Assassine | Runensicht | Schattenmagie → **Schattenläufer** |
| Naturgeist | Natur | Episch | Heiler | Wachstum | Naturmagie → **Naturhüter** |
| Uralter Drache | Drache | Legendär | Angreifer | Fliegen, Zerschmettern | nur nach **Drachenprüfung** fangbar → **Drachenritter** |
| Glutkoloss | Feuer | Einzigartig | Boss | – | **nicht fangbar** |

Jedes Monster hat 4 Fähigkeiten, 3 Entwicklungsstufen (Level 1 / 16 / 32, eigener Name und
größeres Modell), Grundwerte, ein Element mit Stärken/Schwächen und ein individuelles
Potenzial (±8 % Werte).

**Elemente:** Wasser > Feuer, Erde · Feuer > Natur · Erde > Feuer, Wind · Natur > Wasser, Erde ·
Wind > Natur · Licht ⇄ Schatten · Drache > Drache. Stark = ×1,5, schwach = ×0,67.

## Bindung (Stufe 1–5)

| Stufe | Wirkung |
|---|---|
| 1 | Grundangriff |
| 2 | Spezialfähigkeit, per Befehl (`F`) |
| 3 | automatische Kampfunterstützung (Heilen, Schild, Spott …), +5 % krit., **Spezialisierung** für den Spieler |
| 4 | Einzigartige Fähigkeit, per Befehl (`V`) |
| 5 | Klassen- und Skillfreischaltung |

Bindungs-EP gibt es für gemeinsame Kämpfe, Bosskämpfe (viel), Erkundung mit der Monsterfähigkeit,
Training am Trainingsplatz, Quests und Bindungssnacks. Jede Bindungsstufe erhöht zusätzlich die Werte.

## Gefährten im Kampf

- Anzahl aktiver Gefährten: 1 → 2 (Level 10) → 3 (Level 25); Bestienbändiger und Naturhüter +1
- Modi: **Verteidigen** (hilft bei deinem Ziel und gegen Angreifer), **Angriff** (greift alles in der Nähe an), **Passiv**
- Befehle: Fokus aufs Ziel, Spezialfähigkeit, Einzigartige Fähigkeit, Zurückrufen
- Besiegte Gefährten sind 45 s erschöpft (Rastplatz oder Wiederbelebungskraut helfen sofort)

## Klassen

| Klasse | Typ | Freischaltung |
|---|---|---|
| Krieger | Nahkampf | sofort |
| Waldläufer | Fernkampf (Bogen) | sofort |
| Magier | Flächenmagie | sofort |
| Bestienbändiger | Monster-Spezialist, +1 Gefährte, stärkere Gefährten | sofort |
| Flammenkrieger | Nahkampf + Feuer | Level 20 · Feuerwolf Bindung 5 · Entwicklungsstufe 2 · Quest „Feuerprobe“ |
| Schattenläufer | Tarnung + krit. Treffer | Level 20 · Schattenwesen Bindung 5 · Quest „Der Runenpfad“ |
| Naturhüter | Heilung + Unterstützung, +1 Gefährte | Level 20 · Naturgeist Bindung 5 · Quest „Heilung des Hains“ |
| Drachenritter | Elite: Drachenmagie | Level 40 · Uralter Drache Bindung 4 · Quest „Der Drachenschwur“ |

Jede Klasse hat einen eigenen **Skilltree** (Talente, 1 Punkt pro Level, zurücksetzbar) und 4 Fähigkeiten.
Die **Spezialisierung** aus der Monsterbindung (Taste `5`) ist klassenunabhängig. So spielt sich
ein Magier mit Schattenmagie anders als ein Krieger mit Feuer-Spezialisierung.

## Erkundung mit Monsterfähigkeiten (Test-Welt)

| Fähigkeit | Monster | Beispiel |
|---|---|---|
| Zerschmettern | Steingolem, Uralter Drache | Felsblock vor einer Schatznische |
| Fliegen | Windfalke, Uralter Drache | Klippe, Drachenhorst |
| Schwimmen | Wasserdrache | Unterwasser-Grotte |
| Leuchten | Glühkäfer | dunkle Höhle mit Lichtsiegel |
| Klein | Moosling, Kieselkrabbe, Funkenmaus, Brisenspatz | Felsspalt |
| Wachstum | Naturgeist | verdorrte Bäume |
| Runensicht | Schattenwesen | verborgene Runen (nur sichtbar mit Schattenwesen) |

Jeder Spieler braucht **eigene** Gefährten mit der Fähigkeit. Geöffnete Wege gelten nur für ihn.

## Verknüpfung der Systeme

- **Charakterlevel** → Gefährtenplätze, Fähigkeiten, Talentpunkte, Quest-Voraussetzungen
- **Klassen** → durch Monsterbindung + Prüfungsquests freigeschaltet
- **Skilltrees** → Talente verstärken Gefährten (Angriff/LP), Bindungs-EP, Fangchance
- **Kampf** → Element-System, Gefährtenrollen, Spott/Heilung/Tarnung
- **Erkundung & Rätsel & Gebietszugang** → nur mit passenden Monsterfähigkeiten
- **Quests** → Prüfungen verlangen bestimmte Gefährten (z. B. „mit deinem Feuerwolf“)
- **Ausrüstung** → Amulette verstärken Gefährten und Bindung

## Kommunikation ohne Chat

- **Emoji-Rad** (`T` / 😀): 16 Emojis (👋 👍 👎 🙏 😄 😮 😢 ❤️ ❓ ❗ ⚔️ 🆘 💚 👣 ✋ 🎉) + 3 VIP-Emojis
- **Richtungspfeile** (`Z` / 📍): Marker „Hierher“, „Gefahr“, „Angreifen“, „Schatz“, „Monster“.
  Andere Spieler sehen den Marker in der Welt und einen Pfeil am Bildschirmrand.
- Text- und Sprach-Chat sind deaktiviert; es gibt keine freien Texteingaben (auch keine Monster-Spitznamen).

## Shop

| Bereich | Inhalt |
|---|---|
| Münzen (erspielt) | Tränke, Köder, Bindungssnacks, Wiederbelebung, Ausrüstung |
| Edelsteine | Goldene Lockfrucht, Snack-/Kraut-Pakete, Gehege-Erweiterung, Auren (Kosmetik) |
| Game Passes | VIP (+15 % Münzen, VIP-Emojis), Großes Gehege (+100 Plätze), Doppelte Bindung |
| Developer Products | 100 / 550 / 1200 Edelsteine, Abenteurerpaket |

## Nächste Schritte

1. Echte 3D-Modelle und Animationen für die Monster (Blender → Roblox)
2. Eigene Karte statt der Test-Welt, mit NPCs und Dialogen
3. Monster tauschen zwischen Spielern (sicher, nur über Oberfläche)
4. Sounds und Musik
5. Tutorial für die ersten 10 Minuten
6. Englische Übersetzung (Roblox-Lokalisierung)
7. Spieltests und Balancing (Datenwerte in `Config/`)
