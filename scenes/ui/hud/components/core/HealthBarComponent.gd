class_name HealthBarComponent
extends BaseHUDComponent

## Universal health bar component for player health display
## Supports both regular health bars and boss-style health bars with dynamic sizing

@export var health_bar_style: HealthBarStyle = HealthBarStyle.PLAYER
@export var show_percentage: bool = false
@export var show_damage_flash: bool = true
@export var auto_hide_when_full: bool = false

enum HealthBarStyle {
	PLAYER,    # Standard player health bar at bottom of screen
	BOSS,      # Boss health bar that auto-sizes to entity hitbox
	ENEMY      # Small enemy health bar (for elite enemies)
}

# Components
var _health_bar: ProgressBar
var _health_label: Label
var _damage_flash: ColorRect

# State tracking
var _current_health: float = 100.0
var _max_health: float = 100.0
var _has_taken_damage: bool = false
var _flash_tween: Tween

# Boss health bar specific
var _target_entity: Node = null
var _auto_sized: bool = false

func _init() -> void:
	super._init()
	component_id = "health_bar"
	update_frequency = 60.0  # Smooth health animations

func _setup_component() -> void:
	_create_health_bar_ui()
	_setup_health_bar_style()
	_connect_health_signals()

func _update_component(delta: float) -> void:
	# Boss health bars need to track their target entity
	if health_bar_style == HealthBarStyle.BOSS and _target_entity:
		_update_boss_positioning()

func _create_health_bar_ui() -> void:
	# Create main progress bar
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthProgressBar"
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = show_percentage
	_health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_health_bar)
	
	# Create damage flash overlay
	if show_damage_flash:
		_damage_flash = ColorRect.new()
		_damage_flash.name = "DamageFlash"
		_damage_flash.color = Color.RED
		_damage_flash.color.a = 0.0
		_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_damage_flash)
		_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Create health label for detailed display (overlay on progress bar)
	if health_bar_style == HealthBarStyle.PLAYER:
		_health_label = Label.new()
		_health_label.name = "HealthLabel" 
		_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_health_label.text = "100/100"
		_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_health_label)

func _setup_health_bar_style() -> void:
	match health_bar_style:
		HealthBarStyle.PLAYER:
			_setup_player_health_style()
		HealthBarStyle.BOSS:
			_setup_boss_health_style()
		HealthBarStyle.ENEMY:
			_setup_enemy_health_style()

func _setup_player_health_style() -> void:
	# Large health bar for player
	custom_minimum_size = Vector2(300, 25)
	
	# Create player health theme
	var health_theme := Theme.new()
	var style_bg := StyleBoxFlat.new()
	var style_fill := StyleBoxFlat.new()
	
	# Background (empty health) - Make it fully opaque
	style_bg.bg_color = Color(0.15, 0.15, 0.15, 1.0)  # Dark gray, fully opaque
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color(0.6, 0.6, 0.6, 1.0)  # Gray border
	style_bg.corner_radius_top_left = 3
	style_bg.corner_radius_top_right = 3
	style_bg.corner_radius_bottom_left = 3
	style_bg.corner_radius_bottom_right = 3
	
	# Fill (current health) - Bright red, fully opaque
	style_fill.bg_color = Color(0.9, 0.1, 0.1, 1.0)  # Bright red
	style_fill.corner_radius_top_left = 2
	style_fill.corner_radius_top_right = 2
	style_fill.corner_radius_bottom_left = 2
	style_fill.corner_radius_bottom_right = 2
	
	health_theme.set_stylebox("background", "ProgressBar", style_bg)
	health_theme.set_stylebox("fill", "ProgressBar", style_fill)
	
	_health_bar.theme = health_theme
	
	# Style health label if it exists
	if _health_label:
		_health_label.add_theme_color_override("font_color", Color.WHITE)
		# Add slight shadow to make text more readable
		_health_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		_health_label.add_theme_constant_override("shadow_offset_x", 1)
		_health_label.add_theme_constant_override("shadow_offset_y", 1)

func _setup_boss_health_style() -> void:
	# Boss health bars start hidden and auto-size
	visible = false
	
	# Create boss health theme
	var health_theme := Theme.new()
	var style_bg := StyleBoxFlat.new()
	var style_fill := StyleBoxFlat.new()
	
	# Background
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_bg.border_width_left = 1
	style_bg.border_width_top = 1
	style_bg.border_width_right = 1
	style_bg.border_width_bottom = 1
	style_bg.border_color = Color(0.6, 0.5, 0.4, 1)
	style_bg.corner_radius_top_left = 3
	style_bg.corner_radius_top_right = 3
	style_bg.corner_radius_bottom_right = 3
	style_bg.corner_radius_bottom_left = 3
	
	# Fill
	style_fill.bg_color = Color(0.8, 0.2, 0.2, 1)
	style_fill.border_width_left = 1
	style_fill.border_width_top = 1
	style_fill.border_width_right = 1
	style_fill.border_width_bottom = 1
	style_fill.border_color = Color(1, 0.3, 0.3, 1)
	style_fill.corner_radius_top_left = 2
	style_fill.corner_radius_top_right = 2
	style_fill.corner_radius_bottom_right = 2
	style_fill.corner_radius_bottom_left = 2
	
	health_theme.set_stylebox("background", "ProgressBar", style_bg)
	health_theme.set_stylebox("fill", "ProgressBar", style_fill)
	
	_health_bar.theme = health_theme
	_health_bar.show_percentage = false

func _setup_enemy_health_style() -> void:
	# Small health bars for elite enemies
	custom_minimum_size = Vector2(40, 4)
	
	var health_theme := Theme.new()
	var style_bg := StyleBoxFlat.new()
	var style_fill := StyleBoxFlat.new()
	
	style_bg.bg_color = Color(0.3, 0.1, 0.1, 0.8)
	style_fill.bg_color = Color(0.9, 0.3, 0.3, 1.0)
	
	health_theme.set_stylebox("background", "ProgressBar", style_bg)
	health_theme.set_stylebox("fill", "ProgressBar", style_fill)
	
	_health_bar.theme = health_theme
	_health_bar.show_percentage = false

func _connect_health_signals() -> void:
	# Connect to appropriate health signals based on style
	match health_bar_style:
		HealthBarStyle.PLAYER:
			connect_to_signal(EventBus.health_changed, _on_health_changed)
			connect_to_signal(EventBus.damage_applied, _on_damage_taken)
		HealthBarStyle.BOSS:
			# Boss health bars connect to specific boss entities
			pass
		HealthBarStyle.ENEMY:
			# Enemy health bars connect to specific enemy entities
			pass

# Public API
func update_health(current: float, max_health: float) -> void:
	_current_health = current
	_max_health = max_health
	
	if max_health > 0.0:
		var health_percentage = (current / max_health) * 100.0
		_health_bar.max_value = max_health
		_health_bar.value = current
		
		# Update label if available
		if _health_label:
			_health_label.text = "%d/%d" % [int(current), int(max_health)]
		
		# Show health bar after first damage for boss/enemy styles
		if health_bar_style != HealthBarStyle.PLAYER and not _has_taken_damage and current < max_health:
			_has_taken_damage = true
			visible = true
			Logger.debug("Health bar now visible after first damage: " + component_id, "ui")
		
		# Auto-hide when full if enabled
		if auto_hide_when_full and current >= max_health and health_bar_style != HealthBarStyle.PLAYER:
			visible = false
		
		# Critical health warning for player
		if health_bar_style == HealthBarStyle.PLAYER and (current / max_health) <= 0.25:
			_show_critical_health_warning()
	else:
		Logger.warn("Invalid max_health in health update: " + str(max_health), "ui")

func attach_to_entity(entity: Node) -> void:
	"""Attach this health bar to a specific entity (for boss/enemy health bars)"""
	_target_entity = entity
	
	if health_bar_style == HealthBarStyle.BOSS:
		# Auto-adjust size and position on next frame
		call_deferred("_auto_adjust_to_hitbox")

func play_damage_flash() -> void:
	if not show_damage_flash or not _damage_flash:
		return
	
	# Kill existing tween
	if _flash_tween:
		_flash_tween.kill()
	
	_flash_tween = create_tween()
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.set_trans(Tween.TRANS_QUAD)
	
	# Flash red then fade out
	_damage_flash.color.a = 0.5
	_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.3)

# Boss health bar specific methods
func _auto_adjust_to_hitbox() -> void:
	if not _target_entity or health_bar_style != HealthBarStyle.BOSS:
		return
	
	# Find HitBox node in target entity
	var hitbox_node = _target_entity.get_node_or_null("HitBox")
	if not hitbox_node:
		Logger.warn("Target entity has no HitBox node - cannot auto-adjust health bar", "ui")
		return
	
	# Find HitBox collision shape
	var hitbox_shape_node = hitbox_node.get_node_or_null("HitBoxShape")
	if not hitbox_shape_node or not hitbox_shape_node.shape:
		Logger.warn("HitBox has no collision shape - cannot auto-adjust health bar", "ui")
		return
	
	var shape = hitbox_shape_node.shape
	var hitbox_width: float = 40.0  # Default fallback width
	var hitbox_height: float = 20.0  # Default fallback height
	
	# Calculate HitBox dimensions based on shape type
	if shape is CircleShape2D:
		var circle = shape as CircleShape2D
		hitbox_width = circle.radius * 2.0
		hitbox_height = circle.radius * 2.0
	elif shape is RectangleShape2D:
		var rect = shape as RectangleShape2D
		hitbox_width = rect.size.x
		hitbox_height = rect.size.y
	else:
		Logger.warn("Unsupported HitBox shape type: " + str(shape.get_class()), "ui")
	
	# Account for HitBox scaling
	var hitbox_scale = hitbox_node.scale if hitbox_node else Vector2.ONE
	
	# Set health bar width to match scaled HitBox width (with padding)
	var scaled_hitbox_width = hitbox_width * hitbox_scale.x
	var health_bar_width = scaled_hitbox_width * 0.8
	var health_bar_height = 3.0
	
	# Position health bar above the hitbox
	var scaled_hitbox_height = hitbox_height * hitbox_scale.y
	var hitbox_top = hitbox_shape_node.position.y - (scaled_hitbox_height * 0.5)
	var health_bar_y = hitbox_top - 12.0 - health_bar_height
	
	# Apply size and position
	position.x = -(health_bar_width * 0.5)  # Center horizontally
	position.y = health_bar_y
	size.x = health_bar_width
	size.y = health_bar_height
	custom_minimum_size = Vector2(health_bar_width, health_bar_height)
	
	_auto_sized = true
	Logger.debug("Boss health bar auto-adjusted: width=%.1f, y=%.1f" % [health_bar_width, health_bar_y], "ui")

func _update_boss_positioning() -> void:
	# Update position relative to boss entity if needed
	if not _auto_sized:
		_auto_adjust_to_hitbox()

# Signal handlers
func _on_health_changed(current_health: float, max_health: float) -> void:
	update_health(current_health, max_health)

func _on_damage_taken(payload) -> void:
	# Only show damage flash for player health
	if health_bar_style == HealthBarStyle.PLAYER:
		play_damage_flash()

func _show_critical_health_warning() -> void:
	# Flash the health bar red when health is critical
	if _flash_tween:
		_flash_tween.kill()
	
	_flash_tween = create_tween()
	_flash_tween.set_loops()
	_flash_tween.set_ease(Tween.EASE_IN_OUT)
	_flash_tween.set_trans(Tween.TRANS_SINE)
	
	# Pulse the health bar
	_flash_tween.tween_property(_health_bar, "modulate:a", 0.6, 0.5)
	_flash_tween.tween_property(_health_bar, "modulate:a", 1.0, 0.5)

func get_health_stats() -> Dictionary:
	return {
		"current_health": _current_health,
		"max_health": _max_health,
		"health_percentage": (_current_health / _max_health) * 100.0 if _max_health > 0 else 0.0,
		"has_taken_damage": _has_taken_damage,
		"style": HealthBarStyle.keys()[health_bar_style]
	}
