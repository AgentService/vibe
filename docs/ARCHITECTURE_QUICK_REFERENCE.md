# Architecture Quick Reference

> Fast reference for architecture boundary enforcement tools and common patterns.

## 🚀 Quick Commands

### Run Architecture Check
```bash
# Easiest method
double-click tests/tools/check_architecture.bat

# Command line
"./Godot_v4.4.1-stable_win64_console.exe" --headless --script tools/check_boundaries_standalone.gd --quit-after 10

# Pre-commit (automatic)
git commit -m "changes"  # Runs check automatically
```

## 📊 Reading the Matrix

### Good Matrix (No Violations)
```
From\To	autolo	system	scenes	domain	
autolo	0	0	0	X	← Only imports domain
system	X	X	0	X	← Zero in scenes column ✅
scenes	X	X	X	0	← Zero in domain column ✅  
domain	0	0	0	X	← Only internal references
```

### Problem Indicators
- **Non-zero in forbidden cells** = violations
- **System → Scenes** = ❌ Systems accessing UI
- **Scenes → Domain** = ❌ UI bypassing systems
- **Domain → Anything** = ❌ Domain not pure

## 🔧 Common Fixes

### ❌ System Accessing Scene
```gdscript
# BAD
get_node("../../UI/HUD").update_health(hp)

# GOOD  
EventBus.health_changed.emit(hp)
```

### ❌ Domain Using EventBus
```gdscript
# BAD
class_name PlayerStats
func level_up():
    EventBus.level_up.emit(level)

# GOOD
class_name PlayerStats  
func get_level() -> int:
    return level
# (Let systems emit events)
```

### ❌ Scene Importing Domain
```gdscript
# BAD
const PlayerStats = preload("res://scripts/domain/PlayerStats.gd")

# GOOD
@onready var player_system = PlayerSystem.new()
func get_stats(): return player_system.get_player_stats()
```

## 🏗️ Layer Rules

| Layer | Path | Can Import | Purpose |
|-------|------|------------|---------|
| **Domain** | `scripts/domain/` | Domain only | Pure data/helpers |
| **Autoload** | `autoload/` | Domain | Global coordination |
| **Systems** | `scripts/systems/` | Domain, Autoload | Game logic |
| **Scenes** | `scenes/` | Systems, Autoload | UI/Visual |

## 🚨 Violation Types

| Code | Meaning | Fix |
|------|---------|-----|
| `FORBIDDEN_LAYER_IMPORT` | Wrong layer dependency | Restructure imports |
| `SYSTEMS_SCENE_COUPLING` | System using get_node() | Use signals instead |
| `DOMAIN_SIGNAL_COUPLING` | Domain using EventBus | Move to systems |
| `SCENES_DOMAIN_BYPASS` | Scene importing domain | Use systems layer |

## 📋 Workflow Checklist

### Before Coding
- [ ] Run architecture check to see current state
- [ ] Understand which layer you're working in
- [ ] Know what that layer can/cannot import

### While Coding  
- [ ] Follow import rules for your layer
- [ ] Use EventBus for cross-system communication
- [ ] Keep domain models pure (no signals/events)

### Before Committing
- [ ] Run architecture check
- [ ] Fix any violations found
- [ ] Verify matrix looks healthy
- [ ] Commit (pre-commit hook will double-check)

## 🔍 Troubleshooting

### Tool Won't Run
```bash
# Check location
pwd  # Should be in project root directory

# Check Godot exists
ls ./Godot_v4.4.1-stable_win64_console.exe

# Try longer timeout
--quit-after 30
```

### Unexpected Violations
1. Check file is in correct directory for its layer
2. Look for commented code that might be detected
3. Verify import statements match expected patterns

### False Clean (Should Have Violations)
1. Check tool is scanning all directories
2. Verify violation patterns are being detected
3. Test with known bad pattern to confirm tool works

## 🔄 Hideout Phase 0 Signals

### New Typed Signals (Past-tense)
```gdscript
# EventBus.gd - Phase 0 additions
signal enter_map_requested(map_id: StringName)
signal character_selected(character_id: StringName)
```

### Usage Patterns
```gdscript
# MapDevice emitting typed signal
EventBus.enter_map_requested.emit(StringName("forest_01"))

# Character selection system
EventBus.character_selected.emit(StringName("knight_default"))
```

### Boot Configuration
- Config: `config/debug.tres` (DebugConfig Resource)
- Boot modes: `"menu"`, `"hideout"`, `"arena"`, `"map"`
- Scene selection via Main.gd dynamic loading

## ⚖️ EventBus vs StateManager (Quick)

- EventBus (transport of domain events)
  - Use for: damage_requested/applied/taken, xp_gained/leveled_up, ability_* signals, enemy_spawned, debug toggles, pause state changed.
  - Nature: broadcast, decoupled, no navigation logic or global state.

- StateManager (orchestration facade)
  - Use for: high-level navigation and flow: go_to_menu(), go_to_character_select(), go_to_hideout(), start_run(), end_run(), return_to_menu().
  - Holds: current_state (BOOT, MENU, CHARACTER_SELECT, HIDEOUT, ARENA, RESULTS, EXIT).
  - Gates: is_pause_allowed() → true only in HIDEOUT/ARENA/RESULTS.

- Who calls what
  - UI/Scenes (MainMenu, CharacterSelect, PauseOverlay, Results): call StateManager.go_to_*; listen to EventBus for domain updates (e.g., progression_changed).
  - GameOrchestrator: subscribes to StateManager.state_changed; performs scene load/unload.
  - Systems (Damage, WaveDirector, Ability, Melee): emit domain events via EventBus; never navigate directly. To end a run, emit a domain event StateManager subscribes to.
  - Autoloads (RunManager, PlayerProgression, CharacterManager): use StateManager only to initiate/terminate flows; keep domain logic in their layer.

## 🔁 Migration Checklist (facade-first, low-risk)
- [ ] Create thin StateManager autoload (states, signals, API, is_pause_allowed()).
- [ ] Centralize Escape: if StateManager.is_pause_allowed() then PauseUI.toggle_pause().
- [ ] Refactor MainMenu/CharacterSelect/PauseOverlay to call StateManager.go_to_* (remove direct EventBus emits for navigation).
- [ ] Keep EventBus as backbone for domain events; subscribe StateManager to key events (death/victory) to call end_run().
- [ ] Add PauseUI autoload owning PauseOverlay (CanvasLayer WHEN_PAUSED) and subscribing to PauseManager/EventBus.
- [ ] Extend tests: CoreLoop_Isolated (flow), test_pause_resume_lag (global), test_scene_swap_teardown (persistence).

## 📚 Documentation Links

- **Detailed Guide**: [ARCHITECTURE_ENFORCEMENT_GUIDE.md](ARCHITECTURE_ENFORCEMENT_GUIDE.md)
- **Enforcement Rules**: [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md)
- **Overall Architecture**: [../ARCHITECTURE.md](../ARCHITECTURE.md)
- **Development Guidelines**: [../CLAUDE.md](../CLAUDE.md)
