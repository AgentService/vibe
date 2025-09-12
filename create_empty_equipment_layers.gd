@tool
extends EditorScript

## Create empty SpriteFrames resources for equipment layers
## This prevents the syncing issue by giving each layer its own resource

func _run() -> void:
	# Load the base character frames to copy structure
	var base_frames = ResourceLoader.load("res://assets/sprites/raven_character/raven_ranger_frames.tres") as SpriteFrames
	if not base_frames:
		print("Failed to load base frames")
		return
	
	# Create empty SpriteFrames for each equipment layer
	var layer_names = ["pants", "clothing", "accessories", "weapons", "hair", "shield_back", "shield_above"]
	
	for layer_name in layer_names:
		var empty_frames := SpriteFrames.new()
		
		# Copy animation structure from base but with empty/transparent frames
		for anim_name in base_frames.get_animation_names():
			empty_frames.add_animation(anim_name)
			empty_frames.set_animation_loop(anim_name, base_frames.get_animation_loop(anim_name))
			empty_frames.set_animation_speed(anim_name, base_frames.get_animation_speed(anim_name))
			
			# Add transparent placeholder frames
			var frame_count = base_frames.get_frame_count(anim_name)
			for i in range(frame_count):
				# Create a transparent 48x48 texture
				var empty_texture := ImageTexture.new()
				var empty_image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
				empty_image.fill(Color.TRANSPARENT)
				empty_texture.set_image(empty_image)
				
				empty_frames.add_frame(anim_name, empty_texture)
		
		# Save the empty layer resource
		var output_path := "res://assets/sprites/raven_character/layers/raven_%s_layer.tres" % layer_name
		
		# Ensure directory exists
		if not DirAccess.dir_exists_absolute("res://assets/sprites/raven_character/layers/"):
			DirAccess.open("res://assets/sprites/raven_character/").make_dir("layers")
		
		var save_result := ResourceSaver.save(empty_frames, output_path)
		
		if save_result == OK:
			print("Created empty layer: ", output_path)
		else:
			print("Failed to create layer: ", layer_name)
	
	print("Empty equipment layers created!")
	print("Now assign different .tres files to each AnimatedSprite2D layer")