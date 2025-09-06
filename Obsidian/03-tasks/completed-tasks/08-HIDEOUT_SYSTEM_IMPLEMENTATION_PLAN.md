# Implementierungsplan – Hideout-System (modular, zukunftsfest)

Status: Not Started  
Owner: Solo (Indie)  
Priority: High  
Dependencies: EventBus, GameOrchestrator (autoload), RunManager, Logger, RNG, scenes/ui, tests harness  
Risk: Low-Medium (neue Szenen + Autoload-Fluss, additive)  
Complexity: 4/10

---

🧙🏾‍♂️: Verstanden – du willst einen klaren Implementierungsplan für das Hideout:

White-Coding-freundlich (also schlank, Cloud-Session-ready).  
Modular, sodass du später Hauptmenü, Charakter-Selektion, Debug-Weichen, Map-System leicht andocken kannst.  
Kein Refactor-Albtraum in 3 Monaten.

Ich skizziere dir das wie ein Drehbuch für deine Coding-Session, aber auf Architekturebene – du kannst es in Cloud als Checkpoints abarbeiten.

💠: Implementierungsplan – Hideout-System (modular, zukunftsfest)

## 1) Projektstruktur vorbereiten

Ordner anlegen
```
/scenes/
  /core/       (Hauptmenü, Hideout, Debug-Tools)
  /maps/       (alle Spielmaps, Testarena, Biome)
  /ui/         (HUD, Charakterwahl, Debug-Overlays)
/scripts/
  /systems/    (Spawner, Menu-Fluss, ggf. SaveManager)
  /domain/     (Configs/Resources falls nötig)
```

Autoloads (Project Settings → Autoload):
- GameOrchestrator.gd – zentrales Flow/Boot-Management (Repo hat bereits GameOrchestrator; entspricht „GameManager“ in diesem Plan)
- EventBus.gd – globaler Signalhub
- Logger.gd, RunManager.gd – bereits vorhanden
- SaveManager.gd – optional (später, Platzhalter/stub)

Hinweis (Repo-Adaptation): Dieser Plan spricht von „GameManager“. Im aktuellen Repo bitte GameOrchestrator als zentrale Instanz nutzen.

## 2) Hideout-Szene bauen (modular, minimal)

Node-Struktur:
```
Hideout.tscn
├── (Root) Node2D YSort
│    ├── PlayerSpawnPoint (Marker2D)  # eindeutiger Name/ID, z.B. "spawn_hideout_main"
│    ├── MapDevice (Node2D, CollisionShape2D, Interact-Label)
│    ├── ItemStash (optional Dummy)
│    ├── NPCs (optional Platzhalter)
└── Camera2D
```

Wichtig: PlayerSpawnPoint bekommt eine eindeutige ID → GameOrchestrator setzt Spieler dorthin.

## 3) Debug-/Entwicklungsweiche

In GameOrchestrator: DebugConfig laden (z. B. `res://config/debug.json` oder `.t`).

Beispiel-Config:
```json
{
  "debug_mode": true,
  "start_mode": "map",    // "hideout" | "map" | "map_test"
  "map_scene": "res://scenes/maps/test_map.tscn",
  "character_id": "knight_default"
}
```

Startlogik (Pseudo):
- Wenn `debug_mode == true`: `start_mode` aus Config lesen
  - "hideout" → Hideout.tscn laden, Spieler an PlayerSpawnPoint instanzieren
  - "map" → gewünschte Map laden, Spieler an dortigen PlayerSpawnPoint instanzieren
- Später: Menüfluss überschreibt Debug-Start

## 4) Spieler-Spawn sauber kapseln

`scripts/systems/PlayerSpawner.gd` (kleines Helfer-Script):
- Input: `spawn_point_id: String`
- Lädt Spieler-Szene, positioniert an Marker2D mit passender ID
- Einheitlicher Aufruf aus Hideout und Map
- Logger/EventBus nutzen, deterministisch mit RNG falls nötig

## 5) Hauptmenü & Charakterselektion vorbereiten (nur Platzhalter)

- `MainMenu.tscn`: Buttons „Start Game“, „Options“, „Quit“
  - „Start Game“ → lädt `CharacterSelect.tscn`
- `CharacterSelect.tscn`: Dummy-Charaktere (Knight, Ranger, Arcanist)
  - Auswahl → an GameOrchestrator übergeben (`active_character_id`)
  - Danach → `GameOrchestrator.load_hideout()`

Zukunftssicher: Später echte Profil/Save-Daten an denselben Hook hängen.

## 6) Lose Koppelung sicherstellen

- GameOrchestrator entscheidet allein, welche Szene geladen wird
- Hideout kennt keine Map-Logik; Map kennt nicht das Menü
- UI/Interactables senden Events:
  - `EventBus.emit("request_enter_map", { "map_id": "forest_01" })`
- GameOrchestrator hört zu, lädt Map, setzt Spawn

## 7) Cloud-Session Flow (Vibe-Coding)

Checkpoints:
1. Autoloads bereit (GameOrchestrator existiert, EventBus, Logger, RunManager)
2. Hideout.tscn mit PlayerSpawnPoint
3. DebugConfig (debug.json/.tres) + Startlogik (Hideout vs Map) im GameOrchestrator
4. PlayerSpawner.gd (einheitliches Instanziieren)
5. MainMenu + CharacterSelect (Dummies, nur Übergabe an GameOrchestrator)
6. MapDevice im Hideout, das Event `request_enter_map` feuert

Ergebnis: Hideout als Hub, Debug-Bypass für schnelles Testen, Basis für Menü + Charakterwahl – modular und zukunftsfest.

---

## Goals & Acceptance Criteria

- [ ] Debug-Startlogik wählbar: „hideout“ | „map“ | „map_test“
- [ ] Einheitlicher Player-Spawn via PlayerSpawner
- [ ] Event-getriebener Übergang Hideout → Map via EventBus
- [ ] Menü/Char-Select Dummies übergeben Charakter-ID
- [ ] Keine harte Kopplung zwischen UI/Hideout/Map – Orchestrierung via GameOrchestrator
- [ ] Dokumentation/Changelog aktualisiert

---

## File Touch List (Plan)

Code:
- `autoload/GameOrchestrator.gd` (+ Debug-Startlogik, EventBus-Verkabelung)
- `scripts/systems/PlayerSpawner.gd` (NEU)
- `scenes/core/Hideout.tscn` (NEU)
- `scenes/ui/MainMenu.tscn` (NEU, Dummy)
- `scenes/ui/CharacterSelect.tscn` (NEU, Dummy)
- `scenes/core/MapDevice.tscn` (optional, oder Teil von Hideout)

Data/Config:
- `config/debug.json` oder `.tres` (NEU)

Docs:
- `docs/ARCHITECTURE_QUICK_REFERENCE.md` (Hideout/Fluss ergänzt)
- `docs/ARCHITECTURE_RULES.md` (Lose Kopplung/Signals)
- `changelogs/features/YYYY_MM_DD-hideout_system.md` (Feature-Eintrag)

Tests:
- `tests/test_hideout_boot.gd` (isoliert, lädt Hideout und prüft Spawn)
- `tests/test_debug_boot_modes.gd` (hideout/map/map_test)

---

## Repo-Adaptation Notes

- „GameManager“ in der Spezifikation → im Repo bitte „GameOrchestrator“ verwenden (bereits Autoload).
- SaveManager ist optional und kann später als Stub ergänzt werden (Profil/Charakterpersistenz).
- Logger/EventBus sind vorhanden – bitte für Interaktionen (MapDevice → Request) und Logs nutzen.
- Halte dich an .clinerules (statische Typen, EventBus, keine direkte Kopplung, ein Skript pro Szene).

---

## Minimaler Rollout (empfohlen)

- [ ] C1: `Hideout.tscn` + `PlayerSpawnPoint` erstellen
- [ ] C2: `PlayerSpawner.gd` (stub) einfacher Spawn aus GameOrchestrator
- [ ] C3: `debug.json` + Startlogik in GameOrchestrator (hideout/map)
- [ ] C4: MapDevice-Interactable → `request_enter_map` Event
- [ ] C5: MainMenu/CharacterSelect (Dummy) → Übergabe an Orchestrator

Kleine, risikoarme Schritte mit sichtbarem Fortschritt.

---

## Next Recommended TODO to tackle (bewertet)

1) „Checkpoint 2: Hideout.tscn mit PlayerSpawnPoint“  
Begründung: Kleinster, isolierter Schritt mit sofort sichtbarem Ergebnis; entkoppelt von Save/Char-Select; bereitet den Debug-Boot vor. Passt zu Repo-Realität (GameOrchestrator schon vorhanden, EventBus vorhanden).  
Akzeptanz: Szene lädt, Marker2D „spawn_hideout_main“ existiert.

2) Danach: „Checkpoint 3: DebugConfig + Startlogik (GameOrchestrator)“  
Begründung: Schaltet White-Coding-Fluss frei (Cloud-Session-ready). Übergang hideout/map ohne Codeänderung konfigurierbar.

3) Dann: „Checkpoint 4: PlayerSpawner.gd“  
Begründung: Vereinheitlicht Spawn (Hideout/Map), erleichtert Tests.

Diese Reihenfolge maximiert Value bei minimalem Risiko und bindet sich sauber in bestehende Autoload-Architektur ein.

## Architecture Alignment Update (2025-09-06)

Ist-Zustand im Repo:
- Main.tscn instanziert Arena.tscn statisch.
- GameOrchestrator (autoload) initialisiert und injiziert Systeme, lädt aber keine Szenen.
- Kein Hideout vorhanden.

Entscheidung (inkrementell, risikoarm):
- Start-Mode-Auswahl erfolgt kurzfristig in Main.gd (liest res://config/debug.json/.tres) und instanziert dynamisch Hideout oder Arena.
- GameOrchestrator bleibt unverändert als System-Orchestrator.
- Später kann die Boot-Entscheidung in GameOrchestrator migriert werden, wenn gewünscht.

## Phase 0 — Boot Switch via Main.gd (kleinstmögliche Änderung)

Ziel: Ohne invasive Refactors sofort zwischen Hideout/Arena umschalten können, verifizierbar in kleinen Schritten.

Schritte:
- 0.1 Create `res://config/debug.json`:
  ```json
  {
    "debug_mode": true,
    "start_mode": "hideout", // "hideout" | "map" | "map_test"
    "map_scene": "res://scenes/arena/Arena.tscn",
    "character_id": "knight_default"
  }
  ```
- 0.2 Edit `scenes/main/Main.tscn`: Entferne statische Arena-Instanz; nur `Main` Node2D mit Script behalten.
- 0.3 Update `scenes/main/Main.gd`:
  - In `_ready()` DebugConfig laden (FileAccess + JSON.parse)
  - `if debug_mode && start_mode == "hideout"` → `res://scenes/core/Hideout.tscn` instanzieren
  - sonst → `res://scenes/arena/Arena.tscn` instanzieren (Status quo)
  - Bisherige EventBus-Verbindung (combat_step) beibehalten; Logging ergänzen.
- 0.4 Create `scenes/core/Hideout.tscn` (minimal):
  ```
  Hideout.tscn
  ├── Node2D (Root)
  │    ├── PlayerSpawnPoint: Marker2D (name: "spawn_hideout_main")
  │    └── MapDevice (Node2D, optional Platzhalter)
  └── Camera2D
  ```

Akzeptanz (Phase 0):
- Projekt startet in Hideout, wenn debug_mode=true und start_mode="hideout".
- Umstellen auf "map" lädt die Arena wie bisher, ohne Änderungen an GameOrchestrator.

Phase 0 — File Touch List:
- scenes/main/Main.tscn (EDIT)
- scenes/main/Main.gd (EDIT)
- config/debug.json (NEW)
- scenes/core/Hideout.tscn (NEW)

Verification Breakpoint 0:
- Spiel starten → Hideout sichtbar (Marker + Kamera).
- debug.json auf "map" stellen → Arena sichtbar wie bisher.
- Danach Phase 1 ausführen (Spawner/Events) oder Plan anpassen.
