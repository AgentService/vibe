extends CharacterBody2D
class_name Player

const AnimationConfig_Type = preload("res://scripts/domain/AnimationConfig.gd")  # allowed: pure Resource config
const PlayerTypeScript = preload("res://scripts/domain/PlayerType.gd")  # allowed: pure Resource config

## Player character with WASD movement and collision.
## Serves as the center point for projectile spawning and XP collection.

@export var player_type: PlayerTypeScript

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
# Equipment layers for ranger character
@onready var equipment_layers: Array[AnimatedSprite2D] = []
var knight_animation_config: AnimationConfig_Type
var current_animation: String = "idle_down"
var current_direction: String = "down"  # Track facing direction for animations
var current_health: int

var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_direction: Vector2 = Vector2.ZERO
var invulnerable: bool = false

var is_attacking: bool = false
var attack_timer: float = 0.0
var is_hurt: bool = false
var hurt_timer: float = 0.0
var hurt_duration: float = 0.6  # Duration to play hurt animation

# Registration state management
var _registration_in_progress: bool = false

# Death state management
var is_dead: bool = false

func _ready() -> void:
	# Player should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	
	# Reset all state variables on scene ready (critical for restart functionality)
	is_dead = false
	is_rolling = false
	invulnerable = false
	is_attacking = false
	is_hurt = false
	_registration_in_progress = false
	
	# Reset timers
	roll_timer = 0.0
	attack_timer = 0.0
	hurt_timer = 0.0
	
	# Reset animation state
	current_animation = "idle_down"
	current_direction = "down"
	
	# Initialize equipment layers for ranger character
	_setup_equipment_layers()
	
	current_health = get_max_health()
	Logger.info("Player reset: is_dead=%s, health=%d, all state cleared" % [is_dead, current_health], "player")
	
	# Ensure equipment layers start with the correct initial animation
	# This fixes the sync issue where equipment doesn't animate until movement starts
	call_deferred("_sync_initial_equipment_animation")
	
	# Emit initial health signal immediately for UI initialization
	EventBus.health_changed.emit(float(current_health), float(get_max_health()))
	Logger.debug("Player: Emitted early health_changed signal - %d/%d HP" % [current_health, get_max_health()], "player")
	
	_setup_collision()
	_setup_animations()
	
	# DAMAGE V3: Register with unified damage system
	_register_with_damage_system()
	
	# CAMERA: Setup player-following camera
	CameraSystem.setup_camera(self)
	
	# Connect to melee attack signals for animation
	if EventBus.has_signal("melee_attack_started"):
		EventBus.melee_attack_started.connect(_on_melee_attack_started)
		Logger.info("Player: Connected to EventBus.melee_attack_started signal", "player")
	else:
		Logger.error("Player: EventBus.melee_attack_started signal not found!", "player")

# Getter functions that read directly from player_type resource for hot-reload support
func get_move_speed() -> float:
	if player_type:
		return player_type.move_speed
	return 110.0  # Fallback value

func get_pickup_radius() -> float:
	if player_type:
		return player_type.pickup_radius
	return 12.0  # Fallback value

func get_max_health() -> int:
	if player_type:
		return player_type.max_health
	return 199  # Fallback value

func get_roll_duration() -> float:
	if player_type:
		return player_type.roll_duration
	return 0.3  # Fallback value

func get_roll_speed() -> float:
	if player_type:
		return player_type.roll_speed
	return 400.0  # Fallback value

func get_collision_radius() -> float:
	if player_type:
		return player_type.collision_radius
	return 8.0  # Fallback value

func get_attack_animation_duration() -> float:
	if player_type:
		return player_type.attack_animation_duration
	return 0.4  # Fallback value

func _setup_collision() -> void:
	var collision_shape := $CollisionShape2D
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = get_collision_radius()
	collision_shape.shape = circle_shape

func _setup_animations() -> void:
	# Check if editor already provided SpriteFrames with animations
	if _has_editor_animations():
		Logger.info("Player using editor-defined animations (skipping .tres loading)", "player")
		_setup_editor_animation_fallback()
	else:
		Logger.info("Player loading .tres animations", "player")
		_load_knight_animations()
		_setup_sprite_frames()

func _has_editor_animations() -> bool:
	return animated_sprite.sprite_frames != null and \
		   animated_sprite.sprite_frames.get_animation_names().size() > 0

func _setup_editor_animation_fallback() -> void:
	# Ensure editor animations are playing
	var animation_names = animated_sprite.sprite_frames.get_animation_names()
	if animation_names.size() > 0:
		# Try to play "idle_down" if it exists, otherwise fallback
		if animated_sprite.sprite_frames.has_animation("idle_down"):
			animated_sprite.play("idle_down")
			current_animation = "idle_down"
		elif animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
			current_animation = "idle"
		else:
			animated_sprite.play(animation_names[0])
			current_animation = animation_names[0]
		Logger.info("Started editor animation: " + animated_sprite.animation, "player")

func _physics_process(delta: float) -> void:
	_handle_roll_input()
	_update_roll(delta)
	_update_attack(delta)
	_update_hurt(delta)
	_handle_movement(delta)
	_handle_facing()

func _handle_roll_input() -> void:
	if Input.is_action_just_pressed("ui_accept") and not is_rolling:
		_start_roll()

func _start_roll() -> void:
	# Capture current movement direction for dash
	var input_vector: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1.05
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1.0
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1.0
	
	# Use movement direction, or face direction if not moving
	if input_vector != Vector2.ZERO:
		roll_direction = input_vector.normalized()
	else:
		# Roll towards mouse cursor if no movement input
		var mouse_pos := get_global_mouse_position()
		roll_direction = (mouse_pos - global_position).normalized()
	
	is_rolling = true
	roll_timer = 0.0
	invulnerable = true
	
	# Get roll direction for animation
	var roll_anim_direction := _get_direction_from_vector(roll_direction)
	_play_animation("roll_" + roll_anim_direction)

func _update_roll(delta: float) -> void:
	if is_rolling:
		roll_timer += delta
		if roll_timer >= get_roll_duration():
			is_rolling = false
			invulnerable = false

func _update_attack(delta: float) -> void:
	if is_attacking:
		attack_timer += delta
		if attack_timer >= get_attack_animation_duration():
			is_attacking = false
			attack_timer = 0.0

func _update_hurt(delta: float) -> void:
	if is_hurt:
		hurt_timer += delta
		if hurt_timer >= hurt_duration:
			is_hurt = false
			hurt_timer = 0.0

func _handle_movement(_delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	
	if not is_rolling:
		if Input.is_action_pressed("move_left"):
			input_vector.x -= 1.0
		if Input.is_action_pressed("move_right"):
			input_vector.x += 1.0
		if Input.is_action_pressed("move_up"):
			input_vector.y -= 1.0
		if Input.is_action_pressed("move_down"):
			input_vector.y += 1.0
	
	# Update direction based on movement input (WASD)
	if input_vector != Vector2.ZERO and not is_rolling:
		var new_direction: String
		if abs(input_vector.x) > abs(input_vector.y):
			if input_vector.x > 0:
				new_direction = "right"
			else:
				new_direction = "left"
		else:
			if input_vector.y < 0:
				new_direction = "up"
			else:
				new_direction = "down"
		
		if new_direction != current_direction:
			current_direction = new_direction
	
	if is_rolling:
		# Continue dashing in roll direction
		velocity = roll_direction * get_roll_speed()
	elif input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * get_move_speed()
		# Don't override attack or hurt animation with run animation
		if not is_attacking and not is_hurt:
			_play_animation("run_" + current_direction)
	else:
		velocity = Vector2.ZERO
		# Don't override attack or hurt animation with idle animation
		if not is_attacking and not is_hurt:
			_play_animation("idle_" + current_direction)
	
	move_and_slide()
	
	# Update damage system with new position
	DamageService.update_entity_position("player", global_position)
	EntityTracker.update_entity_position("player", global_position)

func get_pos() -> Vector2:
	return global_position

func _load_knight_animations() -> void:
	var resource_path := "res://data/content/knight_animations.tres"
	knight_animation_config = load(resource_path) as AnimationConfig_Type
	if knight_animation_config == null:
		Logger.warn("Failed to load knight animation config from: " + resource_path, "player")
		return
	
	Logger.info("Loaded knight animation config", "player")

func _setup_sprite_frames() -> void:
	if knight_animation_config == null:
		Logger.warn("No knight animation config loaded", "player")
		return
	
	var sprite_frames := SpriteFrames.new()
	var texture := knight_animation_config.sprite_sheet
	
	if texture == null:
		Logger.warn("Failed to load knight sprite sheet", "player")
		return
	
	var frame_width: int = knight_animation_config.frame_size.x
	var frame_height: int = knight_animation_config.frame_size.y
	var columns: int = knight_animation_config.grid_columns
	
	for anim_name in knight_animation_config.animations:
		var anim_data: Dictionary = knight_animation_config.animations[anim_name]
		sprite_frames.add_animation(anim_name)
		
		for frame_index in anim_data.frames:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			var index: int = int(frame_index)
			var col: int = index % columns
			var row: int = int(float(index) / float(columns))  # Explicit conversion for grid row calculation
			atlas.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
			sprite_frames.add_frame(anim_name, atlas)
		
		sprite_frames.set_animation_speed(anim_name, 1.0 / anim_data.duration)
		sprite_frames.set_animation_loop(anim_name, anim_data.loop)
	
	animated_sprite.sprite_frames = sprite_frames
	if sprite_frames.has_animation("idle_down"):
		animated_sprite.play("idle_down")
		current_animation = "idle_down"
	elif sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
		current_animation = "idle"
	else:
		# If no idle animation, use the first available animation
		var animation_names = sprite_frames.get_animation_names()
		if animation_names.size() > 0:
			animated_sprite.play(animation_names[0])
			current_animation = animation_names[0]
			Logger.warn("No 'idle_down' or 'idle' animation found, using: " + animation_names[0], "player")
	Logger.info("Knight sprite frames setup complete", "player")

func _update_animation_direction() -> void:
	# Update current animation to match new direction
	var base_anim := current_animation.split("_")[0]  # Get "idle", "run", etc.
	var new_anim := base_anim + "_" + current_direction
	_play_animation(new_anim)

func _handle_facing() -> void:
	# Direction is now controlled by movement input in _handle_movement()
	# This function can be used for attack-specific facing logic
	pass


func get_health() -> int:
	return current_health

# DAMAGE V3: Register player with unified damage system
func _register_with_damage_system() -> void:
	# Prevent concurrent registration attempts
	if _registration_in_progress:
		Logger.warn("Player registration already in progress - skipping duplicate attempt", "player")
		return
	
	_registration_in_progress = true
	Logger.info("Player registration starting - current_health: %d, max_health: %d, position: %s" % [current_health, get_max_health(), global_position], "player")
	
	# Validate player state before registration
	if current_health <= 0:
		Logger.warn("Player registration attempted with invalid health: %d - resetting to max" % current_health, "player")
		current_health = get_max_health()
	
	# CRITICAL: Ensure is_dead is false during registration (restart scenarios)
	if is_dead:
		Logger.warn("Player registration with is_dead=true - forcing reset to false", "player")
		is_dead = false
	
	var entity_data = {
		"id": "player",
		"type": "player",
		"hp": float(current_health),
		"max_hp": float(get_max_health()),
		"alive": true,
		"pos": global_position
	}
	
	Logger.debug("Player entity_data: %s" % entity_data, "player")
	
	# Check if already registered - if so, just update without unregistering
	var damage_service_exists = DamageService.is_entity_alive("player")
	var entity_tracker_exists = EntityTracker.is_entity_alive("player")
	
	if damage_service_exists and entity_tracker_exists:
		Logger.info("Player already fully registered - updating existing registration without unregistering", "player")
		# Update existing registration (DamageService handles this gracefully)
		DamageService.register_entity("player", entity_data)
		EntityTracker.register_entity("player", entity_data)
	else:
		# Only unregister if partial registration exists
		if damage_service_exists:
			Logger.info("Player partially registered (DamageService only) - cleaning up for fresh registration", "player")
			DamageService.unregister_entity("player")
		if entity_tracker_exists:
			Logger.info("Player partially registered (EntityTracker only) - cleaning up for fresh registration", "player")
			EntityTracker.unregister_entity("player")
		
		# Fresh registration
		Logger.debug("Performing fresh player registration", "player")
		DamageService.register_entity("player", entity_data)
		EntityTracker.register_entity("player", entity_data)
	
	# Validate successful registration
	var damage_service_registered = DamageService.is_entity_alive("player")
	var entity_tracker_registered = EntityTracker.is_entity_alive("player")
	
	Logger.info("Player registration complete - DamageService: %s, EntityTracker: %s" % [damage_service_registered, entity_tracker_registered], "player")
	
	if not damage_service_registered:
		Logger.error("CRITICAL: Player registration with DamageService FAILED!", "player")
	if not entity_tracker_registered:
		Logger.error("CRITICAL: Player registration with EntityTracker FAILED!", "player")
	
	# Connect to damage sync events (check if already connected to prevent errors)
	if EventBus.has_signal("damage_entity_sync") and not EventBus.damage_entity_sync.is_connected(_on_damage_entity_sync):
		EventBus.damage_entity_sync.connect(_on_damage_entity_sync)
		Logger.debug("Player connected to damage_entity_sync signal", "player")
	else:
		Logger.debug("Player already connected to damage_entity_sync signal", "player")
	
	# Emit initial health signal for UI initialization
	EventBus.health_changed.emit(float(current_health), float(get_max_health()))
	Logger.debug("Player: Emitted initial health_changed signal - %d/%d HP" % [current_health, get_max_health()], "player")
	
	Logger.info("Player registered with unified damage system - SUCCESS", "player")
	_registration_in_progress = false

# Helper function to check if player is properly registered
func is_registered_with_damage_system() -> bool:
	var damage_service_ok = DamageService.is_entity_alive("player")
	var entity_tracker_ok = EntityTracker.is_entity_alive("player")
	return damage_service_ok and entity_tracker_ok

# Auto-registration fallback for critical operations
func ensure_damage_registration() -> bool:
	# Skip if player is dead - no need to re-register dead players
	if is_dead:
		Logger.debug("Player is dead - skipping damage registration", "player")
		return false
	
	# Skip if registration is already in progress
	if _registration_in_progress:
		Logger.debug("Player registration in progress - waiting for completion", "player")
		return false  # Let the current registration complete first
	
	if is_registered_with_damage_system():
		return true
	
	Logger.info("Player not properly registered with damage systems - attempting auto-registration", "player")
	_register_with_damage_system()
	
	# Verify registration succeeded
	var success = is_registered_with_damage_system()
	if not success:
		Logger.error("CRITICAL: Player auto-registration FAILED!", "player")
	else:
		Logger.debug("Player auto-registration successful", "player")
	
	return success

# DAMAGE V3: Handle unified damage sync events
func _on_damage_entity_sync(payload: Dictionary) -> void:
	var entity_id: String = payload.get("entity_id", "")
	var entity_type: String = payload.get("entity_type", "")
	var damage: float = payload.get("damage", 0.0)
	var new_hp: float = payload.get("new_hp", 0.0)
	var is_death: bool = payload.get("is_death", false)
	
	# Only handle player entity
	if entity_id != "player" or entity_type != "player":
		return
	
	Logger.info("Player received damage sync: %.1f damage, HP: %.1f" % [damage, new_hp], "player")
	
	# Update player HP
	current_health = int(new_hp)
	
	# Emit health changed signal for UI updates
	EventBus.health_changed.emit(float(current_health), float(get_max_health()))
	Logger.debug("Player: Emitted health_changed signal - %d/%d HP" % [current_health, get_max_health()], "player")
	
	# Update EntityTracker data
	var tracker_data = EntityTracker.get_entity("player")
	if tracker_data.has("id"):
		tracker_data["hp"] = new_hp
	
	# Handle death or damage animation
	if is_death:
		# Prevent multiple death sequences
		if is_dead:
			Logger.debug("Player: Already dead, ignoring additional death damage", "player")
			return
		
		is_dead = true
		_play_hurt_animation()
		EventBus.player_died.emit()
		
		# Start death sequence with proper cleanup and delay
		_handle_death_sequence()
	else:
		_play_hurt_animation()


func _play_hurt_animation() -> void:
	# Trigger hurt animation with proper state management
	is_hurt = true
	hurt_timer = 0.0
	_play_animation("hurt_" + current_direction)
	Logger.info("Player: Playing hurt animation hurt_" + current_direction, "player")

func _play_animation(anim_name: String) -> void:
	# Guard against empty animation names
	if anim_name == "":
		Logger.warn("Attempted to play empty animation name", "player")
		return
		
	if animated_sprite.sprite_frames == null:
		Logger.warn("Player sprite_frames is null, cannot play animation: " + anim_name, "player")
		return
	
	# Debug logging for attack_1 animation specifically
	if anim_name == "attack_1":
		Logger.info("Player: Attempting to play attack_1 animation", "player")
		Logger.info("Player: Has attack_1 animation: " + str(animated_sprite.sprite_frames.has_animation("attack_1")), "player")
	
	if current_animation != anim_name and animated_sprite.sprite_frames.has_animation(anim_name):
		current_animation = anim_name
		animated_sprite.play(anim_name)
		
		# Also play on equipment layers for synchronized animation
		for layer in equipment_layers:
			if layer.sprite_frames and layer.sprite_frames.has_animation(anim_name):
				layer.play(anim_name)
			else:
				# If equipment layer doesn't have this animation, try to find a fallback
				var fallback_anim := _find_fallback_animation(layer.sprite_frames, anim_name)
				if fallback_anim != "":
					layer.play(fallback_anim)
		
		if anim_name == "attack_1":
			Logger.info("Player: Successfully started playing attack_1 animation", "player")
	elif not animated_sprite.sprite_frames.has_animation(anim_name):
		Logger.warn("Player: Animation '" + anim_name + "' does not exist", "player")
		# Fallback: if specific animation doesn't exist, try directional idle or basic idle
		if animated_sprite.sprite_frames.has_animation("idle_" + current_direction) and current_animation != "idle_" + current_direction:
			current_animation = "idle_" + current_direction
			animated_sprite.play("idle_" + current_direction)
		elif animated_sprite.sprite_frames.has_animation("idle") and current_animation != "idle":
			current_animation = "idle"
			animated_sprite.play("idle")
		# If no "idle", just keep playing current animation

func _on_melee_attack_started(_payload: Dictionary) -> void:
	# Play attack animation when melee attack is triggered
	Logger.info("Player: Melee attack started, playing attack animation", "player")
	is_attacking = true
	attack_timer = 0.0
	
	# Temporarily face attack direction (mouse position)
	var attack_direction := _get_attack_direction()
	_play_animation("attack_" + attack_direction)

func _get_direction_from_vector(direction_vector: Vector2) -> String:
	# Convert a Vector2 direction to animation direction string
	if abs(direction_vector.x) > abs(direction_vector.y):
		if direction_vector.x > 0:
			return "right"
		else:
			return "left"
	else:
		if direction_vector.y < 0:
			return "up"
		else:
			return "down"

func _get_attack_direction() -> String:
	# Get attack direction from mouse position for attacks only
	var mouse_pos := get_global_mouse_position()
	var player_pos := global_position
	var direction_vector := mouse_pos - player_pos
	
	if abs(direction_vector.x) > abs(direction_vector.y):
		if direction_vector.x > 0:
			return "right"
		else:
			return "left"
	else:
		if direction_vector.y < 0:
			return "up"
		else:
			return "down"

func _handle_death_sequence() -> void:
	"""Handle the complete death sequence with proper cleanup and timing"""
	Logger.info("Player: Starting death sequence", "player")
	
	# Prepare death result data
	var death_result = {
		"result_type": "death",
		"death_cause": "Killed by enemy",
		"time_survived": Time.get_ticks_msec() / 1000.0,
		"level_reached": PlayerProgression.level if PlayerProgression else 1,
		"enemies_killed": RunManager.stats.get("enemies_killed", 0),
		"damage_dealt": int(RunManager.stats.get("total_damage_dealt", 0.0)),
		"damage_taken": get_max_health() - current_health,
		"xp_gained": RunManager.stats.get("xp_gained", 0),
		"arena_id": StringName("arena")
	}
	
	# Wait for systems to properly clean up (WaveDirector stops spawning, enemies cleared)
	Logger.info("Player: Waiting for systems cleanup...", "player")
	await get_tree().create_timer(0.5).timeout
	
	# Now show results modal over arena background
	Logger.info("Player: Death sequence complete, showing results modal", "player")
	UIManager.show_modal(UIManager.ModalType.RESULTS_SCREEN, {"run_result": death_result})

# Death overlay method removed - no longer blocking result screen buttons

## Setup equipment layers for multi-layer character rendering
func _setup_equipment_layers() -> void:
	equipment_layers.clear()
	
	# Find all AnimatedSprite2D nodes except the base one
	for child in get_children():
		if child is AnimatedSprite2D and child != animated_sprite:
			equipment_layers.append(child)
	
	Logger.info("Found %d equipment layers for synchronization" % equipment_layers.size(), "player")

## Find a fallback animation when equipment layer doesn't have the requested animation
func _find_fallback_animation(sprite_frames: SpriteFrames, requested_anim: String) -> String:
	if not sprite_frames:
		return ""
	
	var available_anims = sprite_frames.get_animation_names()
	if available_anims.is_empty():
		return ""
	
	# Try to find a similar animation based on direction
	var direction = ""
	if "_down" in requested_anim:
		direction = "_down"
	elif "_left" in requested_anim:
		direction = "_left" 
	elif "_right" in requested_anim:
		direction = "_right"
	elif "_up" in requested_anim:
		direction = "_up"
	
	# Look for walk or idle animation in same direction
	for anim in available_anims:
		if direction != "" and direction in anim and ("walk" in anim or "idle" in anim):
			return anim
	
	# Fallback to first available animation
	return available_anims[0]

## Sync equipment layers with initial animation on startup
func _sync_initial_equipment_animation() -> void:
	# Wait for all nodes to be fully ready
	if not animated_sprite:
		return
	
	# Get the current animation that the base character is playing
	var current_base_animation = animated_sprite.animation
	if current_base_animation == "":
		current_base_animation = "idle_down"  # Default fallback
	
	Logger.info("Syncing equipment layers with initial animation: " + current_base_animation, "player")
	
	# Force equipment layers to play the same animation as base character
	for layer in equipment_layers:
		if layer and layer.sprite_frames:
			if layer.sprite_frames.has_animation(current_base_animation):
				layer.play(current_base_animation)
				Logger.debug("Equipment layer synced to: " + current_base_animation, "player")
			else:
				# Find fallback animation for equipment layer
				var fallback_anim = _find_fallback_animation(layer.sprite_frames, current_base_animation)
				if fallback_anim != "":
					layer.play(fallback_anim)
					Logger.debug("Equipment layer using fallback: " + fallback_anim, "player")
	
	Logger.info("Initial equipment synchronization complete", "player")
