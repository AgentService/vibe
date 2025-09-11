# Scene Transition System

## Overview

The scene transition system is built around two core components:
- **`StateManager`** (autoload): Centralized state orchestration with typed state enum
- **`SessionManager`** (autoload): Session resets and entity cleanup management

This system provides a robust, typed approach to managing game states and transitions while ensuring proper cleanup between scenes.

## Core Architecture

### StateManager - Scene State Control

```gdscript
enum State {
    BOOT,
    MENU,
    CHARACTER_SELECT,
    HIDEOUT,
    ARENA,
    RESULTS,
    EXIT
}
```

**Key Features:**
- **Typed state transitions** with validation rules
- **Context-aware transitions** with optional data passing
- **Signal-based communication** for decoupled scene updates
- **Emergency exit handling** from any state

### SessionManager - Entity & Resource Cleanup

```gdscript
enum ResetReason {
    DEBUG_RESET,      # Manual debug reset
    PLAYER_DEATH,     # Player died (preserve enemies for results)
    MAP_TRANSITION,   # Moving between arenas/maps
    HIDEOUT_RETURN,   # Returning to hideout
    RUN_END,          # Run completed/ended
    LEVEL_RESTART     # Restart same level
}
```

**Key Features:**
- **Context-aware cleanup** - different reset types preserve different data
- **Multi-phase reset sequence** - entities → systems → player → UI
- **Player registration validation** - ensures player remains tracked after reset
- **Production entity clearing** via `EntityClearingService`

## Scene Transition API

### Basic Transitions

```gdscript
# Simple state changes
StateManager.go_to_menu()
StateManager.go_to_hideout()
StateManager.go_to_character_select()

# Start a run with context
StateManager.start_run("arena_forest_1", {
    "difficulty": "normal",
    "source": "hideout_portal"
})

# End run with results
StateManager.end_run({
    "success": true,
    "wave_count": 15,
    "xp_gained": 1250
})

# Emergency return to menu
StateManager.return_to_menu("user_quit", {"preserve_character": false})
```

### Context-Passing Examples

```gdscript
# Transition with preserved data
StateManager.go_to_hideout({
    "returning_from": "arena",
    "xp_gained": 500,
    "items_found": ["rare_sword", "health_potion"]
})

# Restart with source tracking
StateManager.start_run("arena_desert_2", {
    "source": "results_restart",
    "previous_attempt": true,
    "retry_count": 2
})
```

## Entity Cleanup System

### EntityClearingService Methods

```gdscript
# Complete world reset - clears everything
EntityClearingService.clear_all_world_objects()

# Clean entity removal (no death events, no XP orbs)
EntityClearingService.clear_all_entities()

# Clear only transient objects (XP orbs, items)
EntityClearingService.clear_transient_objects()
```

### SessionManager Reset Types

#### 1. Debug Reset
```gdscript
SessionManager.reset_debug()
# → Full reset, no preservation
```

#### 2. Player Death Reset
```gdscript
SessionManager.reset_player_death()
# → Preserve enemies for death screen, clear transients only
```

#### 3. Map Transition Reset
```gdscript
SessionManager.reset_map_transition("arena_forest", "arena_desert")
# → Preserve progression, clear map-specific entities
```

#### 4. Hideout Return Reset
```gdscript
SessionManager.reset_hideout_return()
# → Preserve character data, full entity clear
```

## State Validation & Transition Rules

### Valid Transition Matrix

| From State | Can Go To |
|------------|-----------|
| BOOT | → Any state (startup) |
| MENU | → CHARACTER_SELECT, HIDEOUT, EXIT |
| CHARACTER_SELECT | → MENU, HIDEOUT, EXIT |
| HIDEOUT | → MENU, ARENA, CHARACTER_SELECT, EXIT |
| ARENA | → RESULTS, HIDEOUT, MENU, EXIT |
| RESULTS | → MENU, HIDEOUT, ARENA (restart), EXIT |
| EXIT | → Terminal (no transitions) |

### Invalid Transition Handling

```gdscript
# StateManager validates all transitions
StateManager._is_valid_transition(State.RESULTS, State.CHARACTER_SELECT)  # → false

# Invalid transitions are logged and ignored
Logger.error("Invalid state transition: RESULTS -> CHARACTER_SELECT", "state")
```

## Signal Architecture

### StateManager Signals

```gdscript
# Core state transitions
signal state_changed(prev: State, next: State, context: Dictionary)
signal run_started(run_id: StringName, context: Dictionary)
signal run_ended(result: Dictionary)

# Usage example
StateManager.state_changed.connect(_on_state_changed)

func _on_state_changed(prev: StateManager.State, next: StateManager.State, context: Dictionary):
    match next:
        StateManager.State.ARENA:
            _setup_arena_ui(context)
        StateManager.State.RESULTS:
            _show_results_screen(context)
```

### SessionManager Signals

```gdscript
# Reset lifecycle
signal session_reset_started(reason: ResetReason, context: Dictionary)
signal session_reset_completed(reason: ResetReason, duration_ms: float)

# Reset phases
signal entities_cleared()
signal player_reset()
signal systems_reset()

# Usage example
SessionManager.session_reset_started.connect(_on_reset_started)
SessionManager.entities_cleared.connect(_on_entities_cleared)
```

## Multi-Phase Reset Sequence

### 1. Entity Clearing Phase
```gdscript
# Different behavior based on reset reason
if reason == ResetReason.PLAYER_DEATH:
    EntityClearingService.clear_transient_objects()  # Preserve enemies
else:
    EntityClearingService.clear_all_world_objects()  # Full clear
```

### 2. Systems Reset Phase
```gdscript
# Reset WaveDirector
wave_director.reset()

# Reset progression (conditionally)
if not context.get("preserve_progression", false):
    PlayerProgression.reset_session()
```

### 3. Player Reset Phase
```gdscript
# Reset position, health, velocity
player.global_position = spawn_pos
player.reset_health()
player.velocity = Vector2.ZERO

# CRITICAL: Re-register with damage systems
player._register_with_damage_system()

# Validate registration success (with retry)
for retry in range(3):
    if player.is_registered_with_damage_system():
        break
    # Retry registration if failed
```

### 4. UI Reset Phase
```gdscript
# Reset UI state
EventBus.session_ui_reset.emit({"reason": reason, "context": context})

# Clear temporary effects while preserving permanent nodes
_clear_temporary_effects()
```

## Integration with Existing Systems

### EventBus Integration
```gdscript
# Scene transitions trigger EventBus events
EventBus.scene_transition.emit(prev_scene, next_scene, context)
EventBus.session_ui_reset.emit(reset_context)
```

### WaveDirector Integration
```gdscript
# WaveDirector resets clear MultiMesh enemy pools
wave_director.reset()  # Clears ~50 pooled enemies efficiently
```

### EntityTracker Integration
```gdscript
# Clean tracking removal without death events
EntityTracker.unregister_entity(entity_id)
DamageService.unregister_entity(entity_id)
```

## Best Practices

### 1. Always Use StateManager for Transitions
```gdscript
# ✅ Correct
StateManager.go_to_hideout({"source": "arena_complete"})

# ❌ Wrong - bypasses validation and logging
get_tree().change_scene_to_file("res://scenes/hideout/Hideout.tscn")
```

### 2. Provide Context for Complex Transitions
```gdscript
# ✅ Good - context helps systems respond appropriately
StateManager.start_run("arena_boss", {
    "boss_type": "dragon",
    "difficulty_modifier": 1.5,
    "source": "quest_progression"
})
```

### 3. Handle Reset Reasons Appropriately
```gdscript
# ✅ Different cleanup for different scenarios
match reason:
    SessionManager.ResetReason.PLAYER_DEATH:
        # Preserve enemies for death screen stats
        preserve_enemy_data = true
    SessionManager.ResetReason.DEBUG_RESET:
        # Full clean reset
        clear_everything = true
```

### 4. Validate Player Registration After Reset
```gdscript
# ✅ Always verify critical registrations
if not player.is_registered_with_damage_system():
    Logger.error("CRITICAL: Player not registered after reset!")
    player.ensure_damage_registration()
```

## Debugging & Monitoring

### State Logging
```gdscript
# All transitions are automatically logged
Logger.info("State transition: ARENA -> RESULTS (context: {...})", "state")
Logger.info("Session reset completed - reason: Player Death, duration: 25.3ms", "session")
```

### Console Commands
```gdscript
# Manual session reset via console
SessionManager.cmd_reset_session("debug")
SessionManager.cmd_reset_session("death")
SessionManager.cmd_reset_session("transition")
```

### Reset Performance Monitoring
```gdscript
# SessionManager tracks reset duration
session_reset_completed.emit(reason, duration_ms)
# Typical duration: 10-50ms for full world reset
```

## Future Enhancements

### Transition Animations
- Add loading screens between major state changes
- Implement fade-in/fade-out effects for scene transitions
- Create transition-specific animations (e.g., portal effects for arena entry)

### State Persistence
- Save/restore state across application restarts
- Preserve hideout state during arena runs
- Implement checkpoint system for long sequences

### Advanced Context Handling
- Typed context objects instead of Dictionary
- Context validation and schema enforcement
- Context transformation between states

## Related Systems

- **[[Entity-Cleanup-System]]**: Deep dive into entity lifecycle management
- **[[EventBus-System]]**: Signal-based communication patterns
- **[[Scene-Management-System]]**: Overall scene architecture
- **[[Performance-Optimization-System]]**: MultiMesh pool management