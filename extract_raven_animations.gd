@tool
extends EditorScript

## Tool script to extract Raven Fantasy character animations
## Run this from the Godot editor Tools > Execute Script

func _run() -> void:
	var atlas_path := "res://assets/sprites/raven_character/Full.png"
	var output_dir := "res://assets/sprites/raven_character/"
	
	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.open("res://").make_dir_recursive(output_dir.trim_prefix("res://"))
	
	# Load the atlas texture
	var atlas := ResourceLoader.load(atlas_path) as Texture2D
	if not atlas:
		print("Failed to load atlas: ", atlas_path)
		return
	
	print("Atlas size: ", atlas.get_width(), "x", atlas.get_height())
	
	# Create SpriteFrames resource for the character
	var sprite_frames := SpriteFrames.new()
	
	# Animation definitions based on the atlas layout (48x48 grid)
	var animations := {
		# Movement animations (4 directions each)
		"idle_down": {"start": Vector2i(0, 0), "frames": 11, "fps": 5.0, "row": 0},
		"idle_left": {"start": Vector2i(0, 1), "frames": 11, "fps": 5.0, "row": 1},
		"idle_right": {"start": Vector2i(0, 2), "frames": 11, "fps": 5.0, "row": 2},
		"idle_up": {"start": Vector2i(0, 3), "frames": 4, "fps": 5.0, "row": 3},
		
		"walk_down": {"start": Vector2i(0, 4), "frames": 8, "fps": 8.0, "row": 4},
		"walk_left": {"start": Vector2i(0, 5), "frames": 8, "fps": 8.0, "row": 5},
		"walk_right": {"start": Vector2i(0, 6), "frames": 8, "fps": 8.0, "row": 6},
		"walk_up": {"start": Vector2i(0, 7), "frames": 8, "fps": 8.0, "row": 7},
		
		"run_down": {"start": Vector2i(8, 0), "frames": 8, "fps": 12.0, "row": 0},
		"run_left": {"start": Vector2i(8, 1), "frames": 8, "fps": 12.0, "row": 1},
		"run_right": {"start": Vector2i(8, 2), "frames": 8, "fps": 12.0, "row": 2},
		"run_up": {"start": Vector2i(8, 3), "frames": 8, "fps": 12.0, "row": 3},
		
		# Combat animations
		"attack_down": {"start": Vector2i(0, 8), "frames": 4, "fps": 15.0, "row": 8},
		"attack_left": {"start": Vector2i(0, 9), "frames": 4, "fps": 15.0, "row": 9},
		"attack_right": {"start": Vector2i(0, 10), "frames": 4, "fps": 15.0, "row": 10},
		"attack_up": {"start": Vector2i(0, 11), "frames": 4, "fps": 15.0, "row": 11},
		
		# Bow animations (perfect for ranger!)
		"bow_down": {"start": Vector2i(8, 10), "frames": 4, "fps": 12.0, "row": 10},
		"bow_left": {"start": Vector2i(8, 11), "frames": 4, "fps": 12.0, "row": 11},
		"bow_right": {"start": Vector2i(8, 12), "frames": 4, "fps": 12.0, "row": 12},
		"bow_up": {"start": Vector2i(8, 13), "frames": 4, "fps": 12.0, "row": 13},
		
		# Utility animations
		"dodge_down": {"start": Vector2i(16, 4), "frames": 4, "fps": 10.0, "row": 4},
		"dodge_left": {"start": Vector2i(16, 5), "frames": 4, "fps": 10.0, "row": 5},
		"dodge_right": {"start": Vector2i(16, 6), "frames": 4, "fps": 10.0, "row": 6},
		"dodge_up": {"start": Vector2i(16, 7), "frames": 4, "fps": 10.0, "row": 7}
	}
	
	# Create animations
	for anim_name in animations:
		var anim_data = animations[anim_name]
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_loop(anim_name, true)
		sprite_frames.set_animation_speed(anim_name, anim_data.fps)
		
		# Extract frames for this animation
		for i in range(anim_data.frames):
			var frame_rect := Rect2i(
				(anim_data.start.x + i) * 48,  # 48px frame width
				anim_data.start.y * 48,        # 48px frame height
				48, 48
			)
			
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = atlas
			atlas_texture.region = frame_rect
			
			sprite_frames.add_frame(anim_name, atlas_texture)
		
		print("Created animation: ", anim_name, " with ", anim_data.frames, " frames")
	
	# Save the SpriteFrames resource
	var sprite_frames_path := output_dir + "raven_character_frames.tres"
	var save_result := ResourceSaver.save(sprite_frames, sprite_frames_path)
	
	if save_result == OK:
		print("Successfully saved SpriteFrames to: ", sprite_frames_path)
		print("Total animations created: ", sprite_frames.get_animation_names().size())
	else:
		print("Failed to save SpriteFrames: ", save_result)
	
	print("Raven character animation extraction complete!")