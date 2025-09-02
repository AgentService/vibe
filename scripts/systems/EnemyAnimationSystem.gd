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
	
	# Use existing slime sprite as a simple placeholder
	var base_sprite := preload("res://assets/sprites/slime_green.png")
	
	# Create a simple single-frame animation for now
	var frame_texture := ImageTexture.create_from_image(base_sprite.get_image())
	swarm_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(swarm_run_textures.size()) + " swarm textures (placeholder)", "enemies")

func _load_regular_animations() -> void:
	Logger.debug("Loading regular animations", "enemies")
	_create_regular_textures()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Loaded " + str(regular_run_textures.size()) + " regular animation frames", "enemies")

func _create_regular_textures() -> void:
	regular_run_textures.clear()
	
	# Use purple slime sprite as placeholder for regular enemies
	var base_sprite := preload("res://assets/sprites/slime_purple.png")
	
	# Create a simple single-frame animation for now
	var frame_texture := ImageTexture.create_from_image(base_sprite.get_image())
	regular_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(regular_run_textures.size()) + " regular textures (placeholder)", "enemies")

func _load_elite_animations() -> void:
	Logger.debug("Loading elite animations", "enemies")
	_create_elite_textures()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Loaded " + str(elite_run_textures.size()) + " elite animation frames", "enemies")

func _create_elite_textures() -> void:
	elite_run_textures.clear()
	
	# Use knight sprite as placeholder for elite enemies
	var base_sprite := preload("res://assets/sprites/knight.png")
	
	# Create a simple single-frame animation for now
	var frame_texture := ImageTexture.create_from_image(base_sprite.get_image())
	elite_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(elite_run_textures.size()) + " elite textures (placeholder)", "enemies")

func _load_boss_animations() -> void:
	Logger.debug("Loading boss animations", "enemies")
	_create_boss_textures()
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Loaded " + str(boss_run_textures.size()) + " boss animation frames", "enemies")

func _create_boss_textures() -> void:
	boss_run_textures.clear()
	
	# Use fruit sprite as placeholder for boss enemies (distinctive)
	var base_sprite := preload("res://assets/sprites/fruit.png")
	
	# Create a simple single-frame animation for now
	var frame_texture := ImageTexture.create_from_image(base_sprite.get_image())
	boss_run_textures.append(frame_texture)
	
	if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
		Logger.debug("Created " + str(boss_run_textures.size()) + " boss textures (placeholder)", "enemies")