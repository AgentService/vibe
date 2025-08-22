extends Node

## Enemy renderer managing AnimatedSprite2D pool for enemy visualization.
## Handles animation state, culling, and sprite positioning.
## Updates on enemies_updated signal from WaveDirector.

class_name EnemyRenderer

# Pool of AnimatedSprite2D nodes for rendering
var _sprite_pool: Array[AnimatedSprite2D] = []
var _pool_size: int = 200
var _active_sprites: Array[AnimatedSprite2D] = []

# Animation data cache
var _animation_configs: Dictionary = {}
var _sprite_sheets: Dictionary = {}

# Performance optimization
var _visible_sprites: Array[AnimatedSprite2D] = []
var _viewport_culling_enabled: bool = true
var _animation_update_timer: float = 0.0
var _animation_update_interval: float = 1.0 / 15.0  # Update animations at 15Hz

func _ready() -> void:
	_load_enemy_types()
	_create_sprite_pool()
	EventBus.combat_step.connect(_on_combat_step)
	Logger.info("EnemyRenderer initialized with " + str(_pool_size) + " sprite pool", "enemies")

func _load_enemy_types() -> void:
	# Load enemy types from registry
	var enemy_types = _get_enemy_types_from_registry()
	if enemy_types.is_empty():
		Logger.warn("No enemy types found in registry, falling back to hardcoded types", "enemies")
		enemy_types = ["green_slime", "scout"]
	
	# Animation data is now hardcoded - no JSON loading needed
	Logger.info("Using hardcoded animation data for " + str(enemy_types.size()) + " enemy types: " + str(enemy_types), "enemies")

func _get_enemy_types_from_registry() -> Array[String]:
	var registry_path = "res://data/enemies/enemy_registry.json"
	var enemy_types: Array[String] = []
	
	if not FileAccess.file_exists(registry_path):
		Logger.warn("Enemy registry not found: " + registry_path, "enemies")
		return enemy_types
	
	var file = FileAccess.open(registry_path, FileAccess.READ)
	if not file:
		Logger.warn("Failed to open enemy registry: " + registry_path, "enemies")
		return enemy_types
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		Logger.warn("Failed to parse enemy registry: " + str(parse_result), "enemies")
		return enemy_types
	
	var registry_data = json.data
	var enemy_data = registry_data.get("enemy_types", {})
	
	for enemy_type in enemy_data.keys():
		enemy_types.append(enemy_type)
	
	Logger.info("Loaded " + str(enemy_types.size()) + " enemy types from registry: " + str(enemy_types), "enemies")
	return enemy_types

func _create_sprite_pool() -> void:
	for i in range(_pool_size):
		var sprite = AnimatedSprite2D.new()
		sprite.visible = false
		sprite.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(sprite)
		_sprite_pool.append(sprite)
	
	Logger.debug("Created AnimatedSprite2D pool with " + str(_pool_size) + " sprites", "enemies")

func _on_combat_step(payload) -> void:
	# Animations are now handled per-sprite in update_enemies()
	pass

func update_enemies(alive_enemies: Array[Dictionary]) -> void:
	# Reset all sprites to invisible first
	_reset_all_sprites()
	_active_sprites.clear()
	
	# Apply viewport culling if enabled
	var enemies_to_render: Array[Dictionary] = []
	if _viewport_culling_enabled:
		enemies_to_render = _get_visible_enemies(alive_enemies)
	else:
		enemies_to_render = alive_enemies
	
	# Limit to pool size
	var render_count = min(enemies_to_render.size(), _pool_size)
	
	# Update sprite positions and animations
	for i in range(render_count):
		var enemy = enemies_to_render[i]
		var sprite = _sprite_pool[i]
		
		_setup_enemy_sprite(sprite, enemy)
		_active_sprites.append(sprite)
	
	Logger.debug("Rendered " + str(render_count) + "/" + str(alive_enemies.size()) + " enemies", "enemies")

func _reset_all_sprites() -> void:
	for sprite in _sprite_pool:
		sprite.visible = false
		sprite.stop()
		# Clear enemy type metadata to force reconfiguration
		sprite.remove_meta("configured_enemy_type")

func _get_visible_enemies(alive_enemies: Array[Dictionary]) -> Array[Dictionary]:
	var visible_enemies: Array[Dictionary] = []
	var visible_rect = _get_visible_world_rect()
	
	for enemy in alive_enemies:
		if _is_enemy_visible(enemy["pos"], visible_rect):
			visible_enemies.append(enemy)
	
	return visible_enemies

func _get_visible_world_rect() -> Rect2:
	# Get viewport and camera info for culling
	var viewport = get_viewport()
	if not viewport:
		return Rect2(Vector2.ZERO, Vector2(2000, 2000))  # Fallback
	
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return Rect2(Vector2.ZERO, Vector2(2000, 2000))  # Fallback
	
	var viewport_size = viewport.get_visible_rect().size
	var zoom = camera.zoom.x  # Assume uniform zoom
	var camera_pos = camera.global_position
	var margin: float = BalanceDB.get_waves_value("enemy_viewport_cull_margin")
	
	var half_size = (viewport_size / zoom) * 0.5 + Vector2(margin, margin)
	return Rect2(camera_pos - half_size, half_size * 2)

func _is_enemy_visible(enemy_pos: Vector2, visible_rect: Rect2) -> bool:
	return visible_rect.has_point(enemy_pos)

func _setup_enemy_sprite(sprite: AnimatedSprite2D, enemy: Dictionary) -> void:
	var enemy_type = enemy.get("type", "green_slime")
	
	# Set position
	sprite.global_position = enemy["pos"]
	sprite.visible = true
	
	# Setup animation if not already configured for this enemy type
	if not _is_sprite_configured(sprite, enemy_type):
		_configure_sprite_animation(sprite, enemy_type)
	
	# Start animation only if not already playing the correct one
	var animation_name = _get_enemy_animation_state(enemy)
	if sprite.sprite_frames != null and (sprite.animation != animation_name or not sprite.is_playing()):
		if sprite.sprite_frames.has_animation(animation_name):
			sprite.play(animation_name)
		else:
			Logger.warn("Animation '" + animation_name + "' not found for enemy type: " + enemy_type, "enemies")

func _is_sprite_configured(sprite: AnimatedSprite2D, enemy_type: String) -> bool:
	# Check if sprite has the correct animation setup for this enemy type
	if sprite.sprite_frames == null:
		return false
	
	# Check if it's configured for the correct enemy type by looking at metadata
	var configured_type = sprite.get_meta("configured_enemy_type", "")
	if configured_type != enemy_type:
		return false
	
	# Check if required animations exist (double-check sprite_frames is still not null)
	if sprite.sprite_frames == null:
		return false
	return sprite.sprite_frames.has_animation("walk")

func _get_hardcoded_animation_data(enemy_type: String) -> Dictionary:
	# Hardcoded animation data for performance - no JSON loading
	var base_data = {
		"frame_size": {"width": 24, "height": 24},
		"grid": {"columns": 4, "rows": 3}
	}
	
	match enemy_type:
		"green_slime":
			base_data["sprite_sheet"] = "res://assets/sprites/slime_green.png"
			base_data["animations"] = {
				"idle": {"frames": [0], "duration": 0.2, "loop": true},
				"walk": {"frames": [0], "duration": 0.15, "loop": true},
				"hit": {"frames": [0], "duration": 0.1, "loop": false}
			}
		"purple_slime":
			base_data["sprite_sheet"] = "res://assets/sprites/slime_purple.png"
			base_data["animations"] = {
				"idle": {"frames": [0], "duration": 0.25, "loop": true},
				"walk": {"frames": [0], "duration": 0.2, "loop": true},
				"hit": {"frames": [0], "duration": 0.1, "loop": false}
			}
		"scout":
			base_data["sprite_sheet"] = "res://assets/sprites/slime_green.png"
			base_data["animations"] = {
				"idle": {"frames": [0], "duration": 0.15, "loop": true},
				"walk": {"frames": [0], "duration": 0.1, "loop": true},
				"hit": {"frames": [0], "duration": 0.08, "loop": false}
			}
		_:
			# Fallback for unknown enemy types
			base_data["sprite_sheet"] = "res://assets/sprites/slime_green.png"
			base_data["animations"] = {
				"idle": {"frames": [0], "duration": 0.2, "loop": true},
				"walk": {"frames": [0], "duration": 0.15, "loop": true},
				"hit": {"frames": [0], "duration": 0.1, "loop": false}
			}
	
	return base_data

func _configure_sprite_animation(sprite: AnimatedSprite2D, enemy_type: String) -> void:
	# Use hardcoded animation data instead of JSON for better performance
	var anim_data = _get_hardcoded_animation_data(enemy_type)
	var sprite_frames = SpriteFrames.new()
	
	# Load sprite sheet texture
	var texture: Texture2D = load(anim_data.sprite_sheet)
	if not texture:
		texture = _create_fallback_texture(enemy_type)
		Logger.warn("Failed to load sprite sheet for " + enemy_type + ", using fallback", "enemies")
	
	# Setup animations from hardcoded data
	for anim_name in anim_data.animations.keys():
		var anim_config = anim_data.animations[anim_name]
		sprite_frames.add_animation(anim_name)
		
		sprite_frames.set_animation_loop(anim_name, anim_config.loop)
		sprite_frames.set_animation_speed(anim_name, 1.0 / anim_config.duration)
		
		# Add frames from sprite sheet
		for frame_idx in anim_config.frames:
			var frame_texture = _extract_frame_from_sheet(texture, frame_idx, anim_data.frame_size, anim_data.grid)
			sprite_frames.add_frame(anim_name, frame_texture)
	
	sprite.sprite_frames = sprite_frames
	sprite.set_meta("configured_enemy_type", enemy_type)
	Logger.debug("Configured sprite for enemy type: " + enemy_type, "enemies")

func _create_fallback_texture(enemy_type: String) -> ImageTexture:
	# Create simple colored square as fallback
	var size = 24
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	# Different colors for different enemy types
	var color = Color.RED
	match enemy_type:
		"green_slime":
			color = Color(0.2, 0.8, 0.2, 1.0)  # Green
		"scout":
			color = Color(0.2, 0.2, 0.8, 1.0)  # Blue
		"purple_slime":
			color = Color(0.8, 0.2, 0.8, 1.0)  # Purple
		_:
			color = Color(1.0, 0.0, 0.0, 1.0)  # Bright red fallback
	
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _extract_frame_from_sheet(texture: Texture2D, frame_idx: int, frame_size: Dictionary, grid: Dictionary) -> ImageTexture:
	if not texture:
		return _create_fallback_texture("green_slime")
	
	var columns = int(grid.get("columns", 4))
	var frame_width = int(frame_size.get("width", 16))
	var frame_height = int(frame_size.get("height", 16))
	
	var col = int(frame_idx) % columns
	var row = int(frame_idx) / columns
	
	var source_rect = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
	
	# Extract the frame from the sprite sheet
	var img = texture.get_image()
	if not img:
		return _create_fallback_texture("green_slime")
	
	var frame_img = img.get_region(source_rect)
	return ImageTexture.create_from_image(frame_img)

func _get_enemy_animation_state(enemy: Dictionary) -> String:
	# Determine which animation to play based on enemy state
	var velocity = enemy.get("vel", Vector2.ZERO)
	
	if velocity.length() > 10.0:
		return "walk"
	else:
		return "idle"

func get_active_sprite_count() -> int:
	return _active_sprites.size()

func set_viewport_culling(enabled: bool) -> void:
	_viewport_culling_enabled = enabled
	Logger.debug("Viewport culling " + ("enabled" if enabled else "disabled"), "enemies")


func _exit_tree() -> void:
	EventBus.combat_step.disconnect(_on_combat_step)
