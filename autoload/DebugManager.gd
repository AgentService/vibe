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