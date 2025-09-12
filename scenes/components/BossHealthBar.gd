extends ProgressBar

## Flexible Boss Health Bar - Auto-sizes and positions based on parent's HitBox
## Features:
## - Automatically sizes width to match HitBox dimensions  
## - Auto-positions 5px above HitBox bounds
## - Only appears after first damage (performance optimization)
## - Works with both CircleShape2D and RectangleShape2D HitBoxes

class_name BossHealthBar

var has_taken_damage: bool = false
var auto_sized: bool = false

func _ready() -> void:
	# Start hidden - only show after first damage
	visible = false
	
	# Auto-adjust size and position on next frame (after scene tree is ready)
	call_deferred("auto_adjust_to_hitbox")

## Auto-adjust health bar size and position based on parent's HitBox
func auto_adjust_to_hitbox() -> void:
	var parent_node = get_parent()
	if not parent_node:
		Logger.warn("BossHealthBar has no parent - cannot auto-adjust", "bosses")
		return
	
	# Find HitBox node in parent
	var hitbox_node = parent_node.get_node_or_null("HitBox")
	if not hitbox_node:
		Logger.warn("Parent has no HitBox node - cannot auto-adjust BossHealthBar", "bosses")
		return
	
	# Find HitBox collision shape
	var hitbox_shape_node = hitbox_node.get_node_or_null("HitBoxShape")
	if not hitbox_shape_node or not hitbox_shape_node.shape:
		Logger.warn("HitBox has no collision shape - cannot auto-adjust BossHealthBar", "bosses")
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
	
	# Position health bar 12px above the TOP of the scaled HitBox collision area
	var scaled_hitbox_height = hitbox_height * hitbox_scale.y
	var hitbox_top = hitbox_shape_node.position.y - (scaled_hitbox_height * 0.5)
	var health_bar_y = hitbox_top - 12.0 - health_bar_height
	
	# Apply size and position
	position.x = -(health_bar_width * 0.5)  # Center horizontally
	position.y = health_bar_y
	size.x = health_bar_width
	size.y = health_bar_height
	
	auto_sized = true
	Logger.debug("BossHealthBar auto-adjusted: width=%.1f, y=%.1f (hitbox_scale: %.1fx%.1f)" % [health_bar_width, health_bar_y, hitbox_scale.x, hitbox_scale.y], "bosses")

func update_health(current: float, max_health: float) -> void:
	if max_health > 0.0:
		var health_percentage = (current / max_health) * 100.0
		value = health_percentage
		
		# Show health bar after first damage (when HP is below max)
		if not has_taken_damage and current < max_health:
			has_taken_damage = true
			visible = true
			Logger.debug("Boss health bar now visible after first damage", "bosses")
		
		# MEMORY LEAK FIX: Removed frequent debug logging that was causing memory allocation every frame
		# Logger.debug("Boss health updated: %.1f/%.1f (%.0f%%)" % [current, max_health, health_percentage], "bosses")
	else:
		Logger.warn("Invalid max_health in boss health update: " + str(max_health), "bosses")

## Manual trigger for re-adjusting health bar (useful if HitBox changes at runtime)
func readjust_to_hitbox() -> void:
	auto_adjust_to_hitbox()
