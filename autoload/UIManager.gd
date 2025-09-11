extends CanvasLayer
## Unified modal management system for desktop-optimized overlays

# Preload required classes
const BaseModal = preload("res://scripts/ui_framework/BaseModal.gd")
const ModalAnimator = preload("res://scripts/ui_framework/ModalAnimator.gd")
##
## Handles all modal/popup UIs with base classes, consistent theming, and 
## standardized behavior. Integrates perfectly with StateManager for 
## application flow coordination.

enum ModalType {
	# Game-specific modals (layer 5)
	INVENTORY,
	CHARACTER_SCREEN, 
	SKILL_TREE,
	CRAFTING,
	CARD_PICKER,
	# System modals (layer 10)
	RESULTS_SCREEN,
	PAUSE_MENU,
	DEATH_SCREEN,
	SETTINGS,
	CONFIRM_DIALOG
}

# Core modal management
var modal_stack: Array[BaseModal] = []
var modal_factory: ModalFactory
var canvas_layers: Dictionary = {}  # Layer index -> CanvasLayer
var background_dimmer: ColorRect

# Modal state tracking  
var active_modal: BaseModal = null
var modal_transition_running: bool = false

# Performance tracking
var performance_monitor: Dictionary = {
	"modal_open_time": 0.0,
	"animation_count": 0
}

func _ready() -> void:
	# Ensure UIManager can process when paused (for modal functionality)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	setup_canvas_layers()
	setup_modal_system()
	connect_state_management()
	
	# Ensure UIManager handles input before other systems
	process_priority = 100  # Higher priority than GameOrchestrator
	
	Logger.info("UIManager initialized with modal layer system", "ui")

func setup_canvas_layers() -> void:
	# Create canvas layers for different modal types
	for layer_index in [5, 10, 50, 100]:
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = layer_index
		canvas_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Allow processing when paused
		add_child(canvas_layer)
		canvas_layers[layer_index] = canvas_layer
	
	Logger.debug("Canvas layers created: %s" % str(canvas_layers.keys()), "ui")

func setup_modal_system() -> void:
	modal_factory = ModalFactory.new()
	create_background_dimmer()
	setup_input_handling()

func create_background_dimmer() -> void:
	background_dimmer = ColorRect.new()
	background_dimmer.color = Color(0.0, 0.0, 0.0, 0.0)  # Start transparent
	background_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to system modal layer (10) - dimmer appears behind system modals
	canvas_layers[10].add_child(background_dimmer)
	background_dimmer.visible = false

func setup_input_handling() -> void:
	# Handle escape key for modal dismissal and prevent conflicts
	pass  # Individual modals handle their own ESC behavior

func _input(event: InputEvent) -> void:
	# Handle ESC for modal closure when modals are active
	if has_active_modal() and event.is_action_pressed("ui_cancel"):
		Logger.debug("UIManager: Handling ESC for modal closure", "ui")
		hide_current_modal()
		get_viewport().set_input_as_handled()
		return

func show_modal(modal_type: ModalType, data: Dictionary = {}) -> BaseModal:
	"""Primary modal display method - handles full modal lifecycle"""
	if modal_transition_running:
		Logger.warn("Modal transition in progress, queuing request", "ui")
		return null
	
	modal_transition_running = true
	var start_time = Time.get_ticks_msec()
	
	# Create modal through factory
	var modal = modal_factory.create_modal(modal_type, data)
	if not modal:
		modal_transition_running = false
		Logger.error("Failed to create modal: %s" % ModalType.keys()[modal_type], "ui")
		return null
	
	# Determine target layer based on modal type
	var target_layer = get_modal_layer(modal_type)
	
	# Configure modal for display
	configure_modal_display(modal, target_layer)
	
	# Add to modal stack and show
	modal_stack.push_back(modal)
	active_modal = modal
	
	# Show background dimmer if this is the first modal
	if modal_stack.size() == 1:
		show_background_dimmer()
	
	# Call modal's open method to handle pause logic
	modal.open_modal(data)
	
	# Animate modal entrance (temporarily skip for debugging)
	animate_modal_entrance(modal)
	modal.visible = true
	modal.modulate.a = 1.0
	modal.scale = Vector2.ONE
	Logger.info("Modal set to fully visible (animation skipped for debug)", "ui")
	
	# Performance tracking
	performance_monitor.modal_open_time = Time.get_ticks_msec() - start_time
	
	Logger.info("Modal displayed: %s (%.2fms)" % [ModalType.keys()[modal_type], performance_monitor.modal_open_time], "ui")
	EventBus.modal_displayed.emit(modal_type, modal)
	
	modal_transition_running = false
	return modal

func hide_current_modal() -> void:
	"""Handles modal closure with proper cleanup and animation"""
	if modal_stack.is_empty() or modal_transition_running:
		return
	
	modal_transition_running = true
	var modal = modal_stack.pop_back()
	
	# Call modal's close method to handle unpause logic
	modal.close_modal()
	
	# Update active modal reference
	active_modal = modal_stack.back() if not modal_stack.is_empty() else null
	
	# Hide background dimmer if no more modals
	if modal_stack.is_empty():
		hide_background_dimmer()
	
	# Animate modal exit and cleanup
	animate_modal_exit(modal)
	
	Logger.info("Modal hidden: %s" % modal.name, "ui")
	EventBus.modal_hidden.emit(modal)
	
	modal_transition_running = false

func configure_modal_display(modal: BaseModal, target_layer: int) -> void:
	# Add to appropriate canvas layer
	canvas_layers[target_layer].add_child(modal)
	
	# Configure modal properties
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to game
	
	# Debug layer assignment
	Logger.info("Modal added to canvas layer %d, layer count: %d" % [target_layer, canvas_layers.size()], "ui")
	Logger.info("Canvas layer %d children count: %d" % [target_layer, canvas_layers[target_layer].get_child_count()], "ui")
	
	# Connect modal signals
	modal.modal_closed.connect(_on_modal_close_requested)

func animate_modal_entrance(modal: BaseModal) -> void:
	# Ensure modal is visible first
	modal.visible = true
	
	# Start modal with slight transparency and scale
	modal.modulate.a = 0.1  # Start slightly visible for debugging
	modal.scale = Vector2(0.95, 0.95)
	
	# Animate entrance
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(modal, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(modal, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)
	
	performance_monitor.animation_count += 1
	Logger.info("Modal animation started: alpha %f -> 1.0" % modal.modulate.a, "ui")

func animate_modal_exit(modal: BaseModal) -> void:
	# Animate exit
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(modal, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_property(modal, "scale", Vector2(0.95, 0.95), 0.2).set_ease(Tween.EASE_IN)
	
	# Cleanup when animation completes
	tween.tween_callback(func(): _cleanup_modal(modal))

func _cleanup_modal(modal: BaseModal) -> void:
	# Disconnect signals
	if modal.modal_closed.is_connected(_on_modal_close_requested):
		modal.modal_closed.disconnect(_on_modal_close_requested)
	
	# Remove from scene
	modal.queue_free()

func show_background_dimmer() -> void:
	background_dimmer.visible = true
	background_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween = create_tween()
	tween.tween_property(background_dimmer, "color:a", 0.7, 0.3).set_ease(Tween.EASE_OUT)

func hide_background_dimmer() -> void:
	var tween = create_tween()
	tween.tween_property(background_dimmer, "color:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): 
		background_dimmer.visible = false
		background_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)

func get_modal_layer(modal_type: ModalType) -> int:
	"""Determine appropriate canvas layer for modal type"""
	match modal_type:
		ModalType.INVENTORY, ModalType.CHARACTER_SCREEN, ModalType.SKILL_TREE, ModalType.CRAFTING, ModalType.CARD_PICKER:
			return 5  # Game modals
		ModalType.RESULTS_SCREEN, ModalType.PAUSE_MENU, ModalType.DEATH_SCREEN, ModalType.SETTINGS, ModalType.CONFIRM_DIALOG:
			return 10  # System modals
		_:
			return 5  # Default to game layer

func connect_state_management() -> void:
	"""Connect to StateManager for coordinated modal behavior"""
	if StateManager:
		StateManager.state_changed.connect(_on_state_changed)

func _on_state_changed(prev: StateManager.State, next: StateManager.State, context: Dictionary) -> void:
	"""Handle state transitions - close inappropriate modals"""
	match next:
		StateManager.State.MENU:
			close_all_modals()  # Close all modals when returning to menu
		StateManager.State.ARENA:
			close_modals_except([ModalType.PAUSE_MENU, ModalType.INVENTORY, ModalType.RESULTS_SCREEN])

func _on_modal_close_requested() -> void:
	"""Handle modal close request from the modal itself"""
	hide_current_modal()

# Essential modal management methods
func has_active_modal() -> bool:
	"""Check if any modal is currently displayed"""
	return not modal_stack.is_empty()

func get_modal_count() -> int:
	"""Get number of modals in stack"""
	return modal_stack.size()

func close_all_modals() -> void:
	"""Emergency close all modals (e.g., state transitions)"""
	while not modal_stack.is_empty():
		hide_current_modal()

func close_modals_except(allowed_types: Array[ModalType]) -> void:
	"""Close all modals except specified types"""
	# Implementation for selective modal closure - Phase 3

# Modal Factory class
class ModalFactory:
	extends RefCounted
	
	var modal_scenes: Dictionary = {
		UIManager.ModalType.RESULTS_SCREEN: preload("res://scenes/ui/ResultsScreen.tscn"),
		# Additional modals will be added here as they're converted
	}
	
	func create_modal(modal_type: UIManager.ModalType, data: Dictionary) -> BaseModal:
		if not modal_scenes.has(modal_type):
			Logger.error("Unknown modal type: %s" % UIManager.ModalType.keys()[modal_type], "ui")
			return null
		
		var modal_scene = modal_scenes[modal_type]
		var modal = modal_scene.instantiate()
		
		# Verify it's a BaseModal
		if not modal is BaseModal:
			Logger.error("Modal scene is not a BaseModal: %s" % UIManager.ModalType.keys()[modal_type], "ui")
			modal.queue_free()
			return null
		
		# Initialize modal with data
		modal.initialize(data)
		
		Logger.debug("Modal created: %s" % UIManager.ModalType.keys()[modal_type], "ui")
		return modal