class_name MultiMeshManager
extends Node

## Lightweight MultiMesh rendering system for high-count entities
## Use cases: Ghost swarms (1000+ visual-only enemies), projectiles (200+ simultaneous)
## Foundation only - scene-based enemies remain primary for complex behaviors

# MultiMesh node references (injected from Arena)
var mm_projectiles: MultiMeshInstance2D
var mm_ghost_swarm: MultiMeshInstance2D

# Shared dummy texture for headless/textureless runs
var _shared_dummy_tex: ImageTexture

# Object pools for memory efficiency (pre-allocated reuse)
var _multimesh_pool: Array[MultiMesh] = []
var _quadmesh_pool: Dictionary = {}  # size_key -> QuadMesh
var _pool_initialized: bool = false

func _get_shared_dummy_texture() -> Texture2D:
	if _shared_dummy_tex:
		return _shared_dummy_tex
	# Create minimal 1x1 texture for headless mode
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	_shared_dummy_tex = ImageTexture.create_from_image(img)
	return _shared_dummy_tex

## Initialize MultiMeshManager with node references
func setup(projectiles: MultiMeshInstance2D, ghost_swarm: MultiMeshInstance2D) -> void:
	mm_projectiles = projectiles
	mm_ghost_swarm = ghost_swarm

	# Initialize object pools before setup
	_initialize_pools()

	_setup_projectile_multimesh()
	_setup_ghost_swarm_multimesh()

	Logger.info("MultiMeshManager initialized (ghost swarms + projectiles)", "rendering")

## Pre-allocate MultiMesh and QuadMesh pools for reuse
func _initialize_pools() -> void:
	if _pool_initialized:
		return

	# Pre-allocate 10 MultiMesh instances (typically need 2-3)
	for i in range(10):
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = false  # No per-instance colors (use self_modulate)
		multimesh.instance_count = 0
		_multimesh_pool.append(multimesh)

	# Pre-allocate common QuadMesh sizes
	var common_sizes = [
		Vector2(8, 8),    # Projectiles
		Vector2(32, 32),  # Ghost enemies
	]

	for size in common_sizes:
		var size_key = "%dx%d" % [size.x, size.y]
		var quad_mesh = QuadMesh.new()
		quad_mesh.size = size
		_quadmesh_pool[size_key] = quad_mesh

	_pool_initialized = true
	Logger.debug("MultiMesh pools initialized (%d MultiMesh, %d QuadMesh)" % [
		_multimesh_pool.size(), _quadmesh_pool.size()
	], "rendering")

## Get reusable MultiMesh from pool
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
		# Pool exhausted, create new (fallback)
		Logger.warn("MultiMesh pool exhausted, creating new instance", "rendering")
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = false
		multimesh.instance_count = 0
		return multimesh

## Get reusable QuadMesh from pool
func _get_pooled_quadmesh(size: Vector2) -> QuadMesh:
	if not _pool_initialized:
		_initialize_pools()

	var size_key = "%dx%d" % [size.x, size.y]
	if _quadmesh_pool.has(size_key):
		return _quadmesh_pool[size_key]
	else:
		# Size not in pool, create and cache it
		Logger.debug("Creating new QuadMesh for size %s" % size_key, "rendering")
		var quad_mesh = QuadMesh.new()
		quad_mesh.size = size
		_quadmesh_pool[size_key] = quad_mesh
		return quad_mesh

func _setup_projectile_multimesh() -> void:
	# Use pooled MultiMesh and QuadMesh
	var multimesh := _get_pooled_multimesh()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = 0

	var quad_mesh := _get_pooled_quadmesh(Vector2(8, 8))
	multimesh.mesh = quad_mesh

	# Basic projectile texture - skip in headless mode
	if DisplayServer.get_name() != "headless":
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 0.0, 1.0))  # Yellow projectiles
		var tex := ImageTexture.create_from_image(img)
		mm_projectiles.texture = tex
	mm_projectiles.z_index = 2  # Above walls

	mm_projectiles.multimesh = multimesh
	if DisplayServer.get_name() != "headless" and mm_projectiles.texture == null:
		mm_projectiles.texture = _get_shared_dummy_texture()

func _setup_ghost_swarm_multimesh() -> void:
	# Simple ghost swarm setup (static sprite, no animation)
	var multimesh := _get_pooled_multimesh()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = false
	multimesh.instance_count = 0

	var mesh_size = Vector2(32, 32)
	var ghost_mesh := _get_pooled_quadmesh(mesh_size)
	multimesh.mesh = ghost_mesh

	# Semi-transparent white ghosts for visual effect
	if DisplayServer.get_name() != "headless":
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 1.0, 1.0, 0.6))  # Semi-transparent white
		var ghost_tex := ImageTexture.create_from_image(img)
		mm_ghost_swarm.texture = ghost_tex

	mm_ghost_swarm.multimesh = multimesh
	if DisplayServer.get_name() != "headless" and mm_ghost_swarm.texture == null:
		mm_ghost_swarm.texture = _get_shared_dummy_texture()

	# Visual styling for ghosts
	mm_ghost_swarm.self_modulate = Color(0.8, 0.9, 1.0, 0.7)  # Slight blue tint, transparent
	mm_ghost_swarm.z_index = 0  # Same layer as enemies

## Update projectile transforms (called by projectile system)
func update_projectiles(projectile_data: Array[Dictionary]) -> void:
	if not mm_projectiles or not mm_projectiles.multimesh:
		return

	var count := projectile_data.size()
	mm_projectiles.multimesh.instance_count = count

	for i in range(count):
		var projectile := projectile_data[i]
		var proj_transform := Transform2D()
		proj_transform.origin = projectile.get("pos", Vector2.ZERO)

		# Optional: Add rotation for directional projectiles
		if projectile.has("rotation"):
			proj_transform = proj_transform.rotated(projectile["rotation"])

		mm_projectiles.multimesh.set_instance_transform_2d(i, proj_transform)

## Update ghost swarm transforms (called by GhostSwarmSpawner)
func update_ghost_swarm(ghost_positions: PackedVector2Array) -> void:
	if not mm_ghost_swarm or not mm_ghost_swarm.multimesh:
		return

	var count := ghost_positions.size()
	mm_ghost_swarm.multimesh.instance_count = count

	for i in range(count):
		var ghost_transform := Transform2D()
		ghost_transform.origin = ghost_positions[i]
		mm_ghost_swarm.multimesh.set_instance_transform_2d(i, ghost_transform)

## Clear all ghost swarm instances (called when wave ends)
func clear_ghost_swarm() -> void:
	if mm_ghost_swarm and mm_ghost_swarm.multimesh:
		mm_ghost_swarm.multimesh.instance_count = 0

## Clear all projectile instances
func clear_projectiles() -> void:
	if mm_projectiles and mm_projectiles.multimesh:
		mm_projectiles.multimesh.instance_count = 0

## Set custom texture for ghost swarm (for visual variety)
func set_ghost_texture(texture: Texture2D) -> void:
	if mm_ghost_swarm:
		mm_ghost_swarm.texture = texture

## Set custom color modulation for ghost swarm
func set_ghost_modulate(color: Color) -> void:
	if mm_ghost_swarm:
		mm_ghost_swarm.self_modulate = color
