# Domain Layer - CLAUDE.md
> Context-specific documentation for scripts/domain/ - Pure data models & typed classes

**Parent Documentation:** [Main CLAUDE.md](../../CLAUDE.md) | **Layer:** Pure Data Models

## Quick Reference

| Domain Type | Purpose | Key Properties | Usage Pattern |
|-------------|---------|----------------|---------------|
| **EnemyEntity.gd** | Enemy data wrapper | `pos`, `hp`, `alive`, `type_id` | WaveDirector ↔ Systems |
| **Signal Payloads/** | Typed EventBus contracts | Per-signal typed data | EventBus communication |
| **ArenaConfig.gd** | Arena spatial properties | `bounds`, `spawn_radius`, `center` | @export hot-reload |
| **CharacterType.gd** | Player character definitions | `move_speed`, `max_health` | Character creation |
| **EnemyType.gd** | Enemy template definitions | `hp`, `speed`, `spawn_weight` | Enemy spawning |
| **CombatBalance.gd** | Combat parameter config | `damage_multiplier`, `crit_chance` | BalanceDB |

## Domain Architecture Patterns

### 🏗️ **Pure Data Model Rules**

**Domain Layer Constraints:**
```gdscript
# ✅ Domain classes should be pure data
extends Resource  # or RefCounted for payloads
class_name DomainModel

# ✅ Typed properties with validation
@export var health: float = 100.0:
    set(value):
        health = max(0.0, value)  # Simple validation

# ✅ Helper methods for data access
func is_alive() -> bool:
    return health > 0.0

# ❌ Never reference scenes, systems, or autoloads
# ❌ Never use get_node(), EventBus, or system calls
# ❌ Never handle game logic - only data
```

### 📡 **Signal Payload Architecture**

**Typed EventBus Contracts:**
```gdscript
# All signal payloads extend RefCounted
extends RefCounted
class_name SignalPayload

# Required properties for the signal
var entity_id: String
var damage_amount: float
var damage_types: Array[String]

# Constructor for easy creation
func _init(id: String, damage: float, types: Array[String] = []) -> void:
    entity_id = id
    damage_amount = damage
    damage_types = types

# Debug representation
func _to_string() -> String:
    return "SignalPayload(id=%s, damage=%s)" % [entity_id, damage_amount]
```

**EventBus Integration:**
```gdscript
# EventBus preloads all payload types
const DamageDealtPayload_Type = preload("res://scripts/domain/signal_payloads/DamageDealtPayload.gd")

# Systems create and emit typed payloads
func deal_damage(target_id: String, amount: float) -> void:
    var payload = EventBus.DamageDealtPayload_Type.new(target_id, amount, ["physical"])
    EventBus.damage_dealt.emit(payload)

# Systems receive typed payloads
func _on_damage_dealt(payload: EventBus.DamageDealtPayload_Type) -> void:
    Logger.info("Damage dealt: {amount}".format({"amount": payload.damage_amount}))
```

### 🎮 **Entity Data Patterns**

**EnemyEntity Dual-Mode:**
```gdscript
# Dictionary-based for performance (shared data)
var enemy = EnemyEntity.new()
enemy._data_ref = shared_enemy_dict  # References WaveDirector data
enemy.index = 5  # O(1) lookup optimization

# Individual variables for standalone use
var standalone_enemy = EnemyEntity.new()
standalone_enemy.pos = Vector2(100, 200)
standalone_enemy.hp = 50.0

# Transparent property access in both modes
enemy.pos = Vector2(50, 100)  # Updates _data_ref or individual vars
var current_hp = enemy.hp     # Reads from _data_ref or individual vars
```

**Entity Factory Pattern:**
```gdscript
# EnemyFactory creates entities from templates
static func create_enemy(type_id: String, position: Vector2) -> EnemyEntity:
    var template = ContentDB.get_enemy_template(type_id)
    var enemy = EnemyEntity.new()

    enemy.type_id = type_id
    enemy.pos = position
    enemy.max_hp = template.base_hp
    enemy.hp = template.base_hp
    enemy.speed = template.move_speed

    return enemy
```

### 📊 **Configuration Resource Patterns**

**@export Hot-Reload Pattern:**
```gdscript
# Scene-based configurations use @export for automatic hot-reload
extends Resource
class_name ArenaConfig

@export var bounds: Rect2 = Rect2(-400, -300, 800, 600)
@export var spawn_zones: Array[Dictionary] = []
@export var boss_positions: Array[Vector2] = []

# Inspector-friendly arrays
@export var spawn_zone_configs: Array[SpawnZoneConfig] = []

# Validation methods
func validate() -> bool:
    return bounds.size.x > 0 and bounds.size.y > 0

# Helper methods for systems
func get_random_spawn_zone() -> Dictionary:
    if spawn_zones.is_empty():
        return {}
    return spawn_zones[randi() % spawn_zones.size()]
```

**BalanceDB Resource Pattern:**
```gdscript
# Autoload-based configurations for hot-reload via file monitoring
extends Resource
class_name CombatBalance

@export var base_damage: float = 25.0
@export var crit_chance: float = 0.1
@export var damage_multiplier: float = 1.0

# Schema validation for safe loading
func validate() -> Array[String]:
    var errors: Array[String] = []

    if base_damage <= 0:
        errors.append("base_damage must be positive")
    if crit_chance < 0 or crit_chance > 1:
        errors.append("crit_chance must be 0.0-1.0")

    return errors

# Type-safe getters for systems
func get_effective_damage(base: float) -> float:
    return base * damage_multiplier
```

## Domain Type Relationships

### 🔗 **Data Flow Architecture**

```
Configuration Resources:
├── ArenaConfig.tres     → ArenaSystem (@export)
├── CharacterType.tres   → CharacterManager
├── EnemyType.tres       → SpawnDirector
└── CombatBalance.tres   → BalanceDB → Systems

Entity Models:
├── EnemyEntity         ← Created by EnemyFactory
│   └── _data_ref       ← Points to WaveDirector data
├── PlayerEntity        ← Managed by PlayerState
└── ProjectileEntity    ← Future AbilityModule

Signal Contracts:
├── CombatStepPayload   ← RunManager → All Systems
├── DamageDealtPayload  ← Systems → XpSystem, UI
├── EnemyKilledPayload  ← SpawnDirector → XpSystem
└── 11 other payloads   ← Cross-system communication
```

### 🎯 **Template System Architecture**

**Enemy Template Hierarchy:**
```gdscript
# EnemyType.gd - Base template
base_hp: 100.0
move_speed: 80.0
spawn_weight: 1.0
is_special_boss: false

# EnemyTemplate.gd - Specific enemy instance config
extends EnemyType
enemy_id: "ancient_lich"
boss_scene: "res://scenes/bosses/AncientLich.tscn"
spawn_weight: 0.0  # Special bosses don't auto-spawn

# Usage in systems
var template = ContentDB.get_enemy_template("ancient_lich")
var enemy = EnemyFactory.create_from_template(template, spawn_pos)
```

## Data Validation Patterns

### ✅ **Schema Validation**

**Resource Validation:**
```gdscript
# All configuration resources should validate
func validate() -> Array[String]:
    var errors: Array[String] = []

    # Type validation
    if not (base_damage is float):
        errors.append("base_damage must be float")

    # Range validation
    if base_damage <= 0.0:
        errors.append("base_damage must be positive")

    # Required field validation
    if arena_id.is_empty():
        errors.append("arena_id is required")

    return errors

# Usage in loaders
func load_config(path: String) -> ArenaConfig:
    var config = ResourceLoader.load(path) as ArenaConfig
    var errors = config.validate()

    if not errors.is_empty():
        Logger.warn("Config validation failed: {errors}".format({"errors": errors}))
        return _get_default_config()

    return config
```

### 🔒 **Type Safety Patterns**

**Strict Typing:**
```gdscript
# Use specific types, not generic Dictionary/Array
var enemies: Array[EnemyEntity] = []           # ✓
var spawn_zones: Array[SpawnZoneConfig] = []   # ✓
var positions: Array[Vector2] = []             # ✓

# Avoid generic containers
var data: Dictionary = {}                      # ❌
var items: Array = []                          # ❌

# Type-safe property setters
var health: float = 100.0:
    set(value):
        if value < 0.0:
            Logger.warn("Negative health not allowed")
            return
        health = value
```

## Performance Considerations

### ⚡ **Memory Optimization**

**Shared Data References:**
```gdscript
# EnemyEntity can reference shared Dictionary data
var enemies_data: Array[Dictionary] = []  # WaveDirector storage
var enemy_entities: Array[EnemyEntity] = []

# Create wrapper entities that reference shared data
for i in range(enemies_data.size()):
    var entity = EnemyEntity.new()
    entity._data_ref = enemies_data[i]  # No data duplication
    entity.index = i  # O(1) lookup
    enemy_entities.append(entity)
```

**Object Pool for Payloads:**
```gdscript
# EventBus uses object pools for high-frequency payloads
var _damage_payload_pool: ObjectPool

func emit_damage_dealt(target_id: String, damage: float) -> void:
    var payload = _damage_payload_pool.get_object()
    payload.entity_id = target_id
    payload.damage_amount = damage

    damage_dealt.emit(payload)

    # Return to pool after signal processing
    call_deferred("_return_payload", payload)
```

### 🔄 **Hot-Reload Performance**

**Efficient Resource Loading:**
```gdscript
# Use CACHE_MODE_IGNORE for development hot-reload
func reload_balance_data() -> void:
    var balance = ResourceLoader.load(
        "res://data/balance/combat.tres",
        "",
        ResourceLoader.CACHE_MODE_IGNORE
    ) as CombatBalance

    # Validate before applying
    var errors = balance.validate()
    if errors.is_empty():
        _apply_balance_data(balance)
```

## Troubleshooting Guide

### 🚨 **Common Issues**

1. **"Invalid property" errors:** Check typed property setters and validation
2. **Null reference exceptions:** Verify resource loading and validation
3. **Signal payload errors:** Ensure payload classes match EventBus types
4. **Hot-reload not working:** Check @export vs BalanceDB patterns
5. **Memory leaks:** Verify EnemyEntity._data_ref usage

### 🔧 **Debug Patterns**

```gdscript
# Domain layer debug logging
Logger.debug("EnemyEntity created: {entity}".format({"entity": entity._to_string()}), "domain")
Logger.debug("Config validation: {errors}".format({"errors": validation_errors}), "config")

# Payload debugging
func _to_string() -> String:
    return "PayloadName(key1=%s, key2=%s)" % [property1, property2]
```

### 🎬 **Tween Callback Patterns (Added 2025-10-07)**

**Safe Tween Callbacks with Object References:**
```gdscript
# ❌ Wrong: Binding object references directly causes errors if object is freed
tween.finished.connect(_on_tween_finished.bind(sprite, material))

# ✅ Correct: Use instance IDs + metadata for safe object access
var sprite_id = sprite.get_instance_id()
sprite.set_meta("_cleanup_data", cleanup_value)
tween.finished.connect(_on_tween_finished.bind(sprite_id))

static func _on_tween_finished(sprite_id: int) -> void:
    var sprite = instance_from_id(sprite_id) as AnimatedSprite2D
    if sprite and is_instance_valid(sprite):
        var cleanup_data = sprite.get_meta("_cleanup_data", null)
        if cleanup_data != null:
            # Safe cleanup
            sprite.material = cleanup_data
            sprite.remove_meta("_cleanup_data")
```

**Avoiding Lambda Capture in Tweens:**
```gdscript
# ❌ Wrong: Lambda captures local variables that go out of scope
var local_material = shader_material.duplicate()
tween.tween_method(
    func(value: float):
        local_material.set_shader_parameter("progress", value),
    0.0, 1.0, duration
)

# ✅ Correct: Use tween_property() for direct shader parameter animation
var material_instance = shader_material.duplicate()
sprite.material = material_instance
tween.tween_property(material_instance, "shader_parameter/progress", 1.0, duration).from(0.0)
```

**Pattern Summary:**
- Use `tween_property()` for shader animations (no lambda needed)
- Bind instance IDs instead of object references to callbacks
- Store cleanup data in metadata instead of lambda capture
- Always check `is_instance_valid()` in callbacks

### 📊 **Architecture Validation**

Domain layer rules:
- ✅ **Pure data models** - no game logic, no scene references
- ✅ **Typed properties** - use specific types, not generic Dictionary
- ✅ **Validation methods** - validate() returns Array[String] of errors
- ✅ **Safe tween patterns** - use instance IDs + metadata, avoid lambda capture
- ❌ **Must not reference:** Autoloads, systems, scenes, EventBus
- ❌ **Must not contain:** Game logic, UI code, file I/O

## Migration Notes

When creating new domain models:
1. **Extend Resource** for configuration data, RefCounted for payloads
2. **Add validation()** method for all configuration classes
3. **Use typed properties** with setters for validation
4. **Create _to_string()** method for debugging
5. **Document relationships** in this file
6. **Test hot-reload** behavior for configuration resources

---
**See Also:** [System Integration](../systems/CLAUDE.md) | [Resource Patterns](../../data/README.md) | [Signal Architecture](../../autoload/CLAUDE.md)