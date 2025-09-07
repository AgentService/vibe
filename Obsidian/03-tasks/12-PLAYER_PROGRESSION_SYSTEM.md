# Player Progression System — Vibe-Coding Plan (modular, .tres-driven)

Status: In Progress
Owner: Solo (Indie)
Priority: High
Dependencies: EventBus, Logger, GameOrchestrator, DebugManager, (optional) SaveManager, UI base
Risk: Low (additive)
Complexity: 3/10 (small, self-contained)

---

## Goals & Acceptance Criteria

- [x] Data-driven progression:
  - Levels, thresholds, and unlock hooks live in .tres Resources (no hardcoded numbers)
  - Single XP curve resource drives level ups (10+ levels)
- [x] Autoload brain:
  - PlayerProgression.gd (autoload) tracks: level: int, exp: float, xp_to_next: float
  - API: gain_exp(amount: float), load_from_profile(profile: Dictionary), export_state() -> Dictionary
- [x] Signals (via EventBus):
  - xp_gained(amount: float, new_total: float)
  - leveled_up(new_level: int, prev_level: int)
  - progression_changed(state: Dictionary)  # {level, exp, xp_to_next, total_for_level}
- [x] Debug hooks:
  - F12 → Progression Tools: Add XP (+100), Force Level Up (only through PlayerProgression API)
- [ ] Save/Load seams:
  - On profile load, call PlayerProgression.load_from_profile(profile)
  - On save, PlayerProgression.export_state() merged into profile by SaveManager/GameOrchestrator
- [x] UI stubs only (no visuals yet):
  - CharacterScreen.gd subscribes to progression_changed (no-op handler)
  - XPBarUI.gd subscribes to progression_changed (no-op handler)
- [x] Edge cases:
  - Multiple level-ups on a single large XP gain
  - Respect max level (carry-over XP ignored/held at cap)
  - Deterministic, no per-frame allocations, typed signals and functions

---

## Architecture Notes (align with .clinerules)

- Use static typing everywhere; signals past-tense snake_case
- Cross-system communication via EventBus; do not poke PlayerProgression internals from UI/Debug
- All tunables in .tres under data/*; editor-friendly, hot-reloadable
- Logger for info/warn; no print()
- Keep autoload small; no global mutable state beyond owned progression fields

---

## Data Resources (all .tres)

Preferred: typed Resource scripts to enforce structure.

1) PlayerXPCurve.gd (Resource)
```gdscript
extends Resource
class_name PlayerXPCurve
@export var thresholds: Array[int] = []  # total XP required to reach each level (index 0 → level 1 cap)
```

2) PlayerUnlocks.gd (Resource) — placeholder for future gating
```gdscript
extends Resource
class_name PlayerUnlocks
@export var ability_unlocks: Dictionary = {}  # {"fireball": 3, "dash": 2}
@export var map_unlocks: Dictionary = {}      # {"tier2": 5}
```

Initial data:
- data/progression/xp_curve.tres → 10 dummy levels (e.g., [0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500]) — thresholds are total XP to reach next level
- data/progression/unlocks.tres → empty/minimal (future docking)

Note: If `data/xp_curves.tres` already exists, either migrate it or create a dedicated `data/progression/xp_curve.tres` and mark TODO to merge later.

---

## Autoload: PlayerProgression.gd (brain)

Responsibilities:
- Owns current progression state
- Reads PlayerXPCurve on boot
- Provides gain_exp() and auto-level logic (handles multi-level-ups)
- Emits EventBus signals for UI/Systems

API (typed):
```gdscript
extends Node
class_name PlayerProgression

var level: int = 1
var exp: float = 0.0
var xp_to_next: float = 0.0

@export var xp_curve: PlayerXPCurve
@export var unlocks: PlayerUnlocks

func setup(curve: PlayerXPCurve, unlocks_res: PlayerUnlocks) -> void
func gain_exp(amount: float) -> void
func load_from_profile(profile: Dictionary) -> void
func export_state() -> Dictionary
```

Behavior:
- xp_to_next computed from thresholds[level] - current_total_for_level
- If at max level: no further level-up, ignore surplus XP gracefully
- On changes: EventBus.progression_changed.emit(state_dict)
- On exp gain: EventBus.xp_gained.emit(amount, exp)
- On level up: EventBus.leveled_up.emit(new_level, prev_level)

---

## Debug Manager Hook (F12)

- New section: Progression Tools
  - Button: Add XP (+100) → PlayerProgression.gain_exp(100.0)
  - Button: Force Level Up → PlayerProgression.gain_exp(xp_to_next + epsilon)
- No direct state mutation from DebugManager; route via API only
- Log actions via Logger with category "progression_debug"

---

## Save/Load Integration

- On profile load: GameOrchestrator (or SaveManager if present):
  - PlayerProgression.load_from_profile(profile)
- On save:
  - profile.merge(PlayerProgression.export_state())  # or assign fields
- Keep persistence minimal: {level, exp, version}; curve-driven values computed on load

---

## UI Hooks (base stubs)

- scenes/ui/CharacterScreen.gd
  - Connect to EventBus.progression_changed
  - Store last_state for future rendering; no UI yet
- scenes/ui/XPBarUI.gd
  - Connect to EventBus.progression_changed
  - Keep fields: current_xp, needed_xp; no drawing yet
- Zero coupling back to systems; passive subscribers only

---

## Implementation Plan — Small Commit Loops

Phase A — Resources
- [x] Create PlayerXPCurve.gd and PlayerUnlocks.gd (typed Resource scripts)
- [x] data/progression/xp_curve.tres with 10 dummy thresholds
- [x] data/progression/unlocks.tres placeholder
Output: Editor-inspectable data; no game code change risk

Phase B — Autoload Skeleton
- [ ] autoload/PlayerProgression.gd with typed fields, setup() and export/load stubs
- [x] Wire EventBus signals (see below)
- [x] Load curve in _ready() or via GameOrchestrator injection
Output: Autoload exists; no gameplay effect yet

Phase C — Gain EXP + Level Logic
- [x] Implement gain_exp(amount) with multi-level-up loop
- [x] Handle max-level cap; compute xp_to_next
- [x] Emit xp_gained, leveled_up, progression_changed via EventBus
- [x] Logger calls for state transitions
Output: Functional progression core

Phase D — Debug Tools
- [x] Add "Progression Tools" to DebugManager (F12)
- [ ] Buttons → PlayerProgression API (Add XP +100, Force Level Up)
- [x] Guard with dev-mode flag if necessary
Output: Manual test harness during gameplay

Phase E — Save/Load Seam
- [x] Implement load_from_profile(profile), export_state()
- [ ] Hook into existing save/load points in GameOrchestrator (or SaveManager if present)
Output: Persistence seam without overthinking storage

Phase F — UI Stubs
- [x] scenes/ui/CharacterScreen.gd — subscribe to progression_changed (no-op body)
- [x] scenes/ui/XPBarUI.gd — subscribe to progression_changed (no-op body)
Output: Safe docking points for later UI work

Phase G — Tests & Docs
- [x] tests/PlayerProgression_Isolated.tscn/gd (add exp → assert level-ups, caps, signals)
- [ ] docs/ARCHITECTURE_QUICK_REFERENCE.md update (new system + signals)
- [ ] changelogs/features/YYYY_MM_DD-player_progression.md
Output: Verified behavior and documented system

---

## Signals (EventBus
Add to autoload/EventBus.gd:
```gdscript
signal xp_gained(amount: float, new_total: float)
signal leveled_up(new_level: int, prev_level: int)
signal progression_changed(state: Dictionary)
```
Note: Past tense naming retained where applicable; xp_gained is event-style but acceptable as established convention.

---

## Edge Cases & Rules

- Multi-level-up bursts handled in one gain_exp() call (loop until next threshold not reached or cap)
- Max level: set xp_to_next = 0; ignore further XP silently; still emit progression_changed when first reaching cap
- Invalid curve (empty or level index out of range): log error once; freeze leveling; avoid crash
- No per-frame allocations; reuse dictionaries/arrays for emitted state if needed (copy shallow for safety if listeners mutate)

---

## File Touch List

Code:
- scripts/resources/PlayerXPCurve.gd (NEW)
- scripts/resources/PlayerUnlocks.gd (NEW)
- autoload/PlayerProgression.gd (NEW)
- autoload/EventBus.gd (EDIT) +3 signals
- autoload/DebugManager.gd (EDIT) add Progression Tools section
- autoload/GameOrchestrator.gd (EDIT) call load_from_profile/export_state at seam points

Data:
- data/progression/xp_curve.tres (NEW) — 10 dummy levels
- data/progression/unlocks.tres (NEW) — placeholder

UI:
- scenes/ui/CharacterScreen.gd (NEW) — stub
- scenes/ui/XPBarUI.gd (NEW) — stub

Tests:
- tests/PlayerProgression_Isolated.tscn (NEW)
- tests/PlayerProgression_Isolated.gd (NEW)

Docs:
- docs/ARCHITECTURE_QUICK_REFERENCE.md (update)
- changelogs/features/YYYY_MM_DD-player_progression.md (NEW)

---

## Minimal Milestone (ship fast)

- [x] A1: Resources + xp_curve.tres (10 levels)
- [x] B1: PlayerProgression autoload skeleton + EventBus signals
- [x] C1: gain_exp + level logic + Logger + signals
- [ ] D1: Debug F12 buttons for Add XP / Force Level Up
- [ ] Sanity test: gain 1000 XP and observe 2–3 level-ups with events

Then wire E/F/G incrementally.

---

## Test Plan (Isolated)

tests/PlayerProgression_Isolated.gd:
- Setup with dummy curve thresholds [0, 100, 300, 600, ...]
- Case 1: gain 50 → level unchanged, exp updated, xp_to_next correct
- Case 2: gain 500 from fresh → multiple level-ups; final level/exp/xp_to_next validated
- Case 3: max level reached → further XP ignored; signals not spammed beyond progression_changed at cap
- Assert EventBus signal sequence and payload shapes

---

## Future Docking Points (no refactors later)

- Abilities: check required level via PlayerUnlocks; API: has_unlock(id: StringName) → bool
- Maps/Events: has_unlock("tier2") gating; same API
- Talents: consume level from PlayerProgression; resource-driven talent trees
- Items: drop tables require player_level ≥ x (query PlayerProgression.level)
- Ascendancies/Specs: additional .tres layered in PlayerUnlocks
- Server sync: gain_exp, export_state shape matches; switch to remote store later without API change

---

## Timeline

- A–C (Core): ~2–3 hours
- D (Debug): ~30 minutes
- E (Save/Load seam): ~30–45 minutes
- F (UI stubs): ~20 minutes
- G (Tests/Docs): ~60 minutes

Total: ~5 hours incremental, safe to split into 6–8 small commits.

---

## Notes & Guards

- Follow .clinerules for typing, signals, autoload size, and logging
- Keep API minimal and stable; no direct NodePath coupling
- Favor injection of resources (setup(curve, unlocks)) for testability
- Document any EventBus additions in Quick Reference

---

## Known deviations/todos from current implementation

- PlayerProgression.gd lacks setup(curve, unlocks) injection method (plan recommends for testability).
- Replace print() calls in PlayerProgression.gd with Logger to comply with .clinerules.
- get_progression_state() sets "total_for_level" to xp_to_next; consider exposing actual total threshold for clarity.
- GameOrchestrator save/load wiring not yet verified; add calls to load_from_profile/export_state at seam points.
- Debug UI buttons for Add XP / Force Level Up not verified; DebugManager methods exist and F12 toggles debug mode.
- Docs update and feature changelog entry pending.
