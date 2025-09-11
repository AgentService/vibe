extends Node
## Theme management system for game-wide visual consistency
##
## Coordinates theme application, hot-swapping, and validation across all UI systems.
## Integrates with UIManager and provides theme caching for performance optimization.

# Theme resources
var current_theme: MainTheme
var fallback_theme: MainTheme

# Theme cache for performance
var theme_cache: Dictionary = {}
var style_box_cache: Dictionary = {}

# Hot reload support
var theme_file_path: String = ""
var last_theme_modified: float = 0.0

# Integration with other systems
var ui_manager: UIManager
var theme_change_listeners: Array[Callable] = []

signal theme_changed(new_theme: MainTheme)
signal theme_validation_failed(errors: Array[String])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load default theme
	load_default_theme()
	
	# Connect to UIManager if available
	if UIManager:
		ui_manager = UIManager
	
	# Setup hot reload monitoring
	setup_theme_monitoring()
	
	Logger.info("ThemeManager initialized with theme: %s" % (current_theme.resource_path if current_theme else "none"), "ui")

func load_default_theme() -> void:
	"""Load the default game theme"""
	# Try to load main theme resource
	var theme_path = "res://themes/main_theme.tres"
	if ResourceLoader.exists(theme_path):
		current_theme = load(theme_path) as MainTheme
		theme_file_path = theme_path
	else:
		# Create default theme if none exists
		current_theme = MainTheme.new()
		Logger.warn("No main_theme.tres found, using default theme", "ui")
	
	# Create fallback theme
	fallback_theme = MainTheme.new()
	
	# Validate theme
	validate_current_theme()
	
	# Cache theme for performance
	cache_theme_data()

func setup_theme_monitoring() -> void:
	"""Setup file monitoring for hot reload during development"""
	if not theme_file_path.is_empty() and FileAccess.file_exists(theme_file_path):
		last_theme_modified = FileAccess.get_modified_time(theme_file_path)

func _process(_delta: float) -> void:
	"""Monitor theme file for hot reload in development"""
	if Engine.is_editor_hint() and not theme_file_path.is_empty():
		check_theme_hot_reload()

func check_theme_hot_reload() -> void:
	"""Check if theme file has been modified for hot reload"""
	if FileAccess.file_exists(theme_file_path):
		var current_modified = FileAccess.get_modified_time(theme_file_path)
		if current_modified > last_theme_modified:
			Logger.info("Theme file modified, hot reloading...", "ui")
			hot_reload_theme()
			last_theme_modified = current_modified

func hot_reload_theme() -> void:
	"""Hot reload theme from file"""
	var new_theme = load(theme_file_path) as MainTheme
	if new_theme:
		set_theme(new_theme)
		Logger.info("Theme hot reloaded successfully", "ui")
	else:
		Logger.error("Failed to hot reload theme", "ui")

# ============================================================================
# THEME MANAGEMENT
# ============================================================================

func set_theme(new_theme: MainTheme) -> void:
	"""Set the current theme and notify all systems"""
	if not new_theme:
		Logger.error("Cannot set null theme", "ui")
		return
	
	var old_theme = current_theme
	current_theme = new_theme
	
	# Validate new theme
	if not validate_current_theme():
		Logger.warn("Theme validation failed, some features may not work correctly", "ui")
	
	# Clear caches
	clear_caches()
	
	# Cache new theme data
	cache_theme_data()
	
	# Notify listeners
	theme_changed.emit(current_theme)
	
	# Notify UI systems
	notify_theme_change()
	
	Logger.info("Theme changed from %s to %s" % [
		old_theme.resource_path if old_theme else "none",
		new_theme.resource_path if new_theme else "runtime"
	], "ui")

func get_theme() -> MainTheme:
	"""Get the current theme"""
	return current_theme if current_theme else fallback_theme

func validate_current_theme() -> bool:
	"""Validate the current theme configuration"""
	if not current_theme:
		return false
	
	var is_valid = current_theme.validate_theme()
	if not is_valid and current_theme.has_method("get_validation_errors"):
		var errors = []  # MainTheme doesn't expose errors yet, but structure is ready
		theme_validation_failed.emit(errors)
	
	return is_valid

# ============================================================================
# THEME CACHING
# ============================================================================

func cache_theme_data() -> void:
	"""Cache frequently used theme data for performance"""
	if not current_theme:
		return
	
	# Cache common colors
	theme_cache["primary"] = current_theme.primary_color
	theme_cache["secondary"] = current_theme.secondary_color
	theme_cache["text_primary"] = current_theme.text_primary
	theme_cache["text_secondary"] = current_theme.text_secondary
	theme_cache["background_medium"] = current_theme.background_medium
	theme_cache["hover"] = current_theme.hover_color
	
	# Cache style boxes
	cache_style_boxes()
	
	Logger.debug("Theme data cached for performance", "ui")

func cache_style_boxes() -> void:
	"""Cache commonly used StyleBox objects"""
	if not current_theme:
		return
	
	# Cache StyleBox objects to avoid recreation
	style_box_cache["panel"] = current_theme.get_themed_style_box("panel")
	style_box_cache["card_panel"] = current_theme.get_themed_style_box("card_panel")
	style_box_cache["button_normal"] = current_theme.get_themed_style_box("button_normal")
	style_box_cache["button_hover"] = current_theme.get_themed_style_box("button_hover")
	style_box_cache["button_pressed"] = current_theme.get_themed_style_box("button_pressed")
	style_box_cache["tooltip"] = current_theme.get_themed_style_box("tooltip")

func clear_caches() -> void:
	"""Clear theme caches"""
	theme_cache.clear()
	style_box_cache.clear()

# ============================================================================
# THEME APPLICATION HELPERS
# ============================================================================

func apply_theme_to_control(control: Control, variant: String = "") -> void:
	"""Apply current theme to a control"""
	if current_theme:
		current_theme.apply_to_control(control, variant)
	else:
		Logger.warn("No theme available for control theming", "ui")

func apply_theme_to_modal(modal: BaseModal) -> void:
	"""Apply current theme to a modal (backward compatibility)"""
	if current_theme:
		current_theme.apply_to_modal(modal)

func get_cached_color(color_name: String) -> Color:
	"""Get cached color by name for performance"""
	if theme_cache.has(color_name):
		return theme_cache[color_name]
	
	# Fallback to theme lookup
	match color_name:
		"primary": return current_theme.primary_color if current_theme else Color.BLUE
		"secondary": return current_theme.secondary_color if current_theme else Color.ORANGE
		"text_primary": return current_theme.text_primary if current_theme else Color.WHITE
		"text_secondary": return current_theme.text_secondary if current_theme else Color.GRAY
		"background_medium": return current_theme.background_medium if current_theme else Color.BLACK
		"hover": return current_theme.hover_color if current_theme else Color.DARK_GRAY
		_:
			Logger.warn("Unknown cached color: %s" % color_name, "ui")
			return Color.MAGENTA  # Obvious error color

func get_cached_style_box(style_name: String) -> StyleBox:
	"""Get cached StyleBox by name for performance"""
	if style_box_cache.has(style_name):
		return style_box_cache[style_name]
	
	# Fallback to theme generation
	if current_theme:
		var style_box = current_theme.get_themed_style_box(style_name)
		style_box_cache[style_name] = style_box  # Cache for future use
		return style_box
	
	Logger.warn("No theme available for StyleBox: %s" % style_name, "ui")
	return StyleBoxFlat.new()

# ============================================================================
# COMPONENT FACTORY METHODS
# ============================================================================

func create_themed_button(text: String = "", variant: String = "") -> Button:
	"""Create a themed button using current theme"""
	if current_theme:
		return current_theme.create_themed_button(text, variant)
	
	# Fallback button
	var button = Button.new()
	button.text = text
	return button

func create_themed_panel(variant: String = "") -> Panel:
	"""Create a themed panel using current theme"""
	if current_theme:
		return current_theme.create_themed_panel(variant)
	
	# Fallback panel
	return Panel.new()

func create_themed_label(text: String = "", variant: String = "") -> Label:
	"""Create a themed label using current theme"""
	if current_theme:
		return current_theme.create_themed_label(text, variant)
	
	# Fallback label
	var label = Label.new()
	label.text = text
	return label

# ============================================================================
# CARD THEMING HELPERS
# ============================================================================

func get_card_color(rarity: String) -> Color:
	"""Get color for card rarity"""
	if current_theme:
		return current_theme.get_card_color(rarity)
	
	# Fallback rarity colors
	match rarity.to_lower():
		"common": return Color.GRAY
		"uncommon": return Color.GREEN
		"rare": return Color.BLUE
		"epic": return Color.PURPLE
		"legendary": return Color.ORANGE
		"mythic": return Color.RED
		_: return Color.GRAY

func apply_card_theme(card: Control, rarity: String = "common") -> void:
	"""Apply card theming with rarity"""
	if current_theme:
		current_theme.apply_card_theme(card, rarity)
	else:
		# Basic fallback styling
		var card_color = get_card_color(rarity)
		if card.has_method("modulate"):
			card.modulate = card_color

# ============================================================================
# LISTENER MANAGEMENT
# ============================================================================

func add_theme_listener(callback: Callable) -> void:
	"""Add a listener for theme changes"""
	if not theme_change_listeners.has(callback):
		theme_change_listeners.append(callback)

func remove_theme_listener(callback: Callable) -> void:
	"""Remove a theme change listener"""
	theme_change_listeners.erase(callback)

func notify_theme_change() -> void:
	"""Notify all listeners of theme change"""
	for callback in theme_change_listeners:
		if callback.is_valid():
			callback.call(current_theme)
		else:
			# Clean up invalid callbacks
			theme_change_listeners.erase(callback)

# ============================================================================
# INTEGRATION WITH UI SYSTEMS
# ============================================================================

func notify_ui_systems() -> void:
	"""Notify UI systems of theme changes"""
	# Notify UIManager if available
	if ui_manager and ui_manager.has_method("on_theme_changed"):
		ui_manager.on_theme_changed(current_theme)
	
	# Could notify other systems here (HUD, CardSystem, etc.)

# ============================================================================
# THEME VARIANTS AND MODES
# ============================================================================

func set_dark_mode(enabled: bool) -> void:
	"""Switch between dark and light theme modes (future feature)"""
	# For now, just log the request
	Logger.info("Dark mode %s requested (not yet implemented)" % ("enabled" if enabled else "disabled"), "ui")

func set_theme_variant(variant_name: String) -> void:
	"""Apply theme variant (seasonal, event-based, etc.)"""
	Logger.info("Theme variant '%s' requested (not yet implemented)" % variant_name, "ui")

# ============================================================================
# DEBUGGING AND DEVELOPMENT
# ============================================================================

func get_theme_debug_info() -> Dictionary:
	"""Get comprehensive theme debug information"""
	var info = {
		"current_theme_path": current_theme.resource_path if current_theme else "none",
		"theme_valid": validate_current_theme(),
		"cache_size": theme_cache.size() + style_box_cache.size(),
		"listeners_count": theme_change_listeners.size(),
		"hot_reload_enabled": Engine.is_editor_hint() and not theme_file_path.is_empty(),
		"last_modified": Time.get_datetime_string_from_unix_time(last_theme_modified)
	}
	
	if current_theme:
		info.merge(current_theme.get_theme_info())
	
	return info

func dump_theme_info() -> void:
	"""Debug dump of theme information"""
	var info = get_theme_debug_info()
	Logger.info("=== THEME DEBUG INFO ===", "ui")
	for key in info.keys():
		Logger.info("%s: %s" % [key, info[key]], "ui")
	Logger.info("=== END THEME DEBUG ===", "ui")

# ============================================================================
# THEME PRESETS
# ============================================================================

func load_theme_preset(preset_name: String) -> bool:
	"""Load a theme preset by name"""
	var preset_path = "res://themes/%s_theme.tres" % preset_name
	
	if ResourceLoader.exists(preset_path):
		var preset_theme = load(preset_path) as MainTheme
		if preset_theme:
			set_theme(preset_theme)
			Logger.info("Loaded theme preset: %s" % preset_name, "ui")
			return true
	
	Logger.error("Theme preset not found: %s" % preset_name, "ui")
	return false

func get_available_presets() -> Array[String]:
	"""Get list of available theme presets"""
	var presets: Array[String] = []
	var dir = DirAccess.open("res://themes/")
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with("_theme.tres"):
				var preset_name = file_name.replace("_theme.tres", "")
				presets.append(preset_name)
			file_name = dir.get_next()
	
	return presets

# ============================================================================
# THEME EXPORT/IMPORT
# ============================================================================

func export_current_theme(file_path: String) -> bool:
	"""Export current theme to file"""
	if not current_theme:
		Logger.error("No theme to export", "ui")
		return false
	
	var result = ResourceSaver.save(current_theme, file_path)
	if result == OK:
		Logger.info("Theme exported to: %s" % file_path, "ui")
		return true
	else:
		Logger.error("Failed to export theme to: %s" % file_path, "ui")
		return false

func import_theme_from_file(file_path: String) -> bool:
	"""Import theme from file"""
	if not ResourceLoader.exists(file_path):
		Logger.error("Theme file not found: %s" % file_path, "ui")
		return false
	
	var imported_theme = load(file_path) as MainTheme
	if imported_theme:
		set_theme(imported_theme)
		theme_file_path = file_path  # Update for hot reload
		Logger.info("Theme imported from: %s" % file_path, "ui")
		return true
	else:
		Logger.error("Failed to load theme from: %s" % file_path, "ui")
		return false