extends CharacterBody2D

## Ancient Lich Boss - V2 Enemy System Integration
## Scene-based boss with AnimatedSprite2D for proper visual workflow

class_name AncientLich

signal died

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: BossHealthBar = $BossHealthBar

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
var ai_paused: bool = false  # Debug AI pause state

# Animation state
var has_woken_up: bool = false
var is_taking_damage: bool = false
var is_aggroed: bool = false

func _ready() -> void:
	Logger.info("AncientLich boss ready", "bosses")
	
	# Start with wake_up animation and pause it on first frame
	var animated_sprite_node = $AnimatedSprite2D
	if animated_sprite_node and animated_sprite_node.sprite_frames:
		animated_sprite_node.play("wake_up")
		animated_sprite_node.pause()  # Stay on first frame until aggroed
		animated_sprite_node.connect("animation_finished", _on_animation_finished)
		Logger.debug("AncientLich spawned in dormant state", "bosses")
	
	# Connect to combat step for deterministic behavior
	if EventBus:
		EventBus.combat_step.connect(_on_combat_step)
		# DAMAGE V3: Listen for unified damage sync events
		EventBus.damage_entity_sync.connect(_on_damage_entity_sync)
		# DEBUG: Listen for cheat toggles (AI pause)
		EventBus.cheat_toggled.connect(_on_cheat_toggled)
	
	# DAMAGE V3: Register with both DamageService and EntityTracker
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
	Logger.debug("AncientLich registered with DamageService and EntityTracker as " + entity_id, "bosses")
	
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
	
	# DAMAGE V3: Unregister from both systems
	var entity_id = "boss_" + str(get_instance_id())
	DamageService.unregister_entity(entity_id)
	EntityTracker.unregister_entity(entity_id)

func setup_from_spawn_config(config: SpawnConfig) -> void:
	spawn_config = config
	max_health = config.health
	current_health = config.health
	damage = config.damage  
	speed = config.speed
	attack_damage = config.damage
	
	# Set position
	global_position = config.position
	
	# Apply visual config (removed color tint functionality)
	scale = Vector2.ONE * config.size_scale
	
	Logger.info("AncientLich boss spawned: HP=%.1f DMG=%.1f SPD=%.1f" % [max_health, damage, speed], "bosses")

func _on_combat_step(payload) -> void:
	var dt: float = payload.dt
	_update_ai(dt)
	last_attack_time += dt

## DAMAGE V3: Handle unified damage sync events for scene bosses
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
		Logger.info("V3: Boss %s killed via damage sync" % [entity_id], "combat")
		_die()
	else:
		# Update EntityTracker health data
		var tracker_data = EntityTracker.get_entity(entity_id)
		if tracker_data.has("id"):
			tracker_data["hp"] = new_hp
		
		# Visual feedback for taking damage
		_trigger_damage_animation()

func _update_ai(dt: float) -> void:
	# Skip AI updates if paused by debug system
	if ai_paused:
		return
		
	# Get player position from PlayerState
	if not PlayerState.has_player_reference():
		return
		
	target_position = PlayerState.position
	var distance_to_player: float = global_position.distance_to(target_position)
	
	# Trigger aggro when player gets close
	if distance_to_player <= chase_range and not is_aggroed:
		_aggro()
		return
	
	# Only move after fully waking up
	if not has_woken_up:
		return
	
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
	Logger.debug("AncientLich attacks for %.1f damage!" % attack_damage, "bosses")
	
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

# DAMAGE V3: take_damage() method removed - damage handled via unified pipeline
# Bosses register with both DamageService and EntityTracker in _ready() and receive damage via EventBus sync

func _die() -> void:
	Logger.info("AncientLich has been defeated!", "bosses")
	died.emit()  # Signal for integration
	queue_free()

# Public interface for damage system integration  
func get_max_health() -> float:
	return max_health

func get_current_health() -> float:
	return current_health

func set_current_health(new_health: float) -> void:
	var old_health = current_health
	current_health = new_health
	_update_health_bar()
	
	# Play damage animation if health decreased and not already playing damage anim
	if new_health < old_health and not is_taking_damage and has_woken_up:
		is_taking_damage = true
		animated_sprite.play("damage_taken")
	
	# Check for death
	if current_health <= 0.0 and is_alive():
		_die()

func is_alive() -> bool:
	return current_health > 0.0

func _update_health_bar() -> void:
	if health_bar:
		health_bar.update_health(current_health, max_health)

func _aggro() -> void:
	if is_aggroed:
		return
	is_aggroed = true
	Logger.debug("AncientLich aggroed - beginning wake up sequence!", "bosses")
	animated_sprite.play("wake_up")  # Resume/restart the wake up animation

func _on_animation_finished() -> void:
	if animated_sprite.animation == "wake_up":
		has_woken_up = true
		animated_sprite.play("default")
		Logger.debug("AncientLich fully awakened", "bosses")
	elif animated_sprite.animation == "damage_taken":
		is_taking_damage = false
		animated_sprite.play("default")

func _trigger_damage_animation() -> void:
	# Trigger damage animation if not already playing and boss is awake
	if not is_taking_damage and has_woken_up:
		is_taking_damage = true
		animated_sprite.play("damage_taken")

func _on_cheat_toggled(payload: CheatTogglePayload) -> void:
	# Handle AI pause/unpause cheat toggle
	if payload.cheat_name == "ai_paused":
		ai_paused = payload.enabled
		Logger.debug("AncientLich AI paused: %s" % ai_paused, "debug")
