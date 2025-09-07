# PoE-Style Character System — Per-Character Profiles & Progression

Status: ✅ Complete  
Owner: Solo (Indie)  
Priority: High  
Dependencies: EventBus, Logger, GameOrchestrator, PlayerProgression, SaveManager (or internal save module), UI Framework  
Risk: Medium (touches boot flow and persistence paths)  
Complexity: 5/10 (moderate; additive systems + UI)

**COMPLETED**: September 7, 2025  
**Implementation**: Complete PoE-style character system with MVP + post-MVP enhancements. Includes CharacterProfile resources, CharacterManager autoload, enhanced character list UI, debug integration, and comprehensive testing (10/10 tests passing). See PR #14 and changelog.  
**Pull Request**: https://github.com/AgentService/vibe/pull/14

---

## Problem / Intent

Move from a single global progression to Path-of-Exile–style multiple characters. Each character has its own class, name, level, XP, and save file. Players can create, select, and persist multiple characters independently.

### Current State Review

- PlayerProgression.gd (autoload):
  - Already implemented with typed API: gain_exp(amount), load_from_profile(profile: Dictionary), export_state() -> Dictionary
  - Emits EventBus signals: xp_gained(amount, new_total), leveled_up(new_level, prev_level), progression_changed(state: Dictionary)
  - Loads resources at res://data/progression/xp_curve.tres and res://data/progression/unlocks.tres
  - Has _update_xp_to_next(), multi-level-up loop, and max-level handling
  - Uses Logger for structured logs, but also prints to stdout in gain_exp/_level_up (OK for dev; consider replacing with Logger later)
- Boot and menu flow:
  - Main.gd loads initial scene based on config/debug.tres; "menu" starts MainMenu.tscn
  - MainMenu.gd Start Game → EventBus.request_enter_map with { map_id: "character_select" }
  - CharacterSelect.gd shows class buttons (Knight/Ranger/Mage), then immediately emits EventBus.request_enter_map to hideout with { character_id, character_data } (no name input, no persistence)
  - No CharacterManager or per-character save exists yet; selection is session-only

### Design Implications

- Reuse CharacterSelect.tscn for MVP by adding a Name input and creating a CharacterProfile upon class confirmation.
- On “select”, create/load profile, inject into PlayerProgression via load_from_profile(), then transition to hideout.
- Persist minimal profile fields in user://profiles/{id}.tres using a typed Resource for editor friendliness.
- Defer full profile listing and deletion to a later phase.

---

## Goals & Acceptance Criteria

- Character creation:
  - [ ] Screen to enter name and select class (Knight/Ranger)
  - [ ] Validate unique name or generate unique ID regardless of name collisions
- Character-specific progression:
  - [ ] Each character tracks its own {level, exp} and any character-specific unlocks
  - [ ] Progression updates route through existing PlayerProgression API for isolation
- Character persistence (per-character save):
  - [ ] Save and load one file per character (user://profiles/{character_id}.tres or .json)
  - [ ] Track created_date and last_played (ISO "YYYY-MM-DD")
  - [ ] Robust error handling (no crashes on corrupt/missing files)
- Character selection:
  - [ ] Character select screen lists profiles with metadata
  - [ ] Selecting a character wires PlayerProgression + systems to that profile
- Determinism & architecture:
  - [ ] No change to gameplay determinism; boot flow only
  - [ ] Signals via EventBus; no cross-module reach-ins
  - [ ] All arrays/dicts typed; minimal allocations in hot paths
- Tests/docs:
  - [ ] Isolated tests for manager CRUD and per-character progression save/load
  - [ ] Architecture docs + changelog entry

---

## Data Structures

### Character Profile (Resource-backed; saved per character)

Preferred save format: .tres (text, editor-friendly). JSON is acceptable if already standardized.

```
# scripts/resources/CharacterProfile.gd
extends Resource
class_name CharacterProfile

@export var id: StringName
@export var name: String
@export var clazz: StringName        # "Knight" | "Ranger"
@export var level: int               # mirror of PlayerProgression.level
@export var exp: float               # mirror of PlayerProgression.exp
@export var created_date: String     # "YYYY-MM-DD"
@export var last_played: String      # "YYYY-MM-DD"
@export var meta: Dictionary = {}    # future: cosmetics, playtime, etc.
@export var progression: Dictionary = {}  # PlayerProgression.export_state() passthrough
```

Example (logical shape):
```
{
  "id": "knight_myknight_7F3A1C",
  "name": "MyKnight",
  "clazz": "Knight",
  "level": 5,
  "exp": 750.0,
  "created_date": "2025-01-15",
  "last_played": "2025-01-16",
  "progression": {"level": 5, "exp": 750.0, "xp_to_next": 250.0}
}
```

Save path layout:
- user://profiles/
  - {id}.tres  (or .json)
- user://profiles/index.json (optional cache for quick listing)

ID generation:
- `id = slug(clazz + "_" + name) + "_" + short_random_suffix`
- Ensure uniqueness by retrying if file exists.

---

## Systems & Signals

### CharacterManager (autoload)

Responsibilities:
- Own the list of character profiles
- Create/delete/load/save individual profiles
- Track current selection; integrate with PlayerProgression

API (typed):
```
class_name CharacterManager extends Node

var current_profile: CharacterProfile
var profiles: Array[CharacterProfile] = []

func list_characters() -> Array[CharacterProfile]
func create_character(name: String, clazz: StringName) -> CharacterProfile
func delete_character(id: StringName) -> void
func load_character(id: StringName) -> void
func save_current() -> void
func get_current() -> CharacterProfile
```

Signals (EventBus):
```
signal characters_list_changed(profiles: Array[Dictionary])  # shallow summary for UI
signal character_created(profile: Dictionary)
signal character_deleted(character_id: StringName)
signal character_selected(profile: Dictionary)
```

### PlayerProgression integration

- On character selection:
  - PlayerProgression.load_from_profile(current_profile.progression)
- On XP gain / level up:
  - CharacterManager listens to EventBus.progression_changed and updates `current_profile.level`, `current_profile.exp`, and `current_profile.progression`, then `save_current()` with throttling/debounce.
- On save:
  - Persist full CharacterProfile resource to user://profiles/{id}.tres

---

## UI

- CharacterSelectScreen.tscn/gd
  - List existing characters (name, class, level, last_played)
  - Buttons: Play (Select), Delete, Create New
- CharacterCreateScreen.tscn/gd
  - Name input, Class toggles (Knight/Ranger)
  - Validate input, create via CharacterManager, then route to select or launch
- Boot flow (GameOrchestrator):
  - If no current character, open CharacterSelect
  - If none exist, open CharacterCreate

## MVP Implementation (Simple Base)

- Persistence:
  - CharacterProfile.gd Resource with fields: id, name, clazz, level, exp, created_date, last_played, progression
  - Save path: user://profiles/{id}.tres (ensure directory exists)
- CharacterManager (autoload, minimal):
  - create_character(name: String, clazz: StringName) -> CharacterProfile
  - load_character(id: StringName) -> void sets current_profile
  - save_current() -> void writes current_profile to disk
  - Subscribe to EventBus.progression_changed and update current_profile.level/exp/progression; call save_current() (debounced optional)
- UI flow:
  - Keep MainMenu.gd as-is (Start → CharacterSelect)
  - Modify CharacterSelect.gd to add a Name LineEdit; on class selection:
    - name = input or fallback "Hero"
    - profile = CharacterManager.create_character(name, clazz)
    - PlayerProgression.load_from_profile(profile.progression)
    - GameOrchestrator.go_to_hideout() or emit EventBus.request_enter_map for hideout
- Scope limitations:
  - No character list UI yet
  - No delete/rename; no options menu integration
  - Unique ID generation ensures no collision even if names repeat

## Optional Enhancements (Later)

- Character list in CharacterSelect:
  - Show existing profiles with Play/Delete/Create New
  - Sort by last_played desc
- Validation/polish:
  - Unique name validation prompt
  - Class portraits and stats preview
  - Cloud sync hooks and import/export
- Autosave policy:
  - Debounced save via Timer (e.g., 1s) and on mode changes
- Migration:
  - One-time migration from any legacy global progression into a default character

---

## Implementation Plan (Phases & Checklist)

### Phase A — Resources & Save Path
- [ ] scripts/resources/CharacterProfile.gd (typed Resource)
- [ ] Save path helpers: user://profiles/
- [ ] Utility: id generation + slugify(name)

Output: Editor-inspectable resource; save folder resolved.

### Phase B — CharacterManager Autoload
- [ ] autoload/CharacterManager.gd: CRUD, list, load/save, current_profile
- [ ] EventBus signals wired (characters_list, character_created, etc.)
- [ ] Index rebuild (optional): scan user://profiles/ for .tres on boot

Output: Headless manager with persistence.

### Phase C — PlayerProgression Binding
- [ ] On selection: PlayerProgression.load_from_profile(profile.progression)
- [ ] Subscribe to EventBus.progression_changed → update profile state
- [ ] Debounced saves on progression changes to avoid IO spam

Output: Per-character progression owned by profile.

### Phase D — UI Screens
- [ ] scenes/ui/screens/CharacterSelect.tscn/.gd
- [ ] scenes/ui/screens/CharacterCreate.tscn/.gd
- [ ] Hook buttons to CharacterManager API via EventBus or direct calls

Output: Full flow to create/select/delete.

### Phase E — Boot Flow Integration
- [ ] GameOrchestrator.gd: if no current_profile → show CharacterSelect
- [ ] After select, proceed to normal game boot pipeline
- [ ] Update last_played on successful enter

Output: UX starts with character selection if needed.

### Phase F — Migration (Optional)
- [ ] If legacy single-progress exists, offer “Migrate to Default Character” one-time
- [ ] Create default character from existing PlayerProgression state

Output: Smooth upgrade path, no data loss.

### Phase G — Tests & Docs
- [ ] testsCharacterManager_Isolated.tscn/gd: CRUD + save/load
- [ ] tests/CharacterSelection_Flow.tscn/gd: create → select → progress → save
- [ ] docs/ARCHITECTURE_QUICK_REFERENCE.md: add CharacterManager section
- [ ] changelogs/features/YYYY_MM_DD-character_system_poe_style.md

Output: Verified behavior + documented.

---

## Concrete Integration Details (MVP Seams)

- scenes/ui/MainMenu.gd
  - Keep _on_start_game_pressed as-is (navigates to CharacterSelect via EventBus.request_enter_map)
- scenes/ui/CharacterSelect.gd
  - Add Name LineEdit node (e.g., %NameInput) and wire to selection flow
  - Replace current immediate transition with profile create + progression load:
    ```
    func _on_character_selected(character_id: String) -> void:
        var name := %NameInput.text.strip_edges()
        if name == "": name = "Hero"
        var clazz := StringName(character_id.capitalize())  # "Knight"/"Ranger"/"Mage"
        var profile := CharacterManager.create_character(name, clazz)
        PlayerProgression.load_from_profile(profile.progression)
        GameOrchestrator.go_to_hideout()
    ```
- autoload/CharacterManager.gd (NEW)
  - API:
    ```
    class_name CharacterManager
    var current_profile: CharacterProfile
    func create_character(name: String, clazz: StringName) -> CharacterProfile
    func load_character(id: StringName) -> void
    func save_current() -> void
    func list_characters() -> Array[CharacterProfile]  # optional for later
    ```
  - On ready: ensure user://profiles dir exists; scan files if needed
  - Subscribe to EventBus.progression_changed(state): update current_profile.level/exp/progression and save
  - Debounce saves optional (Timer or timestamp check)
- autoload/PlayerProgression.gd (existing)
  - Use load_from_profile(profile.progression) and export_state() as the single source of truth for leveling
  - Optional later: replace print() calls with Logger for consistency
- autoload/GameOrchestrator.gd
  - No changes required for MVP; go_to_hideout() already emits mode change and transition
- autoload/EventBus.gd
  - Optional: add character_selected(profile: Dictionary) if UI needs decoupled selection notification later

## File Touch List

Code:
- scripts/resources/CharacterProfile.gd (NEW)
- autoload/CharacterManager.gd (NEW)
- autoload/GameOrchestrator.gd (EDIT) — boot flow integration
- autoload/PlayerProgression.gd (EDIT) — ensure load/export API alignment
- autoload/EventBus.gd (EDIT) — new typed signals (see above)

UI:
- scenes/ui/screens/CharacterSelect.tscn/.gd (NEW)
- scenes/ui/screens/CharacterCreate.tscn/.gd (NEW)

Data:
- user://profiles/ (runtime save location; no repo files)

Tests:
- tests/CharacterManager_Isolated.tscn/gd (NEW)
- tests/CharacterSelection_Flow.tscn/gd (NEW)

Docs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- changelogs/features/YYYY_MM_DD-character_system_poe_style.md (NEW)

---

## Minimal Milestone (Ship Fast)

- [ ] A1: CharacterProfile.gd + user://profiles/ path helpers
- [ ] B1: CharacterManager.gd (list/create/load/save) + signals
- [ ] C1: Bind PlayerProgression load/export to selected profile
- [ ] D1: Simple CharacterSelect (list + Create + Select)
- [ ] Sanity test: Create Knight “MyKnight”, play, gain XP, save, re-open and verify state

---

## Notes & Guards

- Determinism unaffected; only changes boot flow and persistence
- Typed signals and arrays; no per-frame allocations in CharacterManager
- Use Logger for info/warn/error; no print()
- Debounce disk writes (e.g., timer-based flush or “on scene exit” save)
- Error cases: invalid save files → log warn, skip; never crash
- Avoid tight coupling; UI talks via EventBus or shallow API seams

---

## Open Questions (defer until needed)

- Portraits/cosmetics per class? (future)
- Cross-slot shared unlocks? (keep per-character for now)
- Cloud sync? (out of scope)
