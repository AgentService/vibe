extends Node

## Modern Debug Interface Manager
## Replaces the legacy cheat system with comprehensive debugging tools
## Provides real-time entity inspection, manual spawning, and ability testing

static var instance: DebugManager

signal debug_mode_toggled(enabled: bool)
signal entity_selected(entity_id: String)
signal entity_inspected(entity_data: Dictionary)
signal spawning_requested(enemy_type: String, position: Vector2, count: int)

var debug_enabled: bool = false
var selected_entity_id: String = ""
var debug_ui: Control

# System references for debug operations
var wave_director: WaveDirector
var boss_spawn_manager: BossSpawnManager
var arena_ui_manager: ArenaUIManager

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS  # Work during pause
	Logger.info("DebugManager initialized", "debug")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
		
	var key_event := event as InputEventKey
	
	# F12: Toggle debug mode
	if key_event.keycode == KEY_F12:
		toggle_debug_mode()
		get_viewport().set_input_as_handled()

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
	
	# Clear existing bosses - find all boss nodes in scene tree
	_clear_all_bosses()
	
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

func _clear_all_bosses() -> void:
	# Find all boss nodes in the scene tree and remove them
	var scene_tree := get_tree()
	if not scene_tree:
		return
		
	var current_scene := scene_tree.current_scene
	if not current_scene:
		return
	
	var boss_nodes := _find_boss_nodes(current_scene)
	for boss in boss_nodes:
		Logger.debug("Removing boss node: " + boss.name, "debug")
		boss.queue_free()

func _find_boss_nodes(node: Node) -> Array[Node]:
	var boss_nodes: Array[Node] = []
	
	# Check if current node is a boss (common boss class names or groups)
	if node.name.contains("Boss") or node.name.contains("Lich") or node.name.contains("Dragon"):
		boss_nodes.append(node)
	elif node.is_in_group("bosses"):
		boss_nodes.append(node)
	
	# Recursively check children
	for child in node.get_children():
		boss_nodes.append_array(_find_boss_nodes(child))
	
	return boss_nodes

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
	# Connect spawning signal to actual spawning functionality
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
	debug_ui.visible = false  # Hidden by default
	Logger.debug("Debug UI registered with DebugManager", "debug")

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
	var mouse_pos := get_viewport().get_mouse_position()
	# Convert screen position to world position
	var camera := get_viewport().get_camera_2d()
	if camera:
		var world_pos := camera.to_global(mouse_pos - get_viewport().get_visible_rect().size / 2)
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
	# Emit damage that will instantly kill the entity
	EventBus.damage_requested.emit(
		"debug_system",  # source_id
		entity_id,       # target_id
		999999,          # damage (overkill)
		["debug", "instant_kill"]  # damage_tags
	)

func heal_entity(entity_id: String, amount: int = -1) -> void:
	if not debug_enabled:
		return
		
	var entity_data := EntityTracker.get_entity(entity_id)
	if not entity_data.has("id"):
		Logger.warn("Entity not found for healing: " + entity_id, "debug")
		return
	
	var heal_amount: int = amount if amount > 0 else entity_data.get("max_hp", 100)
	Logger.info("Debug heal entity %s for %d HP" % [entity_id, heal_amount], "debug")
	
	# Emit negative damage (healing)
	EventBus.damage_requested.emit(
		"debug_system",  # source_id
		entity_id,       # target_id
		-heal_amount,    # negative damage = healing
		["debug", "healing"]  # damage_tags
	)

func damage_entity(entity_id: String, amount: int) -> void:
	if not debug_enabled:
		return
		
	Logger.info("Debug damage entity %s for %d HP" % [entity_id, amount], "debug")
	EventBus.damage_requested.emit(
		"debug_system",  # source_id
		entity_id,       # target_id  
		amount,          # damage
		["debug", "manual"]  # damage_tags
	)

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
		const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
		var boss_config = EnemyFactory.spawn_from_template_id(boss_type, spawn_context)
		
		if boss_config:
			# Scale bosses for better visibility/testing
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
		var angle: float = (i * TAU) / count if count > 1 else 0
		var offset := Vector2.from_angle(angle) * 30 * (i / 5 + 1)  # Expanding spiral
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
		const EnemyFactory = preload("res://scripts/systems/enemy_v2/EnemyFactory.gd")
		var enemy_config = EnemyFactory.spawn_from_template_id(enemy_type, spawn_context)
		
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
