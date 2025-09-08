extends RefCounted
class_name ResponsiveUI

## ResponsiveUI - Utility class for responsive UI calculations
## Provides screen size detection, scaling factors, and layout calculations
## Based on best practices from GODOT_UI_REFERENCE.md

enum ScreenSize {
	MOBILE,     # < 800px width
	TABLET,     # 800-1280px width  
	DESKTOP,    # 1280-1920px width
	DESKTOP_4K  # > 1920px width
}

## Base viewport size for scaling calculations
const BASE_WIDTH: float = 1080.0
const BASE_HEIGHT: float = 720.0

## Screen size breakpoints
const MOBILE_MAX_WIDTH: float = 800.0
const TABLET_MAX_WIDTH: float = 1280.0
const DESKTOP_MAX_WIDTH: float = 1920.0

## Scale factors for different screen sizes
const MOBILE_SCALE: float = 0.8
const TABLET_SCALE: float = 0.9
const DESKTOP_SCALE: float = 1.0
const DESKTOP_4K_SCALE: float = 1.2

## Card size constraints
const MIN_CARD_WIDTH: float = 180.0
const MAX_CARD_WIDTH: float = 300.0
const BASE_CARD_WIDTH: float = 240.0
const CARD_ASPECT_RATIO: float = 450.0 / 320.0  # height/width

## Font size multipliers
const BASE_FONT_SIZE_SMALL: int = 14
const BASE_FONT_SIZE_MEDIUM: int = 18
const BASE_FONT_SIZE_LARGE: int = 24
const BASE_FONT_SIZE_TITLE: int = 32

static func get_viewport_size(node: Node) -> Vector2:
	"""Get current viewport size from any node."""
	return node.get_viewport().get_visible_rect().size

static func get_screen_size_category(viewport_size: Vector2) -> ScreenSize:
	"""Determine screen size category based on viewport width."""
	var width = viewport_size.x
	
	if width < MOBILE_MAX_WIDTH:
		return ScreenSize.MOBILE
	elif width < TABLET_MAX_WIDTH:
		return ScreenSize.TABLET
	elif width < DESKTOP_MAX_WIDTH:
		return ScreenSize.DESKTOP
	else:
		return ScreenSize.DESKTOP_4K

static func get_ui_scale_factor(viewport_size: Vector2) -> float:
	"""Get UI scale factor based on screen size."""
	var screen_category = get_screen_size_category(viewport_size)
	
	match screen_category:
		ScreenSize.MOBILE:
			return MOBILE_SCALE
		ScreenSize.TABLET:
			return TABLET_SCALE
		ScreenSize.DESKTOP:
			return DESKTOP_SCALE
		ScreenSize.DESKTOP_4K:
			return DESKTOP_4K_SCALE
		_:
			return DESKTOP_SCALE

static func get_card_size(viewport_size: Vector2) -> Vector2:
	"""Calculate optimal card size based on viewport."""
	var scale_factor = get_ui_scale_factor(viewport_size)
	var card_width = BASE_CARD_WIDTH * scale_factor
	
	# Clamp to min/max constraints
	card_width = clampf(card_width, MIN_CARD_WIDTH, MAX_CARD_WIDTH)
	
	var card_height = card_width * CARD_ASPECT_RATIO
	
	return Vector2(card_width, card_height)

static func get_card_columns(viewport_size: Vector2, card_width: float, max_cards: int = 3) -> int:
	"""Calculate number of card columns that fit in viewport."""
	var available_width = viewport_size.x * 0.8  # Leave 20% margin
	var card_spacing = 40.0 * get_ui_scale_factor(viewport_size)
	var total_card_width = card_width + card_spacing
	
	var max_columns = int(available_width / total_card_width)
	return clampi(max_columns, 1, max_cards)

static func get_responsive_font_size(base_size: int, viewport_size: Vector2) -> int:
	"""Get responsive font size based on screen size."""
	var scale_factor = get_ui_scale_factor(viewport_size)
	return int(base_size * scale_factor)

static func get_responsive_margin(base_margin: float, viewport_size: Vector2) -> float:
	"""Get responsive margin/padding values."""
	var scale_factor = get_ui_scale_factor(viewport_size)
	return base_margin * scale_factor

static func is_touch_device(viewport_size: Vector2) -> bool:
	"""Heuristic to detect if device likely uses touch input."""
	# Simple heuristic: mobile/tablet sizes are likely touch devices
	var screen_category = get_screen_size_category(viewport_size)
	return screen_category == ScreenSize.MOBILE or screen_category == ScreenSize.TABLET

static func get_touch_target_size(viewport_size: Vector2) -> float:
	"""Get minimum touch target size (44dp on mobile recommended)."""
	if is_touch_device(viewport_size):
		return 44.0 * get_ui_scale_factor(viewport_size)
	else:
		return 32.0 * get_ui_scale_factor(viewport_size)

static func calculate_responsive_spacing(base_spacing: float, viewport_size: Vector2) -> float:
	"""Calculate responsive spacing between UI elements."""
	var scale_factor = get_ui_scale_factor(viewport_size)
	return base_spacing * scale_factor

static func get_safe_area_margins(viewport_size: Vector2) -> Dictionary:
	"""Get safe area margins for different screen sizes."""
	var scale_factor = get_ui_scale_factor(viewport_size)
	var screen_category = get_screen_size_category(viewport_size)
	
	var base_margin = 20.0
	match screen_category:
		ScreenSize.MOBILE:
			base_margin = 16.0
		ScreenSize.TABLET:
			base_margin = 24.0
		ScreenSize.DESKTOP:
			base_margin = 32.0
		ScreenSize.DESKTOP_4K:
			base_margin = 48.0
	
	var margin = base_margin * scale_factor
	
	return {
		"left": margin,
		"right": margin,
		"top": margin,
		"bottom": margin
	}

static func should_use_scrolling(viewport_size: Vector2, content_height: float) -> bool:
	"""Determine if scrolling should be enabled based on content size."""
	var available_height = viewport_size.y * 0.9  # Leave 10% margin
	return content_height > available_height

static func get_screen_info(viewport_size: Vector2) -> Dictionary:
	"""Get comprehensive screen information for debugging."""
	var screen_category = get_screen_size_category(viewport_size)
	var scale_factor = get_ui_scale_factor(viewport_size)
	var card_size = get_card_size(viewport_size)
	var card_columns = get_card_columns(viewport_size, card_size.x)
	
	var screen_names = {
		ScreenSize.MOBILE: "Mobile",
		ScreenSize.TABLET: "Tablet", 
		ScreenSize.DESKTOP: "Desktop",
		ScreenSize.DESKTOP_4K: "Desktop 4K"
	}
	
	return {
		"viewport_size": viewport_size,
		"screen_category": screen_names[screen_category],
		"scale_factor": scale_factor,
		"card_size": card_size,
		"card_columns": card_columns,
		"is_touch_device": is_touch_device(viewport_size),
		"touch_target_size": get_touch_target_size(viewport_size)
	}