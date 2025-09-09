extends Node

## Modern Debug Interface Manager
## Replaces the legacy cheat system with comprehensive debugging tools
## Provides real-time entity inspection, manual spawning, and ability testing

static var instance: DebugManager

signal debug_mode_toggled(enabled: bool)
signal entity_selected(entity_id: String)
signal entity_inspected(entity_data: Dictionary)
signal spawning_requested(enemy_type: String, position: Vector2, count: int)

var debug_enabled: bool = false  # Start disabled, check config in _ready()
var selected_entity_id: String = ""
var debug_ui: Control
var boss_scaling: BossScaling


# System references for debug operations
var wave_director: WaveDirector
var boss_spawn_manager: BossSpawnManager
var arena_ui_manager: ArenaUIManager
var ability_trigger: DebugAbilityTrigger
var debug_system_controls: DebugSystemControls

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS  # Work during pause
	
	# Load boss scaling configuration
	_load_boss_scaling()
	
	# Create and add DebugAbilityTrigger
	ability_trigger = DebugAbilityTrigger.new()
	add_child(ability_trigger)
	
	# Check debug configuration to determine initial state
	_check_debug_config()
	
	# Initialize debug mode if enabled by configuration
	if debug_enabled:
		# Wait a frame to ensure all systems are ready
		call_deferred("_initialize_debug_mode")
		Logger.info("DebugManager initialized with debug mode enabled", "debug")
	else:
		Logger.info("DebugManager initialized with debug mode disabled", "debug")
	
	# Register console commands
	call_deferred("_register_console_commands")

func _check_debug_config() -> void:
	"""Check debug configuration to determine if F12 debug panels should be enabled by default."""
	var config_path: String = "res://config/debug.tres"
	
	if ResourceLoader.exists(config_path):
		var debug_config: DebugConfig = load(config_path) as DebugConfig
		if debug_config:
			# F12 debug panel functionality is controlled by debug_panels_enabled only
			# debug_mode is separate and only controls menu skipping, arena direct start etc
			debug_enabled = debug_config.debug_panels_enabled
		else:
			debug_enabled = false
	else:
		debug_enabled = false

func _load_boss_scaling() -> void:
	"""Load boss scaling configuration from data-driven resource."""
	var resource_path := "res://data/core/boss-scaling.tres"
	
	if not ResourceLoader.exists(resource_path):
		Logger.warn("Boss scaling resource not found: %s, using defaults" % resource_path, "debug")
		boss_scaling = BossScaling.new()  # Use defaults
		return
	
	var loaded_scaling = ResourceLoader.load(resource_path) as BossScaling
	if not loaded_scaling:
		Logger.warn("Failed to load boss scaling from: %s, using defaults" % resource_path, "debug")
		boss_scaling = BossScaling.new()  # Use defaults
		return
	
	boss_scaling = loaded_scaling
	Logger.info("Loaded boss scaling configuration from data", "debug")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
		
	var key_event := event as InputEventKey
	
	# F12: Toggle debug mode (only if debug panels were enabled at startup)
	if key_event.keycode == KEY_F12:
		# Check if debug panels are enabled in config before allowing toggle
		var config_path: String = "res://config/debug.tres"
		if ResourceLoader.exists(config_path):
			var debug_config: DebugConfig = load(config_path) as DebugConfig
			if debug_config and debug_config.debug_panels_enabled:
				toggle_debug_mode()
				get_viewport().set_input_as_handled()
			else:
				Logger.debug("F12 ignored - debug panels disabled in config", "debug")
		else:
			Logger.debug("F12 ignored - no debug config found", "debug")

func toggle_debug_mode() -> void:
	debug_enabled = !debug_enabled
	Logger.info("Debug mode toggled: " + str(debug_enabled), "debug")
	emit_signal("debug_mode_toggled", debug_enabled)
	
	if debug_enabled:
		_enter_debug_mode()
	else:
		_exit_debug_mode()

func _enter_debug_mode() -> void:
	Logger.info("Entering debug mode", "debug")
	
	# Disable normal spawning via CheatSystem
	if CheatSystem:
		CheatSystem.spawn_disabled = true
		Logger.debug("Disabled normal enemy spawning", "debug")
	
	# Clear existing enemies via WaveDirector
	if wave_director and wave_director.has_method("clear_all_enemies"):
		wave_director.clear_all_enemies()
	
	# Clear existing entities via unified clear-all (includes bosses via damage pipeline)
	clear_all_entities()
	
	# Show debug UI
	_show_debug_ui()

func _exit_debug_mode() -> void:
	Logger.info("Exiting debug mode", "debug")
	
	# Re-enable normal spawning
	if CheatSystem:
		CheatSystem.spawn_disabled = false
		Logger.debug("Re-enabled normal enemy spawning", "debug")
	
	# Hide debug UI
	_hide_debug_ui()
	
	# Clear selection
	selected_entity_id = ""

# REMOVED: _clear_all_bosses() - use clear_all_entities() for unified damage-based clearing

func clear_all_entities() -> void:
	# Central clear invoked by DebugPanel; uses damage-based clearing for consistency
	var cleared_count := 0
	
	# Get all alive entities from EntityTracker
	var all_entities := EntityTracker.get_alive_entities()
	
	# Apply massive damage to each entity (same approach as kill_entity)
	for entity_id in all_entities:
		var entity_data := EntityTracker.get_entity(entity_id)
		var entity_type = entity_data.get("type", "unknown")
		
		# Skip player entities to avoid clearing the player
		if entity_type == "player":
			continue
			
		# Apply massive damage via DamageService (consistent with kill_entity)
		DamageService.apply_damage(entity_id, 999999, "debug_clear_all", ["debug", "clear_all"])
		cleared_count += 1
		
		Logger.debug("Clearing entity: %s (type: %s)" % [entity_id, entity_type], "debug")
	
	Logger.info("DebugManager: Cleared %d entities via damage-based clearing" % cleared_count, "debug")

# REMOVED: _find_boss_nodes() - no longer needed with unified damage-based clearing

func _show_debug_ui() -> void:
	if debug_ui:
		debug_ui.visible = true
		Logger.debug("Debug UI shown", "debug")

func _hide_debug_ui() -> void:
	if debug_ui:
		debug_ui.visible = false
		Logger.debug("Debug UI hidden", "debug")

# System registration methods (called by Arena during setup)
func register_wave_director(wd: WaveDirector) -> void:
	wave_director = wd
	# Connect spawning signal to actual spawning functionality (only if not already connected)
	if not spawning_requested.is_connected(_on_spawning_requested):
		spawning_requested.connect(_on_spawning_requested)
	Logger.debug("WaveDirector registered with DebugManager", "debug")

func register_boss_spawn_manager(bsm: BossSpawnManager) -> void:
	boss_spawn_manager = bsm
	Logger.debug("BossSpawnManager registered with DebugManager", "debug")

func register_arena_ui_manager(aum: ArenaUIManager) -> void:
	arena_ui_manager = aum
	Logger.debug("ArenaUIManager registered with DebugManager", "debug")

func register_debug_ui(ui: Control) -> void:
	debug_ui = ui
	if debug_ui:
		debug_ui.visible = true  # Visible by default for testing
		Logger.debug("Debug UI registered with DebugManager", "debug")
	else:
		Logger.warn("Attempted to register null debug UI", "debug")

func register_debug_system_controls(dsc: DebugSystemControls) -> void:
	debug_system_controls = dsc
	Logger.debug("DebugSystemControls registered with DebugManager", "debug")

func get_debug_system_controls() -> DebugSystemControls:
	if not debug_system_controls:
		# Try to find it in the scene tree
		var scene_tree := get_tree()
		if scene_tree and scene_tree.current_scene:
			debug_system_controls = _find_debug_system_controls(scene_tree.current_scene)
	return debug_system_controls

func _find_debug_system_controls(node: Node) -> DebugSystemControls:
	# Check if this node is DebugSystemControls
	if node is DebugSystemControls:
		return node as DebugSystemControls
	
	# Check by name as fallback
	if node.name == "DebugSystemControls":
		return node as DebugSystemControls
	
	# Search children recursively
	for child in node.get_children():
		var result = _find_debug_system_controls(child)
		if result:
			return result
	
	return null

# Entity selection methods
func select_entity(entity_id: String) -> void:
	selected_entity_id = entity_id
	emit_signal("entity_selected", entity_id)
	
	# Get entity data from EntityTracker
	var entity_data := EntityTracker.get_entity(entity_id)
	if entity_data.has("id"):
		emit_signal("entity_inspected", entity_data)
		Logger.debug("Entity selected: " + entity_id, "debug")

func get_selected_entity() -> String:
	return selected_entity_id

func is_debug_mode_active() -> bool:
	return debug_enabled


# Enemy spawning methods
func spawn_enemy_at_position(enemy_type: String, position: Vector2, count: int = 1) -> void:
	if not debug_enabled:
		Logger.warn("Cannot spawn enemies - debug mode not active", "debug")
		return
		
	Logger.info("Debug spawn requested: %d x %s at %s" % [count, enemy_type, position], "debug")
	emit_signal("spawning_requested", enemy_type, position, count)

func spawn_enemy_at_cursor(enemy_type: String, count: int = 1) -> void:
	# Get proper world position from camera
	var camera := get_viewport().get_camera_2d()
	if camera:
		var world_pos := camera.get_global_mouse_position()
		spawn_enemy_at_position(enemy_type, world_pos, count)
	else:
		Logger.warn("No camera found for cursor spawn", "debug")

func spawn_enemy_at_player(enemy_type: String, count: int = 1) -> void:
	var player_pos := PlayerState.position if PlayerState.has_player_reference() else Vector2.ZERO
	var offset := Vector2(50, 50)  # Small offset to avoid spawning on player
	spawn_enemy_at_position(enemy_type, player_pos + offset, count)

# Entity manipulation methods
func kill_entity(entity_id: String) -> void:
	if not debug_enabled:
		return
		
	Logger.info("Debug kill entity: " + entity_id, "debug")
	# Apply massive damage that will instantly kill the entity
	DamageService.apply_damage(entity_id, 999999, "debug_system", ["debug", "instant_kill"])

func heal_entity(entity_id: String, amount: int = -1) -> void:
	if not debug_enabled:
		return
		
	var entity_data := EntityTracker.get_entity(entity_id)
	if not entity_data.has("id"):
		Logger.warn("Entity not found for healing: " + entity_id, "debug")
		return
	
	var heal_amount: int = amount if amount > 0 else entity_data.get("max_hp", 100)
	Logger.info("Debug heal entity %s for %d HP" % [entity_id, heal_amount], "debug")
	
	# Apply negative damage (healing) via DamageService
	DamageService.apply_damage(entity_id, -heal_amount, "debug_system", ["debug", "healing"])

func damage_entity(entity_id: String, amount: int) -> void:
	if not debug_enabled:
		return
		
	Logger.info("Debug damage entity %s for %d HP" % [entity_id, amount], "debug")
	# Apply damage directly via DamageService
	DamageService.apply_damage(entity_id, amount, "debug_system", ["debug", "manual"])

# Signal handlers for actual functionality
func _on_spawning_requested(enemy_type: String, position: Vector2, count: int) -> void:
	if not debug_enabled:
		Logger.warn("Spawning requested but debug mode not active", "debug")
		return
		
	Logger.info("Processing spawn request: %d x %s at %s" % [count, enemy_type, position], "debug")
	
	# Check if it's a boss type (ancient_lich, dragon_lord)
	if enemy_type in ["ancient_lich", "dragon_lord"]:
		_spawn_debug_boss(enemy_type, position, count)
	else:
		_spawn_debug_regular_enemy(enemy_type, position, count)

func _spawn_debug_boss(boss_type: String, position: Vector2, count: int) -> void:
	if not boss_spawn_manager:
		Logger.error("BossSpawnManager not available for boss spawning", "debug")
		return
		
	Logger.info("Spawning %d boss(es) of type %s" % [count, boss_type], "debug")
	
	for i in count:
		# Spread out multiple bosses
		var spawn_pos := position + Vector2(i * 100, 0)
		
		# Create boss spawn context for EnemyFactory
		var spawn_context := {
			"run_id": RunManager.run_seed if RunManager else 12345,
			"wave_index": 999,
			"spawn_index": i,
			"position": spawn_pos,
			"context_tags": ["boss", "debug_spawn"]
		}
		
		# Use EnemyFactory to generate boss config
		const EnemyFactoryScript = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
		var boss_config = EnemyFactoryScript.spawn_from_template_id(boss_type, spawn_context)
		
		if boss_config:
			# Scale bosses using configurable multipliers
			if boss_scaling:
				boss_scaling.apply_scaling(boss_config)
			else:
				# Emergency fallback if scaling config failed to load
				boss_config.health *= 3.0
				boss_config.damage *= 1.5
				boss_config.size_scale *= 1.2
			
			# Convert to legacy enemy type for existing spawn system
			var legacy_type := boss_config.to_enemy_type()
			legacy_type.is_special_boss = true
			legacy_type.display_name = boss_type.replace("_", " ").capitalize()
			
			# Spawn via WaveDirector's V2 system
			if wave_director and wave_director.has_method("_spawn_from_config_v2"):
				wave_director._spawn_from_config_v2(legacy_type, boss_config)
				Logger.info("Debug spawned boss: %s at %s" % [boss_type, spawn_pos], "debug")
				
				# If AI is currently paused, immediately apply paused state to new boss
				_apply_ai_pause_to_new_entity()
			else:
				Logger.error("WaveDirector._spawn_from_config_v2 not available", "debug")
		else:
			Logger.error("Failed to generate boss config for: %s" % boss_type, "debug")

func _spawn_debug_regular_enemy(enemy_type: String, position: Vector2, count: int) -> void:
	if not wave_director:
		Logger.error("WaveDirector not available for regular enemy spawning", "debug")
		return
		
	Logger.info("Spawning %d regular enemy(ies) of type %s" % [count, enemy_type], "debug")
	
	for i in count:
		# Spread out multiple enemies in a circle pattern
		var angle: float = (i * TAU) / count if count > 1 else 0.0
		var ring_number: int = int(float(i) / 5.0)  # Explicit conversion for ring calculation
		var offset := Vector2.from_angle(angle) * 30 * (ring_number + 1)  # Expanding spiral
		var spawn_pos := position + offset
		
		# Create spawn context
		var spawn_context := {
			"run_id": RunManager.run_seed if RunManager else 12345,
			"wave_index": 999,
			"spawn_index": i,
			"position": spawn_pos,
			"context_tags": ["debug_spawn"]
		}
		
		# Use EnemyFactory to generate enemy config
		const EnemyFactoryScript = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
		var enemy_config = EnemyFactoryScript.spawn_from_template_id(enemy_type, spawn_context)
		
		if enemy_config:
			# Convert to legacy enemy type for existing spawn system
			var legacy_type := enemy_config.to_enemy_type()
			legacy_type.display_name = enemy_type.replace("_", " ").capitalize()
			
			# Spawn via WaveDirector's V2 system
			if wave_director and wave_director.has_method("_spawn_from_config_v2"):
				wave_director._spawn_from_config_v2(legacy_type, enemy_config)
				Logger.info("Debug spawned enemy: %s at %s" % [enemy_type, spawn_pos], "debug")
			else:
				Logger.error("WaveDirector._spawn_from_config_v2 not available", "debug")
		else:
			Logger.error("Failed to generate enemy config for: %s" % enemy_type, "debug")
	
	# If AI is currently paused, immediately apply paused state to all new enemies
	_apply_ai_pause_to_new_entity()

# Ability triggering methods
func get_entity_abilities(entity_id: String) -> Array[String]:
	if not debug_enabled or not ability_trigger:
		return []
	return ability_trigger.get_entity_abilities(entity_id)

func trigger_entity_ability(entity_id: String, ability_name: String) -> bool:
	if not debug_enabled or not ability_trigger:
		return false
	return ability_trigger.trigger_ability(entity_id, ability_name)

func get_ability_cooldown(entity_id: String, ability_name: String) -> Dictionary:
	if not debug_enabled or not ability_trigger:
		return {"ready": false, "cooldown_remaining": 0.0}
	return ability_trigger.get_ability_cooldown(entity_id, ability_name)

func _apply_ai_pause_to_new_entity() -> void:
	"""If AI is currently paused, immediately apply paused state to newly spawned entities"""
	if not debug_system_controls:
		return
		
	# Check if AI is currently paused
	if debug_system_controls.has_method("is_ai_paused") and debug_system_controls.is_ai_paused():
		Logger.debug("AI is paused, applying pause state to newly spawned entities", "debug")
		
		# Emit the AI pause signal to ensure new entities receive it immediately
		var payload := EventBus.CheatTogglePayload_Type.new("ai_paused", true)
		# Small delay to ensure entities are fully spawned before receiving the signal
		get_tree().create_timer(0.1).timeout.connect(func(): EventBus.cheat_toggled.emit(payload))

# Progression system debug methods
func add_xp(amount: float = 100.0) -> void:
	if not debug_enabled:
		Logger.warn("Cannot add XP - debug mode not active", "debug")
		return
	
	Logger.info("Debug: Adding %.1f XP" % amount, "progression_debug")
	
	if PlayerProgression:
		PlayerProgression.gain_exp(amount)
	else:
		Logger.error("PlayerProgression not available", "progression_debug")

func force_level_up() -> void:
	if not debug_enabled:
		Logger.warn("Cannot force level up - debug mode not active", "debug")
		return
	
	Logger.info("Debug: Forcing level up", "progression_debug")
	
	if PlayerProgression:
		var xp_needed: float = PlayerProgression.xp_to_next + 1.0  # Add small epsilon
		Logger.debug("Forcing level up by adding %.1f XP" % xp_needed, "progression_debug")
		PlayerProgression.gain_exp(xp_needed)
	else:
		Logger.error("PlayerProgression not available", "progression_debug")

func get_progression_info() -> Dictionary:
	if not PlayerProgression:
		return {"error": "PlayerProgression not available"}
	
	return PlayerProgression.get_progression_state()

func reset_progression() -> void:
	if not debug_enabled:
		Logger.warn("Cannot reset progression - debug mode not active", "debug")
		return
	
	Logger.warn("Debug: Resetting progression to level 1", "progression_debug")
	
	if PlayerProgression:
		# Reset to starting values
		var reset_profile: Dictionary = {"level": 1, "exp": 0.0}
		PlayerProgression.load_from_profile(reset_profile)
	else:
		Logger.error("PlayerProgression not available", "progression_debug")

func _initialize_debug_mode() -> void:
	# Called deferred from _ready to ensure systems are initialized
	if debug_enabled:
		Logger.info("Initializing debug mode on startup", "debug")
		_enter_debug_mode()
		# Emit the debug mode toggled signal to ensure all systems are notified
		emit_signal("debug_mode_toggled", true)

## Register damage queue console commands with LimboConsole
func _register_console_commands() -> void:
	if not LimboConsole:
		Logger.warn("LimboConsole not available - damage queue commands not registered", "debug")
		return
	
	# Register damage queue commands
	LimboConsole.register_command(cmd_damage_queue_stats, "damage_queue_stats", "Show damage queue metrics and performance")
	LimboConsole.register_command(cmd_damage_queue_reset, "damage_queue_reset", "Reset damage queue metrics (for testing)")
	
	Logger.info("Damage queue console commands registered", "debug")

## Console command: Show damage queue statistics
func cmd_damage_queue_stats() -> void:
	if not DamageService:
		LimboConsole.error("DamageService not available")
		return
	
	var stats = DamageService.get_queue_stats()
	
	if not stats.get("enabled", false):
		LimboConsole.info("Damage queue is DISABLED")
		return
	
	# Format stats nicely
	var output = "=== Damage Queue Statistics ===\n"
	output += "Enqueued: %d | Processed: %d | Dropped: %d\n" % [stats.enqueued, stats.processed, stats.dropped_overflow]
	output += "Queue: %d/%d (max watermark: %d)\n" % [stats.current_queue_size, stats.queue_capacity, stats.max_watermark]
	output += "Pools: Payload=%d, Tags=%d available\n" % [stats.payload_pool_available, stats.tags_pool_available]
	output += "Performance: %.1f ms/tick (%d ticks)" % [stats.last_tick_ms, stats.total_ticks]
	
	LimboConsole.info(output)

## Console command: Reset damage queue metrics
func cmd_damage_queue_reset() -> void:
	if not DamageService:
		LimboConsole.error("DamageService not available")
		return
	
	DamageService.reset_queue_metrics()
	LimboConsole.info("Damage queue metrics reset")
	Logger.info("Console reset damage queue metrics", "debug")
