class_name AnimationConfig
extends Resource

@export var sprite_sheet: Texture2D
@export var frame_size: Vector2i
@export var grid_columns: int
@export var grid_rows: int
@export var animations: Dictionary = {}

class AnimationData:
	var frames: Array[int] = []
	var duration: float = 0.0
	var loop: bool = true
	
	func _init(p_frames: Array = [], p_duration: float = 0.0, p_loop: bool = true):
		frames = p_frames
		duration = p_duration
		loop = p_loop

func get_animation(name: String) -> AnimationData:
	if animations.has(name):
		var data = animations[name]
		if data is AnimationData:
			return data
		else:
			# Convert from dictionary format if needed
			var anim_data = AnimationData.new()
			anim_data.frames = data.get("frames", [])
			anim_data.duration = data.get("duration", 0.0)
			anim_data.loop = data.get("loop", true)
			return anim_data
	
	push_warning("Animation not found: " + name)
	return AnimationData.new()

func has_animation(name: String) -> bool:
	return animations.has(name)
