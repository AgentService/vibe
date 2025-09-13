extends Panel
class_name PlayerInfoPanel

## Unified player information panel containing health, XP, and level
## Self-contained with all functionality built-in using MainTheme styling

# UI element references - labels in text containers inside progress bars for proper clipping
@onready var health_bar: ProgressBar = $PlayerInfoContainer/HealthContainer/HealthProgressBar
@onready var xp_bar: ProgressBar = $PlayerInfoContainer/XPContainer/XPProgressBar
@onready var health_label: Label = $PlayerInfoContainer/HealthContainer/HealthProgressBar/HealthTextContainer/HealthLabel
@onready var xp_label: Label = $PlayerInfoContainer/XPContainer/XPProgressBar/XPTextContainer/XPLabel
@onready var level_label: Label = $PlayerInfoContainer/XPContainer/XPProgressBar/XPTextContainer/LevelLabel
@onready var damage_flash: ColorRect = $PlayerInfoContainer/DamageFlash

# State tracking
var current_health: float = 100.0
var max_health: float = 100.0
var current_xp: int = 0
var xp_to_next: int = 100
var current_level: int = 1

# Animation references
var _flash_tween: Tween

func _ready() -> void:
	# Apply MainTheme styling
	_apply_main_theme()
	
	# Apply theme styling to UI elements
	_apply_ui_theming()
	
	# Connect to EventBus for updates
	_connect_signals()
	
	# Initialize with current state  
	_initialize_display()

func _apply_main_theme() -> void:
	if not ThemeManager or not ThemeManager.current_theme:
		Logger.warn("PlayerInfoPanel: MainTheme not available", "ui")
		return
	
	var theme = ThemeManager.current_theme
	
	# Create styled background for the panel
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = theme.background_overlay
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = theme.border_color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	
	add_theme_stylebox_override("panel", style_box)

func _apply_ui_theming() -> void:
	"""Apply enhanced AAA styling to match integrated AbilityBar theme"""
	if not ThemeManager or not ThemeManager.current_theme:
		return
	
	var theme = ThemeManager.current_theme
	
	# Apply enhanced styling to progress bars for visual harmony
	_apply_enhanced_progress_bar_styling(theme)
	
func _apply_enhanced_progress_bar_styling(theme: MainTheme) -> void:
	"""Apply AAA-quality styling to progress bars matching ability button theme"""
	
	# Setup Health Bar with enhanced AAA theming
	if health_bar:
		var health_theme := Theme.new()
		var health_bg := _create_enhanced_progress_bg("health", theme)
		var health_fill := _create_enhanced_progress_fill("health", theme)
		
		health_theme.set_stylebox("background", "ProgressBar", health_bg)
		health_theme.set_stylebox("fill", "ProgressBar", health_fill)
		health_bar.theme = health_theme
		health_bar.show_percentage = false
	
	# Setup XP Bar with enhanced AAA theming
	if xp_bar:
		var xp_theme := Theme.new()
		var xp_bg := _create_enhanced_progress_bg("xp", theme)
		var xp_fill := _create_enhanced_progress_fill("xp", theme)
		
		xp_theme.set_stylebox("background", "ProgressBar", xp_bg)
		xp_theme.set_stylebox("fill", "ProgressBar", xp_fill)
		xp_bar.theme = xp_theme
		xp_bar.show_percentage = false
	
	# Apply enhanced label styling to match AAA theme
	_apply_enhanced_label_styling(theme)

func _create_enhanced_progress_bg(bar_type: String, theme: MainTheme) -> StyleBoxFlat:
	"""Create enhanced background StyleBox for progress bars matching ability button quality"""
	var style := StyleBoxFlat.new()
	
	match bar_type:
		"health":
			# Health bar gets darker, more serious background
			style.bg_color = Color(theme.background_dark.r + 0.02, theme.background_dark.g + 0.02, theme.background_dark.b + 0.02, 0.95)
			style.border_color = Color(theme.success_color.r * 0.6, theme.success_color.g * 0.6, theme.success_color.b * 0.6, 0.8)
		"xp":
			# XP bar gets slightly brighter background
			style.bg_color = Color(theme.background_medium.r + 0.05, theme.background_medium.g + 0.05, theme.background_medium.b + 0.05, 0.95)
			style.border_color = Color(theme.primary_color.r * 0.7, theme.primary_color.g * 0.7, theme.primary_color.b * 0.7, 0.8)
	
	# Enhanced styling properties
	style.set_border_width_all(theme.border_width_medium)
	style.set_corner_radius_all(theme.corner_radius_small)
	style.border_blend = true
	style.anti_aliasing = true
	
	# Add subtle shadow for depth
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	
	return style

func _create_enhanced_progress_fill(bar_type: String, theme: MainTheme) -> StyleBoxFlat:
	"""Create enhanced fill StyleBox for progress bars with premium look"""
	var style := StyleBoxFlat.new()
	
	match bar_type:
		"health":
			# Health uses enhanced success color with brightness
			style.bg_color = Color(theme.success_color.r + 0.1, theme.success_color.g + 0.1, theme.success_color.b * 0.9, 1.0)
		"xp":
			# XP uses enhanced primary color
			style.bg_color = Color(theme.primary_color.r + 0.1, theme.primary_color.g + 0.1, theme.primary_color.b + 0.2, 1.0)
	
	# Professional corner radius matching ability buttons
	style.set_corner_radius_all(theme.corner_radius_small - 1)  # Slightly smaller than background for clean look
	style.anti_aliasing = true
	
	return style

func _apply_enhanced_label_styling(theme: MainTheme) -> void:
	"""Apply enhanced label styling with better shadows and colors"""
	if health_label:
		health_label.add_theme_color_override("font_color", theme.text_primary)
		health_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		health_label.add_theme_constant_override("shadow_offset_x", 1)
		health_label.add_theme_constant_override("shadow_offset_y", 1)
	
	if xp_label:
		xp_label.add_theme_color_override("font_color", theme.text_primary)
		xp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		xp_label.add_theme_constant_override("shadow_offset_x", 1)
		xp_label.add_theme_constant_override("shadow_offset_y", 1)
	
	if level_label:
		level_label.add_theme_color_override("font_color", theme.primary_light)
		level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		level_label.add_theme_constant_override("shadow_offset_x", 1)
		level_label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Setup damage flash
	if damage_flash:
		damage_flash.color = Color(1, 0, 0, 0)  # Red with zero alpha initially
		damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _connect_signals() -> void:
	# Connect to progression and health events
	if EventBus:
		EventBus.health_changed.connect(_on_health_changed)
		EventBus.damage_applied.connect(_on_damage_taken)
		EventBus.progression_changed.connect(_on_progression_changed)
		EventBus.leveled_up.connect(_on_leveled_up)
		Logger.debug("PlayerInfoPanel: Connected to EventBus signals (health_changed, damage_applied, progression_changed, leveled_up)", "ui")
	else:
		Logger.warn("PlayerInfoPanel: EventBus not available for signal connections", "ui")

func _initialize_display() -> void:
	# Initialize with PlayerProgression state if available
	if PlayerProgression:
		var state = PlayerProgression.get_progression_state()
		_on_progression_changed(state)
		Logger.debug("PlayerInfoPanel: Initialized with PlayerProgression state", "ui")
	else:
		# Fallback values for XP/level only
		_update_xp_display(0, 100)
		_update_level_display(1)
		Logger.debug("PlayerInfoPanel: PlayerProgression not available, using fallback XP/level values", "ui")
	
	# Initialize health display with default player values
	# This will be overridden when Player emits health_changed signal
	_update_health_display(500.0, 500.0)  # Match default_player.tres max_health
	Logger.debug("PlayerInfoPanel: Initialized health display with default values", "ui")

# Health management
func _update_health_display(current: float, max_hp: float) -> void:
	current_health = current
	max_health = max_hp
	
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current
	
	if health_label:
		health_label.text = "%d/%d HP" % [int(current), int(max_hp)]
	
	# Show critical health warning
	if (current / max_hp) <= 0.25:
		_show_critical_health_warning()

# XP management
func _update_xp_display(current: int, total: int) -> void:
	current_xp = current
	xp_to_next = total
	
	if xp_bar:
		xp_bar.max_value = total
		xp_bar.value = current
	
	if xp_label:
		xp_label.text = "%d/%d" % [current, total]

# Level management
func _update_level_display(level: int) -> void:
	current_level = level
	
	if level_label:
		level_label.text = "Lv: %d" % level  # Shorter format to fit better in XP bar

# Visual effects
func play_damage_flash() -> void:
	if not damage_flash:
		return
	
	# Kill existing tween
	if _flash_tween:
		_flash_tween.kill()
	
	_flash_tween = create_tween()
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.set_trans(Tween.TRANS_QUAD)
	
	# Flash red then fade out
	damage_flash.color.a = 0.5
	_flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.3)

func _show_critical_health_warning() -> void:
	if not health_bar:
		return
	
	# Flash the health bar when health is critical
	if _flash_tween:
		_flash_tween.kill()
	
	_flash_tween = create_tween()
	_flash_tween.set_loops()
	_flash_tween.set_ease(Tween.EASE_IN_OUT)
	_flash_tween.set_trans(Tween.TRANS_SINE)
	
	# Pulse the health bar
	_flash_tween.tween_property(health_bar, "modulate:a", 0.6, 0.5)
	_flash_tween.tween_property(health_bar, "modulate:a", 1.0, 0.5)

func play_level_up_effect() -> void:
	if not xp_bar:
		return
	
	# Flash effect for level up
	var tween = create_tween()
	tween.tween_property(xp_bar, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.2)
	tween.tween_property(xp_bar, "modulate", Color.WHITE, 0.3)

# Signal handlers
func _on_health_changed(current_hp: float, max_hp: float) -> void:
	Logger.debug("PlayerInfoPanel: Health changed - %d/%d HP" % [int(current_hp), int(max_hp)], "ui")
	_update_health_display(current_hp, max_hp)

func _on_damage_taken(payload) -> void:
	play_damage_flash()

func _on_progression_changed(state: Dictionary) -> void:
	Logger.debug("PlayerInfoPanel: Received progression state: %s" % [state], "ui")
	
	var level = int(state.get("level", 1))
	var exp = int(state.get("exp", 0))
	var exp_to_next = int(state.get("xp_to_next", 100))
	
	_update_level_display(level)
	_update_xp_display(exp, exp_to_next)
	
	Logger.debug("PlayerInfoPanel: Progression updated - Level: %d, XP: %d/%d" % [level, exp, exp_to_next], "ui")

func _on_leveled_up(new_level: int, prev_level: int) -> void:
	_update_level_display(new_level)
	play_level_up_effect()
	Logger.debug("PlayerInfoPanel: Level up! %d -> %d" % [prev_level, new_level], "ui")

# Public API
func get_player_info_stats() -> Dictionary:
	return {
		"current_health": current_health,
		"max_health": max_health,
		"health_percentage": (current_health / max_health) * 100.0 if max_health > 0 else 0.0,
		"current_xp": current_xp,
		"xp_to_next": xp_to_next,
		"xp_percentage": (float(current_xp) / float(xp_to_next)) * 100.0 if xp_to_next > 0 else 0.0,
		"current_level": current_level
	}
