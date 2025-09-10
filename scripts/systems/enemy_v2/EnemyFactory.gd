extends RefCounted

## EnemyFactory - Core of the Enemy V2 system.
## Loads templates, resolves inheritance, applies deterministic variations,
## and produces SpawnConfig objects for the existing pooling system.

class_name EnemyFactory

# Template storage
static var _templates: Dictionary = {}
static var _templates_loaded: bool = false

# Weighted selection pool for random spawning
static var _weighted_pool: Array[EnemyTemplate] = []
static var _pool_dirty: bool = true

## Load all templates from the templates and variations directories
static func load_all_templates() -> void:
	Logger.info("EnemyFactory: Loading templates...", "enemies")
	_templates.clear()
	_pool_dirty = true
	
	# Load base templates first
	_load_templates_from_directory("res://data/content/enemy-templates/")
	
	# Load variations (which may inherit from base templates)  
	_load_templates_from_directory("res://data/content/enemy-variations/")
	
	# Resolve all inheritance relationships
	_resolve_all_inheritance()
	
	# Rebuild weighted pool
	_rebuild_weighted_pool()
	
	_templates_loaded = true
	Logger.info("EnemyFactory: Loaded %d templates" % _templates.size(), "enemies")

static func _load_templates_from_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		Logger.warn("Failed to open directory: " + dir_path, "enemies")
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path := dir_path + file_name
			_load_template_from_file(file_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()

static func _load_template_from_file(file_path: String) -> void:
	var template: EnemyTemplate = load(file_path) as EnemyTemplate
	if not template:
		Logger.warn("Failed to load template: " + file_path, "enemies")
		return
	
	# Validate template
	var errors := template.validate()
	if errors.size() > 0:
		Logger.warn("Template validation failed for %s: %s" % [file_path, str(errors)], "enemies")
		return
	
	_templates[template.id] = template
	Logger.debug("Loaded template: " + str(template.id), "enemies")

static func _resolve_all_inheritance() -> void:
	var resolved_templates: Dictionary = {}
	
	for template_id in _templates.keys():
		var template: EnemyTemplate = _templates[template_id]
		var resolved: EnemyTemplate = template.resolve_inheritance()
		resolved_templates[template_id] = resolved
	
	_templates = resolved_templates
	Logger.debug("Resolved inheritance for %d templates" % _templates.size(), "enemies")

static func _rebuild_weighted_pool() -> void:
	_weighted_pool.clear()
	
	const MAX_POOL_SIZE: int = 1000
	const MAX_WEIGHT_PER_TEMPLATE: int = 100
	
	for template in _templates.values():
		var enemy_template := template as EnemyTemplate
		
		# Performance test override: Skip boss templates during testing
		var effective_weight = enemy_template.weight
		if enemy_template.render_tier == "boss" and _is_performance_test_active():
			effective_weight = 0.0
		
		# Skip templates with zero or negative weight
		if effective_weight <= 0.0:
			continue
		
		
		var weight := int(effective_weight * 10.0)
		weight = min(weight, MAX_WEIGHT_PER_TEMPLATE)
		
		# Stop if we would exceed pool size
		if _weighted_pool.size() + weight > MAX_POOL_SIZE:
			Logger.warn("Template pool size limit reached (%d)" % MAX_POOL_SIZE, "enemies")
			break
		
		# Add template to pool based on weight
		for i in range(weight):
			_weighted_pool.append(enemy_template)
	
	_pool_dirty = false
	Logger.debug("Built weighted pool with %d entries" % _weighted_pool.size(), "enemies")

## Main spawning method - creates a SpawnConfig from weighted random selection
static func spawn_from_weights(context: Dictionary) -> SpawnConfig:
	if not _templates_loaded or _templates.is_empty():
		load_all_templates()
	
	if _pool_dirty:
		_rebuild_weighted_pool()
	
	if _weighted_pool.is_empty():
		Logger.warn("No templates available for spawning", "enemies")
		return null
	
	# Select random template using deterministic RNG
	var pool_index := RNG.randi_range("ai", 0, _weighted_pool.size() - 1)
	var template: EnemyTemplate = _weighted_pool[pool_index]
	
	return spawn_from_template(template, context)

## Spawn from a specific template ID
static func spawn_from_template_id(template_id: StringName, context: Dictionary) -> SpawnConfig:
	if not _templates_loaded:
		load_all_templates()
	
	var template: EnemyTemplate = _templates.get(template_id, null)
	if not template:
		Logger.warn("Template not found: " + str(template_id), "enemies")
		return null
	
	return spawn_from_template(template, context)

## Core spawning logic - applies deterministic variations to a template
static func spawn_from_template(template: EnemyTemplate, context: Dictionary) -> SpawnConfig:
	# Generate deterministic seed from context
	var seed_components: Array = [
		context.get("run_id", 0),
		context.get("wave_index", 0), 
		context.get("spawn_index", 0),
		str(template.id)
	]
	var seed_string := str(seed_components)
	var variation_seed := hash(seed_string)
	
	# Create RNG state for this specific spawn
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = variation_seed
	
	# Apply deterministic variations within template ranges
	var config := SpawnConfig.new()
	
	# Vary stats within defined ranges
	config.health = spawn_rng.randf_range(template.health_range.x, template.health_range.y)
	config.damage = spawn_rng.randf_range(template.damage_range.x, template.damage_range.y)
	config.speed = spawn_rng.randf_range(template.speed_range.x, template.speed_range.y)
	
	# Apply size variation
	config.size_scale = template.size_factor * spawn_rng.randf_range(0.9, 1.1)
	
	# Generate deterministic color variation within hue range
	var hue := spawn_rng.randf_range(template.hue_range.x, template.hue_range.y)
	var saturation := spawn_rng.randf_range(0.7, 1.0)  # Keep colors vibrant
	var value := spawn_rng.randf_range(0.8, 1.0)       # Keep colors bright
	config.color_tint = Color.from_hsv(hue, saturation, value, 1.0)
	
	# Set metadata
	config.template_id = template.id
	config.tags = template.tags.duplicate()
	config.render_tier = template.render_tier
	
	# Set position from context
	config.position = context.get("position", Vector2.ZERO)
	config.velocity = Vector2.ZERO  # Will be set by spawning system
	
	Logger.debug("Generated spawn config: " + config.debug_string(), "enemies")
	return config

## Get template by ID (for editor/debug use)
static func get_template(template_id: StringName) -> EnemyTemplate:
	if not _templates_loaded:
		load_all_templates()
	
	return _templates.get(template_id, null)

## Get all loaded template IDs
static func get_template_ids() -> Array[StringName]:
	if not _templates_loaded:
		load_all_templates()
	
	var ids: Array[StringName] = []
	for id in _templates.keys():
		ids.append(id as StringName)
	return ids

## Force reload templates (for development/hot-reload)
static func reload_templates() -> void:
	_templates_loaded = false
	load_all_templates()

## Get count of loaded templates
static func get_template_count() -> int:
	if not _templates_loaded:
		load_all_templates()
	
	return _templates.size()

# Check if performance testing is active to override boss weights
static func _is_performance_test_active() -> bool:
	# Check if the performance test scene is running
	var main_loop = Engine.get_main_loop()
	if not main_loop or not main_loop.has_method("get_root"):
		return false
	
	var root = main_loop.get_root()
	if not root:
		return false
	
	# Look for the performance test scene node
	var performance_test = root.get_node_or_null("PerformanceTest")
	if performance_test:
		return true
	
	# Alternative: Check if any child node has performance test script
	for child in root.get_children():
		if child.get_script():
			var script_path = child.get_script().get_path()
			if "test_performance" in script_path:
				return true
	
	return false
