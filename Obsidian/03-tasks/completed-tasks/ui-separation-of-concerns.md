# UI Separation of Concerns Enhancement

**Status:** Pending  
**Priority:** MEDIUM  
**Category:** Architecture Improvement  
**Created:** 2025-09-07  

## Task Linkage & Sequencing

- Sequencing: 12 → 14 → 15 (no code here; this documents scope and dependencies).
  - Task 12 — Game State Manager Core Loop: Introduce thin StateManager autoload (states, signals), add is_pause_allowed(), and have GameOrchestrator swap scenes on StateManager.state_changed. This unblocks 14 and 15. See ./12-GAME_STATE_MANAGER_CORE_LOOP.md.
  - Task 14 — Hideout Phase 1 Menu + Character Select Integration: Refactor MainMenu.gd and CharacterSelect.gd to call StateManager.go_to_* for navigation; keep EventBus for domain/domain updates only. Optionally include presenter extraction per this doc’s Phase 1 (see Acceptance Criteria Mapping). See ./14-HIDEOUT_PHASE_1_MAIN_MENU_AND_CHARACTER_SELECT_INTEGRATION.md.
  - Task 15 — Pause & Escape Menu: Add PauseUI autoload (global CanvasLayer overlay), centralize Escape handling (e.g., in GameOrchestrator), gate via StateManager.is_pause_allowed(), and route overlay buttons to StateManager.go_to_*. See ./15-PAUSE_AND_ESCAPE_MENU.md.

- Responsibilities:
  - EventBus remains the transport for domain events (damage, progression, etc.).
  - StateManager becomes the single navigation/orchestration façade for high-level flow and pause policy.

## Acceptance Criteria Mapping

- What Task 14 completes with “navigation-only” refactor:
  - UI navigation decoupled from EventBus (UI calls StateManager.go_to_*).
  - CharacterSelect/MainMenu no longer trigger flow via EventBus directly.
  - This partially satisfies this doc; Phase 1 remains incomplete until presenter extraction and data move are done.

- What is additionally required to mark this doc’s Phase 1 (Character System) “Complete” alongside Task 14:
  - Create presenter: scripts/presenters/CharacterSelectPresenter.gd (signals + logic interface as specified).
  - Move character data: data/content/player/character_types.tres (remove hardcoded character data from UI).
  - Refactor scenes/ui/CharacterSelect.gd to be a pure view (no business logic; subscribe to presenter signals).
  - Update creation/validation flow to live in presenter; UI emits intents only.
  - Add/adjust tests per the Testing Strategy in this doc (presenter unit tests; UI integration with signals).

- Out of scope for 12/14/15 (remains pending in this doc):
  - Phase 2 (Radar System decoupling), Phase 3 (DebugPanel cleanup), Phase 4 (InputManager + Keybindings).

- Dependencies/Policy:
  - Task 12 must precede acceptance for Task 14/15 that relies on StateManager API (states, is_pause_allowed()).
  - Task 15 aligns with “No direct scene tree navigation in UI” by routing Pause overlay actions through StateManager and centralizing Escape handling.

## Objective

Refactor UI components to achieve proper separation of concerns, moving business logic out of UI classes and implementing pure presenter patterns.

## Current Issues Found

### Critical Violations

#### CharacterSelect.gd - Mixed Responsibilities
**File:** `scenes/ui/CharacterSelect.gd`  
**Issues:**
- Character data hardcoded in UI (lines 23-34)
- Character creation logic embedded in UI component
- Direct CharacterManager API calls from UI
- Business validation mixed with UI state

**Current Architecture:**
```
CharacterSelect (UI) 
├── Character data definition
├── Character creation logic
├── Character validation
└── UI presentation
```

**Target Architecture:**
```
CharacterSelect (UI) ← CharacterSelectPresenter (Logic) ← CharacterManager (Data)
```

#### EnemyRadar.gd - Scene Tree Navigation
**File:** `scenes/ui/EnemyRadar.gd:107`  
**Issues:**
- Direct parent traversal: `current.get_parent()`
- Tight coupling to scene hierarchy
- Violates encapsulation principles

#### DebugPanel.gd - Direct Node Access
**File:** `scenes/debug/DebugPanel.gd:472,493,501`  
**Issues:**
- Hard-coded node paths: `get_node("PanelContainer")`
- UI structure knowledge embedded in logic
- Difficult to test and maintain

### Medium Priority Issues

#### KeybindingsDisplay.gd - Parent Dependency
**File:** `scenes/ui/KeybindingsDisplay.gd:162`  
**Issues:**
- Parent node manipulation for UI state
- Should use signals for parent communication

## Refactoring Plan

### Phase 1: Character Selection Separation

#### Create CharacterSelectPresenter
```gdscript
# scripts/presenters/CharacterSelectPresenter.gd
extends RefCounted
class_name CharacterSelectPresenter

signal character_data_loaded(characters: Array[CharacterProfile])
signal character_created(profile: CharacterProfile)
signal character_deleted(character_id: StringName)
signal error_occurred(message: String)

var character_manager: CharacterManager
var character_types: Array[CharacterType]

func load_character_list() -> void
func create_character(name: String, type: StringName) -> void
func delete_character(character_id: StringName) -> void
func validate_character_name(name: String) -> bool
```

#### Refactor CharacterSelect.gd
```gdscript
# Remove all business logic
# Keep only UI state management
# Connect to presenter signals
# Pure view layer implementation
```

### Phase 2: Radar System Decoupling

#### Create RadarSystem
```gdscript
# scripts/systems/RadarSystem.gd
extends Node
class_name RadarSystem

signal enemies_detected(enemy_data: Array[Dictionary])
signal radar_config_changed(config: RadarConfigResource)

func scan_for_enemies() -> void
func update_radar_range(range: float) -> void
func set_radar_enabled(enabled: bool) -> void
```

#### Refactor EnemyRadar.gd
```gdscript
# Remove scene tree navigation
# Connect to RadarSystem signals
# Pure UI visualization of radar data
# No business logic or data gathering
```

### Phase 3: Debug Panel Architecture

#### Create DebugController
```gdscript
# scripts/systems/debug/DebugController.gd (already exists, enhance)
extends Node
class_name DebugController

signal debug_state_changed(state: Dictionary)
signal command_executed(command: String, result: Variant)

func execute_debug_command(command: String) -> void
func get_debug_state() -> Dictionary
func toggle_debug_feature(feature: String) -> void
```

#### Refactor DebugPanel.gd
```gdscript
# Remove direct node access patterns
# Use @onready var references for UI elements
# Connect to DebugController for all logic
# Implement proper signal-based communication
```

### Phase 4: Keybindings Separation

#### Create InputManager
```gdscript
# scripts/systems/InputManager.gd
extends Node
class_name InputManager

signal keybindings_changed(bindings: Dictionary)
signal input_context_changed(context: StringName)

func get_current_keybindings() -> Dictionary
func set_keybinding(action: StringName, event: InputEvent) -> void
func reset_to_defaults() -> void
```

## Implementation Steps

### Step 1: Character System
1. Create `CharacterSelectPresenter.gd`
2. Move character data to `data/content/player/character_types.tres`
3. Refactor `CharacterSelect.gd` to use presenter
4. Update character creation flow
5. Test character selection functionality

### Step 2: Radar System
1. Enhance existing `RadarSystem` or create new one
2. Move radar logic out of UI component
3. Implement signal-based communication
4. Test radar functionality preservation

### Step 3: Debug Interface
1. Enhance existing `DebugController.gd`
2. Remove hard-coded node paths from `DebugPanel.gd`
3. Implement proper UI element references
4. Test debug functionality

### Step 4: Input System
1. Create `InputManager` system
2. Move keybinding logic out of UI
3. Implement signal-based input updates
4. Test input configuration

## Architecture Benefits

### Before (Current Issues)
```
UI Component
├── Business Logic      ❌ Mixed concerns
├── Data Access        ❌ Tight coupling
├── Validation         ❌ Hard to test
└── Presentation       ✅ Appropriate
```

### After (Target Architecture)
```
UI Component (Pure View)
├── Presentation Only   ✅ Single responsibility
├── Signal Handling     ✅ Loose coupling
└── State Display       ✅ Easy to test

Presenter/System (Logic)
├── Business Rules      ✅ Testable
├── Data Coordination   ✅ Centralized
└── Validation         ✅ Reusable
```

## Success Criteria

- ✅ No business logic in UI components
- ✅ No direct scene tree navigation in UI
- ✅ All data access through systems/presenters
- ✅ Signals used for all cross-component communication
- ✅ UI components are pure presentation layer
- ✅ Business logic is unit testable
- ✅ Existing functionality fully preserved

## Files to Create/Modify

### New Files
- `scripts/presenters/CharacterSelectPresenter.gd`
- `scripts/systems/RadarSystem.gd` (if not exists)
- `scripts/systems/InputManager.gd`
- `data/content/player/character_types.tres`

### Modified Files
- `scenes/ui/CharacterSelect.gd` (major refactor)
- `scenes/ui/EnemyRadar.gd` (remove scene navigation)
- `scenes/debug/DebugPanel.gd` (remove hard-coded paths)
- `scenes/ui/KeybindingsDisplay.gd` (use InputManager)

## Testing Strategy

### Unit Tests
- Test presenters independently
- Mock data layer for UI tests
- Validate business logic separation

### Integration Tests
- Test UI → Presenter → Data flow
- Validate signal communication
- Ensure no direct coupling remains

### Functional Tests
- Character creation/selection works
- Radar display functions correctly
- Debug panel operates normally
- Keybinding configuration preserved

## Documentation Updates

- Update ARCHITECTURE.md with presenter pattern
- Document signal contracts for new components
- Update CHANGELOG.md with separation improvements
