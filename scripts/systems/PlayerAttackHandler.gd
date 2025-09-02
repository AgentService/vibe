class_name PlayerAttackHandler
extends Node

# Handles player input to attack system conversion
# Manages melee attacks, projectile attacks, auto-attacks, and debug spawning

# Dependencies injected from Arena
var player: Player
var melee_system: MeleeSystem
var ability_system: AbilitySystem
var wave_director: WaveDirector
var melee_effects_node: Node2D
var arena_viewport: Viewport

# Internal state for debug projectile spawning
var spawn_timer: float = 0.0
var base_spawn_interval: float = 0.25

func setup(player_ref: Player, melee_sys: MeleeSystem, ability_sys: AbilitySystem, wave_dir: WaveDirector, melee_fx: Node2D, viewport: Viewport) -> void:
	player = player_ref
	melee_system = melee_sys
	ability_system = ability_sys
	wave_director = wave_dir
	melee_effects_node = melee_fx
	arena_viewport = viewport
	Logger.info("PlayerAttackHandler initialized", "player")

# Handle melee attack at target position
func handle_melee_attack(target_pos: Vector2) -> void:
	if not player or not melee_system:
		return
	
	var player_pos = player.global_position
	var alive_enemies = wave_director.get_alive_enemies()
	melee_system.perform_attack(player_pos, target_pos, alive_enemies)

# Handle projectile attack toward target position  
func handle_projectile_attack(target_pos: Vector2) -> void:
	if not player or not ability_system:
		return
	
	spawn_debug_projectile(target_pos)

# Handle auto-attack if enabled
func handle_auto_attack() -> void:
	if not melee_system.auto_attack_enabled or not player:
		return
	
	var player_pos = player.global_position
	var alive_enemies = wave_director.get_alive_enemies()
	
	# Only attack if there are enemies nearby
	if alive_enemies.size() > 0:
		melee_system.perform_attack(player_pos, melee_system.auto_attack_target, alive_enemies)

# Update debug spawning (called from process)
func handle_debug_spawning(delta: float) -> void:
	# Only auto-shoot projectiles if player has projectile abilities
	if not RunManager.stats.get("has_projectiles", false):
		return
		
	spawn_timer += delta
	var current_interval: float = base_spawn_interval / RunManager.stats.fire_rate_mult
	
	if spawn_timer >= current_interval:
		spawn_timer = 0.0
		spawn_debug_projectile()

# Spawn a debug projectile toward mouse position
func spawn_debug_projectile(target_pos: Vector2 = Vector2.ZERO) -> void:
	if not player:
		return
	
	var spawn_pos: Vector2 = player.global_position
	var mouse_pos := target_pos
	# If no target provided, get world mouse position from viewport
	if mouse_pos == Vector2.ZERO and arena_viewport:
		var screen_pos = arena_viewport.get_mouse_position()
		mouse_pos = arena_viewport.get_camera_2d().get_global_transform() * screen_pos
	var direction := (mouse_pos - spawn_pos).normalized()

	var projectile_count: int = 1 + RunManager.stats.projectile_count_add
	var base_speed: float = 480.0 * RunManager.stats.projectile_speed_mult
	
	for i in range(projectile_count):
		var spread: float = 0.0
		if projectile_count > 1:
			var spread_range: float = 0.4
			spread = RNG.randf_range("waves", -spread_range, spread_range) * (i - projectile_count / 2.0)
		
		var final_direction: Vector2 = direction.rotated(spread)
		ability_system.spawn_projectile(spawn_pos, final_direction, base_speed, 2.0)

# Handle melee attack started event for visual effects
func on_melee_attack_started(player_pos: Vector2, target_pos: Vector2) -> void:
	show_melee_cone_effect(player_pos, target_pos)

# Show melee cone visual effect
func show_melee_cone_effect(player_pos: Vector2, target_pos: Vector2) -> void:
	# Use manually created polygon from the scene
	var cone_polygon = melee_effects_node.get_node("MeleeCone")
	if not cone_polygon:
		return
	
	# Get effective melee stats to match the actual damage area
	var effective_range = melee_system._get_effective_range()
	var range_scale = effective_range / 100.0  # Assuming your cone is ~100 units long
	
	# Position and scale the cone at player position
	cone_polygon.global_position = player_pos
	cone_polygon.scale = Vector2(range_scale, range_scale)  # Scale to match damage range
	
	# Point the cone toward mouse/target position (where damage occurs)
	var attack_dir = (target_pos - player_pos).normalized()
	cone_polygon.rotation = attack_dir.angle() - PI/2  # Fix 90° offset (cone was 1/4 ahead)
	
	# Show the cone with transparency
	cone_polygon.visible = true
	cone_polygon.modulate.a = 0.3
	
	# Hide after short duration
	var tween = create_tween()
	tween.tween_property(cone_polygon, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): cone_polygon.visible = false)
