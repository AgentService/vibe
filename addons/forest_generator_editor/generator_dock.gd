@tool
extends Control

var generate_button: Button
var seed_input: SpinBox
var arena_size_x: SpinBox
var arena_size_y: SpinBox
var tree_spacing_min_input: SpinBox
var tree_spacing_max_input: SpinBox
var tree_chance_input: SpinBox

# New enhanced configuration controls
var camera_extension_input: SpinBox
var spawn_layer_toggle: CheckBox
var spawn_border_spacing_input: SpinBox

# Organic boundary controls
var organic_boundaries_toggle: CheckBox
var noise_frequency_input: SpinBox
var noise_amplitude_input: SpinBox
var boundary_edge_fill_input: SpinBox

# Density gradient controls
var edge_density_input: SpinBox
var invert_gradient_toggle: CheckBox

# Organic boundary fine-tuning controls
var organic_octaves_input: SpinBox
var organic_lacunarity_input: SpinBox
var organic_gain_input: SpinBox
var organic_amplitude_input: SpinBox
var organic_curvature_input: SpinBox

# Ultra-strong gap-free system controls
var fill_sample_spacing_input: SpinBox
var fill_coverage_radius_input: SpinBox
var fill_angular_density_input: SpinBox
var fill_minimum_chance_input: SpinBox
var fill_maximum_multiplier_input: SpinBox
var fill_noise_variation_input: SpinBox


func _init():
	name = "Forest Generator"
	# Expand to fill available dock space
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Set minimum size to ensure content is visible
	set_custom_minimum_size(Vector2(250, 400))

	# Create scrollable container that fills the dock
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll_container)

	# Main content container
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Forest Arena Generator"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Basic Controls section (always visible)
	_create_basic_controls(vbox)

	vbox.add_child(HSeparator.new())

	# Camera Extension section (collapsible)
	_create_collapsible_section(vbox, "Camera Extension", _create_camera_extension_controls)

	vbox.add_child(HSeparator.new())

	# Organic Boundaries section (collapsible)
	_create_collapsible_section(vbox, "Organic Boundaries", _create_organic_boundary_controls)

	vbox.add_child(HSeparator.new())

	# Advanced Tuning section (collapsible)
	_create_collapsible_section(vbox, "Advanced Tuning", _create_advanced_tuning_controls)

	vbox.add_child(HSeparator.new())

	# Generate button
	generate_button = Button.new()
	generate_button.text = "Generate Forest Arena"
	generate_button.pressed.connect(_on_generate_pressed)
	vbox.add_child(generate_button)

	# Info labels
	_create_info_labels(vbox)

func _create_basic_controls(container: VBoxContainer) -> void:
	"""Create basic generation controls that are always visible"""
	# Seed control
	var seed_label = Label.new()
	seed_label.text = "Generation Seed:"
	container.add_child(seed_label)

	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 999999
	seed_input.value = 12345
	container.add_child(seed_input)

	# Arena size controls
	var size_label = Label.new()
	size_label.text = "Arena Size:"
	container.add_child(size_label)

	var size_hbox = HBoxContainer.new()
	container.add_child(size_hbox)

	arena_size_x = SpinBox.new()
	arena_size_x.min_value = 10
	arena_size_x.max_value = 100
	arena_size_x.value = 50
	size_hbox.add_child(arena_size_x)

	var x_label = Label.new()
	x_label.text = " x "
	size_hbox.add_child(x_label)

	arena_size_y = SpinBox.new()
	arena_size_y.min_value = 10
	arena_size_y.max_value = 100
	arena_size_y.value = 50
	size_hbox.add_child(arena_size_y)

	# Tree spacing controls
	var spacing_label = Label.new()
	spacing_label.text = "Tree Spacing (Min - Max):"
	container.add_child(spacing_label)

	var spacing_hbox = HBoxContainer.new()
	container.add_child(spacing_hbox)

	tree_spacing_min_input = SpinBox.new()
	tree_spacing_min_input.min_value = 1
	tree_spacing_min_input.max_value = 10
	tree_spacing_min_input.value = 1
	spacing_hbox.add_child(tree_spacing_min_input)

	var dash_label = Label.new()
	dash_label.text = " - "
	spacing_hbox.add_child(dash_label)

	tree_spacing_max_input = SpinBox.new()
	tree_spacing_max_input.min_value = 1
	tree_spacing_max_input.max_value = 10
	tree_spacing_max_input.value = 1
	spacing_hbox.add_child(tree_spacing_max_input)

	# Tree placement chance
	var chance_label = Label.new()
	chance_label.text = "Tree Placement (0.0-1.0):"
	container.add_child(chance_label)

	tree_chance_input = SpinBox.new()
	tree_chance_input.min_value = 0.0
	tree_chance_input.max_value = 1.0
	tree_chance_input.step = 0.1
	tree_chance_input.value = 0.6
	container.add_child(tree_chance_input)

func _create_collapsible_section(parent: VBoxContainer, title: String, content_creator: Callable) -> void:
	"""Create a collapsible section with title and content"""
	var button = Button.new()
	button.text = "▼ " + title
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(button)

	var content_container = VBoxContainer.new()
	parent.add_child(content_container)

	# Call the content creator function to populate the section
	content_creator.call(content_container)

	# Connect button to toggle visibility
	button.pressed.connect(func(): _toggle_section(button, content_container))

func _toggle_section(button: Button, container: VBoxContainer) -> void:
	"""Toggle section visibility and button text"""
	container.visible = !container.visible
	var title = button.text.substr(2)  # Remove the arrow
	button.text = ("▼ " if container.visible else "▶ ") + title

func _create_camera_extension_controls(container: VBoxContainer) -> void:
	"""Create camera extension controls"""
	# Camera boundary extension
	var camera_label = Label.new()
	camera_label.text = "Camera Extension (more trees):"
	container.add_child(camera_label)

	camera_extension_input = SpinBox.new()
	camera_extension_input.min_value = 0
	camera_extension_input.max_value = 50
	camera_extension_input.value = 25
	container.add_child(camera_extension_input)

	# Edge density control
	var edge_density_label = Label.new()
	edge_density_label.text = "Edge Density Multiplier (1.0+):"
	container.add_child(edge_density_label)

	edge_density_input = SpinBox.new()
	edge_density_input.min_value = 1.0
	edge_density_input.max_value = 999999
	edge_density_input.step = 0.5
	edge_density_input.value = 40.0
	container.add_child(edge_density_input)

	# Gradient inversion control
	invert_gradient_toggle = CheckBox.new()
	invert_gradient_toggle.text = "Invert Gradient (denser toward edges)"
	invert_gradient_toggle.button_pressed = true  # Default to denser toward edges
	container.add_child(invert_gradient_toggle)

	# Spawn layer controls
	spawn_layer_toggle = CheckBox.new()
	spawn_layer_toggle.text = "Enable Spawn Layer"
	spawn_layer_toggle.button_pressed = true
	container.add_child(spawn_layer_toggle)

	var spawn_spacing_label = Label.new()
	spawn_spacing_label.text = "Spawn Border Spacing:"
	container.add_child(spawn_spacing_label)

	spawn_border_spacing_input = SpinBox.new()
	spawn_border_spacing_input.min_value = 0
	spawn_border_spacing_input.max_value = 10
	spawn_border_spacing_input.value = 5
	container.add_child(spawn_border_spacing_input)

func _create_organic_boundary_controls(container: VBoxContainer) -> void:
	"""Create organic boundary controls"""
	# Organic boundaries toggle
	organic_boundaries_toggle = CheckBox.new()
	organic_boundaries_toggle.text = "Enable Organic Boundaries"
	organic_boundaries_toggle.button_pressed = true
	container.add_child(organic_boundaries_toggle)

	# Noise frequency control
	var frequency_label = Label.new()
	frequency_label.text = "Shape Smoothness (0.0-1.0):"
	container.add_child(frequency_label)

	noise_frequency_input = SpinBox.new()
	noise_frequency_input.min_value = 0.0
	noise_frequency_input.max_value = 1.0
	noise_frequency_input.step = 0.01
	noise_frequency_input.value = 0.05
	container.add_child(noise_frequency_input)

	# Noise amplitude control
	var amplitude_label = Label.new()
	amplitude_label.text = "Shape Variation (0.0-50.0):"
	container.add_child(amplitude_label)

	noise_amplitude_input = SpinBox.new()
	noise_amplitude_input.min_value = 0.0
	noise_amplitude_input.max_value = 50.0
	noise_amplitude_input.step = 0.5
	noise_amplitude_input.value = 3.0
	container.add_child(noise_amplitude_input)

	# Boundary edge fill control
	var edge_fill_label = Label.new()
	edge_fill_label.text = "Edge Fill Chance (0.0-1.0):"
	container.add_child(edge_fill_label)

	boundary_edge_fill_input = SpinBox.new()
	boundary_edge_fill_input.min_value = 0.0
	boundary_edge_fill_input.max_value = 1.0
	boundary_edge_fill_input.step = 0.1
	boundary_edge_fill_input.value = 0.9
	container.add_child(boundary_edge_fill_input)

	# Ultra-strong gap-free system controls
	var gap_free_title = Label.new()
	gap_free_title.text = "Ultra-Strong Gap-Free Controls:"
	gap_free_title.add_theme_font_size_override("font_size", 11)
	container.add_child(gap_free_title)

	# Sample spacing control
	var spacing_label = Label.new()
	spacing_label.text = "Sample Spacing (1-20):"
	container.add_child(spacing_label)

	fill_sample_spacing_input = SpinBox.new()
	fill_sample_spacing_input.min_value = 1
	fill_sample_spacing_input.max_value = 20
	fill_sample_spacing_input.step = 1
	fill_sample_spacing_input.value = 1
	container.add_child(fill_sample_spacing_input)

	# Coverage radius control (allowing fractional values)
	var coverage_label = Label.new()
	coverage_label.text = "Coverage Radius (0.0-3.0):"
	container.add_child(coverage_label)

	fill_coverage_radius_input = SpinBox.new()
	fill_coverage_radius_input.min_value = 0.0
	fill_coverage_radius_input.max_value = 3.0
	fill_coverage_radius_input.step = 0.1
	fill_coverage_radius_input.value = 1.0
	container.add_child(fill_coverage_radius_input)

	# Angular density control
	var angular_label = Label.new()
	angular_label.text = "Angular Density (0.1-1.0):"
	container.add_child(angular_label)

	fill_angular_density_input = SpinBox.new()
	fill_angular_density_input.min_value = 0.1
	fill_angular_density_input.max_value = 1.0
	fill_angular_density_input.step = 0.05
	fill_angular_density_input.value = 0.2
	container.add_child(fill_angular_density_input)

	# Minimum chance control
	var min_chance_label = Label.new()
	min_chance_label.text = "Minimum Chance (0.0-1.0):"
	container.add_child(min_chance_label)

	fill_minimum_chance_input = SpinBox.new()
	fill_minimum_chance_input.min_value = 0.0
	fill_minimum_chance_input.max_value = 1.0
	fill_minimum_chance_input.step = 0.05
	fill_minimum_chance_input.value = 0.8
	container.add_child(fill_minimum_chance_input)

	# Maximum multiplier control
	var max_mult_label = Label.new()
	max_mult_label.text = "Max Edge Multiplier (1.0-20.0):"
	container.add_child(max_mult_label)

	fill_maximum_multiplier_input = SpinBox.new()
	fill_maximum_multiplier_input.min_value = 1.0
	fill_maximum_multiplier_input.max_value = 20.0
	fill_maximum_multiplier_input.step = 0.5
	fill_maximum_multiplier_input.value = 8.0
	container.add_child(fill_maximum_multiplier_input)

	# Noise variation control
	var noise_var_label = Label.new()
	noise_var_label.text = "Noise Variation (0.0-0.5):"
	container.add_child(noise_var_label)

	fill_noise_variation_input = SpinBox.new()
	fill_noise_variation_input.min_value = 0.0
	fill_noise_variation_input.max_value = 0.5
	fill_noise_variation_input.step = 0.02
	fill_noise_variation_input.value = 0.1
	container.add_child(fill_noise_variation_input)

func _create_advanced_tuning_controls(container: VBoxContainer) -> void:
	"""Create advanced organic tuning controls"""
	# Noise octaves control
	var octaves_label = Label.new()
	octaves_label.text = "Noise Octaves (0-8):"
	container.add_child(octaves_label)

	organic_octaves_input = SpinBox.new()
	organic_octaves_input.min_value = 0
	organic_octaves_input.max_value = 8
	organic_octaves_input.step = 1
	organic_octaves_input.value = 2
	container.add_child(organic_octaves_input)

	# Lacunarity control
	var lacunarity_label = Label.new()
	lacunarity_label.text = "Lacunarity (0.0+):"
	container.add_child(lacunarity_label)

	organic_lacunarity_input = SpinBox.new()
	organic_lacunarity_input.min_value = 0.0
	organic_lacunarity_input.max_value = 10.0
	organic_lacunarity_input.step = 0.1
	organic_lacunarity_input.value = 1.5
	container.add_child(organic_lacunarity_input)

	# Gain control
	var gain_label = Label.new()
	gain_label.text = "Gain (0.0-1.0):"
	container.add_child(gain_label)

	organic_gain_input = SpinBox.new()
	organic_gain_input.min_value = 0.0
	organic_gain_input.max_value = 1.0
	organic_gain_input.step = 0.1
	organic_gain_input.value = 0.3
	container.add_child(organic_gain_input)

	# Amplitude multiplier control
	var amplitude_mult_label = Label.new()
	amplitude_mult_label.text = "Amplitude Multiplier (0.0-2.0):"
	container.add_child(amplitude_mult_label)

	organic_amplitude_input = SpinBox.new()
	organic_amplitude_input.min_value = 0.0
	organic_amplitude_input.max_value = 2.0
	organic_amplitude_input.step = 0.1
	organic_amplitude_input.value = 0.5
	container.add_child(organic_amplitude_input)

	# Curvature scale control
	var curvature_label = Label.new()
	curvature_label.text = "Curvature Scale (0.0+):"
	container.add_child(curvature_label)

	organic_curvature_input = SpinBox.new()
	organic_curvature_input.min_value = 0.0
	organic_curvature_input.max_value = 50.0
	organic_curvature_input.step = 0.5
	organic_curvature_input.value = 8.0
	container.add_child(organic_curvature_input)

func _create_info_labels(container: VBoxContainer) -> void:
	"""Create information and help labels"""
	# Note about auto-seeding
	var auto_seed_label = Label.new()
	auto_seed_label.text = "Note: Seed auto-increments each generation"
	auto_seed_label.add_theme_font_size_override("font_size", 9)
	auto_seed_label.modulate = Color(0.7, 0.7, 0.7)
	container.add_child(auto_seed_label)

	# Info label
	var info_label = Label.new()
	info_label.text = "Select ForestArena scene in editor, then click Generate."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 10)
	container.add_child(info_label)

	# Runtime hotkey hint
	var hotkey_label = Label.new()
	hotkey_label.text = "Runtime: Press F6 to regenerate"
	hotkey_label.add_theme_font_size_override("font_size", 9)
	hotkey_label.modulate = Color(0.8, 0.8, 0.8)
	container.add_child(hotkey_label)

func _on_generate_pressed():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()

	# Look for ProceduralArenaGenerator in the current scene
	var current_scene = EditorInterface.get_edited_scene_root()
	if not current_scene:
		push_error("No scene is currently open")
		return


	var generator = _find_forest_generator(current_scene)
	if not generator:
		push_error("No ProceduralArenaGenerator found in current scene. Please open ForestArena.tscn")
		return

	# Check if this is a placeholder instance (tool mode issue)
	if not generator.has_method("generate_arena"):
		push_error("Generator instance is not properly initialized. Try saving and reloading the scene.")
		return

	# Validate that the generator has required resources
	if not generator.generation_params:
		push_error("Generator is missing GenerationParams resource. Please assign it in the inspector.")
		return

	if not generator.biome_config:
		push_error("Generator is missing BiomeConfig resource. Please assign it in the inspector.")
		return

	# Update generator settings via GenerationParams resource
	if generator.generation_params:
		generator.generation_params.generation_seed = int(seed_input.value)
		generator.generation_params.arena_size = Vector2i(int(arena_size_x.value), int(arena_size_y.value))

		# Apply enhanced feature settings
		generator.generation_params.camera_boundary_extension = int(camera_extension_input.value)
		generator.generation_params.enable_spawn_layer = spawn_layer_toggle.button_pressed
		generator.generation_params.spawn_border_spacing = int(spawn_border_spacing_input.value)
		generator.generation_params.edge_density_multiplier = edge_density_input.value
		generator.generation_params.invert_density_gradient = invert_gradient_toggle.button_pressed

		# Apply organic boundary settings
		generator.generation_params.enable_organic_boundaries = organic_boundaries_toggle.button_pressed
		generator.generation_params.boundary_noise_frequency = noise_frequency_input.value
		generator.generation_params.boundary_noise_amplitude = noise_amplitude_input.value
		generator.generation_params.boundary_edge_fill_chance = boundary_edge_fill_input.value

		# Apply organic fine-tuning settings
		generator.generation_params.organic_noise_octaves = int(organic_octaves_input.value)
		generator.generation_params.organic_noise_lacunarity = organic_lacunarity_input.value
		generator.generation_params.organic_noise_gain = organic_gain_input.value
		generator.generation_params.organic_amplitude_multiplier = organic_amplitude_input.value
		generator.generation_params.organic_curvature_scale = organic_curvature_input.value

		# Apply ultra-strong gap-free settings
		generator.generation_params.fill_sample_spacing = int(fill_sample_spacing_input.value)
		generator.generation_params.fill_coverage_radius = fill_coverage_radius_input.value
		generator.generation_params.fill_angular_density = fill_angular_density_input.value
		generator.generation_params.fill_minimum_chance = fill_minimum_chance_input.value
		generator.generation_params.fill_maximum_multiplier = fill_maximum_multiplier_input.value
		generator.generation_params.fill_noise_variation = fill_noise_variation_input.value


	# Update biome settings via BiomeConfig resource
	if generator.biome_config:
		generator.biome_config.tree_spacing_min = int(tree_spacing_min_input.value)
		generator.biome_config.tree_spacing_max = int(tree_spacing_max_input.value)
		generator.biome_config.tree_placement_chance = tree_chance_input.value

	# Generate!
	var current_seed = generator.generation_params.generation_seed if generator.generation_params else 0
	print("🌲 Generating procedural arena with seed: ", current_seed)
	generator.generate_arena()

	# Update UI to show the incremented seed
	if generator.generation_params:
		seed_input.value = generator.generation_params.generation_seed

	# Mark scene as modified so user can save
	EditorInterface.mark_scene_as_unsaved()

# Removed random seed function - auto-incrementing now

func _find_forest_generator(node: Node) -> Node:
	"""Recursively find ProceduralArenaGenerator in the scene tree"""
	# Check if this node has the generate_arena method (our script)
	if node.has_method("generate_arena"):
		var script = node.get_script()
		if script:
			# Check if it's the ProceduralArenaGenerator script
			var script_path = str(script.resource_path)
			if "ProceduralArenaGenerator" in script_path:
				return node

	# Search children
	for child in node.get_children():
		var result = _find_forest_generator(child)
		if result:
			return result

	return null