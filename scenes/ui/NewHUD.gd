extends Control
class_name NewHUD

## New component-based HUD system using HUDManager for coordination
## Designed to coexist with and eventually replace the old HUD system

# Layer 1 - Primary HUD (Game UI)
@onready var player_info_panel: PlayerInfoPanel = $Layer1_PrimaryHUD/GameUI/PlayerInfoPanel
@onready var enemy_radar: RadarComponent = $Layer1_PrimaryHUD/GameUI/EnemyRadar
@onready var keybindings_display: KeybindingsComponent = $Layer1_PrimaryHUD/GameUI/KeybindingsDisplay
@onready var ability_bar: AbilityBarComponent = $Layer1_PrimaryHUD/GameUI/PlayerInfoPanel/PlayerInfoContainer/AbilityBarContainer/AbilityBar2

# Layer 100 - Debug UI
# PerformanceDisplay temporarily removed due to node parenting issues

# State tracking
var _is_initialized: bool = false

func _ready() -> void:
	# HUD should always process (including during pause)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wait for HUDManager to be ready
	if HUDManager:
		_initialize_new_hud()
	else:
		# Retry initialization on next frame if HUDManager not ready
		call_deferred("_initialize_new_hud")

func _initialize_new_hud() -> void:
	if _is_initialized:
		return
	
	Logger.info("Initializing new component-based HUD system", "ui")
	
	# No programmatic layout management - use editor positioning
	# Components positioned via scene editor, not HUDManager config
	
	# Connect to progression signals
	_connect_new_hud_signals()
	
	# Style the remaining non-component elements
	_style_legacy_elements()
	
	# Initialize component states
	_initialize_component_states()
	
	# All components should now be positioned by HUDManager
	_is_initialized = true
	Logger.info("New HUD system initialization complete - Layer 1 (Game UI) + Layer 100 (Debug UI) architecture", "ui")

func _connect_new_hud_signals() -> void:
	# Connect to EventBus signals
	if EventBus:
		EventBus.health_changed.connect(_on_health_changed)
		EventBus.progression_changed.connect(_on_progression_changed)
		EventBus.leveled_up.connect(_on_leveled_up)
	
	# Connect to HUDManager signals (simplified - no layout management)
	if HUDManager:
		HUDManager.hud_visibility_changed.connect(_on_hud_visibility_changed)

func _style_legacy_elements() -> void:
	# No legacy elements to style - everything now handled by components
	# PlayerInfoPanel handles level label styling via MainTheme
	pass

func _initialize_component_states() -> void:
	# Initialize player info panel (handles its own health/xp/level initialization)
	# PlayerInfoPanel connects to EventBus and handles its own updates
	
	# Initialize progression display with current state
	if PlayerProgression:
		var state = PlayerProgression.get_progression_state()
		_on_progression_changed(state)
	
	# Initialize keybindings display
	if keybindings_display:
		keybindings_display.refresh_keybindings()

func _apply_hud_layout() -> void:
	# No programmatic layout - respect editor positioning for all elements
	pass

# Signal handlers - PlayerInfoPanel handles health/xp/level updates internally
func _on_health_changed(current_health: float, max_health: float) -> void:
	# PlayerInfoPanel handles health updates via its own EventBus connections
	pass

func _on_progression_changed(state: Dictionary) -> void:
	# PlayerInfoPanel handles progression updates via its own EventBus connections
	var level = int(state.get("level", 1))
	Logger.debug("New HUD: Progression changed - Level: %d (handled by PlayerInfoPanel)" % [level], "ui")

func _on_leveled_up(new_level: int, prev_level: int) -> void:
	# PlayerInfoPanel handles level updates via its own EventBus connections
	Logger.debug("New HUD: Level up detected! %d -> %d (handled by PlayerInfoPanel)" % [prev_level, new_level], "ui")

func _on_hud_visibility_changed(visible: bool) -> void:
	Logger.debug("New HUD: HUD visibility changed to %s" % visible, "ui")
	# Could respond to global HUD visibility changes if needed

# Public API for switching between HUD systems
func set_hud_visible(visible: bool) -> void:
	self.visible = visible
	if visible:
		Logger.info("New HUD system shown", "ui")
	else:
		Logger.info("New HUD system hidden", "ui")

func get_hud_performance_stats() -> Dictionary:
	var stats = {
		"system": "new_hud",
		"initialized": _is_initialized,
		"components": {}
	}
	
	# Gather stats from all components
	if player_info_panel:
		stats.components["player_info"] = {"active": true, "consolidated": true}
	
	if enemy_radar and enemy_radar.has_method("get_radar_stats"):
		stats.components["radar"] = enemy_radar.get_radar_stats()
	
	# Performance display temporarily removed
	# if performance_display and performance_display.has_method("get_current_performance_stats"):
	# 	stats.components["performance"] = performance_display.get_current_performance_stats()
	
	if keybindings_display and keybindings_display.has_method("get_keybinding_stats"):
		stats.components["keybindings"] = keybindings_display.get_keybinding_stats()
	
	if ability_bar and ability_bar.has_method("get_ability_stats"):
		stats.components["ability_bar"] = ability_bar.get_ability_stats()
	
	return stats
