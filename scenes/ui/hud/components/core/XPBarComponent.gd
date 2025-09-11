extends BaseHUDComponent
class_name XPBarComponent

## Experience bar component showing progression towards next level
## Styled to match original HUD system with blue theme

@onready var xp_bar: ProgressBar = $XPBar
@onready var xp_label: Label = $XPLabel

# XP tracking
var current_xp: int = 0
var xp_to_next: int = 100
var current_level: int = 1

func _setup_component() -> void:
	_style_xp_bar()
	_initialize_xp_display()

func bind_events() -> void:
	if EventBus:
		EventBus.progression_changed.connect(_on_progression_changed)
		EventBus.leveled_up.connect(_on_leveled_up)

func _style_xp_bar() -> void:
	if not xp_bar:
		return
		
	# Create theme matching old HUD system
	var xp_theme := Theme.new()
	var style_bg := StyleBoxFlat.new()
	var style_fill := StyleBoxFlat.new()
	
	# Background (empty XP)
	style_bg.bg_color = Color(0.2, 0.2, 0.4, 0.8)  # Dark blue-gray
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color(0.4, 0.4, 0.6, 1.0)  # Light blue-gray border
	style_bg.corner_radius_top_left = 3
	style_bg.corner_radius_top_right = 3
	style_bg.corner_radius_bottom_left = 3
	style_bg.corner_radius_bottom_right = 3
	
	# Fill (current XP)
	style_fill.bg_color = Color(0.4, 0.6, 1.0, 1.0)  # Bright blue
	style_fill.corner_radius_top_left = 2
	style_fill.corner_radius_top_right = 2
	style_fill.corner_radius_bottom_left = 2
	style_fill.corner_radius_bottom_right = 2
	
	xp_theme.set_stylebox("background", "ProgressBar", style_bg)
	xp_theme.set_stylebox("fill", "ProgressBar", style_fill)
	
	xp_bar.theme = xp_theme
	xp_bar.show_percentage = false

func _style_xp_label() -> void:
	if not xp_label:
		return
		
	# Style label to be readable over the XP bar
	var label_theme := Theme.new()
	label_theme.set_color("font_color", "Label", Color.WHITE)
	label_theme.set_color("font_shadow_color", "Label", Color.BLACK)
	label_theme.set_constant("shadow_offset_x", "Label", 1)
	label_theme.set_constant("shadow_offset_y", "Label", 1)
	
	xp_label.theme = label_theme
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _initialize_xp_display() -> void:
	# Get initial progression state from PlayerProgression
	if PlayerProgression:
		var state = PlayerProgression.get_progression_state()
		_on_progression_changed(state)
		Logger.debug("XPBarComponent: Initialized with PlayerProgression state", "ui")
	else:
		# Fallback values
		_update_xp_display(0, 100)
		Logger.debug("XPBarComponent: PlayerProgression not available, using fallback values", "ui")

func _update_xp_display(current: int, total: int) -> void:
	current_xp = current
	xp_to_next = total
	
	if xp_bar:
		xp_bar.max_value = total
		xp_bar.value = current
	
	if xp_label:
		xp_label.text = "XP: %d/%d" % [current, total]
	
	Logger.debug("XPBarComponent: Updated display - %d/%d XP" % [current, total], "ui")

# Signal handlers
func _on_progression_changed(state: Dictionary) -> void:
	var exp = int(state.get("exp", 0))
	var exp_to_next = int(state.get("xp_to_next", 100))
	current_level = int(state.get("level", 1))
	
	Logger.debug("XPBarComponent: Progression changed - Level: %d, XP: %d/%d" % [current_level, exp, exp_to_next], "ui")
	_update_xp_display(exp, exp_to_next)

func _on_leveled_up(new_level: int, prev_level: int) -> void:
	current_level = new_level
	Logger.debug("XPBarComponent: Level up! %d -> %d" % [prev_level, new_level], "ui")
	
	# Flash effect for level up
	if xp_bar:
		var tween = create_tween()
		tween.tween_property(xp_bar, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.2)
		tween.tween_property(xp_bar, "modulate", Color.WHITE, 0.3)

# Public API
func get_xp_stats() -> Dictionary:
	return {
		"current_xp": current_xp,
		"xp_to_next": xp_to_next,
		"current_level": current_level,
		"progress_percent": (float(current_xp) / float(xp_to_next)) * 100.0 if xp_to_next > 0 else 0.0
	}

func set_xp_visible(visible: bool) -> void:
	self.visible = visible
	if visible:
		Logger.debug("XPBarComponent: Shown", "ui")
	else:
		Logger.debug("XPBarComponent: Hidden", "ui")