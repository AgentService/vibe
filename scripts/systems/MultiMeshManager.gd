class_name MultiMeshManager
extends Node

# Manages all MultiMesh instances for projectiles and enemy tiers
# Handles initialization, configuration, and provides clean interface

const EnemyRenderTier_Type := preload("res://scripts/systems/EnemyRenderTier.gd")

# MultiMesh node references (injected from Arena)
var mm_projectiles: MultiMeshInstance2D
var mm_enemies_swarm: MultiMeshInstance2D
var mm_enemies_regular: MultiMeshInstance2D
var mm_enemies_elite: MultiMeshInstance2D
var mm_enemies_boss: MultiMeshInstance2D

# Dependencies
var enemy_render_tier: EnemyRenderTier

# Shared dummy texture to avoid null texture errors in headless/textureless runs
var _shared_dummy_tex: ImageTexture

func _get_shared_dummy_texture() -> Texture2D:
	if _shared_dummy_tex:
		return _shared_dummy_tex
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	_shared_dummy_tex = ImageTexture.create_from_image(img)
	return _shared_dummy_tex

# Initialize MultiMeshManager with node references and configure all MultiMesh instances
func setup(projectiles: MultiMeshInstance2D, swarm: MultiMeshInstance2D, regular: MultiMeshInstance2D, elite: MultiMeshInstance2D, boss: MultiMeshInstance2D, tier_helper: EnemyRenderTier) -> void:
	mm_projectiles = projectiles
	mm_enemies_swarm = swarm
	mm_enemies_regular = regular
	mm_enemies_elite = elite
	mm_enemies_boss = boss
	enemy_render_tier = tier_helper
	
	_setup_projectile_multimesh()
	_setup_tier_multimeshes()
	
	Logger.info("MultiMeshManager initialized", "enemies")

func _setup_projectile_multimesh() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(8, 8)
	multimesh.mesh = quad_mesh

	# Basic projectile texture for visual feedback
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 0.0, 1.0))  # Yellow projectiles
	var tex := ImageTexture.create_from_image(img)
	mm_projectiles.texture = tex
	mm_projectiles.z_index = 2  # Above walls

	mm_projectiles.multimesh = multimesh
	if mm_projectiles.texture == null:
		mm_projectiles.texture = _get_shared_dummy_texture()

func _setup_tier_multimeshes() -> void:
	# Setup SWARM tier MultiMesh (small squares)
	var swarm_multimesh := MultiMesh.new()
	swarm_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	swarm_multimesh.use_colors = true
	swarm_multimesh.instance_count = 0
	var swarm_mesh := QuadMesh.new()
	swarm_mesh.size = Vector2(32, 32)  # 32x32 to match knight sprite frame
	swarm_multimesh.mesh = swarm_mesh
	
	# Load knight sprite for swarm enemies (static frame)
	var knight_texture := load("res://assets/sprites/knight.png") as Texture2D
	if knight_texture:
		# Extract first frame (32x32) from knight spritesheet
		var knight_image := knight_texture.get_image()
		var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
		var swarm_tex := ImageTexture.create_from_image(frame_image)
		mm_enemies_swarm.texture = swarm_tex
	mm_enemies_swarm.multimesh = swarm_multimesh
	if mm_enemies_swarm.texture == null:
		mm_enemies_swarm.texture = _get_shared_dummy_texture()
	mm_enemies_swarm.z_index = 0  # Gameplay entities layer
	
	# Setup REGULAR tier MultiMesh (medium rectangles)
	var regular_multimesh := MultiMesh.new()
	regular_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	regular_multimesh.use_colors = true
	regular_multimesh.instance_count = 0
	var regular_mesh := QuadMesh.new()
	regular_mesh.size = Vector2(32, 32)  # 32x32 to match knight sprite frame
	regular_multimesh.mesh = regular_mesh
	# Load knight sprite for regular enemies (static frame)
	if knight_texture:
		# Extract second frame (32x32) from knight spritesheet
		var knight_image := knight_texture.get_image()
		var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(32, 0, 32, 32), Vector2i.ZERO)
		var regular_tex := ImageTexture.create_from_image(frame_image)
		mm_enemies_regular.texture = regular_tex
	mm_enemies_regular.multimesh = regular_multimesh
	if mm_enemies_regular.texture == null:
		mm_enemies_regular.texture = _get_shared_dummy_texture()
	mm_enemies_regular.z_index = 0  # Gameplay entities layer
	
	# Setup ELITE tier MultiMesh (large diamonds)
	var elite_multimesh := MultiMesh.new()
	elite_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	elite_multimesh.use_colors = true
	elite_multimesh.instance_count = 0
	var elite_mesh := QuadMesh.new()
	elite_mesh.size = Vector2(48, 48)  # Larger elite size 
	elite_multimesh.mesh = elite_mesh
	# Load knight sprite for elite enemies (static frame)
	if knight_texture:
		# Extract third frame (32x32) from knight spritesheet, scale to 48x48
		var knight_image := knight_texture.get_image()
		var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(64, 0, 32, 32), Vector2i.ZERO)
		frame_image.resize(48, 48)  # Scale up for elite
		var elite_tex := ImageTexture.create_from_image(frame_image)
		mm_enemies_elite.texture = elite_tex
	mm_enemies_elite.multimesh = elite_multimesh
	if mm_enemies_elite.texture == null:
		mm_enemies_elite.texture = _get_shared_dummy_texture()
	mm_enemies_elite.z_index = 0  # Gameplay entities layer
	
	# Setup BOSS tier MultiMesh (large diamonds)
	var boss_multimesh := MultiMesh.new()
	boss_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	boss_multimesh.use_colors = true
	boss_multimesh.instance_count = 0
	var boss_mesh := QuadMesh.new()
	boss_mesh.size = Vector2(56, 56)  # Largest size for boss distinction (SWARM:32, REGULAR:32, ELITE:48, BOSS:56)
	boss_multimesh.mesh = boss_mesh
	# Load knight sprite for boss enemies (static frame)
	if knight_texture:
		# Extract fourth frame (32x32) from knight spritesheet, scale to 56x56
		var knight_image := knight_texture.get_image()
		var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(96, 0, 32, 32), Vector2i.ZERO)
		frame_image.resize(56, 56)  # Scale up for boss
		var boss_tex := ImageTexture.create_from_image(frame_image)
		mm_enemies_boss.texture = boss_tex
	mm_enemies_boss.multimesh = boss_multimesh
	if mm_enemies_boss.texture == null:
		mm_enemies_boss.texture = _get_shared_dummy_texture()
	mm_enemies_boss.z_index = 0  # Gameplay entities layer
	
	Logger.debug("Tier MultiMesh instances initialized", "enemies")

func update_projectiles(alive_projectiles: Array[Dictionary]) -> void:
	var count := alive_projectiles.size()
	mm_projectiles.multimesh.instance_count = count

	for i in range(count):
		var projectile := alive_projectiles[i]
		var proj_transform := Transform2D()
		proj_transform.origin = projectile["pos"]
		mm_projectiles.multimesh.set_instance_transform_2d(i, proj_transform)

func update_enemies(alive_enemies: Array[EnemyEntity]) -> void:
	if enemy_render_tier == null:
		Logger.warn("EnemyRenderTier is null, skipping tier-based rendering", "enemies")
		return
	
	# Group enemies by tier
	var tier_groups := enemy_render_tier.group_enemies_by_tier(alive_enemies)
	
	# PHASE 1: Track MultiMesh instance counts for memory leak investigation
	var total_instances = 0
	for tier in tier_groups:
		total_instances += tier_groups[tier].size()
	
	# Log instance counts every 60 updates (approximately every 2 seconds at 30fps)
	var frame_count = Engine.get_process_frames()
	if frame_count % 60 == 0:
		Logger.debug("MultiMesh instances: Total=%d, Swarm=%d, Regular=%d, Elite=%d, Boss=%d" % [
			total_instances,
			tier_groups[EnemyRenderTier_Type.Tier.SWARM].size(),
			tier_groups[EnemyRenderTier_Type.Tier.REGULAR].size(), 
			tier_groups[EnemyRenderTier_Type.Tier.ELITE].size(),
			tier_groups[EnemyRenderTier_Type.Tier.BOSS].size()
		], "enemies")
	
	# Update each tier's MultiMesh with safety checks
	if is_instance_valid(mm_enemies_swarm):
		_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.SWARM], mm_enemies_swarm, Vector2(24, 24), EnemyRenderTier_Type.Tier.SWARM)
	if is_instance_valid(mm_enemies_regular):
		_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.REGULAR], mm_enemies_regular, Vector2(32, 32), EnemyRenderTier_Type.Tier.REGULAR) 
	if is_instance_valid(mm_enemies_elite):
		_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.ELITE], mm_enemies_elite, Vector2(48, 48), EnemyRenderTier_Type.Tier.ELITE)
	if is_instance_valid(mm_enemies_boss):
		_update_tier_multimesh(tier_groups[EnemyRenderTier_Type.Tier.BOSS], mm_enemies_boss, Vector2(64, 64), EnemyRenderTier_Type.Tier.BOSS)

func _update_tier_multimesh(tier_enemies: Array[Dictionary], mm_instance: MultiMeshInstance2D, _base_size: Vector2, tier: EnemyRenderTier_Type.Tier) -> void:
	# Safety check: ensure mm_instance is valid and not freed
	if not is_instance_valid(mm_instance):
		Logger.warn("MultiMeshInstance2D is invalid/freed for tier %s" % tier, "enemies")
		return
	
	var count := tier_enemies.size()
	if mm_instance and mm_instance.multimesh:
		# PHASE 1: Track instance count changes for potential memory leaks
		var previous_count = mm_instance.multimesh.instance_count
		mm_instance.multimesh.instance_count = count
		
		# Log significant changes in instance count
		if abs(count - previous_count) > 50:  # Log when changes > 50 instances
			Logger.debug("MultiMesh %s: instance_count %d → %d (change: %+d)" % [
				tier, previous_count, count, count - previous_count
			], "enemies")
		
		for i in range(count):
			var enemy := tier_enemies[i]
			
			# Transform with position and sprite flipping
			var instance_transform := Transform2D()
			instance_transform.origin = enemy["pos"]
			
			# Apply sprite flipping based on movement direction
			if enemy.has("direction"):
				var direction: Vector2 = enemy["direction"]
				if direction.x < 0:
					# Flip horizontally for leftward movement
					instance_transform.x = Vector2(-1, 0)
				else:
					# Normal orientation for rightward movement
					instance_transform.x = Vector2(1, 0)
				instance_transform.y = Vector2(0, 1)
			
			mm_instance.multimesh.set_instance_transform_2d(i, instance_transform)
			
			# Set color based on tier for visual debugging
			var tier_color := get_tier_debug_color(tier)
			mm_instance.multimesh.set_instance_color(i, tier_color)

func get_enemy_color_for_type(type_id: String) -> Color:
	# Fallback colors based on type_id
	match type_id:
		"knight_swarm":
			return Color(1.0, 0.0, 0.0, 1.0)  # Red
		"knight_regular":
			return Color(0.0, 1.0, 0.0, 1.0)  # Green
		"knight_elite":
			return Color(0.0, 0.0, 1.0, 1.0)  # Blue
		"knight_boss":
			return Color(1.0, 0.0, 1.0, 1.0)  # Magenta
		_:
			return Color(1.0, 0.0, 0.0, 1.0)  # Default red

func get_tier_debug_color(tier: EnemyRenderTier_Type.Tier) -> Color:
	# Distinct colors for each tier for visual debugging - more saturated for better visibility
	match tier:
		EnemyRenderTier_Type.Tier.SWARM:
			return Color(1.5, 0.3, 0.3, 1.0)  # Bright Red
		EnemyRenderTier_Type.Tier.REGULAR:
			return Color(0.3, 1.5, 1.5, 1.0)  # Bright Cyan
		EnemyRenderTier_Type.Tier.ELITE:
			return Color(1.5, 0.3, 1.5, 1.0)  # Bright Magenta
		EnemyRenderTier_Type.Tier.BOSS:
			return Color(1.8, 0.9, 0.2, 1.0)  # Very Bright Orange
		_:
			return Color(1.0, 1.0, 1.0, 1.0)  # White fallback
