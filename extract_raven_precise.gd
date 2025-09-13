@tool
extends EditorScript

## Precise Raven Fantasy frame extraction avoiding border artifacts
## This script extracts frames with exact pixel boundaries to prevent bleeding

func _run() -> void:
	var atlas_path := "res://assets/sprites/Raven Fantasy - Pixelart Top Down Character Base 2.0/Raven Fantasy - Pixelart Top Down Character Base 2.0/Base/Full.png"
	
	# Load the atlas
	var atlas := ResourceLoader.load(atlas_path) as Texture2D
	if not atlas:
		print("Failed to load atlas: ", atlas_path)
		return
	
	print("Atlas loaded: ", atlas.get_width(), "x", atlas.get_height())
	
	# Create SpriteFrames with precise regions
	var sprite_frames := SpriteFrames.new()
	
	# Define exact frame coordinates for each animation
	# Based on the Full.png layout - adjust these coordinates as needed
	var frame_definitions = {
		"idle_down": [
			{"x": 48, "y": 48},    # Frame 1
			{"x": 96, "y": 48},    # Frame 2  
			{"x": 144, "y": 48},   # Frame 3
			{"x": 192, "y": 48}    # Frame 4
		],
		"idle_left": [
			{"x": 48, "y": 96},
			{"x": 96, "y": 96},
			{"x": 144, "y": 96},
			{"x": 192, "y": 96}
		],
		"idle_right": [
			{"x": 48, "y": 144},
			{"x": 96, "y": 144},
			{"x": 144, "y": 144},
			{"x": 192, "y": 144}
		],
		"idle_up": [
			{"x": 48, "y": 192},
			{"x": 96, "y": 192},
			{"x": 144, "y": 192},
			{"x": 192, "y": 192}
		],
		"walk_down": [
			{"x": 288, "y": 48},
			{"x": 336, "y": 48},
			{"x": 384, "y": 48},
			{"x": 432, "y": 48}
		],
		"walk_left": [
			{"x": 288, "y": 96},
			{"x": 336, "y": 96},
			{"x": 384, "y": 96},
			{"x": 432, "y": 96}
		],
		"walk_right": [
			{"x": 288, "y": 144},
			{"x": 336, "y": 144},
			{"x": 384, "y": 144},
			{"x": 432, "y": 144}
		],
		"walk_up": [
			{"x": 288, "y": 192},
			{"x": 336, "y": 192},
			{"x": 384, "y": 192},
			{"x": 432, "y": 192}
		],
		"run_down": [
			{"x": 528, "y": 48},
			{"x": 576, "y": 48},
			{"x": 624, "y": 48},
			{"x": 672, "y": 48}
		],
		"run_left": [
			{"x": 528, "y": 96},
			{"x": 576, "y": 96},
			{"x": 624, "y": 96},
			{"x": 672, "y": 96}
		],
		"run_right": [
			{"x": 528, "y": 144},
			{"x": 576, "y": 144},
			{"x": 624, "y": 144},
			{"x": 672, "y": 144}
		],
		"run_up": [
			{"x": 528, "y": 192},
			{"x": 576, "y": 192},
			{"x": 624, "y": 192},
			{"x": 672, "y": 192}
		]
	}
	
	# Create animations with precise coordinates
	for anim_name in frame_definitions:
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_loop(anim_name, true)
		
		# Set appropriate speeds
		if "idle" in anim_name:
			sprite_frames.set_animation_speed(anim_name, 5.0)
		elif "walk" in anim_name:
			sprite_frames.set_animation_speed(anim_name, 8.0)
		elif "run" in anim_name:
			sprite_frames.set_animation_speed(anim_name, 12.0)
		
		# Add frames with exact coordinates
		for frame_data in frame_definitions[anim_name]:
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = atlas
			atlas_texture.region = Rect2i(frame_data.x, frame_data.y, 48, 48)
			
			sprite_frames.add_frame(anim_name, atlas_texture)
		
		print("Created precise animation: ", anim_name)
	
	# Save the clean SpriteFrames
	var output_path := "res://assets/sprites/raven_character/raven_precise_frames.tres"
	var save_result := ResourceSaver.save(sprite_frames, output_path)
	
	if save_result == OK:
		print("SUCCESS: Saved clean SpriteFrames to: ", output_path)
	else:
		print("ERROR: Failed to save SpriteFrames: ", save_result)
	
	print("Precise extraction complete - no border artifacts!")