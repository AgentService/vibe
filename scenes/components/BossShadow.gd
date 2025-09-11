extends Sprite2D

## Flexible Boss Shadow - Auto-sizes and positions based on parent's HitBox
## Features:
## - Automatically sizes to match HitBox dimensions with configurable multiplier
## - Auto-positions below HitBox bounds with configurable offset
## - Supports both CircleShape2D and RectangleShape2D HitBoxes
## - Configurable opacity, size, and visual properties

class_name BossShadow

# Shadow configuration - can be overridden by parent boss
@export var size_multiplier: float = 1.0: set = _set_size_multiplier  # Size relative to HitBox (neutral default)
@export var opacity: float = 0.6: set = _set_opacity  # Shadow transparency
@export var offset_y: float = -5.0: set = _set_offset_y  # Pixels above HitBox bottom
@export var enabled: bool = true: set = _set_enabled  # Can disable shadows per-boss

var auto_sized: bool = false

func _ready() -> void:
	# Set initial properties
	z_index = -1  # Ensure shadow renders below boss
	modulate = Color(0, 0, 0, opacity)
	
	# Hide if disabled
	if not enabled:
		visible = false
		return
	
	# Auto-adjust size and position on next frame (after scene tree is ready)
	call_deferred("auto_adjust_to_hitbox")

## Auto-adjust shadow size and position based on parent's HitBox
func auto_adjust_to_hitbox() -> void:
	var parent_node = get_parent()
	if not parent_node:
		Logger.warn("BossShadow has no parent - cannot auto-adjust", "bosses")
		return
	
	# Find HitBox node in parent
	var hitbox_node = parent_node.get_node_or_null("HitBox")
	if not hitbox_node:
		Logger.debug("Parent has no HitBox node - using default shadow positioning", "bosses")
		_apply_default_shadow_settings()
		return
	
	# Find HitBox collision shape
	var hitbox_shape_node = hitbox_node.get_node_or_null("HitBoxShape")
	if not hitbox_shape_node or not hitbox_shape_node.shape:
		Logger.debug("HitBox has no collision shape - using default shadow positioning", "bosses")
		_apply_default_shadow_settings()
		return
	
	var shape = hitbox_shape_node.shape
	var width: float = 32.0  # Default fallback width
	var height: float = 32.0  # Default fallback height
	
	# Calculate BASE dimensions from shape (before scale transform)
	if shape is CircleShape2D:
		var circle = shape as CircleShape2D
		width = circle.radius * 2.0
		height = circle.radius * 2.0
	elif shape is RectangleShape2D:
		var rect = shape as RectangleShape2D
		width = rect.size.x
		height = rect.size.y
	else:
		Logger.warn("Unsupported HitBox shape type for shadow: " + str(shape.get_class()), "bosses")
		_apply_default_shadow_settings()
		return
	
	# CRITICAL: Apply HitBox scale transform to get EFFECTIVE dimensions
	# This accounts for boss scaling (e.g., 2.0x size_factor makes HitBox 2x larger)
	var effective_width = width * hitbox_node.scale.x
	var effective_height = height * hitbox_node.scale.y
	
	Logger.debug("Shadow calc: base=%.1fx%.1f, hitbox_scale=%v, effective=%.1fx%.1f" % [
		width, height, hitbox_node.scale, effective_width, effective_height], "debug")
	
	# Calculate shadow dimensions using EFFECTIVE (scaled) dimensions
	var shadow_width = effective_width * size_multiplier  # Match effective HitBox width with size multiplier  
	var shadow_height = effective_width * size_multiplier * 0.3  # Height based on effective WIDTH for realistic ground shadow
	
	# Position shadow at the bottom of the BASE (unscaled) HitBox with configurable offset
	# This ensures shadow offset_y remains consistent regardless of boss scale
	var hitbox_world_bottom = hitbox_node.position.y + hitbox_shape_node.position.y + (height * 0.5)
	var shadow_y = hitbox_world_bottom - offset_y  # Apply offset_y for positioning adjustment
	
	# Apply size and position (accounting for both HitBox and HitBoxShape positions)
	position.x = hitbox_node.position.x + hitbox_shape_node.position.x  # Match HitBox center horizontally
	position.y = shadow_y
	scale.x = shadow_width / texture.get_width() if texture else 1.0
	scale.y = shadow_height / texture.get_height() if texture else 0.4
	
	auto_sized = true
	Logger.debug("BossShadow auto-adjusted: effective_hitbox=%.1fx%.1f, shadow=%.1fx%.1f, y=%.1f" % [
		effective_width, effective_height, shadow_width, shadow_height, shadow_y], "debug")

## Apply default shadow settings when HitBox is not available
func _apply_default_shadow_settings() -> void:
	# Use reasonable defaults based on typical boss sizes
	position = Vector2(0, 16)  # 16 pixels below boss center
	scale = Vector2(1.0, 0.4)  # Standard size, flattened
	auto_sized = true
	Logger.debug("BossShadow using default settings", "bosses")

## Update shadow properties (called from boss configuration)
func configure_shadow(config: Dictionary) -> void:
	if config.has("enabled"):
		enabled = config.enabled
		visible = enabled
	
	if config.has("size_multiplier"):
		size_multiplier = config.size_multiplier
	
	if config.has("opacity"):
		opacity = config.opacity
		modulate = Color(0, 0, 0, opacity)
	
	if config.has("offset_y"):
		offset_y = config.offset_y
	
	# Re-adjust if already sized
	if auto_sized:
		call_deferred("auto_adjust_to_hitbox")
	
	Logger.debug("BossShadow configured: enabled=%s, size=%.2f, opacity=%.2f" % [enabled, size_multiplier, opacity], "bosses")

## Manual trigger for re-adjusting shadow (useful if HitBox changes at runtime)
func readjust_to_hitbox() -> void:
	auto_adjust_to_hitbox()

## Setters for real-time Inspector updates
func _set_size_multiplier(value: float) -> void:
	size_multiplier = value
	if auto_sized:
		call_deferred("auto_adjust_to_hitbox")

func _set_opacity(value: float) -> void:
	opacity = value
	modulate = Color(0, 0, 0, opacity)

func _set_offset_y(value: float) -> void:
	offset_y = value
	if auto_sized:
		call_deferred("auto_adjust_to_hitbox")

func _set_enabled(value: bool) -> void:
	enabled = value
	visible = enabled
	if not enabled:
		return
	# Re-enable and readjust if needed
	if auto_sized:
		call_deferred("auto_adjust_to_hitbox")
