# Freeland – Chroniken von Lindenhain (Roblox)

Ein Mehrspieler-Action-RPG für Roblox, in dem du Monster als Gefährten gewinnst und
gemeinsam mit ihnen kämpfst, erkundest und neue Klassen freischaltest.
Das ausführliche Spielkonzept steht in [`docs/Spielkonzept.md`](docs/Spielkonzept.md).

Der gesamte Code ist **Luau** und wird mit **Rojo** aus diesem Ordner in Roblox Studio
übertragen. Alle Oberflächen werden im Code gebaut. Eine **Test-Welt** wird automatisch
erzeugt, sodass das Spiel sofort spielbar ist.

---

## 1. Einrichtung (einmalig)

1. **Roblox Studio** installieren: <https://create.roblox.com>
2. **Rojo** installieren (überträgt den Code nach Studio). Am einfachsten:
   - Visual Studio Code installieren und dort die Erweiterung **„Rojo – Roblox Studio Sync“** hinzufügen, **oder**
   - Rojo per Kommandozeile installieren (z. B. mit `rokit add rojo-rbx/rojo` oder von der Rojo-Webseite).
3. Das **Rojo-Plugin für Roblox Studio** installieren (die VS-Code-Erweiterung bietet das an).

## 2. Spiel starten

```bash
cd roblox
rojo serve
```

In Roblox Studio: neue leere Baseplate öffnen → Plugins → **Rojo → Connect**.
Danach auf **Play** drücken.

Alternativ als Datei bauen: `rojo build -o Freeland.rbxl` und die Datei in Studio öffnen.

> Die Test-Welt entsteht nur, wenn im Workspace **kein** Ordner `Map` existiert.
> Die Standard-„Baseplate“ von Studio wird dabei automatisch entfernt.

## 3. Wichtige Einstellungen in Studio / Creator Dashboard

| Einstellung | Wo | Wert |
|---|---|---|
| Speichern testen | Game Settings → Security | **Enable Studio Access to API Services** an |
| Text-Chat | wird vom Spiel abgeschaltet (Projektdatei + Client) | – |
| Sprach-Chat | Game Settings → Communication | **Voice Chat aus** |
| Altersfreigabe | Creator Dashboard → Experience Questionnaire | ausfüllen (Kampf mit Fantasy-Monstern, keine Chats) |
| Genre / Geräte | Creator Dashboard → Places | Rollenspiel; PC, Handy, Tablet, Konsole |

Hinweis: Funktionen der Roblox-Plattform außerhalb des Spiels (z. B. Freundschaftsanfragen
oder private Nachrichten in der Roblox-App) können von einem Spiel nicht abgeschaltet werden.
Im Spiel selbst gibt es **keinen** Chat, nur Emojis und Richtungspfeile.

## 4. Shop mit Robux einrichten

1. Spiel veröffentlichen (File → Publish to Roblox).
2. Creator Dashboard → dein Spiel → **Monetization**:
   - **Passes**: „VIP-Abenteurer“, „Großes Gehege“, „Doppelte Bindung“ anlegen
   - **Developer Products**: „100/550/1200 Edelsteine“, „Abenteurerpaket“ anlegen
3. Die IDs in [`src/shared/Config/Shop.luau`](src/shared/Config/Shop.luau) bei `id = 0` eintragen.

Solange eine ID `0` ist, zeigt der Shop „Bald verfügbar“. Käufe werden auf dem Server
einmalig gutgeschrieben und erst nach erfolgreichem Speichern bestätigt.

## 5. Eigene Inhalte einbauen

### Eigene Monster-Modelle
Lege ein Model mit der Monster-ID als Namen (z. B. `Feuerwolf`) in
`ReplicatedStorage → Assets → Monsters`. Anforderungen: `HumanoidRootPart` als PrimaryPart
und ein `Humanoid`. Ohne Modell erscheint ein farbiger Platzhalter.

### Eigene Karte
Erstelle im Workspace einen Ordner **`Map`**. Dann wird die Test-Welt nicht mehr gebaut.
Spielfunktionen werden über **Tags** (Tag-Editor in Studio) und **Attribute** vergeben:

| Tag | Attribute | Wirkung |
|---|---|---|
| `MonsterSpawnZone` | `Species` („Moosling,Funkenmaus“), `MinLevel`, `MaxLevel`, `MaxCount`, `Respawn` | wilde Monster |
| `ExploreGate` | `GateId`, `Trait`, `Action` (`Open`/`Teleport`/`Loot`/`Light`/`Grow`), `Reward` („coins:80,Heiltrank:2“), `RequiresGate`, `Label` | Erkundung mit Monsterfähigkeiten |
| `TrainingSpot` | – | Training (Bindung) |
| `RestSpot` | – | Heilt Spieler + Gefährten |
| `HiddenRune` | (zusätzlich zu `ExploreGate`) | nur mit Runensicht sichtbar |

Für `Teleport` ein `ObjectValue` namens `Target` (Ziel-Part) in das Tor legen,
für `Light` ein `ObjectValue` namens `Lights` (Ordner mit Lichtern).

### Daten & Balancing
Alle Werte stehen in `src/shared/Config/`:
`Monsters`, `Abilities`, `Classes` (inkl. Skilltrees), `Items`, `Quests`, `Shop`,
`Communication` (Emojis/Pfeile), `GameConfig` (allgemeine Werte).

## 6. Steuerung

| Aktion | PC | Handy/Tablet |
|---|---|---|
| Ziel wählen | Monster anklicken / `Tab` | antippen / „⟳ Ziel“ |
| Grundangriff, Fähigkeiten | `1` `2` `3` `4` | runde Knöpfe rechts |
| Spezialisierung | `5` | Knopf „Spez.“ |
| Gefährten: Spezial / Einzigartig | `F` / `V` | 🐾✨ / 🐾🌟 |
| Gefährten: Fokus / Modus / Zurück | `Q` / `G` / `R` | 🎯 / 🛡️ / ↩️ |
| Vertrauensritual (Fangen) | `E` halten | Knopf halten |
| Emojis / Richtungspfeil | `T` / `Z` | 😀 / 📍 |

## 7. Tests

```bash
cd roblox
cargo run --release --manifest-path tools/luaurun/Cargo.toml -- tests/run_tests.luau
```
Prüft die Syntax aller Dateien, die Konsistenz aller Spieldaten (z. B. dass jede
Fähigkeit, jedes Item und jede Quest existiert) und die Spielformeln.
Linter: `selene src tests`, Formatierung: `stylua src tests`.

## 8. Projektstruktur

```
roblox/
├── default.project.json      Rojo-Projekt (Zuordnung zu Roblox-Diensten)
├── src/shared/               ReplicatedStorage.Shared – Daten, Formeln, Netzwerk
│   ├── Config/               alle Spieldaten
│   ├── Formulas.luau         Rechenregeln (Server + Client)
│   └── Net.luau              RemoteEvents/RemoteFunctions
├── src/server/               ServerScriptService.Server
│   ├── Main.server.luau      startet alle Dienste
│   ├── Services/             Daten, Kampf, Gefährten, KI, Fangen, Quests, Shop …
│   └── Modules/              Monster-Bau, Fähigkeiten, Hinweise
├── src/client/               StarterPlayerScripts.Client – HUD, Menüs, Eingabe, Effekte
├── src/character/            ersetzt die Standard-Regeneration
├── tests/                    Tests außerhalb von Roblox
└── tools/luaurun/            kleiner Luau-Testrunner (Rust)
```
