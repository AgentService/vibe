extends RefCounted
class_name ModalAnimator
## Static animation utilities for modal overlays with performance optimization
##
## Provides standardized modal animations with tween pooling to reduce allocations
## and ensure consistent visual feedback across all overlays.

# Tween pool for performance optimization
static var tween_pool: Array[Tween] = []
static var active_tweens: Array[Tween] = []

# Animation presets
enum AnimationType {
	FADE_IN,
	SCALE_IN,
	SLIDE_IN_FROM_TOP,
	SLIDE_IN_FROM_BOTTOM,
	BOUNCE_IN,
	FADE_OUT,
	SCALE_OUT,
	SLIDE_OUT_TO_TOP,
	SLIDE_OUT_TO_BOTTOM
}

# Default animation settings optimized for desktop
const DEFAULT_DURATION: float = 0.3
const FAST_DURATION: float = 0.2
const DEFAULT_EASE: Tween.EaseType = Tween.EASE_OUT
const EXIT_EASE: Tween.EaseType = Tween.EASE_IN

static func get_tween() -> Tween:
	"""Get a tween from the pool or create a new one"""
	var tween: Tween
	if tween_pool.is_empty():
		tween = Engine.get_main_loop().create_tween()
	else:
		tween = tween_pool.pop_back()
	
	active_tweens.append(tween)
	tween.finished.connect(_return_tween.bind(tween), CONNECT_ONE_SHOT)
	return tween

static func _return_tween(tween: Tween) -> void:
	"""Return tween to pool for reuse"""
	active_tweens.erase(tween)
	tween_pool.append(tween)

# Core animation methods
static func fade_in_modal(modal: Control, duration: float = DEFAULT_DURATION, ease_type: Tween.EaseType = DEFAULT_EASE) -> Tween:
	"""Fade in modal from transparent to opaque"""
	var tween = get_tween()
	modal.modulate.a = 0.0
	modal.visible = true
	tween.tween_property(modal, "modulate:a", 1.0, duration).set_ease(ease_type)
	
	Logger.debug("Modal fade in started: %s" % modal.name, "ui")
	return tween

static func fade_out_modal(modal: Control, duration: float = FAST_DURATION, ease_type: Tween.EaseType = EXIT_EASE) -> Tween:
	"""Fade out modal from opaque to transparent"""
	var tween = get_tween()
	tween.tween_property(modal, "modulate:a", 0.0, duration).set_ease(ease_type)
	
	Logger.debug("Modal fade out started: %s" % modal.name, "ui")
	return tween

static func scale_in_modal(modal: Control, from_scale: float = 0.8, duration: float = DEFAULT_DURATION, ease_type: Tween.EaseType = DEFAULT_EASE) -> Tween:
	"""Scale in modal from small to normal size"""
	var tween = get_tween()
	tween.set_parallel(true)
	
	modal.modulate.a = 0.0
	modal.scale = Vector2.ONE * from_scale
	modal.visible = true
	
	tween.tween_property(modal, "modulate:a", 1.0, duration).set_ease(ease_type)
	tween.tween_property(modal, "scale", Vector2.ONE, duration).set_ease(ease_type)
	
	Logger.debug("Modal scale in started: %s" % modal.name, "ui")
	return tween

static func scale_out_modal(modal: Control, to_scale: float = 0.9, duration: float = FAST_DURATION, ease_type: Tween.EaseType = EXIT_EASE) -> Tween:
	"""Scale out modal from normal to small size"""
	var tween = get_tween()
	tween.set_parallel(true)
	
	tween.tween_property(modal, "modulate:a", 0.0, duration).set_ease(ease_type)
	tween.tween_property(modal, "scale", Vector2.ONE * to_scale, duration).set_ease(ease_type)
	
	Logger.debug("Modal scale out started: %s" % modal.name, "ui")
	return tween

static func slide_in_modal(modal: Control, from_direction: Vector2, duration: float = DEFAULT_DURATION, ease_type: Tween.EaseType = DEFAULT_EASE) -> Tween:
	"""Slide in modal from specified direction"""
	var tween = get_tween()
	tween.set_parallel(true)
	
	var original_position = modal.position
	modal.position = original_position + from_direction
	modal.modulate.a = 0.0
	modal.visible = true
	
	tween.tween_property(modal, "position", original_position, duration).set_ease(ease_type)
	tween.tween_property(modal, "modulate:a", 1.0, duration).set_ease(ease_type)
	
	Logger.debug("Modal slide in started: %s" % modal.name, "ui")
	return tween

static func slide_out_modal(modal: Control, to_direction: Vector2, duration: float = FAST_DURATION, ease_type: Tween.EaseType = EXIT_EASE) -> Tween:
	"""Slide out modal to specified direction"""
	var tween = get_tween()
	tween.set_parallel(true)
	
	var target_position = modal.position + to_direction
	
	tween.tween_property(modal, "position", target_position, duration).set_ease(ease_type)
	tween.tween_property(modal, "modulate:a", 0.0, duration).set_ease(ease_type)
	
	Logger.debug("Modal slide out started: %s" % modal.name, "ui")
	return tween

static func bounce_in_modal(modal: Control, scale_factor: float = 1.1, duration: float = DEFAULT_DURATION) -> Tween:
	"""Bounce in modal with overshoot for playful effect"""
	var tween = get_tween()
	tween.set_parallel(true)
	
	modal.modulate.a = 0.0
	modal.scale = Vector2(0.8, 0.8)
	modal.visible = true
	
	# Fade in
	tween.tween_property(modal, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)
	
	# Bounce scale animation
	var scale_tween = tween.tween_property(modal, "scale", Vector2.ONE * scale_factor, duration * 0.7).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(modal, "scale", Vector2.ONE, duration * 0.3).set_ease(Tween.EASE_IN)
	
	Logger.debug("Modal bounce in started: %s" % modal.name, "ui")
	return tween

# Background dimmer animations
static func dim_background(dimmer: ColorRect, target_alpha: float = 0.7, duration: float = DEFAULT_DURATION) -> Tween:
	"""Animate background dimmer to target alpha"""
	var tween = get_tween()
	dimmer.visible = true
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	
	tween.tween_property(dimmer, "color:a", target_alpha, duration).set_ease(DEFAULT_EASE)
	
	Logger.debug("Background dimmer animation started", "ui")
	return tween

static func undim_background(dimmer: ColorRect, duration: float = FAST_DURATION) -> Tween:
	"""Animate background dimmer to transparent"""
	var tween = get_tween()
	
	tween.tween_property(dimmer, "color:a", 0.0, duration).set_ease(EXIT_EASE)
	tween.tween_callback(func(): 
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
	
	Logger.debug("Background undimmer animation started", "ui")
	return tween

# Preset animation combinations
static func animate_modal_entrance(modal: Control, animation_type: AnimationType = AnimationType.SCALE_IN) -> Tween:
	"""Animate modal entrance with preset animation"""
	match animation_type:
		AnimationType.FADE_IN:
			return fade_in_modal(modal)
		AnimationType.SCALE_IN:
			return scale_in_modal(modal)
		AnimationType.SLIDE_IN_FROM_TOP:
			return slide_in_modal(modal, Vector2(0, -200))
		AnimationType.SLIDE_IN_FROM_BOTTOM:
			return slide_in_modal(modal, Vector2(0, 200))
		AnimationType.BOUNCE_IN:
			return bounce_in_modal(modal)
		_:
			return scale_in_modal(modal)

static func animate_modal_exit(modal: Control, animation_type: AnimationType = AnimationType.SCALE_OUT) -> Tween:
	"""Animate modal exit with preset animation"""
	match animation_type:
		AnimationType.FADE_OUT:
			return fade_out_modal(modal)
		AnimationType.SCALE_OUT:
			return scale_out_modal(modal)
		AnimationType.SLIDE_OUT_TO_TOP:
			return slide_out_modal(modal, Vector2(0, -200))
		AnimationType.SLIDE_OUT_TO_BOTTOM:
			return slide_out_modal(modal, Vector2(0, 200))
		_:
			return scale_out_modal(modal)

# Utility methods
static func stop_all_animations() -> void:
	"""Stop all active animations - emergency cleanup"""
	for tween in active_tweens:
		if tween.is_valid():
			tween.kill()
	
	active_tweens.clear()
	Logger.warn("All modal animations stopped", "ui")

static func get_active_animation_count() -> int:
	"""Get number of currently active animations"""
	return active_tweens.size()

static func animate_button_hover(button: Control, hover_scale: float = 1.05, duration: float = 0.1) -> Tween:
	"""Quick button hover animation"""
	var tween = get_tween()
	tween.tween_property(button, "scale", Vector2.ONE * hover_scale, duration).set_ease(Tween.EASE_OUT)
	return tween

static func animate_button_unhover(button: Control, duration: float = 0.1) -> Tween:
	"""Quick button unhover animation"""
	var tween = get_tween()
	tween.tween_property(button, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)
	return tween

static func animate_button_press(button: Control, press_scale: float = 0.95, duration: float = 0.05) -> Tween:
	"""Quick button press animation"""
	var tween = get_tween()
	tween.tween_property(button, "scale", Vector2.ONE * press_scale, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)
	return tween

# Performance monitoring
static func get_performance_stats() -> Dictionary:
	"""Get animation performance statistics"""
	return {
		"active_animations": active_tweens.size(),
		"pooled_tweens": tween_pool.size(),
		"total_tweens_created": active_tweens.size() + tween_pool.size()
	}