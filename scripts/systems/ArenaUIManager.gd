extends Node

## Arena UI Manager - Phase 4 Arena Refactoring
## Manages HUD, CardSelection, and DebugPanel instantiation and UI-related signal wiring
## Centralizes all UI management for the Arena scene

class_name ArenaUIManager

const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const CARD_SELECTION_SCENE: PackedScene = preload("res://scenes/ui/CardSelection.tscn")
const DEBUG_PANEL_SCENE: PackedScene = preload("res://scenes/debug/DebugPanel.tscn")

var hud: HUD
var card_selection: CardSelection
var debug_panel: Control

signal card_selected(card: CardResource)

func setup() -> void:
	# Create UI layer for HUD and card selection
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	# Instantiate HUD
	hud = HUD_SCENE.instantiate()
	ui_layer.add_child(hud)
	Logger.info("ArenaUIManager: HUD instantiated", "ui")

	# Instantiate card selection
	card_selection = CARD_SELECTION_SCENE.instantiate()
	ui_layer.add_child(card_selection)
	Logger.info("ArenaUIManager: CardSelection instantiated", "ui")

	# Note: Pause menu is now handled by PauseUI autoload

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
	if hud and hud.has_method("_toggle_debug_overlay"):
		hud._toggle_debug_overlay()

# Getter methods for Arena to access UI elements
func get_hud() -> HUD:
	return hud

func get_card_selection() -> CardSelection:
	return card_selection


func get_debug_panel() -> Control:
	return debug_panel

func _exit_tree() -> void:
	# Clean up any connections if needed
	Logger.debug("ArenaUIManager cleanup complete", "ui")
