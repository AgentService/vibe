extends CharacterBody2D

## DragonLord special boss - example scene-based enemy
## Demonstrates hybrid spawning system with complex boss behavior
## Emits "died" signal for integration with WaveDirector

signal died

var max_health: float = 200.0
var current_health: float = 200.0
var speed: float = 80.0
var attack_damage: float = 50.0
var attack_cooldown: float = 2.0
var last_attack_time: float = 0.0

# AI state
var target_position: Vector2
var attack_range: float = 100.0
var chase_range: float = 400.0

func _ready() -> void:
	Logger.info("DragonLord boss spawned with " + str(max_health) + " HP", "bosses")
	
	# Start the animation
	var animated_sprite = $CollisionShape/AnimatedSprite2D
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("default")  # Start playing the default animation
		Logger.debug("Dragon Lord animation started", "bosses")
	
	# Connect to combat step for deterministic behavior
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)
	
	# DAMAGE V2: Register with DamageService
	var entity_id = "boss_" + str(get_instance_id())
	var entity_data = {
		"id": entity_id,
		"type": "boss",
		"hp": current_health,
		"max_hp": max_health,
		"alive": true,
		"pos": global_position
	}
	DamageService.register_entity(entity_id, entity_data)
	Logger.debug("DragonLord registered with DamageService as " + entity_id, "bosses")

func _exit_tree() -> void:
	# Clean up signal connections
	if EventBus and EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	
	# DAMAGE V2: Unregister from DamageService
	var entity_id = "boss_" + str(get_instance_id())
	DamageService.unregister_entity(entity_id)

func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	_update_ai(dt)
	last_attack_time += dt

func _update_ai(dt: float) -> void:
	# Get player position from PlayerState
	if not PlayerState.has_player_reference():
		return
		
	target_position = PlayerState.position
	var distance_to_player: float = global_position.distance_to(target_position)
	
	# Chase behavior when player is in range
	if distance_to_player <= chase_range:
		if distance_to_player > attack_range:
			# Move toward player
			var direction: Vector2 = (target_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
		else:
			# In attack range - stop and attack
			velocity = Vector2.ZERO
			if last_attack_time >= attack_cooldown:
				_perform_attack()
				last_attack_time = 0.0

func _perform_attack() -> void:
	Logger.info("DragonLord attacks for " + str(attack_damage) + " damage!", "bosses")
	
	# Emit damage to player if in range
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		# DAMAGE V2: Use DamageService for player damage (when implemented)
		# For now, use old EventBus.damage_taken signal for player damage
		if EventBus:
			EventBus.damage_taken.emit(attack_damage)

# DAMAGE V2: take_damage() method removed - damage handled via DamageService
# Bosses register with DamageService in _ready() and receive damage via unified pipeline

func _die() -> void:
	Logger.info("DragonLord has been defeated!", "bosses")
	died.emit()  # Signal for WaveDirector to handle XP/loot
	queue_free()  # Remove from scene

# Public interface for damage system integration
func get_max_health() -> float:
	return max_health

func get_current_health() -> float:
	return current_health

func set_current_health(new_health: float) -> void:
	current_health = new_health

func is_alive() -> bool:
	return current_health > 0.0
