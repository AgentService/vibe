extends Node

## FPSLimiter - Configurable frame rate limiting
## Provides standard FPS cap options like modern games (Unlimited, VSync, 30/60/120/144)

enum FPSMode {
	UNLIMITED,  # No cap, renders as fast as possible (lowest input lag)
	VSYNC,      # Sync to monitor refresh rate (tear-free)
	CAP_30,     # 30 FPS cap
	CAP_60,     # 60 FPS cap
	CAP_120,    # 120 FPS cap
	CAP_144     # 144 FPS cap
}

# Current FPS mode
var current_mode: FPSMode = FPSMode.CAP_60

# Frame timing
var _target_frame_time_usec: int = 16667  # Microseconds (1/60 = 16.667ms)
var _last_frame_time: int = 0
var _frame_start_time: int = 0

func _ready() -> void:
	# Start in CAP_60 mode by default
	set_fps_mode(FPSMode.CAP_60)

	# Process at highest priority to control frame timing
	process_priority = 1000

	Logger.info("FPSLimiter initialized (mode: %s)" % FPSMode.keys()[current_mode], "performance")

func _process(_delta: float) -> void:
	if current_mode == FPSMode.UNLIMITED or current_mode == FPSMode.VSYNC:
		return  # No limiting needed

	# Calculate frame time
	_frame_start_time = Time.get_ticks_usec()
	var elapsed_usec = _frame_start_time - _last_frame_time

	# If we rendered too fast, sleep the remaining time
	if elapsed_usec < _target_frame_time_usec:
		var sleep_usec = _target_frame_time_usec - elapsed_usec

		# Use microsecond-precision sleep (much more accurate than msec)
		OS.delay_usec(sleep_usec)

	_last_frame_time = Time.get_ticks_usec()

## Set FPS limiting mode
func set_fps_mode(mode: FPSMode) -> void:
	current_mode = mode

	match mode:
		FPSMode.UNLIMITED:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			Logger.info("FPS Mode: UNLIMITED (no cap)", "performance")

		FPSMode.VSYNC:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			Engine.max_fps = 0
			Logger.info("FPS Mode: VSYNC (monitor refresh rate)", "performance")

		FPSMode.CAP_30:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			_target_frame_time_usec = 33333  # 1/30 = 33.333ms
			_last_frame_time = Time.get_ticks_usec()
			Logger.info("FPS Mode: CAP_30 (30 FPS)", "performance")

		FPSMode.CAP_60:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			_target_frame_time_usec = 16667  # 1/60 = 16.667ms
			_last_frame_time = Time.get_ticks_usec()
			Logger.info("FPS Mode: CAP_60 (60 FPS)", "performance")

		FPSMode.CAP_120:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			_target_frame_time_usec = 8333   # 1/120 = 8.333ms
			_last_frame_time = Time.get_ticks_usec()
			Logger.info("FPS Mode: CAP_120 (120 FPS)", "performance")

		FPSMode.CAP_144:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			_target_frame_time_usec = 6944   # 1/144 = 6.944ms
			_last_frame_time = Time.get_ticks_usec()
			Logger.info("FPS Mode: CAP_144 (144 FPS)", "performance")

## Get current FPS mode as string for UI display
func get_mode_string() -> String:
	match current_mode:
		FPSMode.UNLIMITED: return "Unlimited"
		FPSMode.VSYNC: return "VSync"
		FPSMode.CAP_30: return "30 FPS"
		FPSMode.CAP_60: return "60 FPS"
		FPSMode.CAP_120: return "120 FPS"
		FPSMode.CAP_144: return "144 FPS"
		_: return "Unknown"

## Cycle to next FPS mode (for quick testing)
func cycle_fps_mode() -> void:
	var next_mode = (current_mode + 1) % FPSMode.size()
	set_fps_mode(next_mode as FPSMode)

	# Emit notification for UI
	Logger.info("FPS Mode changed to: %s" % get_mode_string(), "performance")
