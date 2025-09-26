# Bullet Upgrade System - Strategy Pattern Implementation - 2025-09-26

## 🎯 Overview

This guide outlines implementing a flexible bullet upgrade system using the Strategy Pattern, integrated with the existing vibe game architecture. The system allows modular, data-driven upgrades that can be combined and reused across different abilities.

## 🏗️ Architecture Integration

### Existing System Alignment
- **Resource-based configuration** - Follows `/data/content/` patterns
- **EventBus communication** - Integrates with damage and combat systems
- **Typed GDScript** - Maintains project type safety standards
- **Logger integration** - Uses centralized logging system

### File Structure
```
scripts/resources/
├── BaseBulletStrategy.gd          # Base strategy interface
├── strategies/
│   ├── DamageBulletStrategy.gd    # Damage modification
│   ├── SpeedBulletStrategy.gd     # Speed modification
│   ├── PierceBulletStrategy.gd    # Piercing behavior
│   └── ParticleBulletStrategy.gd  # Visual effects
data/content/bullet-upgrades/
├── damage_boost.tres              # Configured upgrade instances
├── speed_boost.tres
└── pierce_upgrade.tres
```

## 📋 Implementation Plan

### Phase 1: Base Strategy System
1. Create `BaseBulletStrategy` Resource class
2. Define upgrade application interface
3. Add upgrade metadata (name, icon, description)

### Phase 2: Core Upgrade Types
1. Damage modification strategy
2. Speed modification strategy
3. Piercing behavior strategy
4. Multi-shot strategy

### Phase 3: Player Integration
1. Upgrade collection system
2. Bullet modification pipeline
3. EventBus integration for upgrade events

### Phase 4: Pickup System
1. Upgrade pickup areas
2. Resource-based configuration
3. UI feedback integration

## 🔧 Technical Implementation

### Base Strategy Resource

```gdscript
# scripts/resources/BaseBulletStrategy.gd
@tool
class_name BaseBulletStrategy
extends Resource

## Base class for bullet upgrade strategies using Strategy Pattern
## Provides modular, reusable bullet modifications

@export var upgrade_id: String = ""
@export var upgrade_name: String = ""
@export var upgrade_description: String = ""
@export var upgrade_icon: Texture2D
@export var stack_limit: int = 1  # How many times this can be applied
@export var rarity: int = 1       # 1=Common, 2=Rare, 3=Epic, 4=Legendary

func apply_upgrade(bullet: Node2D, context: Dictionary = {}) -> void:
	"""Override this method to implement upgrade behavior"""
	Logger.warn("BaseBulletStrategy.apply_upgrade() not implemented", "abilities")

func can_apply_to_bullet(bullet: Node2D) -> bool:
	"""Override to add conditional upgrade logic"""
	return true

func get_upgrade_summary() -> String:
	"""Return human-readable upgrade effect description"""
	return upgrade_description
```

### Damage Strategy Example

```gdscript
# scripts/resources/strategies/DamageBulletStrategy.gd
@tool
class_name DamageBulletStrategy
extends BaseBulletStrategy

@export var damage_increase: float = 5.0
@export var damage_multiplier: float = 1.0
@export var damage_type_modifier: String = ""  # "fire", "ice", "poison"

func apply_upgrade(bullet: Node2D, context: Dictionary = {}) -> void:
	if not bullet.has_method("modify_damage"):
		Logger.warn("Bullet missing modify_damage method for DamageBulletStrategy", "abilities")
		return

	# Apply flat damage increase
	if damage_increase > 0:
		bullet.modify_damage(damage_increase, "flat")
		Logger.debug("Applied +%s damage to bullet" % damage_increase, "abilities")

	# Apply multiplicative damage
	if damage_multiplier != 1.0:
		bullet.modify_damage(damage_multiplier, "multiply")
		Logger.debug("Applied x%s damage multiplier to bullet" % damage_multiplier, "abilities")

	# Add damage type
	if not damage_type_modifier.is_empty():
		bullet.add_damage_type(damage_type_modifier)
		Logger.debug("Added %s damage type to bullet" % damage_type_modifier, "abilities")

func get_upgrade_summary() -> String:
	var parts: Array[String] = []
	if damage_increase > 0:
		parts.append("+%s damage" % damage_increase)
	if damage_multiplier != 1.0:
		parts.append("x%s damage" % damage_multiplier)
	if not damage_type_modifier.is_empty():
		parts.append("Adds %s damage" % damage_type_modifier)
	return " | ".join(parts)
```

### Speed Strategy Example

```gdscript
# scripts/resources/strategies/SpeedBulletStrategy.gd
@tool
class_name SpeedBulletStrategy
extends BaseBulletStrategy

@export var speed_increase: float = 100.0
@export var speed_multiplier: float = 1.0

func apply_upgrade(bullet: Node2D, context: Dictionary = {}) -> void:
	if not bullet.has_method("modify_speed"):
		Logger.warn("Bullet missing modify_speed method for SpeedBulletStrategy", "abilities")
		return

	if speed_increase > 0:
		bullet.modify_speed(speed_increase, "flat")

	if speed_multiplier != 1.0:
		bullet.modify_speed(speed_multiplier, "multiply")

	Logger.debug("Applied speed upgrade: +%s, x%s" % [speed_increase, speed_multiplier], "abilities")

func get_upgrade_summary() -> String:
	var parts: Array[String] = []
	if speed_increase > 0:
		parts.append("+%s speed" % speed_increase)
	if speed_multiplier != 1.0:
		parts.append("x%s speed" % speed_multiplier)
	return " | ".join(parts)
```

### Player Integration

```gdscript
# Addition to existing Player class
class_name Player
extends CharacterBody2D

# Bullet upgrade system
var bullet_upgrades: Array[BaseBulletStrategy] = []
var upgrade_counts: Dictionary = {}  # track stacking

func add_bullet_upgrade(strategy: BaseBulletStrategy) -> bool:
	"""Add a bullet upgrade strategy with stack limit checking"""

	var current_count = upgrade_counts.get(strategy.upgrade_id, 0)
	if current_count >= strategy.stack_limit:
		Logger.info("Upgrade %s at stack limit (%s)" % [strategy.upgrade_name, strategy.stack_limit], "abilities")
		return false

	bullet_upgrades.append(strategy)
	upgrade_counts[strategy.upgrade_id] = current_count + 1

	Logger.info("Added bullet upgrade: %s (stack %s/%s)" % [strategy.upgrade_name, current_count + 1, strategy.stack_limit], "abilities")
	EventBus.player_upgrade_acquired.emit(strategy.upgrade_id, strategy.upgrade_name)

	return true

func apply_bullet_upgrades(bullet: Node2D) -> void:
	"""Apply all collected upgrades to a newly created bullet"""

	var upgrade_context = {
		"player": self,
		"bullet_count": bullet_upgrades.size()
	}

	for strategy in bullet_upgrades:
		if strategy.can_apply_to_bullet(bullet):
			strategy.apply_upgrade(bullet, upgrade_context)
		else:
			Logger.debug("Skipped upgrade %s for bullet (conditions not met)" % strategy.upgrade_name, "abilities")

# Modified shooting method
func shoot() -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	# Apply all upgrades before bullet starts moving
	apply_bullet_upgrades(bullet)

	# Configure bullet position and direction
	bullet.global_position = global_position
	bullet.direction = get_aim_direction()
```

### Enhanced Bullet Base Class

```gdscript
# scripts/systems/Bullet.gd enhancement
class_name Bullet
extends Node2D

@export var base_damage: float = 10.0
@export var base_speed: float = 500.0
var current_damage: float
var current_speed: float
var damage_types: Array[String] = []
var can_pierce: bool = false
var pierce_count: int = 0

func _ready() -> void:
	current_damage = base_damage
	current_speed = base_speed

func modify_damage(value: float, operation: String = "flat") -> void:
	"""Modify bullet damage with different operations"""
	match operation:
		"flat":
			current_damage += value
		"multiply":
			current_damage *= value
		"set":
			current_damage = value

	Logger.debug("Bullet damage modified: %s -> %s" % [base_damage, current_damage], "abilities")

func modify_speed(value: float, operation: String = "flat") -> void:
	"""Modify bullet speed with different operations"""
	match operation:
		"flat":
			current_speed += value
		"multiply":
			current_speed *= value
		"set":
			current_speed = value

func add_damage_type(damage_type: String) -> void:
	"""Add a damage type to this bullet"""
	if damage_type not in damage_types:
		damage_types.append(damage_type)

func enable_piercing(max_pierce: int = 1) -> void:
	"""Enable bullet piercing with specified count"""
	can_pierce = true
	pierce_count = max_pierce
```

### Upgrade Pickup System

```gdscript
# scripts/systems/UpgradePickup.gd
class_name UpgradePickup
extends Area2D

@export var upgrade_strategy: BaseBulletStrategy
@export var pickup_effect: PackedScene
@export var auto_pickup_radius: float = 50.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if upgrade_strategy:
		# Update visual representation
		_update_pickup_visual()

func _update_pickup_visual() -> void:
	"""Update sprite and UI based on upgrade strategy"""
	var sprite = $Sprite2D as Sprite2D
	if sprite and upgrade_strategy.upgrade_icon:
		sprite.texture = upgrade_strategy.upgrade_icon

	var label = $Label as Label
	if label:
		label.text = upgrade_strategy.upgrade_name

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var player = body as Player
	if not player:
		return

	if player.add_bullet_upgrade(upgrade_strategy):
		_trigger_pickup_effect()
		EventBus.upgrade_collected.emit(upgrade_strategy.upgrade_id, global_position)
		queue_free()
	else:
		Logger.info("Player couldn't acquire upgrade %s (stack limit or conditions)" % upgrade_strategy.upgrade_name, "abilities")

func _trigger_pickup_effect() -> void:
	"""Spawn pickup effect and play sound"""
	if pickup_effect:
		var effect = pickup_effect.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
```

## 📊 Resource Configuration Examples

### Damage Upgrade Resource
```tres
# data/content/bullet-upgrades/damage_boost.tres
[gd_resource type="Resource" script_class="DamageBulletStrategy" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/strategies/DamageBulletStrategy.gd" id="1"]

[resource]
script = ExtResource("1")
upgrade_id = "damage_boost_basic"
upgrade_name = "Damage Boost"
upgrade_description = "Increases bullet damage by 5"
upgrade_icon = preload("res://assets/ui/icons/damage_icon.png")
stack_limit = 5
rarity = 1
damage_increase = 5.0
damage_multiplier = 1.0
damage_type_modifier = ""
```

### Pierce Upgrade Resource
```tres
# data/content/bullet-upgrades/pierce_upgrade.tres
[gd_resource type="Resource" script_class="PierceBulletStrategy" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/strategies/PierceBulletStrategy.gd" id="1"]

[resource]
script = ExtResource("1")
upgrade_id = "pierce_basic"
upgrade_name = "Piercing Shot"
upgrade_description = "Bullets pass through 2 enemies"
upgrade_icon = preload("res://assets/ui/icons/pierce_icon.png")
stack_limit = 3
rarity = 2
max_pierce_count = 2
```

## 🔗 EventBus Integration

### New Signals Required
```gdscript
# Addition to EventBus.gd
signal player_upgrade_acquired(upgrade_id: String, upgrade_name: String)
signal upgrade_collected(upgrade_id: String, position: Vector2)
signal bullet_upgrade_applied(bullet_id: String, upgrade_id: String)
```

## 🧪 Testing Strategy

### Unit Tests
```gdscript
# tests/test_bullet_upgrades.gd
extends SceneTree

func test_damage_upgrade_stacking():
	var bullet = preload("res://scenes/bullets/BasicBullet.tscn").instantiate()
	var damage_upgrade = preload("res://data/content/bullet-upgrades/damage_boost.tres")

	var initial_damage = bullet.current_damage

	damage_upgrade.apply_upgrade(bullet)
	damage_upgrade.apply_upgrade(bullet)

	assert(bullet.current_damage == initial_damage + (damage_upgrade.damage_increase * 2))
	print("✅ Damage stacking test passed")

func test_strategy_validation():
	var speed_upgrade = preload("res://data/content/bullet-upgrades/speed_boost.tres")
	var bullet_without_speed = Node2D.new()

	# Should handle missing methods gracefully
	speed_upgrade.apply_upgrade(bullet_without_speed)
	print("✅ Strategy validation test passed")
```

## 🎨 UI Integration

### Upgrade Display Component
```gdscript
# scenes/ui/components/UpgradeDisplay.gd
class_name UpgradeDisplay
extends Control

@onready var upgrade_grid: GridContainer = $UpgradeGrid
@onready var upgrade_icon_scene: PackedScene = preload("res://scenes/ui/components/UpgradeIcon.tscn")

func update_upgrades(upgrades: Array[BaseBulletStrategy], counts: Dictionary) -> void:
	"""Update display with current player upgrades"""

	# Clear existing icons
	for child in upgrade_grid.get_children():
		child.queue_free()

	# Group upgrades by ID
	var grouped_upgrades: Dictionary = {}
	for upgrade in upgrades:
		if upgrade.upgrade_id not in grouped_upgrades:
			grouped_upgrades[upgrade.upgrade_id] = {
				"strategy": upgrade,
				"count": 0
			}
		grouped_upgrades[upgrade.upgrade_id].count += 1

	# Create UI icons
	for upgrade_id in grouped_upgrades.keys():
		var upgrade_data = grouped_upgrades[upgrade_id]
		var strategy = upgrade_data.strategy as BaseBulletStrategy
		var count = upgrade_data.count

		var icon = upgrade_icon_scene.instantiate() as UpgradeIcon
		upgrade_grid.add_child(icon)
		icon.setup_upgrade(strategy, count)
```

## 🚀 Performance Considerations

### Optimization Strategies
- **Object pooling** for upgrade effects
- **Cached upgrade calculations** for identical bullets
- **Lazy evaluation** of upgrade conditions
- **Batch upgrade application** for multi-shot abilities

### Memory Management
- **Resource reuse** - Same upgrade strategy instances across pickups
- **Weak references** in upgrade context to avoid cycles
- **Cleanup tracking** for temporary upgrade effects

## 📋 Implementation Checklist

### Core System
- [ ] Create BaseBulletStrategy resource class
- [ ] Implement damage upgrade strategy
- [ ] Implement speed upgrade strategy
- [ ] Implement pierce upgrade strategy
- [ ] Add player upgrade collection system
- [ ] Create bullet modification pipeline

### Integration
- [ ] Add EventBus signals for upgrade events
- [ ] Integrate with Logger system
- [ ] Create upgrade pickup areas
- [ ] Add UI upgrade display component
- [ ] Configure example upgrade resources

### Testing
- [ ] Create unit tests for upgrade stacking
- [ ] Test upgrade combination scenarios
- [ ] Validate resource configuration loading
- [ ] Performance test with many upgrades

### Documentation
- [ ] Update ability system architecture docs
- [ ] Create upgrade configuration guide
- [ ] Document upgrade creation workflow
- [ ] Add troubleshooting guide

## 🔮 Future Extensions

### Advanced Upgrade Types
- **Conditional upgrades** - Triggered by specific events
- **Temporary upgrades** - Duration-based effects
- **Upgrade evolution** - Upgrades that transform based on conditions
- **Upgrade synergies** - Combinations that unlock new effects

### System Enhancements
- **Upgrade trees** - Prerequisites and unlock paths
- **Upgrade crafting** - Combine basic upgrades into advanced ones
- **Upgrade trading** - Multiplayer upgrade exchange
- **Upgrade persistence** - Save/load upgrade collections

---

**Status**: 📋 **DESIGN COMPLETE**
**Next Phase**: Implementation of base strategy system
**Integration Ready**: Aligns with existing project architecture
**Last Updated**: 2025-09-26