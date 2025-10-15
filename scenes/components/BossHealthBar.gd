extends ProgressBar

## Flexible Boss Health Bar - Auto-sizes and positions based on parent's HitBox
## Features:
## - Automatically sizes width to match HitBox dimensions  
## - Auto-positions 5px above HitBox bounds
## - Only appears after first damage (performance optimization)
## - Works with both CircleShape2D and RectangleShape2D HitBoxes

class_name BossHealthBar

## Distance above HitBox top (higher = more space above boss)
@export var y_offset_above_hitbox: float = 12.0

var has_taken_damage: bool = false
var auto_sized: bool = false
var is_poisoned: bool = false
var _parent_entity_id: String = ""

# Store original fill stylebox for color switching
var _original_fill_color: Color = Color.RED
var _poison_fill_color: Color = Color(0.2, 0.8, 0.2)  # Green

func _ready() -> void:
	# Start hidden - only show after first damage
	visible = false

	# Setup custom fill color (red by default)
	_setup_fill_color()

	# Auto-adjust size and position on next frame (after scene tree is ready)
	call_deferred("auto_adjust_to_hitbox")

	# Get parent entity ID and connect to status signals
	call_deferred("_setup_entity_id")


func _setup_fill_color() -> void:
	# Create custom StyleBoxFlat for the fill
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = _original_fill_color
	fill_style.border_width_left = 0
	fill_style.border_width_right = 0
	fill_style.border_width_top = 0
	fill_style.border_width_bottom = 0

	# Override the theme fill stylebox
	add_theme_stylebox_override("fill", fill_style)

func _setup_entity_id() -> void:
	var parent_node = get_parent()
	if parent_node and "entity_id" in parent_node:
		_parent_entity_id = parent_node.entity_id

		# Connect to StatusEffectSystem signals for event-driven updates
		if StatusEffectSystem:
			StatusEffectSystem.status_applied.connect(_on_status_applied)
			StatusEffectSystem.status_removed.connect(_on_status_removed)

## Auto-adjust health bar size and position based on parent's HitBox
func auto_adjust_to_hitbox() -> void:
	var parent_node = get_parent()
	if not parent_node:
		return
	
	# Find HitBox node in parent
	var hitbox_node = parent_node.get_node_or_null("HitBox")
	if not hitbox_node:
		return
	
	# Find HitBox collision shape
	var hitbox_shape_node = hitbox_node.get_node_or_null("HitBoxShape")
	if not hitbox_shape_node or not hitbox_shape_node.shape:
		return
	
	var shape = hitbox_shape_node.shape
	var hitbox_width: float = 40.0  # Default fallback width
	var hitbox_height: float = 20.0  # Default fallback height
	
	# Calculate HitBox dimensions based on shape type (unscaled collision shape dimensions)
	if shape is CircleShape2D:
		var circle = shape as CircleShape2D
		hitbox_width = circle.radius * 2.0
		hitbox_height = circle.radius * 2.0
	elif shape is RectangleShape2D:
		var rect = shape as RectangleShape2D
		hitbox_width = rect.size.x
		hitbox_height = rect.size.y
	else:
		Logger.warn("Unsupported HitBox shape type: " + str(shape.get_class()), "bosses")
	
	# Account for HitBox scaling (since HitBox node is scaled individually)
	var hitbox_scale = hitbox_node.scale if hitbox_node else Vector2.ONE
	
	# Set health bar width to match scaled HitBox width (with slight padding)
	var scaled_hitbox_width = hitbox_width * hitbox_scale.x
	var health_bar_width = scaled_hitbox_width * 0.8
	var health_bar_height = 3.0  # Fixed height - no scaling compensation needed
	
	# Position health bar above the TOP of the scaled HitBox collision area
	var scaled_hitbox_height = hitbox_height * hitbox_scale.y
	var hitbox_top = hitbox_shape_node.position.y - (scaled_hitbox_height * 0.5)
	var health_bar_y = hitbox_top - y_offset_above_hitbox - health_bar_height
	
	# Apply size and position
	position.x = -(health_bar_width * 0.5)  # Center horizontally
	position.y = health_bar_y
	size.x = health_bar_width
	size.y = health_bar_height
	
	auto_sized = true

func update_health(current: float, max_health: float) -> void:
	if max_health > 0.0:
		var health_percentage = (current / max_health) * 100.0
		value = health_percentage

		# Show health bar after first damage (when HP is below max)
		if not has_taken_damage and current < max_health:
			has_taken_damage = true
			visible = true

		# MEMORY LEAK FIX: Removed frequent debug logging that was causing memory allocation every frame
		# Logger.debug("Boss health updated: %.1f/%.1f (%.0f%%)" % [current, max_health, health_percentage], "bosses")
	else:
		Logger.warn("Invalid max_health in boss health update: " + str(max_health), "bosses")


## Event-driven: Called when status effect is applied
func _on_status_applied(entity_id: String, effect_type: String) -> void:
	if entity_id == _parent_entity_id and effect_type == "poison":
		# Change fill color to green
		_set_fill_color(_poison_fill_color)
		is_poisoned = true


## Event-driven: Called when status effect is removed/expires
func _on_status_removed(entity_id: String, effect_type: String) -> void:
	if entity_id == _parent_entity_id and effect_type == "poison":
		# Restore original red color
		_set_fill_color(_original_fill_color)
		is_poisoned = false


## Change the healthbar fill color
func _set_fill_color(color: Color) -> void:
	var fill_style := get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = color

## Manual trigger for re-adjusting health bar (useful if HitBox changes at runtime)
func readjust_to_hitbox() -> void:
	auto_adjust_to_hitbox()


## Cleanup signal connections on destruction
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Disconnect from StatusEffectSystem to prevent memory leaks
		if StatusEffectSystem and is_instance_valid(StatusEffectSystem):
			if StatusEffectSystem.status_applied.is_connected(_on_status_applied):
				StatusEffectSystem.status_applied.disconnect(_on_status_applied)
			if StatusEffectSystem.status_removed.is_connected(_on_status_removed):
				StatusEffectSystem.status_removed.disconnect(_on_status_removed)
