# Autoload Layer - CLAUDE.md
> Context-specific documentation for autoload/ - Global singletons and coordination systems

**Parent Documentation:** [Main CLAUDE.md](../CLAUDE.md) | **Layer:** Foundation

## Quick Reference

| Autoload | Purpose | Key Signals/Methods | Dependencies |
|----------|---------|-------------------|--------------|
| **EventBus.gd** | Central event hub with typed payloads | All cross-system signals | Domain payload classes |
| **GameOrchestrator.gd** | System initialization & dependency injection | `initialize_systems()`, `world_ready` | All system classes |
| **StateManager.gd** | Scene transitions & game state | `go_to_arena()`, `go_to_hideout()` | SceneTransitionManager |
| **RunManager.gd** | 30Hz fixed-step combat timing + RNG seeding | `combat_step` signal (30Hz), `run_seed` | RNG, BalanceDB |
| **RNG.gd** | Deterministic random streams | `stream(name)` for seeded RNG | None (pure) |
| **Logger.gd** | Centralized logging with categories | `info()`, `warn()`, `debug()` | BalanceDB for config |
| **BalanceDB.gd** | Hot-reloadable balance data | `balance_reloaded` signal | None (foundation) |
| **SessionState.gd** | Session-only run tracking (MEGABONK/ROR2) | `start_run()`, `end_run()`, `get_final_stats()` | EventBus, MetaProgression |
| **MetaProgression.gd** | Persistent currency & unlocks | `add_rift_fragments()`, `get_rift_fragments()` | None (persistence) |
| **LocalLeaderboard.gd** | Personal best tracking per map/tier | `add_run()`, `get_personal_best()`, `get_leaderboard()` | None (persistence) |
| **PlayerProgression.gd** | In-run XP & leveling (simplified) | `leveled_up`, `xp_gained` | None (session-only) |
| **MapLevel.gd** | Time-based progression tracking | `level_increased`, `level_changed` | StateManager for run lifecycle |

## Autoload Architecture Patterns

### 🏗️ **Initialization Order & Dependencies**

```gdscript
# Core Foundation (No dependencies)
1. Logger             ← Base logging
2. RNG                ← Deterministic seeding
3. BalanceDB          ← Data foundation

# Persistence Layer
4. MetaProgression    ← Persistent currency & unlocks (user://meta_progression.tres)
5. LocalLeaderboard   ← Personal best tracking (user://local_leaderboard.tres)

# System Coordination
6. EventBus           ← Signal hub (depends on payload classes)
7. RunManager         ← Fixed-step timing + RNG seeding (depends on RNG, BalanceDB)
8. StateManager       ← Scene management
9. SessionState       ← Session-only run tracking (depends on EventBus, MetaProgression)

# Game Systems
10. PlayerProgression ← In-run XP (simplified, session-only)
11. MapLevel          ← Time-based progression tracking
12. GameOrchestrator  ← System initialization (last)
```

### 🔄 **EventBus Signal Architecture**

**Typed Payload Pattern:**
```gdscript
# ✓ Correct: Use typed payloads
const CombatStepPayload_Type = preload("res://scripts/domain/signal_payloads/CombatStepPayload.gd")
signal combat_step(payload)  # payload: CombatStepPayload_Type

# EventBus emits
var payload = CombatStepPayload_Type.new()
payload.delta_time = RunManager.COMBAT_DT
EventBus.combat_step.emit(payload)

# Systems connect
EventBus.combat_step.connect(_on_combat_step)
func _on_combat_step(payload: EventBus.CombatStepPayload_Type) -> void:
```

**High-Frequency Optimization:**
```gdscript
# Object pools for damage signals to reduce allocations
var _damage_applied_pool: ObjectPool
var _damage_dealt_pool: ObjectPool
```

### 🎮 **GameOrchestrator Dependency Injection**

**System Creation Pattern:**
```gdscript
# GameOrchestrator creates systems with proper dependencies
func initialize_systems() -> void:
    card_system = CardSystem_Type.new()
    spawn_director = SpawnDirector_Type.new()
    radar_system = RadarSystem_Type.new(spawn_director)  # Inject dependency

    # Systems register with autoloads
    systems["card_system"] = card_system
    systems["spawn_director"] = spawn_director
```

**Arena Integration:**
```gdscript
# Arena receives injected systems from GameOrchestrator
func setup_systems(injected_systems: Dictionary) -> void:
    _card_system = injected_systems.card_system
    _spawn_director = injected_systems.spawn_director
```

### ⏱️ **RunManager Fixed-Step Pattern**

**30Hz Combat Timing:**
```gdscript
# Fixed-step accumulator pattern
const COMBAT_DT: float = 1.0 / 30.0  # 30Hz

func _process(delta: float) -> void:
    if PauseManager.is_paused():
        return  # Don't accumulate time during pause

    _accumulator += delta
    while _accumulator >= COMBAT_DT:
        _accumulator -= COMBAT_DT
        _emit_combat_step()
```

### 🎲 **RNG Deterministic Streams**

**Named Stream Pattern:**
```gdscript
# Different streams for different game systems
RNG.stream("crit")    # Critical hit calculations
RNG.stream("loot")    # Item drops and rewards
RNG.stream("waves")   # Enemy spawning
RNG.stream("boss")    # Boss AI decisions

# Usage in systems
var crit_roll = RNG.stream("crit").randf()
var spawn_type = RNG.stream("waves").randi_range(0, enemy_types.size() - 1)
```

### 📊 **BalanceDB Hot-Reload Pattern**

**Resource Monitoring:**
```gdscript
# BalanceDB watches .tres files for changes
func _ready() -> void:
    # Monitor specific balance files
    _monitor_file("res://data/balance/combat.tres")
    _monitor_file("res://data/balance/player.tres")

    # Emit reload signal when changed
    balance_reloaded.emit()
```

**System Integration:**
```gdscript
# Systems connect to balance reload
func _ready() -> void:
    BalanceDB.balance_reloaded.connect(_reload_balance)

func _reload_balance() -> void:
    # Refresh cached balance values
    _damage_multiplier = BalanceDB.combat.damage_multiplier
```

### 🎮 **Progression Autoloads (Task 04 - MEGABONK/ROR2 Architecture)**

**SessionState - Session-Only Run Tracking:**
```gdscript
# Start a new run (clears previous session data)
SessionState.start_run(character_id, map_id, tier)

# Session stats tracked via EventBus signals
EventBus.enemy_killed.connect(_on_enemy_killed)  # Auto-tracked
EventBus.damage_dealt.connect(_on_damage_dealt)  # Auto-tracked
EventBus.xp_gained.connect(_on_xp_gained)        # Auto-tracked

# Access current run state
var is_active = SessionState.is_run_active()
var current_char = SessionState.current_character
var current_tier = SessionState.current_tier
var kills = SessionState.kills
var damage = SessionState.damage_dealt

# End run and calculate rewards
SessionState.end_run()  # Emits run_ended signal with final stats

# Get comprehensive final stats
var stats = SessionState.get_final_stats()
# Returns: {character_id, map_id, tier, kills, damage_dealt, time_survived,
#           stage_reached, xp_gained, final_swarm_entered, rift_fragments_earned}
```

**MetaProgression - Persistent Currency:**
```gdscript
# Award Rift Fragments (persistent across runs)
MetaProgression.add_rift_fragments(amount)  # Emits rift_fragments_changed signal

# Check balance
var balance = MetaProgression.get_rift_fragments()

# Spend fragments (for unlocks/upgrades)
if MetaProgression.can_afford(cost):
    MetaProgression.spend_rift_fragments(cost)

# Reset for testing
MetaProgression.reset_all()
```

**LocalLeaderboard - Personal Best Tracking:**
```gdscript
# Add run to leaderboard (called by SessionState on end_run)
var rank = LocalLeaderboard.add_run(map_id, tier, run_data)
# Returns 1-10 if made leaderboard, -1 if didn't qualify

# Get personal best for specific map+tier
var best = LocalLeaderboard.get_personal_best("forest_arena", 1)
# Returns: {character_id, kills, time_survived, stage_reached, ...}

# Get full leaderboard for display
var leaderboard = LocalLeaderboard.get_leaderboard("forest_arena", 1)
# Returns: Array[Dictionary] sorted by rift_fragments_earned

# Get all maps/tiers with entries
var maps = LocalLeaderboard.get_maps_with_entries()
var tiers = LocalLeaderboard.get_tiers_with_entries("forest_arena")
```

**Architecture Notes:**
- **No CharacterManager:** Character selection handled by SessionState + MainMenu UI
- **No Profiles Directory:** Only two persistence files:
  - `user://meta_progression.tres` (Rift Fragments)
  - `user://local_leaderboard.tres` (Personal bests)
- **Session vs Meta Separation:** SessionState = temporary run data, MetaProgression = permanent unlocks
- **Bottom-Up Migration:** Phase 1-6 built new systems first, Phase 7 verified integration complete

## Common Integration Patterns

### 🔌 **System ↔ Autoload Communication**

```gdscript
# ✓ Systems emit to EventBus
EventBus.enemy_killed.emit(payload)

# ✓ Autoloads provide services
var damage = BalanceDB.combat.base_damage
var random_enemy = RNG.stream("waves").pick_random(enemy_types)

# ✗ Never directly reference systems from autoloads
# autoload_script.gd should NOT call arena.get_player()
```

### 📝 **Logging Integration**

```gdscript
# Category-based logging in autoloads
Logger.info("System initialized", "orchestrator")
Logger.warn("Balance file missing", "balance")
Logger.debug("RNG seed updated", "rng")

# F6 toggles DEBUG/INFO levels
# F5 reloads log configuration
```

### 🔄 **State Transition Patterns**

```gdscript
# StateManager handles all scene transitions
StateManager.go_to_arena()           # Menu → Arena
StateManager.go_to_hideout()         # Arena → Hideout
StateManager.go_to_character_select() # Menu → Character Select

# Never use direct EventBus for navigation:
# ✗ EventBus.request_scene_change.emit("arena")
```

## Performance Considerations

### ⚡ **Zero-Allocation Patterns**

- **EventBus:** Object pools for high-frequency payloads (damage_applied, damage_dealt)
- **RunManager:** Fixed accumulator, no per-frame allocations
- **RNG:** Cached stream instances, no dynamic creation

### 🔍 **Process Mode Management**

```gdscript
# Critical autoloads continue during pause
Logger:     PROCESS_MODE_ALWAYS    # Logging always available
EventBus:   PROCESS_MODE_ALWAYS    # Events during pause menus

# Game systems pause properly
RunManager: PROCESS_MODE_PAUSABLE  # Combat stops during pause
```

## Troubleshooting Guide

### 🚨 **Common Issues**

1. **"Unknown autoload" errors:** Check initialization order
2. **Signal not firing:** Verify EventBus signal connections use typed payloads
3. **RNG not deterministic:** Ensure same seed and stream usage
4. **Balance not reloading:** Check BalanceDB file monitoring setup
5. **Systems not initialized:** Verify GameOrchestrator.initialize_systems() called

### 🔧 **Debug Tools**

- **F6:** Toggle Logger DEBUG/INFO levels
- **F5:** Force reload balance data
- **Logger categories:** "orchestrator", "balance", "rng", "state"

## Migration Notes

When creating new autoloads:
1. **Add to initialization order** in GameOrchestrator
2. **Use typed EventBus signals** with payload classes
3. **Follow PROCESS_MODE patterns** (ALWAYS vs PAUSABLE)
4. **Integrate with Logger** using appropriate categories
5. **Update this documentation** with new patterns

---
**See Also:** [System Integration](../scripts/systems/CLAUDE.md) | [Domain Models](../scripts/domain/CLAUDE.md) | [Architecture Rules](../ARCHITECTURE.md)