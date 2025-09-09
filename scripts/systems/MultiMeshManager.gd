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

# PHASE 4 OPTIMIZATION: Pre-allocated MultiMesh and QuadMesh pools for reuse
# Target: 10-20MB reduction from MultiMesh instances, 5-10MB from QuadMesh objects
var _multimesh_pool: Array[MultiMesh] = []
var _quadmesh_pool: Dictionary = {}  # size_key -> QuadMesh
var _pool_initialized: bool = false

func _get_shared_dummy_texture() -> Texture2D:
	if _shared_dummy_tex:
		return _shared_dummy_tex
	# In headless mode, return null to avoid texture errors
	if DisplayServer.get_name() == "headless":
		return null
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
	
	# PHASE 4 OPTIMIZATION: Initialize pools before setup
	_initialize_pools()
	
	_setup_projectile_multimesh()
	_setup_tier_multimeshes()
	
	Logger.info("MultiMeshManager initialized with optimized pools", "enemies")

# PHASE 4 OPTIMIZATION: Initialize MultiMesh and QuadMesh pools for reuse
func _initialize_pools() -> void:
	if _pool_initialized:
		return
	
	# Pre-allocate MultiMesh instances for reuse (typically need 5-6 instances)
	for i in range(10):  # Pre-allocate more than needed for safety
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = true
		multimesh.instance_count = 0
		_multimesh_pool.append(multimesh)
	
	# Pre-allocate common QuadMesh sizes for reuse
	var common_sizes = [
		Vector2(8, 8),    # Projectiles
		Vector2(32, 32),  # Swarm, Regular enemies
		Vector2(48, 48),  # Elite enemies
		Vector2(56, 56)   # Boss enemies
	]
	
	for size in common_sizes:
		var size_key = "%dx%d" % [size.x, size.y]
		var quad_mesh = QuadMesh.new()
		quad_mesh.size = size
		_quadmesh_pool[size_key] = quad_mesh
	
	_pool_initialized = true
	Logger.debug("MultiMesh and QuadMesh pools initialized (%d MultiMesh, %d QuadMesh)" % [
		_multimesh_pool.size(), _quadmesh_pool.size()
	], "enemies")

# PHASE 4 OPTIMIZATION: Get reusable MultiMesh from pool
func _get_pooled_multimesh() -> MultiMesh:
	if not _pool_initialized:
		_initialize_pools()
	
	if _multimesh_pool.size() > 0:
		var multimesh = _multimesh_pool.pop_back()
		# Reset to clean state
		multimesh.instance_count = 0
		multimesh.mesh = null
		return multimesh
	else:
		# Pool exhausted, create new one (fallback)
		Logger.warn("MultiMesh pool exhausted, creating new instance", "enemies")
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = true
		multimesh.instance_count = 0
		return multimesh

# PHASE 4 OPTIMIZATION: Get reusable QuadMesh from pool
func _get_pooled_quadmesh(size: Vector2) -> QuadMesh:
	if not _pool_initialized:
		_initialize_pools()
	
	var size_key = "%dx%d" % [size.x, size.y]
	if _quadmesh_pool.has(size_key):
		return _quadmesh_pool[size_key]
	else:
		# Size not in pool, create and cache it
		Logger.debug("Creating new QuadMesh for size %s" % size_key, "enemies")
		var quad_mesh = QuadMesh.new()
		quad_mesh.size = size
		_quadmesh_pool[size_key] = quad_mesh
		return quad_mesh

func _setup_projectile_multimesh() -> void:
	# PHASE 4 OPTIMIZATION: Use pooled MultiMesh and QuadMesh instead of creating new ones
	var multimesh := _get_pooled_multimesh()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := _get_pooled_quadmesh(Vector2(8, 8))
	multimesh.mesh = quad_mesh

	# Basic projectile texture for visual feedback - skip in headless mode
	if DisplayServer.get_name() != "headless":
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 0.0, 1.0))  # Yellow projectiles
		var tex := ImageTexture.create_from_image(img)
		mm_projectiles.texture = tex
	mm_projectiles.z_index = 2  # Above walls

	mm_projectiles.multimesh = multimesh
	if mm_projectiles.texture == null:
		mm_projectiles.texture = _get_shared_dummy_texture()

func _setup_tier_multimeshes() -> void:
	# Load knight sprite once - skip entirely in headless mode to avoid texture errors
	var knight_texture: Texture2D = null
	if DisplayServer.get_name() != "headless":
		knight_texture = load("res://assets/sprites/knight.png") as Texture2D
	
	# Setup SWARM tier MultiMesh (small squares) - PHASE 4 OPTIMIZED
	var swarm_multimesh := _get_pooled_multimesh()
	swarm_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	swarm_multimesh.use_colors = true
	swarm_multimesh.instance_count = 0
	var swarm_mesh := _get_pooled_quadmesh(Vector2(32, 32))  # 32x32 to match knight sprite frame
	swarm_multimesh.mesh = swarm_mesh
	
	# Load knight sprite for swarm enemies (static frame)
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
	
	# Setup REGULAR tier MultiMesh (medium rectangles) - PHASE 4 OPTIMIZED
	var regular_multimesh := _get_pooled_multimesh()
	regular_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	regular_multimesh.use_colors = true
	regular_multimesh.instance_count = 0
	var regular_mesh := _get_pooled_quadmesh(Vector2(32, 32))  # 32x32 to match knight sprite frame
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
	
	# Setup ELITE tier MultiMesh (large diamonds) - PHASE 4 OPTIMIZED
	var elite_multimesh := _get_pooled_multimesh()
	elite_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	elite_multimesh.use_colors = true
	elite_multimesh.instance_count = 0
	var elite_mesh := _get_pooled_quadmesh(Vector2(48, 48))  # Larger elite size 
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
	
	# Setup BOSS tier MultiMesh (large diamonds) - PHASE 4 OPTIMIZED
	var boss_multimesh := _get_pooled_multimesh()
	boss_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	boss_multimesh.use_colors = true
	boss_multimesh.instance_count = 0
	var boss_mesh := _get_pooled_quadmesh(Vector2(56, 56))  # Largest size for boss distinction (SWARM:32, REGULAR:32, ELITE:48, BOSS:56)
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
