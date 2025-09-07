# Hideout Phase 1 — Main Menu + Character Select Integration

Status: Updated — Use StateManager facade; refactor UI to route via StateManager
Owner: Solo (Indie)
Priority: High
Type: System Integration
Dependencies 12-GAME_STATE_MANAGER_CORE_LOOP, 13-RUN_RESULTS_AND_RESTART_FLOW, CharacterManager (Complete), PlayerProgression, GameOrchestrator, StateManager (NEW), EventBus
Risk: Low–Medium (UI wiring + flow integration)
Complexity: 3/10

---

## Purpose

Introduce a minimal, modular Main Menu and Character Select flow that plugs into the StateManager-driven core loop. Use CharacterManager for per-character profiles and route all transitions via StateManager to enter the Hideout cleanly. No tight coupling; event-driven.

---

## Goals & Acceptance Criteria

- [ ] Minimal Main Menu (scenes/ui/screens/MainMenu.tscn/gd)
  - Buttons: Continue (if profile exists), New Character, Quit (optional)
  - Start → `StateManager.go_to_character_select()` (or Continue → `StateManager.go_to_hideout()` with last_profile)
- [ ] Character Select (scenes/ui/screens/CharacterSelect.tscn/gd)
  - List existing profiles (name, class, level, last_played)
  - Create new profile (Name input + class toggle; uses CharacterManager.create_character)
  - On select: `PlayerProgression.load_from_profile(profile.progression)` then `StateManager.go_to_hideout({character_id})`
- [ ] GameOrchestrator integration
  - On StateManager state_changed → instantiate/destroy MainMenu or CharacterSelect scenes appropriately
  - No direct scene cross-calls; all via StateManager public API and EventBus
- [ ] Hideout entry
  - Enterout from CharacterSelect or Continue with selected/current profile
- [ ] Debug boot compatibility via config/debug.tres (menu | hideout)
- [ ] Tests validate flow + teardown (no leaks)

---

## Implementation Plan (Small Phases)

### Phase A — Main Menu (Minimal)
- [ ] Create `scenes/ui/screens/MainMenu.tscn` with a VBox of buttons
- [ ] `MainMenu.gd`:
  - If CharacterManager has profiles → enable Continue (loads most recent by last_played, or current set)
  - Continue → `StateManager.go_to_hideout({reason: "continue"})`
  - New Character → `StateManager.go_to_character_select()`
  - Quit () → `StateManager.return_to_menu("quit")` or OS.exit() for debug

### Phase B — Character Select (MVP)
- [ ] Create `scenes/ui/screens/CharacterSelect.tscn` with:
  - Scroll list of profiles (Name/Class/Level/Last Played)
  - Create panel: LineEdit Name + Class buttons (Knight/Ranger/Mage)
  - Buttons: Create, Select, Delete (Delete optional for later)
- [ ] `CharacterSelect.gd`:
  - On Create: `CharacterManager.create_character(name, clazz)` → refresh list
  - On Select:
    - `var p := CharacterManager.get_selected()`
    - `PlayerProgression.load_from_profile(p.progression)`
    - `StateManager.go_to_hideoutcharacter_id: p.id})`

### Phase C — UI Refactor to StateManager
- [ ] Update `scenes/ui/MainMenu.gd`: replace `EventBus.request_enter_map` emits with `StateManager.go_to_character_select()` / `StateManager.go_to_menu()`
- [ ] Update `scenes/ui/CharacterSelect.gd`: replace `EventBus.request_enter_map` emits with `StateManager.go_to_hideout(ctx)` after loading progression
- [ ] Keep EventBus-based transitions as a fallback only during migration; remove after tests pass

### Phase C — GameOrchestrator Wiring
- [ ] Subscribe to StateManager.state_changed
- [ ] When entering MENU → add_child(MainMenu); CHARACTER_SELECT → add_child(CharacterSelect)
- [ ] Ensure previous scene is freed and signals disconnected before switching
- [ ] When entering HIDEOUT → load Hideout scene as currently implemented (Phase 0 complete)

### Phase D — Debug Boot Modes
- [ ] config/debug.tres: boot_mode "menu" or "hideout" remains supported
- [ ] If boot_mode == "menu" → `StateManager.go_to_menu()`
- [ ] If boot_mode == "hideout" and CharacterManager has no profile → optionally `go_to_character_select()` first

### Phase E — Tests & Docs
- [ ] tests/CharacterSelection_Flow.tscn/gd:
  - MENU → CHARACTER_SELECT → create/select → HIDEOUT sequence assertions
- [ ] tests/test_scene_swap_teardown.gd: verify no dangling signals on transitions
- [ ] tests/test_debug_boot_modes.gd: boot to menu/hideout works through StateManager
- [ ] Update docs:
  - docs/ARCHITECTURE_QUICK_REFERENCE.md (flow diagram)
  - docs/ARCHITECTURE_RULES.md (UI flows must route via StateManager)

---

## File Touch List

Code:
- autoload/GameOrchestrator.gd (EDIT: route state → screen instantiation)
- autoload/StateManager.gd (No change unless additional UI state data needed)
- autoload/EventBus.gd (optional UI action signals)

UI:
- scenes/ui/screens/MainMenu.tscn (NEW)
- scenes/ui/screens/MainMenu.gd (NEW)
- scenes/ui/screens/CharacterSelect.tscn (NEW or EDIT existing)
- scenes/ui/screens/CharacterSelect.gd (NEW or EDIT existing)

Tests:
- tests/CharacterSelection_Flow.tscn/gd (NEW)
- tests/test_scene_swap_teardown.gd (verify)
- tests/test_debug_boot_modes.gd (verify)

Docs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- docs/ARCHITECTURE_RULES.md (update)

---

## Notes & Guards

- Keep UI scenes dumb; all navigation via StateManager public API.
- Use CharacterManager APIs only; no direct file IO from UI.
- On selection, immediately update `last_played` and persist via CharacterManager.
- No per-frame allocations in menus; lightweight scenes.

---

## Minimal Milestone

- [ ] A1: MainMenu → CharacterSelect → Create/Select → Hideout Via StateManager
- [ ] B1: Continue button uses last/current profile to Hideout
- [ ] Sanity test: Manual flow + CharacterSelection_Flow passes
