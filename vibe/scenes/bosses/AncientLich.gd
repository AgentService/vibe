extends CharacterBody2D

## Ancient Lich Boss - V2 Enemy System Integration
## Scene-based boss with AnimatedSprite2D for proper visual workflow

class_name AncientLich

signal died

@onready var animated_sprite: AnimatedSprite2D = $CollisionShape2D/AnimatedSprite2D

var spawn_config: SpawnConfig
var max_health: float = 200.0
var current_health: float = 200.0
var damage: float = 25.0
var speed: float = 60.0
var attack_damage: float = 25.0
var attack_cooldown: float = 1.5
var last_attack_time: float = 0.0

# AI state
var target_position: Vector2
var attack_range: float = 60.0
var chase_range: float = 300.0

func _ready() -> void:
	Logger.info("AncientLich boss ready", "enemies")
	
	# Start animation like DragonLord - always do this in _ready
	var animated_sprite_node = $CollisionShape2D/AnimatedSprite2D
	if animated_sprite_node and animated_sprite_node.sprite_frames:
		animated_sprite_node.play("default")
		Logger.debug("AncientLich animation started", "enemies")
	
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
	Logger.debug("AncientLich registered with DamageService as " + entity_id, "enemies")

func _exit_tree() -> void:
	# Clean up signal connections
	if EventBus and EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	
	# DAMAGE V2: Unregister from DamageService
	var entity_id = "boss_" + str(get_instance_id())
	DamageService.unregister_entity(entity_id)

func setup_from_spawn_config(config: SpawnConfig) -> void:
	spawn_config = config
	max_health = config.health
	current_health = config.health
	damage = config.damage  
	speed = config.speed
	attack_damage = config.damage
	
	# Set position
	global_position = config.position
	
	# Apply visual config
	modulate = config.color_tint
	scale = Vector2.ONE * config.size_scale
	
	Logger.info("AncientLich boss spawned: HP=%.1f DMG=%.1f SPD=%.1f" % [max_health, damage, speed], "enemies")

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
	Logger.debug("AncientLich attacks for %.1f damage!" % attack_damage, "enemies")
	
	# Emit damage to player if in range
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		# Use EventBus to damage player with proper payload
		if EventBus:
			var source_id = EntityId.enemy(-1)  # Special boss ID
			var target_id = EntityId.player()
			var damage_tags = PackedStringArray(["magic", "boss"])
			var damage_payload = EventBus.DamageRequestPayload_Type.new(source_id, target_id, attack_damage, damage_tags)
			EventBus.damage_requested.emit(damage_payload)

# OLD DAMAGE METHOD - COMMENTED OUT FOR DAMAGE_V2 REFACTOR
func take_damage(amount: float, _source: String = "") -> void:
	# current_health -= amount
	# Logger.info("AncientLich takes %.1f damage (%.1f/%.1f HP)" % [amount, current_health, max_health], "enemies")
	
	# if current_health <= 0:
	#	_die()
	
	# TEMPORARY: Do nothing until DamageRegistry handles boss damage
	pass

func _die() -> void:
	Logger.info("AncientLich has been defeated!", "enemies")
	died.emit()  # Signal for integration
	queue_free()

# Public interface for damage system integration  
func get_max_health() -> float:
	return max_health

func get_current_health() -> float:
	return current_health

func set_current_health(new_health: float) -> void:
	current_health = new_health

func is_alive() -> bool:
	return current_health > 0.0
