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

	# 8x8 yellow point as texture
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 0.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	mm_projectiles.texture = tex
	mm_projectiles.z_index = 2  # Above walls

	mm_projectiles.multimesh = multimesh

func _setup_tier_multimeshes() -> void:
	# Setup SWARM tier MultiMesh (small squares)
	var swarm_multimesh := MultiMesh.new()
	swarm_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	swarm_multimesh.use_colors = true
	swarm_multimesh.instance_count = 0
	var swarm_mesh := QuadMesh.new()
	swarm_mesh.size = Vector2(32, 32)  # 32x32 to match knight sprite frame
	swarm_multimesh.mesh = swarm_mesh
	
	# Texture will be set by EnemyAnimationSystem
	mm_enemies_swarm.multimesh = swarm_multimesh
	mm_enemies_swarm.z_index = 0  # Gameplay entities layer
	
	# Setup REGULAR tier MultiMesh (medium rectangles)
	var regular_multimesh := MultiMesh.new()
	regular_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	regular_multimesh.use_colors = true
	regular_multimesh.instance_count = 0
	var regular_mesh := QuadMesh.new()
	regular_mesh.size = Vector2(32, 32)  # 32x32 to match knight sprite frame
	regular_multimesh.mesh = regular_mesh
	# Texture will be set by EnemyAnimationSystem
	mm_enemies_regular.multimesh = regular_multimesh
	mm_enemies_regular.z_index = 0  # Gameplay entities layer
	
	# Setup ELITE tier MultiMesh (large diamonds)
	var elite_multimesh := MultiMesh.new()
	elite_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	elite_multimesh.use_colors = true
	elite_multimesh.instance_count = 0
	var elite_mesh := QuadMesh.new()
	elite_mesh.size = Vector2(48, 48)  # Larger elite size 
	elite_multimesh.mesh = elite_mesh
	# Texture will be set by EnemyAnimationSystem
	mm_enemies_elite.multimesh = elite_multimesh
	mm_enemies_elite.z_index = 0  # Gameplay entities layer
	
	# Setup BOSS tier MultiMesh (large diamonds)
	var boss_multimesh := MultiMesh.new()
	boss_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	boss_multimesh.use_colors = true
	boss_multimesh.instance_count = 0
	var boss_mesh := QuadMesh.new()
	boss_mesh.size = Vector2(56, 56)  # Largest size for boss distinction (SWARM:32, REGULAR:32, ELITE:48, BOSS:56)
	boss_multimesh.mesh = boss_mesh
	# Texture will be set by EnemyAnimationSystem
	mm_enemies_boss.multimesh = boss_multimesh
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
		mm_instance.multimesh.instance_count = count
		
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
