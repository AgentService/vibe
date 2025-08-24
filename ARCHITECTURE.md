# ARCHITECTURE.md
Godot 4.2 roguelike — mechanics-first, data-driven, deterministic.

## ALWAYS END TASK WITH ##
- **update CHANGELOG.md with quick summary** of what you have done (current week's changes only)
- **ALWAYS CHECK LESSONS_LEARNED.md FIRST** before starting any task
- **ADD LEARNINGS TO LESSONS_LEARNED.md** after task completion if applicable (new patterns, solutions, or insights discovered)
- **ALWAYS CHECK CLAUDE.md** before starting any task

- *"YOU MUST keep tunables in /vibe/data/* (.tres resources)"


## Layers
- **Scenes (UI/View):** Represent state; minimal logic; connect/disconnect signals only.
  ```gdscript
  # Arena.gd - scene layer
  @onready var ability_system: AbilitySystem = AbilitySystem.new()
  EventBus.level_up.connect(_on_level_up)  # UI responses only
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
- **Autoloads (Glue):** RunManager (flow, fixed step), EventBus (global signals), RNG (seeded streams), ContentDB (.tres load), BalanceDB (resource loading).

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

| Signal | Emitter | Arguments | Cadence | Pause Behavior | Purpose |
|--------|---------|-----------|---------|----------------|---------|
| **TIMING** |
| `combat_step` | RunManager | `dt: float` | 30Hz fixed | Paused during UI | Drives deterministic combat updates |
| **DAMAGE** |
| `damage_requested` | AbilitySystem, Projectiles | `source_id: EntityId, target_id: EntityId, base_damage: float, tags: PackedStringArray` | Per collision | Active | Request damage calculation |
| `damage_applied` | DamageSystem | `target_id: EntityId, final_damage: float, is_crit: bool, tags: PackedStringArray` | Per damage | Active | Single damage instance applied |
| `damage_batch_applied` | DamageSystem | `damage_instances: Array[Dictionary]` | Per AoE/batch | Active | Multiple damage instances for AoE |
| **ENTITIES** |
| `entity_killed` | DamageSystem | `entity_id: EntityId, death_pos: Vector2, rewards: Dictionary` | Per death | Active | Entity death with typed rewards |
| `enemy_killed` | WaveDirector | `pos: Vector2, xp_value: int` | Per death | Active | Legacy enemy death (deprecated) |
| **PROGRESSION** |
| `xp_changed` | XpSystem | `current_xp: int, next_level_xp: int` | Per XP gain | Active | XP values updated |
| `level_up` | XpSystem | `new_level: int` | Per level | Triggers pause | Player leveled up, show CardPicker |
| **PLAYER STATE** |
| `player_position_changed` | PlayerState | `position: Vector2` | 10-15Hz / 12px delta | Active | Cached player position for systems |
| **GAME STATE** |
| `game_paused_changed` | RunManager | `is_paused: bool` | On state change | N/A | Game pause state coordination |

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
├── vibe/                          # Main Godot project
│   ├── autoload/                  # Global singletons
│   │   ├── EventBus.gd           # Global signal system
│   │   ├── RNG.gd                # Seeded random number generation
│   │   └── RunManager.gd         # Game flow and fixed-step timing
│   ├── scenes/                    # UI and game scenes
│   │   ├── arena/                 # Combat arena
│   │   │   ├── Arena.gd          # Arena logic
│   │   │   └── Arena.tscn        # Arena scene
│   │   └── main/                  # Main menu and game flow
│   │       ├── Main.gd            # Main game controller
│   │       └── Main.tscn         # Main scene
│   ├── scripts/                   # Game systems and logic
│   │   └── systems/               # Core game systems
│   │       └── AbilitySystem.gd   # Ability and skill management
│   ├── tests/                     # Test scenes and scripts
│   │   ├── run_tests.gd           # Test runner
│   │   ├── run_tests.tscn         # Test scene
│   │   └── test_rng_streams.gd    # RNG system tests
│   ├── project.godot              # Godot project configuration
│   └── icon.svg                   # Project icon
├── ARCHITECTURE.md                # This file - system design and decisions
├── CHANGELOG.md                   # Current week development changes (see /changelogs/ for archives)
├── changelogs/                    # Change tracking system (weekly archives, features)
│   ├── README.md                  # Changelog management approach
│   ├── weekly/                    # Weekly archives (2025-wXX.md)
│   └── features/                  # Feature implementation files (DD_MM_YYYY-FEATURE_NAME.md)
├── CLAUDE.md                      # Claude-specific notes and decisions
├── CURSOR.md                      # Cursor-specific notes and decisions
└── LESSONS_LEARNED.md             # Godot patterns and learnings
```

### Key Directories:
- **`vibe/autoload/`**: Global systems accessible throughout the game
- **`vibe/scenes/`**: Visual representation and UI logic
- **`vibe/scripts/systems/`**: Core game mechanics and rules
- **`vibe/tests/`**: Automated testing and validation
- **Root level**: Project documentation and decision tracking

