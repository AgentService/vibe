extends CharacterBody2D
class_name Player

const AnimationConfig_Type = preload("res://scripts/domain/AnimationConfig.gd")  # allowed: pure Resource config
const PlayerTypeScript = preload("res://scripts/domain/PlayerType.gd")  # allowed: pure Resource config

## Player character with WASD movement and collision.
## Serves as the center point for projectile spawning and XP collection.

@export var player_type: PlayerTypeScript

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var knight_animation_config: AnimationConfig_Type
var current_animation: String = "idle"
var current_health: int

var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_direction: Vector2 = Vector2.ZERO
var invulnerable: bool = false

func _ready() -> void:
	# Player should pause with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player")
	current_health = get_max_health()
	_setup_collision()
	_setup_animations()
	EventBus.damage_taken.connect(_on_damage_taken)

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
		# Try to play "idle" if it exists, otherwise play the first animation
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
			current_animation = "idle"
		else:
			animated_sprite.play(animation_names[0])
			current_animation = animation_names[0]
		Logger.info("Started editor animation: " + animated_sprite.animation, "player")

func _physics_process(delta: float) -> void:
	_handle_roll_input()
	_update_roll(delta)
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
	_play_animation("roll")
	
	# Face the roll direction
	if roll_direction.x > 0:
		animated_sprite.flip_h = false  # Face right
	elif roll_direction.x < 0:
		animated_sprite.flip_h = true   # Face left

func _update_roll(delta: float) -> void:
	if is_rolling:
		roll_timer += delta
		if roll_timer >= get_roll_duration():
			is_rolling = false
			invulnerable = false

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
	
	if is_rolling:
		# Continue dashing in roll direction
		velocity = roll_direction * get_roll_speed()
	elif input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * get_move_speed()
		_play_animation("run")
	else:
		velocity = Vector2.ZERO
		_play_animation("idle")
	
	move_and_slide()

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
			var row: int = index / columns
			atlas.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
			sprite_frames.add_frame(anim_name, atlas)
		
		sprite_frames.set_animation_speed(anim_name, 1.0 / anim_data.duration)
		sprite_frames.set_animation_loop(anim_name, anim_data.loop)
	
	animated_sprite.sprite_frames = sprite_frames
	if sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
		current_animation = "idle"
	else:
		# If no idle animation, use the first available animation
		var animation_names = sprite_frames.get_animation_names()
		if animation_names.size() > 0:
			animated_sprite.play(animation_names[0])
			current_animation = animation_names[0]
			Logger.warn("No 'idle' animation found, using: " + animation_names[0], "player")
	Logger.info("Knight sprite frames setup complete", "player")

func _handle_facing() -> void:
	# Don't change facing during roll - let roll direction control it
	if is_rolling:
		return
		
	var mouse_pos := get_global_mouse_position()
	var player_pos := global_position
	
	if mouse_pos.x > player_pos.x:
		animated_sprite.flip_h = false
	else:
		animated_sprite.flip_h = true

func _on_damage_taken(damage: int) -> void:
	# Check for god mode cheat
	if CheatSystem and CheatSystem.is_god_mode_active():
		return
	
	if invulnerable:
		return  # No damage during dodge roll
		
	current_health = max(0, current_health - damage)
	
	if current_health <= 0:
		_play_animation("death")
		EventBus.player_died.emit()
		
		# End run through StateManager with death result
		var death_result = {
			"result_type": "death",
			"death_cause": "Health reached zero",
			"time_survived": Time.get_ticks_msec() / 1000.0,  # Convert to seconds
			"level_reached": PlayerProgression.get_level() if PlayerProgression else 1,
			"enemies_killed": 0,  # TODO: Track this in a combat stats system
			"damage_dealt": 0,    # TODO: Track this in a combat stats system
			"damage_taken": get_max_health() - current_health,
			"xp_gained": 0,       # TODO: Track XP gained this run
			"arena_id": StringName("arena")
		}
		
		# Delay end_run call to allow death animation to start
		await get_tree().create_timer(0.1).timeout
		StateManager.end_run(death_result)
	else:
		_play_animation("hit")

func get_health() -> int:
	return current_health


func _play_animation(anim_name: String) -> void:
	# Guard against empty animation names
	if anim_name == "":
		Logger.warn("Attempted to play empty animation name", "player")
		return
		
	if animated_sprite.sprite_frames == null:
		Logger.warn("Player sprite_frames is null, cannot play animation: " + anim_name, "player")
		return
	
	if current_animation != anim_name and animated_sprite.sprite_frames.has_animation(anim_name):
		current_animation = anim_name
		animated_sprite.play(anim_name)
	elif not animated_sprite.sprite_frames.has_animation(anim_name):
		# Fallback: if specific animation doesn't exist, try to stay on current or use "idle"
		if animated_sprite.sprite_frames.has_animation("idle") and current_animation != "idle":
			current_animation = "idle"
			animated_sprite.play("idle")
		# If no "idle", just keep playing current animation
