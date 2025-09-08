extends Node

## Enemy Animation System - Phase 7 Arena Refactoring
## Manages all enemy tier animations and texture loading for MultiMesh rendering
## Handles frame-based animation for swarm, regular, elite, and boss enemy types

class_name EnemyAnimationSystem

# Animation frame storage for each tier
var swarm_run_textures: Array[ImageTexture] = []
var swarm_current_frame: int = 0
var swarm_frame_timer: float = 0.0
var swarm_frame_duration: float = 0.1

var regular_run_textures: Array[ImageTexture] = []
var regular_current_frame: int = 0
var regular_frame_timer: float = 0.0
var regular_frame_duration: float = 0.1

var elite_run_textures: Array[ImageTexture] = []
var elite_current_frame: int = 0
var elite_frame_timer: float = 0.0
var elite_frame_duration: float = 0.1

var boss_run_textures: Array[ImageTexture] = []
var boss_current_frame: int = 0
var boss_frame_timer: float = 0.0
var boss_frame_duration: float = 0.1

# MultiMesh references for applying animations
var mm_enemies_swarm: MultiMeshInstance2D
var mm_enemies_regular: MultiMeshInstance2D
var mm_enemies_elite: MultiMeshInstance2D
var mm_enemies_boss: MultiMeshInstance2D

func setup(multimesh_refs: Dictionary) -> void:
	mm_enemies_swarm = multimesh_refs.get("swarm")
	mm_enemies_regular = multimesh_refs.get("regular") 
	mm_enemies_elite = multimesh_refs.get("elite")
	mm_enemies_boss = multimesh_refs.get("boss")
	
	# Load all animation textures
	_load_swarm_animations()
	_load_regular_animations()
	_load_elite_animations()
	_load_boss_animations()
	
	Logger.info("EnemyAnimationSystem setup complete", "animations")

func animate_frames(delta: float) -> void:
	_animate_swarm_tier(delta)
	_animate_regular_tier(delta)
	_animate_elite_tier(delta)
	_animate_boss_tier(delta)

func _animate_swarm_tier(delta: float) -> void:
	if swarm_run_textures.is_empty() or not mm_enemies_swarm:
		return
		
	swarm_frame_timer += delta
	if swarm_frame_timer >= swarm_frame_duration:
		swarm_frame_timer = 0.0
		swarm_current_frame = (swarm_current_frame + 1) % swarm_run_textures.size()
		
		# Update SWARM tier texture
		if mm_enemies_swarm and mm_enemies_swarm.multimesh and mm_enemies_swarm.multimesh.instance_count > 0:
			mm_enemies_swarm.texture = swarm_run_textures[swarm_current_frame]

func _animate_regular_tier(delta: float) -> void:
	if regular_run_textures.is_empty() or not mm_enemies_regular:
		return
		
	regular_frame_timer += delta
	if regular_frame_timer >= regular_frame_duration:
		regular_frame_timer = 0.0
		regular_current_frame = (regular_current_frame + 1) % regular_run_textures.size()
		
		# Update REGULAR tier texture
		if mm_enemies_regular and mm_enemies_regular.multimesh and mm_enemies_regular.multimesh.instance_count > 0:
			mm_enemies_regular.texture = regular_run_textures[regular_current_frame]

func _animate_elite_tier(delta: float) -> void:
	if elite_run_textures.is_empty() or not mm_enemies_elite:
		return
		
	elite_frame_timer += delta
	if elite_frame_timer >= elite_frame_duration:
		elite_frame_timer = 0.0
		elite_current_frame = (elite_current_frame + 1) % elite_run_textures.size()
		
		# Update ELITE tier texture
		if mm_enemies_elite and mm_enemies_elite.multimesh and mm_enemies_elite.multimesh.instance_count > 0:
			mm_enemies_elite.texture = elite_run_textures[elite_current_frame]

func _animate_boss_tier(delta: float) -> void:
	if boss_run_textures.is_empty() or not mm_enemies_boss:
		return
		
	boss_frame_timer += delta
	if boss_frame_timer >= boss_frame_duration:
		boss_frame_timer = 0.0
		boss_current_frame = (boss_current_frame + 1) % boss_run_textures.size()
		
		# Update BOSS tier texture
		if mm_enemies_boss and mm_enemies_boss.multimesh and mm_enemies_boss.multimesh.instance_count > 0:
			mm_enemies_boss.texture = boss_run_textures[boss_current_frame]

func _load_swarm_animations() -> void:
	Logger.debug("Loading swarm animations", "enemies")
	_create_swarm_textures()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Loaded " + str(swarm_run_textures.size()) + " swarm animation frames", "enemies")

func _create_swarm_textures() -> void:
	swarm_run_textures.clear()
	
	# Load swarm animation config
	var swarm_animation_config: AnimationConfig = load("res://data/content/swarm_enemy_animations.tres")
	if not swarm_animation_config:
		Logger.error("Failed to load swarm animation config", "enemies")
		return
	
	var sprite_sheet: Texture2D = swarm_animation_config.sprite_sheet
	var frame_width: int = swarm_animation_config.frame_size.x
	var frame_height: int = swarm_animation_config.frame_size.y
	var columns: int = swarm_animation_config.grid_columns
	
	var run_anim: Dictionary = swarm_animation_config.animations.run
	swarm_frame_duration = run_anim.duration
	
	var sprite_image: Image = sprite_sheet.get_image()
	
	for frame_idx in run_anim.frames:
		var index: int = int(frame_idx)
		var col: int = index % columns
		@warning_ignore("integer_division")
		var row: int = int(index / columns)
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(sprite_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i.ZERO)
		
		var frame_texture := ImageTexture.create_from_image(frame_image)
		swarm_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(swarm_run_textures.size()) + " swarm animation textures", "enemies")

func _load_regular_animations() -> void:
	Logger.debug("Loading regular animations", "enemies")
	_create_regular_textures()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Loaded " + str(regular_run_textures.size()) + " regular animation frames", "enemies")

func _create_regular_textures() -> void:
	regular_run_textures.clear()
	
	# Load regular animation config
	var regular_animation_config: AnimationConfig = load("res://data/content/regular_enemy_animations.tres")
	if not regular_animation_config:
		Logger.error("Failed to load regular animation config", "enemies")
		return
	
	var sprite_sheet: Texture2D = regular_animation_config.sprite_sheet
	var frame_width: int = regular_animation_config.frame_size.x
	var frame_height: int = regular_animation_config.frame_size.y
	var columns: int = regular_animation_config.grid_columns
	
	var run_anim: Dictionary = regular_animation_config.animations.run
	regular_frame_duration = run_anim.duration
	
	var sprite_image: Image = sprite_sheet.get_image()
	
	for frame_idx in run_anim.frames:
		var index: int = int(frame_idx)
		var col: int = index % columns
		@warning_ignore("integer_division")
		var row: int = int(index / columns)
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(sprite_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i.ZERO)
		
		var frame_texture := ImageTexture.create_from_image(frame_image)
		regular_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(regular_run_textures.size()) + " regular animation textures", "enemies")

func _load_elite_animations() -> void:
	Logger.debug("Loading elite animations", "enemies")
	_create_elite_textures()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Loaded " + str(elite_run_textures.size()) + " elite animation frames", "enemies")

func _create_elite_textures() -> void:
	elite_run_textures.clear()
	
	# Load elite animation config
	var elite_animation_config: AnimationConfig = load("res://data/content/elite_enemy_animations.tres")
	if not elite_animation_config:
		Logger.error("Failed to load elite animation config", "enemies")
		return
	
	var sprite_sheet: Texture2D = elite_animation_config.sprite_sheet
	var frame_width: int = elite_animation_config.frame_size.x
	var frame_height: int = elite_animation_config.frame_size.y
	var columns: int = elite_animation_config.grid_columns
	
	var run_anim: Dictionary = elite_animation_config.animations.run
	elite_frame_duration = run_anim.duration
	
	var sprite_image: Image = sprite_sheet.get_image()
	
	for frame_idx in run_anim.frames:
		var index: int = int(frame_idx)
		var col: int = index % columns
		@warning_ignore("integer_division")
		var row: int = int(index / columns)
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(sprite_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i.ZERO)
		
		var frame_texture := ImageTexture.create_from_image(frame_image)
		elite_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(elite_run_textures.size()) + " elite animation textures", "enemies")

func _load_boss_animations() -> void:
	Logger.debug("Loading boss animations", "enemies")
	_create_boss_textures()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Loaded " + str(boss_run_textures.size()) + " boss animation frames", "enemies")

func _create_boss_textures() -> void:
	boss_run_textures.clear()
	
	# Load boss animation config
	var boss_animation_config: AnimationConfig = load("res://data/content/boss_enemy_animations.tres")
	if not boss_animation_config:
		Logger.error("Failed to load boss animation config", "enemies")
		return
	
	var sprite_sheet: Texture2D = boss_animation_config.sprite_sheet
	var frame_width: int = boss_animation_config.frame_size.x
	var frame_height: int = boss_animation_config.frame_size.y
	var columns: int = boss_animation_config.grid_columns
	
	var run_anim: Dictionary = boss_animation_config.animations.run
	boss_frame_duration = run_anim.duration
	
	var sprite_image: Image = sprite_sheet.get_image()
	
	for frame_idx in run_anim.frames:
		var index: int = int(frame_idx)
		var col: int = index % columns
		@warning_ignore("integer_division")
		var row: int = int(index / columns)
		
		var frame_image := Image.create(frame_width, frame_height, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(sprite_image, Rect2i(col * frame_width, row * frame_height, frame_width, frame_height), Vector2i.ZERO)
		
		var frame_texture := ImageTexture.create_from_image(frame_image)
		boss_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(boss_run_textures.size()) + " boss animation textures", "enemies")
