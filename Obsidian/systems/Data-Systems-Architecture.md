# Data Systems Architecture

#architecture #data-driven #autoload #validation

## 🏗️ Overview

The game follows a **data-driven architecture** where all tunables, configuration, and balance values are externalized into JSON files. This enables runtime tuning, hot-reloading, and clear separation between code logic and game balance.

## 📊 System Components

### [[BalanceDB]] - Schema Validation & Hot-Reload
**Purpose**: Load, validate, and manage all balance data with type safety and hot-reload support  
**Location**: `vibe/autoload/BalanceDB.gd`  
**Status**: ✅ Production-ready with comprehensive validation

```gdscript
# Core usage pattern
var projectile_speed: float = BalanceDB.get_abilities_value("projectile_speed")
var enemy_hp: float = BalanceDB.get_waves_value("enemy_hp")

# Hot-reload via F5 key
BalanceDB.balance_reloaded.connect(_on_balance_reloaded)
```

### [[RNG]] - Deterministic Random Streams  
**Purpose**: Seeded random number generation with named streams for deterministic gameplay  
**Location**: `vibe/autoload/RNG.gd`  
**Status**: ✅ Production-ready with stream management

```gdscript
# Named streams for different systems
var crit_roll: float = RNG.stream("combat").randf()
var loot_roll: int = RNG.stream("drops").randi_range(1, 100)
```

### [[Logger]] - Centralized Logging System
**Purpose**: Structured logging with configurable levels and optional category filtering  
**Location**: `vibe/autoload/Logger.gd`  
**Status**: ✅ Production-ready with complete migration

```gdscript
Logger.info("Game started")
Logger.debug("Player position: " + str(position), "player")
Logger.warn("Pool exhaustion detected", "abilities")
```

**Config**: `/data/debug/log_config.json` • **Hot-reload**: F5/F6 keys

### [[RunManager]] - Player Stats & Session State
**Purpose**: Manage player progression stats loaded from BalanceDB with hot-reload support  
**Location**: `vibe/autoload/RunManager.gd`  
**Status**: ✅ Production-ready with BalanceDB integration

```gdscript
# Automatically reloads when BalanceDB changes
var projectile_count: int = 1 + RunManager.stats.projectile_count_add
var fire_rate: float = base_rate * RunManager.stats.fire_rate_mult
```

## 📁 Data Organization

### Balance Data (`/data/balance/`)
Core gameplay balance values loaded by [[BalanceDB]]:

| File | Purpose | Schema Status | Hot-Reload |
|------|---------|---------------|------------|
| `combat.json` | Damage, crit, collision radii | ✅ Validated | ✅ |
| `abilities.json` | Projectile pools, speeds, TTL | ✅ Validated | ✅ |
| `waves.json` | Enemy spawning, health, arena bounds | ✅ Validated | ✅ |
| `player.json` | Base stats and multipliers | ✅ Validated | ✅ |

### Enemy Data (`/data/enemies/`)
Enemy type definitions for data-driven spawning system:

| File | Purpose | Schema Status | Hot-Reload |
|------|---------|---------------|------------|
| `grunt_basic.json` | Basic melee enemy type | ✅ Validated | ✅ |
| `slime_green.json` | Medium health chase enemy | ✅ Validated | ✅ |
| `archer_skeleton.json` | Fast flee-behavior enemy | ✅ Validated | ✅ |

### UI Configuration (`/data/ui/`)
User interface configuration with gameplay impact:

| File | Purpose | Schema Status | Hot-Reload |
|------|---------|---------------|------------|
| `radar.json` | Enemy radar range, colors, sizing | ✅ Validated | ✅ |

### Debug Configuration (`/data/debug/`)
Development tools and logging configuration:

| File | Purpose | Schema Status | Hot-Reload |
|------|---------|---------------|------------|
| `log_config.json` | Logger levels and category filtering | ⚡ JSON-based | ✅ |

### Arena Data (`/data/arena/`)
Level layouts and procedural generation templates:

| Directory | Purpose | Schema Status | System |
|-----------|---------|---------------|--------|
| `layouts/*.json` | Arena definitions | ⚠️ Arena-specific | ArenaSystem |
| `layouts/rooms/*.json` | Room configurations | ⚠️ Arena-specific | ArenaSystem |

## 🔍 Schema Validation System

### Type Safety Features
**Implemented in**: `BalanceDB._validate_data()`

```gdscript
# JSON float-to-int conversion handling
if expected_type == TYPE_INT and actual_type == TYPE_FLOAT:
    var float_val: float = data[field_name]
    if float_val == floor(float_val):
        pass  # Accept whole number floats as valid integers
```

### Validation Coverage
- ✅ **Type Validation**: Float, int, Dictionary, String with JSON number handling
- ✅ **Required Fields**: Missing critical fields caught at load time  
- ✅ **Range Validation**: Min/max bounds for gameplay-critical values
- ✅ **Nested Structures**: Complex objects like `arena_center`, `colors`
- ✅ **Optional Fields**: Schema flexibility for backward compatibility
- ✅ **Unknown Fields**: Warnings for potential typos

### Error Handling Strategy
```gdscript
# Validation failure → Fallback values → Continue execution
if not _validate_data(data, filename):
    push_error("Schema validation failed for: " + file_path + ". Using fallback values.")
    _data[filename] = _fallback_data.get(filename, {})
    return  # Game continues with safe defaults
```

## 🔥 Hot-Reload Architecture

### Signal-Based Updates
All systems connect to `BalanceDB.balance_reloaded` signal:

```gdscript
# System registration pattern
func _ready() -> void:
    _load_balance_values()
    if BalanceDB:
        BalanceDB.balance_reloaded.connect(_load_balance_values)

func _load_balance_values() -> void:
    # Reload all balance-dependent values
    projectile_radius = BalanceDB.get_combat_value("projectile_radius")
    enemy_radius = BalanceDB.get_combat_value("enemy_radius")
```

### Current Hot-Reload Support (UPDATED)
| System | Hot-Reload Status | Integration |
|--------|-------------------|-------------|
| DamageSystem | ✅ Combat values + object identity collision | Direct BalanceDB |
| AbilitySystem | ✅ Projectile settings | Direct BalanceDB |
| WaveDirector | ✅ Enemy spawn values + Array[EnemyEntity] pools | Direct BalanceDB + EnemyRegistry |
| EnemyRegistry | ✅ JSON enemy system (knight_*) | Pure JSON loading from res://data/enemies/ |
| EnemyRenderTier | ✅ Tier assignment + Dictionary conversion | EnemyRegistry dependency |
| EnemyBehaviorSystem | ✅ AI behavior patterns | EnemyRegistry dependency |
| MeleeSystem | ✅ Combat values + WaveDirector references | Direct BalanceDB + pool indexing |
| RunManager | ✅ Player stats | Direct BalanceDB |
| UI Systems | ✅ Radar configuration | Direct BalanceDB |
| Logger | ✅ Log config & levels | BalanceDB signal integration |

### F5/F6 Trigger Mechanisms
```gdscript
# BalanceDB._input() - F5 key detection
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
        Logger.info("F5 pressed - Hot-reloading balance data...", "balance")
        reload_balance_data()
        Logger.info("Balance data reloaded successfully!", "balance")

# Logger._input() - F6 debug toggle
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_F6:
        toggle_debug_mode()
```

## 🎛️ Configuration Patterns

### Adding New Balance Values

1. **Update JSON Schema** in BalanceDB schema definitions:
```gdscript
"new_system": {
    "required": {
        "new_value": TYPE_FLOAT,
        "another_value": TYPE_INT
    },
    "ranges": {
        "new_value": {"min": 0.1, "max": 100.0}
    }
}
```

2. **Add to Fallback Data** for safety:
```gdscript
"new_system": {
    "new_value": 10.0,
    "another_value": 5
}
```

3. **Update Load Sequence** in `load_all_balance_data()`:
```gdscript
_load_balance_file("new_system")
```

4. **Create Accessor Methods**:
```gdscript
func get_new_system_value(key: String) -> Variant:
    return _get_value("new_system", key)
```

### System Integration Pattern
```gdscript
# Standard pattern for balance-dependent systems
class_name NewSystem
extends Node

var new_value: float
var another_value: int

func _ready() -> void:
    _load_balance_values()
    if BalanceDB:
        BalanceDB.balance_reloaded.connect(_load_balance_values)

func _load_balance_values() -> void:
    new_value = BalanceDB.get_new_system_value("new_value")
    another_value = BalanceDB.get_new_system_value("another_value")
    print("NewSystem: Reloaded balance values")
```

## 🧪 Testing & Validation

### Test Coverage
**Location**: `vibe/tests/test_balance_validation.gd`

- ✅ Valid data acceptance
- ✅ Missing required field rejection  
- ✅ Invalid type detection
- ✅ Range boundary validation
- ✅ Nested structure validation
- ✅ Unknown field warnings
- ✅ UI data validation

### Manual Testing Approach
```gdscript
# Test with intentionally broken data
{
    "projectile_radius": "invalid_string",  // Should fail type check
    "enemy_radius": -5.0,                  // Should fail range check
    "missing_required": true               // Should warn about unknown field
}
```

## 📈 Performance Considerations

### Load-Time Validation
- **When**: Only during file loading and hot-reload (F5)
- **Cost**: ~5ms validation overhead at startup
- **Benefit**: Prevents runtime errors during gameplay

### Memory Efficiency  
- **JSON Parsing**: Files loaded once, cached in `_data` Dictionary
- **Fallback Strategy**: Hardcoded defaults prevent crashes
- **Hot-Reload**: Full reload on F5, not incremental updates

### Runtime Access Cost
```gdscript
# Cached dictionary lookup - very fast
var value = BalanceDB.get_combat_value("projectile_radius")
// ~0.001ms per access
```

## 🔗 System Dependencies

### Dependency Graph
```
Logger (Output Layer)
├── BalanceDB (Core Data) ──┐
├── RunManager (Player Stats) ──┤
├── DamageSystem (Combat Values) ──┤ 
├── AbilitySystem (Projectile Config) ──┤
├── WaveDirector (Enemy Spawn Data) ──┤
└── UI Systems (Interface Config) ──┘
```

### Initialization Order
1. **Logger** loads first (autoload priority) - output foundation
2. **BalanceDB** loads data and connects to Logger for output
3. **RNG** initializes with seed management  
4. **RunManager** loads player stats from BalanceDB
5. **Game Systems** connect to balance_reloaded signal and use Logger
6. **Scene Systems** access validated data and log via Logger at runtime

## 🏰 Typed Enemy System Architecture (UPDATED)

### EnemyEntity Object Model
The system now uses typed [[EnemyEntity]] objects backed by JSON data for compile-time safety:

```gdscript
# Runtime typed objects with Dictionary compatibility
class_name EnemyEntity extends Resource

var type_id: String       # Enemy type identifier
var pos: Vector2          # World position
var vel: Vector2          # Current velocity  
var hp: float            # Current health
var max_hp: float        # Maximum health
var alive: bool          # Alive state
var speed: float         # Movement speed
var size: Vector2        # Collision size

# Conversion methods for MultiMesh compatibility
func to_dictionary() -> Dictionary
func from_dictionary(enemy_dict: Dictionary, enemy_type: EnemyType = null) -> EnemyEntity
```

### Object Pool Management
[[WaveDirector]] maintains pre-allocated pools for zero-allocation gameplay:

```gdscript
# Pre-allocated enemy pool
var enemies: Array[EnemyEntity] = []

# Pool initialization with typed objects
func _initialize_pool() -> void:
    enemies.resize(max_enemies)
    for i in range(max_enemies):
        enemies[i] = EnemyEntity.new()  # Typed objects
```

### Signal Flow Changes
- **enemies_updated**: Now emits `Array[EnemyEntity]` instead of `Array[Dictionary]`
- **Object Identity**: Systems track enemies by reference, not index
- **Type Safety**: Compile-time guarantees for all enemy data access

## 🏰 Enemy JSON System

### Schema Structure
The enemy system uses a pure JSON-driven architecture with standardized schema:

#### Required Fields
```json
{
  "id": "knight_swarm",                    // Unique enemy identifier
  "display_name": "Swarm Knight",          // Human-readable name
  "health": 3.0,                          // Base HP value
  "speed": 80.0,                          // Movement speed
  "size": {"x": 20, "y": 20},            // Pixel dimensions for tier assignment
  "collision_radius": 10.0,               // Physics collision size
  "xp_value": 1,                          // Experience reward
  "spawn_weight": 0.4,                    // Relative spawn probability
  "visual": {                             // Appearance configuration
    "color": {"r": 1.0, "g": 0.0, "b": 0.0, "a": 1.0},
    "shape": "square"
  },
  "behavior": {                           // AI configuration
    "ai_type": "chase_player",
    "aggro_range": 300.0
  }
}
```

#### Folder Structure
```
/enemies/
├── config/
│   ├── enemy_registry.json    # Central registry with spawn weights
│   └── enemy_tiers.json       # Tier definitions and boundaries
├── knight_swarm.json          # Individual enemy types
├── knight_regular.json
├── knight_elite.json
└── knight_boss.json
```

#### Tier Assignment Rules
| Tier | Size Range | Example | Render Method | Visual |
|------|------------|---------|---------------|---------|
| SWARM | ≤24px | knight_swarm (20px) | MultiMesh fast | Red |
| REGULAR | 25-48px | knight_regular (36px) | MultiMesh normal | Green |
| ELITE | 49-64px | knight_elite (56px) | MultiMesh enhanced | Blue |
| BOSS | >64px | knight_boss (80px) | Individual sprite | Magenta |

### Data Flow Pipeline
1. **Registry Loading**: `enemy_registry.json` lists all enemy types with spawn weights
2. **Individual Loading**: `EnemyRegistry` loads each `knight_*.json` file
3. **Tier Assignment**: `EnemyRenderTier` assigns visual tier based on size/type
4. **Render Routing**: Enemies assigned to appropriate MultiMesh instances
5. **Visual Distinction**: Different colors/animations per tier for gameplay clarity

## 🚀 Future Enhancements

### Planned Improvements
- [ ] **Incremental Validation**: Only re-validate changed files
- [ ] **Schema Versioning**: Automatic migration support
- [ ] **Editor Integration**: Visual schema validation in Godot editor  
- [ ] **Performance Profiling**: Balance data access optimization

### Architecture Extensions
- [ ] **ContentDB Integration**: Merge arena data validation with BalanceDB
- [ ] **Modding Support**: External JSON override system
- [ ] **Network Sync**: Multiplayer balance data synchronization

## 📚 Related Documentation

### Core Architecture Files
- [[ARCHITECTURE.md]] - Overall project architecture decisions
- [[CLAUDE.md]] - Data-driven development guidelines  
- [[LESSONS_LEARNED.md]] - JSON validation patterns and solutions

### Implementation References
- `vibe/data/README.md` - JSON schema documentation
- `vibe/tests/test_balance_validation.gd` - Validation test examples
- `CHANGELOG.md` - Schema validation system implementation history

---

**Key Takeaway**: The data systems architecture enables **rapid iteration** through hot-reloadable, validated JSON configuration while maintaining **type safety** and **runtime stability** through comprehensive fallback mechanisms.