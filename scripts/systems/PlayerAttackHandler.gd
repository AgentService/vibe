class_name PlayerAttackHandler
extends Node

# Handles player input to attack system conversion
# Manages melee attacks, projectile attacks, auto-attacks, and debug spawning

# MeleeVisualConfig class loaded via class_name - no preload needed

# Dependencies injected from Arena
var player: Player
var melee_system: MeleeSystem
var wave_director: WaveDirector
var melee_effects_node: Node2D
var arena_viewport: Viewport


# Visual configuration
var visual_config: MeleeVisualConfig

func setup(player_ref: Player, melee_sys: MeleeSystem, wave_dir: WaveDirector, melee_fx: Node2D, viewport: Viewport) -> void:
	player = player_ref
	melee_system = melee_sys
	wave_director = wave_dir
	melee_effects_node = melee_fx
	arena_viewport = viewport
	
	# Connect MeleeSystem's local signal to this handler for both visual effects and EventBus relay
	if melee_system:
		melee_system.melee_attack_started.connect(_on_melee_attack_signal)
	
	# Load visual configuration
	_load_visual_config()
	
	Logger.info("PlayerAttackHandler initialized", "player")

# Handle melee attack at target position
func handle_melee_attack(target_pos: Vector2) -> void:
	if not player or not melee_system:
		return
	
	var player_pos = player.global_position
	var alive_enemies = wave_director.get_alive_enemies()
	melee_system.perform_attack(player_pos, target_pos, alive_enemies)


# Handle auto-attack if enabled
func handle_auto_attack() -> void:
	if not melee_system or not melee_system.auto_attack_enabled or not player:
		return
	
	var player_pos = player.global_position
	var alive_enemies = wave_director.get_alive_enemies()
	
	# Only attack if there are enemies nearby
	if alive_enemies.size() > 0:
		melee_system.perform_attack(player_pos, melee_system.auto_attack_target, alive_enemies)



# Handle melee attack started signal from MeleeSystem
func _on_melee_attack_signal(player_pos: Vector2, target_pos: Vector2) -> void:
	# Show visual effects
	show_melee_cone_effect(player_pos, target_pos)
	
	# Emit to EventBus for player animation
	EventBus.melee_attack_started.emit({
		"player_pos": player_pos,
		"target_pos": target_pos
	})

# Handle melee attack started event for visual effects
func on_melee_attack_started(player_pos: Vector2, target_pos: Vector2) -> void:
	show_melee_cone_effect(player_pos, target_pos)

func _load_visual_config() -> void:
	var config_path = "res://data/content/melee_visual_config.tres"
	visual_config = load(config_path) as MeleeVisualConfig
	if not visual_config:
		Logger.warn("Failed to load melee visual config, using defaults", "player")
		visual_config = MeleeVisualConfig.new()

# Show melee cone visual effect
func show_melee_cone_effect(player_pos: Vector2, target_pos: Vector2) -> void:
	if not visual_config:
		return
	
	# Validate melee_effects_node before accessing
	if not melee_effects_node or not is_instance_valid(melee_effects_node):
		Logger.warn("MeleeEffects node is invalid or null, skipping cone effect", "combat")
		return
		
	# Use manually created polygon from the scene
	var cone_polygon = melee_effects_node.get_node("MeleeCone")
	if not cone_polygon:
		Logger.warn("MeleeCone node not found under MeleeEffects, skipping visual effect", "combat")
		return
	
	# Position the cone at player position
	cone_polygon.global_position = player_pos
	
	# Scale cone based on effective range (if enabled)
	if visual_config.scale_with_range:
		var effective_range = melee_system._get_effective_range()
		var range_scale = effective_range / visual_config.base_range_reference
		cone_polygon.scale = Vector2(range_scale, range_scale)
	else:
		cone_polygon.scale = Vector2.ONE
	
	# Point the cone toward target position
	var attack_dir = (target_pos - player_pos).normalized()
	cone_polygon.rotation = attack_dir.angle() + deg_to_rad(visual_config.rotation_offset)
	
	# Apply visual config
	cone_polygon.visible = true
	cone_polygon.modulate = visual_config.cone_color
	cone_polygon.modulate.a = visual_config.max_opacity
	
	# Kill any existing tween to allow overlapping attacks
	if cone_polygon.has_method("get_tween"):
		var existing_tween = cone_polygon.get_tween()
		if existing_tween:
			existing_tween.kill()
	
	# Fade out based on config - allow interruption for overlapping attacks
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple tweens to run simultaneously
	tween.tween_property(cone_polygon, "modulate:a", 0.0, visual_config.fade_duration)
	tween.tween_callback(func(): 
		if cone_polygon and is_instance_valid(cone_polygon):
			# Only hide if alpha is actually 0 (not interrupted by new attack)
			if cone_polygon.modulate.a <= 0.01:
				cone_polygon.visible = false
	)
