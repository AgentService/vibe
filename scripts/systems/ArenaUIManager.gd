extends Node

## Arena UI Manager - Phase 4 Arena Refactoring
## Manages HUD, CardSelection, and DebugPanel instantiation and UI-related signal wiring
## Centralizes all UI management for the Arena scene

class_name ArenaUIManager

const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const NEW_HUD_SCENE: PackedScene = preload("res://scenes/ui/NewHUD.tscn")
const CARD_SELECTION_SCENE: PackedScene = preload("res://scenes/ui/CardSelection.tscn")
const DEBUG_PANEL_SCENE: PackedScene = preload("res://scenes/debug/DebugPanel.tscn")

@export var use_new_hud_system: bool = false

var hud: HUD
var new_hud: NewHUD
var card_selection: CardSelection
var debug_panel: Control
var active_hud_type: String = "old"

signal card_selected(card: CardResource)

func setup() -> void:
	# Create UI layer for HUD and card selection
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	# Instantiate HUD system based on configuration
	_setup_hud_system(ui_layer)

	# Instantiate card selection
	card_selection = CARD_SELECTION_SCENE.instantiate()
	ui_layer.add_child(card_selection)
	Logger.info("ArenaUIManager: CardSelection instantiated", "ui")

	# Note: Pause menu is now handled by PauseUI autoload

	# Check debug configuration before instantiating debug panel
	var config_path: String = "res://config/debug.tres"
	var should_create_debug_panel: bool = true
	
	if ResourceLoader.exists(config_path):
		var debug_config: DebugConfig = load(config_path) as DebugConfig
		if debug_config and not debug_config.debug_panels_enabled:
			should_create_debug_panel = false
			Logger.info("ArenaUIManager: DebugPanel disabled via debug.tres configuration", "ui")
	
	if should_create_debug_panel:
		# Instantiate debug panel
		debug_panel = DEBUG_PANEL_SCENE.instantiate()
		ui_layer.add_child(debug_panel)
		debug_panel.visible = false  # Hidden by default
		Logger.info("ArenaUIManager: DebugPanel instantiated", "ui")

		# Register debug panel with DebugManager
		if DebugManager:
			DebugManager.register_debug_ui(debug_panel)

	# Bubble card selection events through manager
	card_selection.card_selected.connect(func(card): card_selected.emit(card))
	
	Logger.info("ArenaUIManager setup complete", "systems")

func setup_card_system(card_system_ref: CardSystem) -> void:
	# Connect card system to card selection UI
	if card_selection and card_selection.has_method("setup_card_system"):
		card_selection.setup_card_system(card_system_ref)
		Logger.debug("CardSystem connected to UI manager", "ui")

func toggle_pause() -> void:
	# Pause is now handled by PauseUI autoload via PauseManager
	PauseManager.toggle_pause()

func open_card_selection(cards: Array[CardResource]) -> void:
	if card_selection:
		card_selection.open_with_cards(cards)

func try_toggle_debug_overlay() -> void:
	if active_hud_type == "old" and hud and hud.has_method("_toggle_debug_overlay"):
		hud._toggle_debug_overlay()
	elif active_hud_type == "new" and new_hud:
		# New HUD system doesn't have a toggle debug overlay method
		# Debug is handled by the PerformanceComponent visibility
		Logger.info("Debug overlay toggle not available in new HUD system", "ui")

# Getter methods for Arena to access UI elements
func get_hud() -> HUD:
	return hud

func get_new_hud() -> NewHUD:
	return new_hud

func get_active_hud() -> Control:
	match active_hud_type:
		"old":
			return hud
		"new":
			return new_hud
		_:
			return null

func get_card_selection() -> CardSelection:
	return card_selection


func get_debug_panel() -> Control:
	return debug_panel

func _setup_hud_system(ui_layer: CanvasLayer) -> void:
	# Check if we should use the new HUD system
	# This can be controlled via export variable or debug config
	var should_use_new_hud = use_new_hud_system
	
	# Also check debug config for HUD system preference
	var config_path: String = "res://config/debug.tres"
	if ResourceLoader.exists(config_path):
		var debug_config: DebugConfig = load(config_path) as DebugConfig
		if debug_config and debug_config.has_method("get") and debug_config.get("use_new_hud_system"):
			should_use_new_hud = debug_config.get("use_new_hud_system")
	
	if should_use_new_hud:
		# Use new component-based HUD system
		new_hud = NEW_HUD_SCENE.instantiate()
		ui_layer.add_child(new_hud)
		active_hud_type = "new"
		Logger.info("ArenaUIManager: New component-based HUD instantiated", "ui")
	else:
		# Use legacy HUD system  
		hud = HUD_SCENE.instantiate()
		ui_layer.add_child(hud)
		active_hud_type = "old"
		Logger.info("ArenaUIManager: Legacy HUD instantiated", "ui")

func toggle_hud_system() -> void:
	"""Debug method to toggle between old and new HUD systems at runtime"""
	if active_hud_type == "old" and hud:
		# Switch to new HUD
		hud.visible = false
		if not new_hud:
			new_hud = NEW_HUD_SCENE.instantiate()
			get_child(0).add_child(new_hud)  # Add to UI layer
		new_hud.visible = true
		active_hud_type = "new"
		Logger.info("Switched to new HUD system", "ui")
	elif active_hud_type == "new" and new_hud:
		# Switch to old HUD
		new_hud.visible = false
		if not hud:
			hud = HUD_SCENE.instantiate()
			get_child(0).add_child(hud)  # Add to UI layer
		hud.visible = true
		active_hud_type = "old"
		Logger.info("Switched to old HUD system", "ui")

func get_active_hud_stats() -> Dictionary:
	"""Get performance stats from the currently active HUD system"""
	match active_hud_type:
		"old":
			return {"system": "legacy", "active": hud != null, "visible": hud.visible if hud else false}
		"new":
			if new_hud and new_hud.has_method("get_hud_performance_stats"):
				return new_hud.get_hud_performance_stats()
			else:
				return {"system": "new", "active": new_hud != null, "visible": new_hud.visible if new_hud else false}
		_:
			return {"system": "unknown", "active": false}

func _exit_tree() -> void:
	# Clean up any connections if needed
	Logger.debug("ArenaUIManager cleanup complete", "ui")
