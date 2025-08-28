# ARCHITECTURE.md
Godot 4.2 roguelike — mechanics-first, data-driven, deterministic.

## ALWAYS END TASK WITH ##
- **update CHANGELOG.md with quick summary** of what you have done (current week's changes only)
- **ALWAYS CHECK LESSONS_LEARNED.md FIRST** before starting any task
- **ADD LEARNINGS TO LESSONS_LEARNED.md** after task completion if applicable (new patterns, solutions, or insights discovered)
- **ALWAYS CHECK CLAUDE.md** before starting any task

- *"YOU MUST keep tunables in /data/* (.tres resources)"


## Layers
- **Scenes (UI/View):** Represent state; minimal logic; connect/disconnect signals only.
  ```gdscript
  # Arena.gd - scene layer
  @onready var ability_system: AbilitySystem = AbilitySystem.new()
  EventBus.level_up.connect(_on_level_up)  # UI responses only
  ```
  
  **Exception:** Scenes may import pure Resource configuration classes from domain:
  ```gdscript
  # ✅ Allowed - Pure Resource config classes
  const AnimationConfig = preload("res://scripts/domain/AnimationConfig.gd")
  const ArenaConfig = preload("res://scripts/domain/ArenaConfig.gd")
  
  # ❌ Not allowed - Business logic classes
  const EnemyEntity = preload("res://scripts/domain/EnemyEntity.gd")
  ```
- **Systems (Rules):** Ability, Damage, Wave, Item, SkillTree. Compute results; emit signals.
  ```gdscript
  # AbilitySystem.gd - system layer  
  EventBus.combat_step.connect(_on_combat_step)
  EventBus.damage_requested.emit(source_id, target_id, damage, tags)
  ```
- **Domain (Models):** Item/Affix/Skill/Support/TreeNode; pure data/helpers only.
  ```gdscript
  # Skill.gd - domain layer
  class_name Skill
  var id: String
  var damage: float
  func get_modified_damage(stats: Dictionary) -> float: ...
  ```
- **Autoloads (Glue):** `BalanceDB`, `CheatSystem`, `EventBus`, `GameOrchestrator`, `Logger`, `PauseManager`, `PlayerState`, `RNG`, and `RunManager`.

## Fixed-Step Combat Loop (Decision 5A)
```gdscript
# RunManager.gd (simplified)
const COMBAT_DT := 1.0 / 30.0
var _accum := 0.0

func _process(delta: float) -> void:
    _accum += delta
    while _accum >= COMBAT_DT:
        EventBus.emit_signal("combat_step", COMBAT_DT)
        _accum -= COMBAT_DT
```

Systems subscribe to `combat_step(dt)` and update in lockstep (DoT, AI, cooldowns).

## RNG Strategy (Decision 6A)
- `RNG.seed_run(run_seed: int)` in RunManager
- `RNG.stream(name: String)` returns a stable sub-stream (e.g., `hash(run_seed, name)`)
- Streams: `crit`, `loot`, `waves`, `ai`, `craft`
- No direct calls to `randi()`; always via a stream


## Signals Matrix

| Signal | Emitter(s) | Payload | Cadence | Purpose |
|--------|------------|---------|---------|---------|
| **TIMING** |
| `combat_step` | RunManager | `CombatStepPayload` | 30Hz Fixed | Drives deterministic combat updates. |
| **DAMAGE** |
| `damage_requested` | AbilitySystem, Projectiles | `DamageRequestPayload` | Per Hit | Requests a damage calculation from the `DamageSystem`. |
| `damage_applied` | DamageSystem | `DamageAppliedPayload` | Per Hit | Confirms a single damage instance was applied. |
| `damage_batch_applied` | DamageSystem | `DamageBatchAppliedPayload` | Per AoE | Confirms multiple damage instances for AoE attacks. |
| `damage_dealt` | DamageSystem | `DamageDealtPayload` | Per Hit | Signals damage was dealt, used for camera shake, etc. |
| `damage_taken` | Enemy Systems | `damage: int` | Per Hit | Signals the player has taken damage. |
| `player_died` | DamageSystem | `()` | On Death | Signals the player's health has reached zero. |
| **MELEE** |
| `melee_attack_started` | MeleeSystem | `payload` | On Attack | A melee attack has been initiated. |
| `melee_enemies_hit` | MeleeSystem | `payload` | On Hit | A melee attack has hit one or more enemies. |
| **ENTITIES** |
| `entity_killed` | DamageSystem | `EntityKilledPayload` | On Death | An entity has been killed, contains reward data. |
| `enemy_killed` | WaveDirector | `EnemyKilledPayload` | On Death | **[DEPRECATED]** Legacy signal, use `entity_killed`. |
| **PROGRESSION** |
| `xp_changed` | XpSystem | `XpChangedPayload` | On XP Gain | The player's XP has changed. |
| `level_up` | XpSystem | `LevelUpPayload` | On Level Up | The player has leveled up, triggers pause and card UI. |
| **GAME STATE & CAMERA** |
| `game_paused_changed` | PauseManager | `GamePausedChangedPayload` | On Change | The game's pause state has changed. |
| `arena_bounds_changed` | ArenaSystem | `ArenaBoundsChangedPayload` | On Load | Informs the camera of the new arena's boundaries. |
| `player_position_changed` | PlayerState | `PlayerPositionChangedPayload` | ~15Hz | Provides cached player position for other systems. |
| **INTERACTION & LOOT** |
| `interaction_prompt_changed` | (Unused) | `InteractionPromptChangedPayload` | - | **[DEPRECATED]** No longer used. |
| `loot_generated` | Arena Systems | `LootGeneratedPayload` | On Event | Signals loot was generated (e.g., from a chest). |
| **DEBUG** |
| `cheat_toggled` | CheatSystem | `CheatTogglePayload` | On Toggle | A debug cheat has been toggled. |

### Signal Usage Rules
- **EntityId-based**: Use typed EntityId for all entity references, never Node references
- **Pause-aware**: Mark systems with appropriate `process_mode` for pause handling  
- **Cleanup**: Always disconnect in `_exit_tree()` to prevent memory leaks
- **No get_node**: Systems must never use `get_node("../")` - use signals or autoloads only

```gdscript
# ✓ Correct signal usage
func _exit_tree() -> void:
    EventBus.combat_step.disconnect(_on_combat_step)

# ✗ Wrong - direct node access
get_node("../Player").take_damage(10)
```





## Project Structure

```
GodotGame/
├── (root)/                        # Main Godot project
│   ├── addons/                    # Third-party plugins (e.g., MCP)
│   ├── assets/                    # Art, sound, and music assets
│   ├── autoload/                  # Global singletons (e.g., EventBus)
│   ├── data/                      # .tres resources for balance, config, etc.
│   ├── scenes/                    # Game scenes
│   │   ├── arena/
│   │   ├── bosses/
│   │   ├── main/
│   │   └── ui/
│   ├── scripts/                   # GDScript logic files
│   │   ├── domain/                # Pure data classes and signal payloads
│   │   ├── resources/             # Custom Resource definitions
│   │   ├── systems/               # Core game logic systems
│   │   └── utils/                 # Helper scripts and utilities
│   ├── tests/                     # Automated test scenes and scripts
│   ├── project.godot              # Godot project configuration
│   └── icon.svg                   # Project icon
├── ARCHITECTURE.md                # This file - system design and decisions
├── CHANGELOG.md                   # Current week development changes
├── changelogs/                    # Change tracking archives
├── CLAUDE.md                      # AI-specific notes and decisions
└── LESSONS_LEARNED.md             # Godot patterns and learnings
```

### Key Directories:
- **`autoload/`**: Global systems accessible throughout the game.
- **`data/`**: Data-driven `.tres` resources for tuning and content.
- **`scenes/`**: Visual representation and UI logic.
- **`scripts/domain/`**: Pure data classes, including signal payloads.
- **`scripts/systems/`**: Core game mechanics and rules.
- **`tests/`**: Automated testing and validation.
- **Root level**: Project documentation and decision tracking.
