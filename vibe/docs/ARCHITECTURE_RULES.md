# Architecture Boundary Enforcement Rules

This document defines the automated enforcement rules for the project's layered architecture, as implemented in the boundary checking tools.

## Layer Definitions

### 🔧 Autoload Layer (`autoload/`)
**Purpose**: Global singletons for system coordination  
**Can Import**: Domain models only  
**Can Call**: Domain models and other autoloads  
**Examples**: `EventBus.gd`, `RNG.gd`, `RunManager.gd`

### ⚙️ Systems Layer (`scripts/systems/`)  
**Purpose**: Game logic and rules implementation  
**Can Import**: Domain models and autoloads  
**Can Call**: Domain models, autoloads, and other systems via signals  
**Examples**: `AbilitySystem.gd`, `DamageSystem.gd`, `WaveDirector.gd`

### 🎨 Scenes Layer (`scenes/`)
**Purpose**: UI and visual representation  
**Can Import**: Systems and autoloads  
**Can Call**: Systems and autoloads only  
**Examples**: `Arena.gd`, `Player.gd`, `HUD.gd`

### 📦 Domain Layer (`scripts/domain/`)
**Purpose**: Pure data models and helpers  
**Can Import**: Nothing (pure data)  
**Can Call**: Only other domain models  
**Examples**: `EntityId.gd`, signal payload classes

## Enforced Rules

### ❌ Forbidden Patterns

#### 1. Systems Accessing Scenes Directly
```gdscript
# ❌ VIOLATION: Systems cannot use get_node() to access parent scenes
func _on_enemy_killed():
    get_node("../../UI/HUD").update_score(10)  # FORBIDDEN
```

**Fix**: Use signals instead
```gdscript
# ✅ CORRECT: Use EventBus for communication
func _on_enemy_killed():
    EventBus.score_updated.emit(10)
```

#### 2. Domain Models Using EventBus
```gdscript
# ❌ VIOLATION: Domain models must be pure data
class_name PlayerStats
func level_up():
    EventBus.level_up.emit(level)  # FORBIDDEN
```

**Fix**: Keep domain pure, let systems handle events
```gdscript
# ✅ CORRECT: Pure data model
class_name PlayerStats
func get_next_level_xp() -> int:
    return level * 100  # Pure calculation only
```

#### 3. Scenes Importing Domain Directly
```gdscript
# ❌ VIOLATION: Scenes should not bypass systems
const PlayerStats = preload("res://scripts/domain/PlayerStats.gd")  # FORBIDDEN
```

**Fix**: Access domain through systems
```gdscript
# ✅ CORRECT: Access via systems
@onready var player_system: PlayerSystem = PlayerSystem.new()
func _ready():
    var stats = player_system.get_player_stats()
```

#### 4. Circular Dependencies
```gdscript
# ❌ VIOLATION: Systems depending on scenes
const Arena = preload("res://scenes/arena/Arena.tscn")  # FORBIDDEN
```

### ✅ Allowed Patterns

#### Signal-Based Communication
```gdscript
# ✅ Systems emit to EventBus
EventBus.damage_requested.emit(source_id, target_id, damage, ["fire"])

# ✅ Scenes listen to EventBus
EventBus.health_changed.connect(_on_health_changed)
```

#### Dependency Injection
```gdscript
# ✅ Pass systems to scenes via constructor/setup
func setup_arena(ability_system: AbilitySystem):
    self.ability_system = ability_system
```

#### Pure Domain Helpers
```gdscript
# ✅ Domain models as pure utilities
class_name DamageCalculator
static func calculate_crit_damage(base: float, crit_mult: float) -> float:
    return base * crit_mult
```

## Validation Tools

### 1. Automated Test (`tests/test_architecture_boundaries.gd`)
Runs automatically in CI and pre-commit hooks to detect violations.

```bash
# Run manually
cd vibe
../godot --headless --script tests/test_architecture_boundaries.gd
```

### 2. Static Analysis Tool (`tools/check_boundaries.gd`)
Provides detailed dependency analysis and violation reports.

```bash
# Run from Godot Editor: Tools > Execute Script > check_boundaries.gd
```

### 3. Pre-commit Hook (`.git/hooks/pre-commit`)
Automatically runs validation before each commit.

```bash
# Bypass if needed (NOT RECOMMENDED)
git commit --no-verify
```

### 4. CI Pipeline (`.github/workflows/architecture-check.yml`)
Runs on all PRs and provides detailed violation reports.

## Common Violation Types

### `SYSTEMS_NO_SCENE_ACCESS`
**Problem**: System using `get_node()` to access parent scenes  
**Fix**: Use signals or dependency injection

### `DOMAIN_NO_EVENTBUS`  
**Problem**: Domain model using EventBus  
**Fix**: Move event emission to systems layer

### `SCENES_NO_DIRECT_DOMAIN`
**Problem**: Scene importing domain models directly  
**Fix**: Access domain through systems

### `FORBIDDEN_LAYER_IMPORT`
**Problem**: Layer importing from forbidden layer  
**Fix**: Restructure to follow proper dependency flow

## Debugging Violations

### 1. Check the Violation Report
```
[SYSTEMS_NO_SCENE_ACCESS] scripts/systems/AbilitySystem.gd:45
  Systems must not use get_node() to access parent scenes. Use signals instead.
```

### 2. Review Layer Rules
- Identify which layer the file belongs to
- Check what that layer is allowed to import/call
- Restructure code to follow proper boundaries

### 3. Use Allowed Alternatives
- **Instead of get_node()**: Use signals via EventBus
- **Instead of direct imports**: Use dependency injection
- **Instead of tight coupling**: Use loose coupling via signals

## Benefits of Enforcement

### 🧪 **Testability**
Clean boundaries make unit testing possible by eliminating tight coupling.

### 🔧 **Maintainability**  
Clear separation of concerns makes code easier to understand and modify.

### 👥 **Team Scaling**
Automated enforcement prevents architecture decay as team grows.

### 🔄 **Refactoring Safety**
Well-defined boundaries make large refactoring operations safer.

### 📈 **Code Quality**
Enforced patterns lead to more consistent, predictable code.

## Overrides and Exceptions

### Temporary Bypasses
If you must temporarily bypass enforcement (rare cases):

```gdscript
# Add comment to bypass specific checks
get_node("../Player")  # allowed: legacy code migration
```

### Permanent Exceptions
Update the validation rules in `test_architecture_boundaries.gd` if legitimate exceptions are needed.

## Related Documentation

- [ARCHITECTURE.md](../../ARCHITECTURE.md) - Overall system design
- [CLAUDE.md](../../CLAUDE.md) - Development guidelines  
- [EventBus System](../../Obsidian/systems/EventBus-System.md) - Signal patterns