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
@export var offset_y: float = 0.0: set = _set_offset_y  # Pixels above HitBox bottom
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
	
	# Position shadow using sprite-based positioning for consistency across different boss configurations
	# This ensures shadows appear at the same ground level regardless of HitBox setup variations
	var shadow_y = _calculate_sprite_based_shadow_position(parent_node)
	
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

## SPRITE-BASED SHADOW POSITIONING: Calculate shadow position based on sprite bounds for consistency
func _calculate_sprite_based_shadow_position(parent_node: Node) -> float:
	# Try to get the AnimatedSprite2D from the parent boss
	var animated_sprite = parent_node.get_node_or_null("AnimatedSprite2D")
	if not animated_sprite:
		Logger.debug("No AnimatedSprite2D found, using fallback shadow positioning", "debug")
		return _calculate_fallback_shadow_position(parent_node)
	
	# Calculate sprite bottom position (sprite center + half height)
	var sprite_position = animated_sprite.position
	var sprite_scale = animated_sprite.scale
	
	# Get sprite texture bounds
	var sprite_height = 32.0  # Default fallback
	if animated_sprite.sprite_frames and animated_sprite.animation:
		var current_frame_texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
		if current_frame_texture:
			sprite_height = current_frame_texture.get_height()
	
	# Calculate effective sprite bottom (considering scale and position)
	var effective_sprite_height = sprite_height * sprite_scale.y
	var sprite_bottom = sprite_position.y + (effective_sprite_height * 0.5)
	
	# Apply configurable offset
	var shadow_y = sprite_bottom - offset_y
	
	Logger.debug("Sprite-based shadow positioning: sprite_pos=%v, sprite_h=%.1f, effective_h=%.1f, bottom=%.1f, final_y=%.1f" % [
		sprite_position, sprite_height, effective_sprite_height, sprite_bottom, shadow_y], "debug")
	
	return shadow_y

## FALLBACK SHADOW POSITIONING: Use HitBox method when sprite info unavailable
func _calculate_fallback_shadow_position(parent_node: Node) -> float:
	# Get HitBox information
	var hitbox_node = parent_node.get_node_or_null("HitBox")
	if not hitbox_node:
		return 16.0  # Default fallback position
	
	var hitbox_shape_node = hitbox_node.get_node_or_null("HitBoxShape")
	if not hitbox_shape_node or not hitbox_shape_node.shape:
		return 16.0  # Default fallback position
	
	# Use original HitBox-based calculation
	var shape = hitbox_shape_node.shape
	var height = 32.0  # Default
	
	if shape is CircleShape2D:
		var circle = shape as CircleShape2D
		height = circle.radius * 2.0
	elif shape is RectangleShape2D:
		var rect = shape as RectangleShape2D
		height = rect.size.y
	
	var hitbox_world_bottom = hitbox_node.position.y + hitbox_shape_node.position.y + (height * 0.5)
	var shadow_y = hitbox_world_bottom - offset_y
	
	Logger.debug("Fallback HitBox shadow positioning: hitbox_bottom=%.1f, final_y=%.1f" % [hitbox_world_bottom, shadow_y], "debug")
	
	return shadow_y
