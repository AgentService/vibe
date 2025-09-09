extends CharacterBody2D
class_name Player

const AnimationConfig_Type = preload("res://scripts/domain/AnimationConfig.gd")  # allowed: pure Resource config
const PlayerTypeScript = preload("res://scripts/domain/PlayerType.gd")  # allowed: pure Resource config

## Player character with WASD movement and collision.
## Serves as the center point for projectile spawning and XP collection.

@export var player_type: PlayerTypeScript

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
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

func _ready() -> void:
	# Player should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	current_health = get_max_health()
	_setup_collision()
	_setup_animations()
	
	# DAMAGE V3: Register with unified damage system
	_register_with_damage_system()
	
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
	var entity_data = {
		"id": "player",
		"type": "player",
		"hp": float(current_health),
		"max_hp": float(get_max_health()),
		"alive": true,
		"pos": global_position
	}
	
	# Register with both systems for unified damage V3
	DamageService.register_entity("player", entity_data)
	EntityTracker.register_entity("player", entity_data)
	
	# Connect to damage sync events
	if EventBus.has_signal("damage_entity_sync"):
		EventBus.damage_entity_sync.connect(_on_damage_entity_sync)
	
	Logger.info("Player registered with unified damage system", "player")

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
	
	# Update EntityTracker data
	var tracker_data = EntityTracker.get_entity("player")
	if tracker_data.has("id"):
		tracker_data["hp"] = new_hp
	
	# Handle death or damage animation
	if is_death:
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
	
	# Now transition to results screen
	Logger.info("Player: Death sequence complete, transitioning to results", "player")
	StateManager.end_run(death_result)

# Death overlay method removed - no longer blocking result screen buttons
