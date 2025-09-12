extends Node

## Arena UI Manager - Simplified Clean HUD System
## Manages component-based HUD, CardSelection, and DebugPanel instantiation
## Centralizes all UI management for the Arena scene

class_name ArenaUIManager

const HUD_SCENE: PackedScene = preload("res://scenes/ui/NewHUD.tscn")
const CARD_SELECTION_SCENE: PackedScene = preload("res://scenes/ui/CardSelection.tscn")
const DEBUG_PANEL_SCENE: PackedScene = preload("res://scenes/debug/DebugPanel.tscn")

var hud: NewHUD
var card_selection: CardSelection
var debug_panel: Control

signal card_selected(card: CardResource)

func setup() -> void:
	# Create UI layer for HUD and card selection
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	# Instantiate component-based HUD system
	hud = HUD_SCENE.instantiate()
	ui_layer.add_child(hud)
	Logger.info("ArenaUIManager: Component-based HUD instantiated", "ui")

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
	# Debug overlay handled by PerformanceComponent in component-based HUD
	if hud and hud.has_method("toggle_performance_display"):
		hud.toggle_performance_display()
	else:
		Logger.info("Debug overlay toggle handled by PerformanceComponent", "ui")

# Getter methods for Arena to access UI elements
func get_hud() -> NewHUD:
	return hud

func get_active_hud() -> Control:
	return hud

func get_card_selection() -> CardSelection:
	return card_selection


func get_debug_panel() -> Control:
	return debug_panel


func get_active_hud_stats() -> Dictionary:
	"""Get performance stats from the component-based HUD system"""
	if hud and hud.has_method("get_hud_performance_stats"):
		return hud.get_hud_performance_stats()
	else:
		return {"system": "component_based", "active": hud != null, "visible": hud.visible if hud else false}

func _exit_tree() -> void:
	# Clean up any connections if needed
	Logger.debug("ArenaUIManager cleanup complete", "ui")
