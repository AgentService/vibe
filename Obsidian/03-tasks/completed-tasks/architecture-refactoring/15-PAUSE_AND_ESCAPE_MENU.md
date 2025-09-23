# Pause & Escape Menu (Global Overlay, State-Gated)

Status: Updated — Implement via global autoload + StateManager  
Owner: Solo (Indie)  
Priority: High  
Type: System Integration  
Dependencies: 12-GAME_STATE_MANAGER_CORE_LOOP, EventBus, PauseManager (existing), GameOrchestrator, UI/HUD  
Risk: Low  
Complexity: 3/10

---

## Purpose
Provide a single, global pause overlay that works in all gameplay states after the player has started a run (or entered the hideout), not just in Arena. Use a persistent CanvasLayer managed by an autoload to ensure availability across scene swaps. Route navigation via StateManager; PauseManager remains the single source of truth for pausing.

---

## Design Decision
- Use a thin `StateManager` autoload facade for navigation APIs (go_to_menu, go_to_character_select, go_to_hideout, go_to_arena, go_to_results) to centralize flow and keep UI scenes dumb. Internally, StateManager delegates to `GameOrchestrator` and/or emits the appropriate EventBus requests.  
- Keep EventBus for signals; expose typed methods from StateManager for consumers. This aligns with .clinerules: autoloads small/focused, event-driven, no cross-module reach-ins.

---

## Goals & Acceptance Criteria
- [ ] Escape toggles a global Pause overlay in allowed states:
  - Allowed: HIDEOUT, ARENA, RESULTS (or RUN_SUMMARY), any “in-session” state after first character selection
  - Disallowed: MENU, CHARACTER_SELECT, BOOT
- [ ] Pause overlay (UI) contains:
  - Resume (unpause)
  - Return to Hideout (only shown in Arena)
  - Return to Menu
  - Settings (stub)
- [ ] Navigation routes via StateManager:
  - Resume → PauseManager.unpause()
  - Return to Hideout → StateManager.go_to_hideout({reason: "pause_menu"})
  - Return to Menu → StateManager.go_to_menu({reason: "pause_menu"})
- [ ] Deterministic: gameplay loops only pause input/time; no logic mutation outside PauseManager
- [ ] No leaks: overlay is persistent, signals connected once; freed only on shutdown; state transitions clean
- [ ] Tests validate global toggle and teardown across scenes

---

## Implementation Plan (Small Phases)

### Phase A — Global Pause UI Autoload
- [ ] Create `autoload/PauseUI.gd` (NEW) — persistent manager for the overlay
  - On _ready(): instantiate `res://scenes/ui/overlays/PauseOverlay.tscn` once and add as child
  - Set overlay CanvasLayer `process_mode = WHEN_PAUSED`
  - Subscribe to `EventBus.game_paused_changed` to show/hide UI based on PauseManager state
  - Provide API:
    - `func toggle_pause() -> void` (calls PauseManager.toggle_pause(); shows/hides overlay)
    - `func show_overlay()`, `func hide_overlay()`
    - `func is_allowed_state() -> bool` (delegates to StateManager)
- [ ] Add PauseUI.gd to Project Settings → Autoload (doc-only step)

### Phase B — Global Escape Handling
- [ ] Centralize Escape handling in `autoload/GameOrchestrator.gd` (or a tiny InputRouter if preferred)
  - In `_unhandled_input(event)`: if Escape pressed and `StateManager.is_pause_allowed()` then `PauseUI.toggle_pause()`
  - Ensure this does not steal input from critical UI (e.g., Card Picker) by checking a UI-blocking flag if present
- [ ] Remove/avoid per-scene Escape handling (e.g., Arena-only), to prevent duplication

### Phase C — Overlay Buttons → StateManager
- [ ] Keep UI logic in `scenes/ui/overlays/PauseOverlay.tscn/.gd` (existing PauseMenu)
  - Replace calls that emit EventBus directly for menu navigation with:
    - `StateManager.go_to_menu({source: "pause_menu_quit"})`
    - For arena-only button “Return to Hideout”: `StateManager.go_to_hideout({source: "pause_menu"})`
  - Always call `PauseManager.pause_game(false)` before navigation
  - Gate visibility of “Return to Hideout” by `StateManager.current_state == &"ARENA"`

### Phase D — StateManager Gates
- [ ] Implement/confirm `autoload/StateManager.gd` (thin, typed) with:
  - `var current_state: StringName` and `func is_pause_allowed() -> bool`
  - Public methods: `go_to_menu()`, `go_to_character_select()`, `go_to_hideout(ctx := {})`, `go_to_arena(ctx := {})`, `go_to_results(ctx := {})`
  - Internally call `GameOrchestrator.go_*` or emit EventBus request signals (keeps current system)
  - Update state in response to flow and transition confirmations; emit `state_changed` typed signal
- [ ] Update MainMenu, CharacterSelect, PauseOverlay to use StateManager methods instead of raw EventBus where possible (keep EventBus fallback temporarily)

### Phase E — Tests
- [ ] Update `tests/CoreLoop_Isolated.gd`: simulate Escape in ARENA and HIDEOUT; assert Pause overlay shows/hides and PauseManager flips
- [ Update `tests/test_pause_resume_lag.gd`: ensure no regressions under the new global overlay
- [ ] Update `tests/test_scene_swap_teardown.gd`: verify overlay persists (as autoload), no extra lingering instances, and signals remain single-connected
- [ ] Add small test for disallowed states (MENU/CHARACTER_SELECT) — Escape should do nothing

### Phase F — Docs
- [ ] docs/ARCHITECTURE_QUICK_REFERENCE.md: add PauseUI autoload + state gates; central Escape handling
- [ ] docs/ARCHITECTURE_RULES.md: UI flows via StateManager; no per-scene pause UI duplication

---

## File Touch List

Code:
- autoload/PauseUI.gd (NEW)
- autoload/StateManager.gd (NEW or confirm existing; add public API and is_pause_allowed)
- autoload/GameOrchestrator.gd (EDIT: central Escape handling, or delegate to InputRouter)
- scenes/ui/overlays/PauseOverlay.tscn (EXISTING)
- scenes/ui/overlays/PauseOverlay.gd (EDIT: route via StateManager, hide “Return to Hideout” if not in ARENA)
- scenes/ui/MainMenu.gd (EDIT later: use StateManager)
- scenes/ui/CharacterSelect.gd (EDIT later: use StateManager)

Tests:
- tests/CoreLoop_Isolated.gd (EDIT)
- tests/test_pause_resume_lag.gd (verify)
- tests/test_scene_swap_teardown.gd (verify)
- tests/test_debug_boot_modes.gd (verify MENU/Hideout behavior remains)

Docs:
- docs/ARCHITECTURE_RULES.md (update)
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)

---

## Notes & Guards
- Keep PauseUI and StateManager autoloads small and focused; they orchestrate, not own gameplay logic.
- PauseManager remains the only owner of `get_tree().paused`; PauseUI/UI only requests changes via PauseManager.
- Ensure CanvasLayer Z-order and focus allow UI operation when paused; grab_focus on opening.
- Avoid per-frame allocations; connect signals once; reuse references.
- Keep EventBus as the backbone; StateManager is a thin facade for clarity and tests.

---

## Minimal Milestone
- [ ] Global Escape toggles Pause overlay in ARENA and HIDEOUT via PauseUI (autoload)
- [ ] Buttons function (Resume/Hideout/Menu) via StateManager
- [ ] Disallowed in MENU/CHARACTER_SELECT
- [ ] Sanity test: Manual + CoreLoop_Isolated passes without leaks
