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

# PHASE C: 30Hz update decimation variables
var _last_30hz_update: float = 0.0
var _transform_update_needed: bool = true

# MULTIMESH INVESTIGATION: Feature flags for stepwise performance testing
var investigation_step_1_colors_disabled: bool = true  # Already implemented
var investigation_step_2_early_preallocation: bool = false
var investigation_step_3_30hz_only: bool = false  # false = 60Hz, true = 30Hz only
var investigation_step_4_bypass_grouping: bool = false
var investigation_step_5_single_multimesh: bool = false
var investigation_step_6_no_textures: bool = false
var investigation_step_7_position_only: bool = false
var investigation_step_8_static_transforms: bool = false
var investigation_step_9_minimal_baseline: bool = false

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
	# Create minimal 1x1 texture even in headless mode to prevent null texture errors
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
	
	# PHASE C: Connect to combat_step for 30Hz update decimation
	if EventBus.combat_step.connect(_on_combat_step) != OK:
		Logger.warn("Failed to connect to EventBus.combat_step", "enemies")
	
	Logger.info("MultiMeshManager initialized with optimized pools", "enemies")

# PHASE 4 OPTIMIZATION: Initialize MultiMesh and QuadMesh pools for reuse
func _initialize_pools() -> void:
	if _pool_initialized:
		return
	
	# Pre-allocate MultiMesh instances for reuse (typically need 5-6 instances)
	for i in range(10):  # Pre-allocate more than needed for safety
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = false  # PHASE A: Disable per-instance colors for performance
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
		multimesh.use_colors = false  # PHASE A: Disable per-instance colors for performance
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
	# Skip all texture operations in headless mode to prevent console errors
	if DisplayServer.get_name() != "headless" and mm_projectiles.texture == null:
		mm_projectiles.texture = _get_shared_dummy_texture()

func _setup_tier_multimeshes() -> void:
	# Skip all texture operations in headless mode to prevent errors
	var is_headless = DisplayServer.get_name() == "headless"
	var knight_texture: Texture2D = null
	if not is_headless:
		knight_texture = load("res://assets/sprites/knight.png") as Texture2D
	
	# Setup SWARM tier MultiMesh (small squares) - PHASE 4 OPTIMIZED
	var swarm_multimesh := _get_pooled_multimesh()
	swarm_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	swarm_multimesh.use_colors = false  # PHASE A: Disable per-instance colors for performance
	swarm_multimesh.instance_count = 0
	
	# INVESTIGATION STEP 6: Simplified mesh without textures
	var swarm_mesh_size = Vector2(32, 32)
	if investigation_step_6_no_textures or investigation_step_9_minimal_baseline:
		swarm_mesh_size = Vector2(16, 16)  # Smaller for minimal baseline
	var swarm_mesh := _get_pooled_quadmesh(swarm_mesh_size)
	swarm_multimesh.mesh = swarm_mesh
	
	# INVESTIGATION STEP 6: Skip texture loading entirely
	if not investigation_step_6_no_textures and not investigation_step_9_minimal_baseline:
		# Load knight sprite for swarm enemies (static frame) - skip in headless mode
		if knight_texture and not is_headless:
			# Extract first frame (32x32) from knight spritesheet
			var knight_image := knight_texture.get_image()
			var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			frame_image.blit_rect(knight_image, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
			var swarm_tex := ImageTexture.create_from_image(frame_image)
			mm_enemies_swarm.texture = swarm_tex
		mm_enemies_swarm.multimesh = swarm_multimesh
		# Skip texture checks in headless mode to prevent console errors
		if not is_headless and mm_enemies_swarm.texture == null:
			mm_enemies_swarm.texture = _get_shared_dummy_texture()
	else:
		# No textures for investigation steps or headless mode - skip texture assignment entirely in headless
		if not is_headless:
			mm_enemies_swarm.texture = null
		mm_enemies_swarm.multimesh = swarm_multimesh
	
	# PHASE A: Set per-tier color once via self_modulate instead of per-instance colors
	mm_enemies_swarm.self_modulate = get_tier_debug_color(EnemyRenderTier_Type.Tier.SWARM)
	mm_enemies_swarm.z_index = 0  # Gameplay entities layer
	
	# Setup REGULAR tier MultiMesh (medium rectangles) - PHASE 4 OPTIMIZED
	var regular_multimesh := _get_pooled_multimesh()
	regular_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	regular_multimesh.use_colors = false  # PHASE A: Disable per-instance colors for performance
	regular_multimesh.instance_count = 0
	var regular_mesh := _get_pooled_quadmesh(Vector2(32, 32))  # 32x32 to match knight sprite frame
	regular_multimesh.mesh = regular_mesh
	# Load knight sprite for regular enemies (static frame) - skip in headless mode
	if knight_texture and not is_headless:
		# Extract second frame (32x32) from knight spritesheet
		var knight_image := knight_texture.get_image()
		var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(32, 0, 32, 32), Vector2i.ZERO)
		var regular_tex := ImageTexture.create_from_image(frame_image)
		mm_enemies_regular.texture = regular_tex
	mm_enemies_regular.multimesh = regular_multimesh
	# Skip texture checks in headless mode to prevent console errors
	if not is_headless and mm_enemies_regular.texture == null:
		mm_enemies_regular.texture = _get_shared_dummy_texture()
	# PHASE A: Set per-tier color once via self_modulate instead of per-instance colors
	mm_enemies_regular.self_modulate = get_tier_debug_color(EnemyRenderTier_Type.Tier.REGULAR)
	mm_enemies_regular.z_index = 0  # Gameplay entities layer
	
	# Setup ELITE tier MultiMesh (large diamonds) - PHASE 4 OPTIMIZED
	var elite_multimesh := _get_pooled_multimesh()
	elite_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	elite_multimesh.use_colors = false  # PHASE A: Disable per-instance colors for performance
	elite_multimesh.instance_count = 0
	var elite_mesh := _get_pooled_quadmesh(Vector2(48, 48))  # Larger elite size 
	elite_multimesh.mesh = elite_mesh
	# Load knight sprite for elite enemies (static frame) - skip in headless mode
	if knight_texture and not is_headless:
		# Extract third frame (32x32) from knight spritesheet, scale to 48x48
		var knight_image := knight_texture.get_image()
		var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(64, 0, 32, 32), Vector2i.ZERO)
		frame_image.resize(48, 48)  # Scale up for elite
		var elite_tex := ImageTexture.create_from_image(frame_image)
		mm_enemies_elite.texture = elite_tex
	mm_enemies_elite.multimesh = elite_multimesh
	# Skip texture checks in headless mode to prevent console errors
	if not is_headless and mm_enemies_elite.texture == null:
		mm_enemies_elite.texture = _get_shared_dummy_texture()
	# PHASE A: Set per-tier color once via self_modulate instead of per-instance colors
	mm_enemies_elite.self_modulate = get_tier_debug_color(EnemyRenderTier_Type.Tier.ELITE)
	mm_enemies_elite.z_index = 0  # Gameplay entities layer
	
	# Setup BOSS tier MultiMesh (large diamonds) - PHASE 4 OPTIMIZED
	var boss_multimesh := _get_pooled_multimesh()
	boss_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	boss_multimesh.use_colors = false  # PHASE A: Disable per-instance colors for performance
	boss_multimesh.instance_count = 0
	var boss_mesh := _get_pooled_quadmesh(Vector2(56, 56))  # Largest size for boss distinction (SWARM:32, REGULAR:32, ELITE:48, BOSS:56)
	boss_multimesh.mesh = boss_mesh
	# Load knight sprite for boss enemies (static frame) - skip in headless mode
	if knight_texture and not is_headless:
		# Extract fourth frame (32x32) from knight spritesheet, scale to 56x56
		var knight_image := knight_texture.get_image()
		var frame_image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		frame_image.blit_rect(knight_image, Rect2i(96, 0, 32, 32), Vector2i.ZERO)
		frame_image.resize(56, 56)  # Scale up for boss
		var boss_tex := ImageTexture.create_from_image(frame_image)
		mm_enemies_boss.texture = boss_tex
	mm_enemies_boss.multimesh = boss_multimesh
	# Skip texture checks in headless mode to prevent console errors
	if not is_headless and mm_enemies_boss.texture == null:
		mm_enemies_boss.texture = _get_shared_dummy_texture()
	# PHASE A: Set per-tier color once via self_modulate instead of per-instance colors
	mm_enemies_boss.self_modulate = get_tier_debug_color(EnemyRenderTier_Type.Tier.BOSS)
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
	
	# INVESTIGATION STEP 4: Bypass grouping overhead
	if investigation_step_4_bypass_grouping:
		_update_enemies_direct(alive_enemies)
		return
	
	# PHASE B: Use light grouping API to avoid per-frame allocations
	var tier_groups := enemy_render_tier.group_enemies_by_tier_light(alive_enemies)
	
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

# INVESTIGATION STEP 4: Direct enemy update bypassing grouping overhead
func _update_enemies_direct(alive_enemies: Array[EnemyEntity]) -> void:
	# INVESTIGATION STEP 5: Single multimesh mode - use only mm_enemies_swarm
	if investigation_step_5_single_multimesh:
		_update_single_multimesh(alive_enemies)
		return
	
	# Direct update without grouping - still use multiple tiers but skip allocation overhead
	# For simplicity, just put all enemies in SWARM tier for this step
	if is_instance_valid(mm_enemies_swarm):
		_update_tier_multimesh(alive_enemies, mm_enemies_swarm, Vector2(32, 32), EnemyRenderTier_Type.Tier.SWARM)
	
	# Set other tiers to 0 instances
	if is_instance_valid(mm_enemies_regular) and mm_enemies_regular.multimesh:
		mm_enemies_regular.multimesh.instance_count = 0
	if is_instance_valid(mm_enemies_elite) and mm_enemies_elite.multimesh:
		mm_enemies_elite.multimesh.instance_count = 0 
	if is_instance_valid(mm_enemies_boss) and mm_enemies_boss.multimesh:
		mm_enemies_boss.multimesh.instance_count = 0

# INVESTIGATION STEP 5: Single multimesh update for all enemies
func _update_single_multimesh(alive_enemies: Array[EnemyEntity]) -> void:
	# Use only mm_enemies_swarm for all enemies
	if is_instance_valid(mm_enemies_swarm):
		_update_tier_multimesh(alive_enemies, mm_enemies_swarm, Vector2(32, 32), EnemyRenderTier_Type.Tier.SWARM)
	
	# Zero out all other multimeshes
	if is_instance_valid(mm_enemies_regular) and mm_enemies_regular.multimesh:
		mm_enemies_regular.multimesh.instance_count = 0
	if is_instance_valid(mm_enemies_elite) and mm_enemies_elite.multimesh:
		mm_enemies_elite.multimesh.instance_count = 0
	if is_instance_valid(mm_enemies_boss) and mm_enemies_boss.multimesh:
		mm_enemies_boss.multimesh.instance_count = 0

# INVESTIGATION STEP 8: Set static transforms once for render-only baseline
func _set_static_transforms_grid(tier_enemies: Array[EnemyEntity], mm_instance: MultiMeshInstance2D, tier: EnemyRenderTier_Type.Tier) -> void:
	# INVESTIGATION STEP 8: Set enemies in a fixed grid pattern for consistent rendering performance test
	# This eliminates per-frame position calculation overhead while still rendering all enemies
	var count = tier_enemies.size()
	var grid_size = ceil(sqrt(count))
	var spacing = 64.0  # Fixed spacing between enemies
	var start_pos = Vector2(200, 200)  # Start position in arena
	
	for i in range(count):
		var grid_x = i % int(grid_size)
		var grid_y = i / int(grid_size)
		var static_pos = start_pos + Vector2(grid_x * spacing, grid_y * spacing)
		
		# Simple transform with no rotation/scaling - just position
		var instance_transform := Transform2D(Vector2.RIGHT, Vector2.UP, static_pos)
		mm_instance.multimesh.set_instance_transform_2d(i, instance_transform)

# INVESTIGATION: Configure investigation step for testing
func set_investigation_step(step_number: int) -> void:
	# Reset all flags first
	investigation_step_1_colors_disabled = true  # Always true (already implemented)
	investigation_step_2_early_preallocation = false
	investigation_step_3_30hz_only = false
	investigation_step_4_bypass_grouping = false
	investigation_step_5_single_multimesh = false
	investigation_step_6_no_textures = false
	investigation_step_7_position_only = false
	investigation_step_8_static_transforms = false
	investigation_step_9_minimal_baseline = false
	
	# Enable specific step(s)
	match step_number:
		1:
			# Colors already disabled (no additional flags needed)
			pass
		2:
			investigation_step_2_early_preallocation = true
		3:
			investigation_step_3_30hz_only = true
		4:
			investigation_step_4_bypass_grouping = true
		5:
			investigation_step_4_bypass_grouping = true
			investigation_step_5_single_multimesh = true
		6:
			investigation_step_4_bypass_grouping = true
			investigation_step_5_single_multimesh = true
			investigation_step_6_no_textures = true
		7:
			investigation_step_4_bypass_grouping = true
			investigation_step_5_single_multimesh = true
			investigation_step_6_no_textures = true
			investigation_step_7_position_only = true
		8:
			investigation_step_4_bypass_grouping = true
			investigation_step_5_single_multimesh = true
			investigation_step_6_no_textures = true
			investigation_step_7_position_only = true
			investigation_step_8_static_transforms = true
		9:
			# Minimal baseline - all optimizations
			investigation_step_2_early_preallocation = true
			investigation_step_3_30hz_only = true
			investigation_step_4_bypass_grouping = true
			investigation_step_5_single_multimesh = true
			investigation_step_6_no_textures = true
			investigation_step_7_position_only = true
			investigation_step_9_minimal_baseline = true
	
	Logger.info("Investigation step %d configured" % step_number, "enemies")

# PHASE C: Combat step handler for 30Hz update decimation
func _on_combat_step(payload) -> void:
	_transform_update_needed = true

func _update_tier_multimesh(tier_enemies: Array[EnemyEntity], mm_instance: MultiMeshInstance2D, _base_size: Vector2, tier: EnemyRenderTier_Type.Tier) -> void:
	# Safety check: ensure mm_instance is valid and not freed
	if not is_instance_valid(mm_instance):
		Logger.warn("MultiMeshInstance2D is invalid/freed for tier %s" % tier, "enemies")
		return
	
	var count := tier_enemies.size()
	if mm_instance and mm_instance.multimesh:
		# PHASE 1: Track instance count changes for potential memory leaks
		var previous_count = mm_instance.multimesh.instance_count
		
		# INVESTIGATION STEP 2: Early preallocation to avoid mid-phase buffer resizes
		if investigation_step_2_early_preallocation:
			# Pre-grow to target capacity (500 divided among tiers)
			var target_capacity = 1000  # Rough estimate per tier for 1000 total
			if previous_count < target_capacity:
				mm_instance.multimesh.instance_count = target_capacity
				previous_count = target_capacity
		
		# PHASE A: Update instance_count to match actual alive enemies
		# Always set to current count to ensure dead enemies are not rendered
		mm_instance.multimesh.instance_count = count
		# This ensures dead enemies are immediately removed from rendering
		
		# Log significant changes in instance count
		if abs(count - previous_count) > 50:  # Log when changes > 50 instances
			Logger.debug("MultiMesh %s: instance_count %d → %d (change: %+d)" % [
				tier, previous_count, count, count - previous_count
			], "enemies")
		
		# PHASE C & INVESTIGATION STEP 3: Transform update frequency control
		var should_update_transforms = true  # Default: always update (60Hz)
		
		if investigation_step_3_30hz_only:
			# Only update when combat step triggered (30Hz decimation)
			should_update_transforms = _transform_update_needed
		else:
			# Always update for 60Hz (default behavior)
			should_update_transforms = true
		
		if should_update_transforms:
			# INVESTIGATION STEP 8: Static transforms - set transforms but don't update them each frame
			if investigation_step_8_static_transforms:
				# Set static transforms at fixed positions for all enemies (performance test)
				# This tests rendering performance without the overhead of per-frame position updates
				_set_static_transforms_grid(tier_enemies, mm_instance, tier)
			else:
				# Normal dynamic transform updates
				for i in range(count):
					var enemy := tier_enemies[i]
					
					# PHASE B: Read fields directly from EnemyEntity instead of Dictionary lookups
					var instance_transform := Transform2D()
					instance_transform.origin = enemy.pos
					
					# INVESTIGATION STEP 7: Position-only transforms (no rotation/scaling)
					if investigation_step_7_position_only or investigation_step_9_minimal_baseline:
						# Only set position, keep basis as identity
						instance_transform = Transform2D(Vector2.RIGHT, Vector2.UP, enemy.pos)
					else:
						# Apply sprite flipping based on movement direction
						if enemy.direction != Vector2.ZERO:
							if enemy.direction.x < 0:
								# Flip horizontally for leftward movement
								instance_transform.x = Vector2(-1, 0)
							else:
								# Normal orientation for rightward movement
								instance_transform.x = Vector2(1, 0)
							instance_transform.y = Vector2(0, 1)
					
					mm_instance.multimesh.set_instance_transform_2d(i, instance_transform)
			
			# Reset the flag after updating
			_transform_update_needed = false
			
			# PHASE A: Per-instance colors removed - now using per-tier self_modulate for performance

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
