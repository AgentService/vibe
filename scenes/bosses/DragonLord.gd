extends CharacterBody2D

## DragonLord special boss - example scene-based enemy
## Demonstrates hybrid spawning system with complex boss behavior
## Emits "died" signal for integration with WaveDirector

signal died

@onready var health_bar: BossHealthBar = $BossHealthBar

var spawn_config: SpawnConfig
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
var ai_paused: bool = false  # Debug AI pause state

func _ready() -> void:
	Logger.info("DragonLord boss spawned with " + str(max_health) + " HP", "bosses")
	
	# Start the animation
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("default")  # Start playing the default animation
		Logger.debug("Dragon Lord animation started", "bosses")
	
	# Connect to combat step for deterministic behavior
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)
		# Listen for unified damage sync events
		EventBus.damage_entity_sync.connect(_on_damage_entity_sync)
		# DEBUG: Listen for cheat toggles (AI pause)
		EventBus.cheat_toggled.connect(_on_cheat_toggled)
	
	# Register with both DamageService and EntityTracker
	var entity_id = "boss_" + str(get_instance_id())
	var entity_data = {
		"id": entity_id,
		"type": "boss",
		"hp": current_health,
		"max_hp": max_health,
		"alive": true,
		"pos": global_position
	}
	
	# Register with both systems for unified damage V3
	DamageService.register_entity(entity_id, entity_data)
	EntityTracker.register_entity(entity_id, entity_data)
	Logger.debug("DragonLord registered with DamageService and EntityTracker as " + entity_id, "bosses")
	
	# Initialize health bar
	_update_health_bar()

func _exit_tree() -> void:
	# Clean up signal connections
	if EventBus and EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if EventBus and EventBus.damage_entity_sync.is_connected(_on_damage_entity_sync):
		EventBus.damage_entity_sync.disconnect(_on_damage_entity_sync)
	if EventBus and EventBus.cheat_toggled.is_connected(_on_cheat_toggled):
		EventBus.cheat_toggled.disconnect(_on_cheat_toggled)
	
	# Unregister from both systems
	var entity_id = "boss_" + str(get_instance_id())
	DamageService.unregister_entity(entity_id)
	EntityTracker.unregister_entity(entity_id)

func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	_update_ai(dt)
	last_attack_time += dt

## Handle unified damage sync events for scene bosses
func _on_damage_entity_sync(payload: Dictionary) -> void:
	var entity_id: String = payload.get("entity_id", "")
	var entity_type: String = payload.get("entity_type", "")
	var new_hp: float = payload.get("new_hp", 0.0)
	var is_death: bool = payload.get("is_death", false)
	
	# Only handle boss entities matching this instance
	if entity_type != "boss":
		return
	
	var expected_entity_id = "boss_" + str(get_instance_id())
	if entity_id != expected_entity_id:
		return  # Not for this boss
	
	# Update boss HP
	current_health = new_hp
	_update_health_bar()
	
	# Handle death
	if is_death:
		Logger.info("Boss %s killed via damage sync" % [entity_id], "combat")
		_die()
	else:
		# Update EntityTracker health data
		var tracker_data = EntityTracker.get_entity(entity_id)
		if tracker_data.has("id"):
			tracker_data["hp"] = new_hp
		
		# Visual feedback for taking damage (DragonLord doesn't have damage animation)
		Logger.debug("DragonLord took %.1f damage, HP: %.1f/%.1f" % [payload.get("damage", 0.0), new_hp, max_health], "bosses")

func _update_ai(dt: float) -> void:
	# Skip AI updates if paused by debug system
	if ai_paused:
		return
		
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
			
			# Update EntityTracker and DamageService positions
			var entity_id = "boss_" + str(get_instance_id())
			EntityTracker.update_entity_position(entity_id, global_position)
			DamageService.update_entity_position(entity_id, global_position)
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
		# Use DamageService for player damage (when implemented)
		# For now, use old EventBus.damage_taken signal for player damage
		if EventBus:
			EventBus.damage_taken.emit(attack_damage)

# take_damage() method removed - damage handled via unified pipeline
# Bosses register with both DamageService and EntityTracker in _ready() and receive damage via EventBus sync

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
	_update_health_bar()
	
	# Check for death
	if current_health <= 0.0 and is_alive():
		_die()

func is_alive() -> bool:
	return current_health > 0.0

func _update_health_bar() -> void:
	if health_bar:
		health_bar.update_health(current_health, max_health)

# V2 Enemy System Integration
func setup_from_spawn_config(config: SpawnConfig) -> void:
	spawn_config = config
	max_health = config.health
	current_health = config.health
	attack_damage = config.damage
	speed = config.speed
	
	# Set position
	global_position = config.position
	Logger.debug("DragonLord setup from spawn config: HP=" + str(max_health) + " damage=" + str(attack_damage) + " speed=" + str(speed), "bosses")

func _on_cheat_toggled(payload: CheatTogglePayload) -> void:
	# Handle AI pause/unpause cheat toggle
	if payload.cheat_name == "ai_paused":
		ai_paused = payload.enabled
		Logger.debug("DragonLord AI paused: %s" % ai_paused, "debug")
