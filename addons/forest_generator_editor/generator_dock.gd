@tool
extends Control

var generate_button: Button
var seed_input: SpinBox
var arena_size_x: SpinBox
var arena_size_y: SpinBox

# Simplified Boundary Controls
var boundary_shape_option: OptionButton
var shape_length_input: SpinBox
var shape_height_input: SpinBox
# arena_base_size removed - boundary system is now single source of truth
var tree_spacing_horizontal_input: SpinBox
var tree_spacing_vertical_input: SpinBox
var tree_row_count_input: SpinBox
var tree_density_input: SpinBox

# Natural Placement Controls
var enable_staggered_toggle: CheckBox
var placement_randomness_input: SpinBox
var max_random_offset_input: SpinBox

# Natural Coverage Extension
var ground_extension_input: SpinBox
var spawn_layer_toggle: CheckBox
var spawn_border_spacing_input: SpinBox

func _init():
	name = "Forest Generator"
	# Expand to fill available dock space
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Set minimum size to ensure content is visible
	set_custom_minimum_size(Vector2(250, 350))

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
	title.text = "Simplified Forest Generator"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Basic Controls section
	_create_basic_controls(vbox)

	vbox.add_child(HSeparator.new())

	# Simplified Boundary section
	_create_simplified_boundary_controls(vbox)

	vbox.add_child(HSeparator.new())

	# Natural Placement section
	_create_natural_placement_controls(vbox)

	vbox.add_child(HSeparator.new())

	# Natural Coverage Extension section
	_create_natural_coverage_controls(vbox)

	vbox.add_child(HSeparator.new())

	# Generate button
	generate_button = Button.new()
	generate_button.text = "Generate Simplified Arena"
	generate_button.pressed.connect(_on_generate_pressed)
	vbox.add_child(generate_button)

	# Info labels
	_create_info_labels(vbox)

func _create_basic_controls(container: VBoxContainer) -> void:
	"""Create basic generation controls"""
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
	arena_size_x.max_value = 150
	arena_size_x.value = 150
	size_hbox.add_child(arena_size_x)

	var x_label = Label.new()
	x_label.text = " x "
	size_hbox.add_child(x_label)

	arena_size_y = SpinBox.new()
	arena_size_y.min_value = 10
	arena_size_y.max_value = 150
	arena_size_y.value = 150
	size_hbox.add_child(arena_size_y)

func _create_simplified_boundary_controls(container: VBoxContainer) -> void:
	"""Create simplified boundary controls"""
	var boundary_title = Label.new()
	boundary_title.text = "Simplified Boundary System"
	boundary_title.add_theme_font_size_override("font_size", 12)
	container.add_child(boundary_title)

	# Shape selection
	var shape_label = Label.new()
	shape_label.text = "Boundary Shape:"
	container.add_child(shape_label)

	boundary_shape_option = OptionButton.new()
	boundary_shape_option.add_item("Circle")
	boundary_shape_option.add_item("Rectangle")
	boundary_shape_option.selected = 0  # Default to Circle
	container.add_child(boundary_shape_option)

	# Shape length (width)
	var length_label = Label.new()
	length_label.text = "Shape Width (1=circle/square, 2-5=wide ellipse/rectangle):"
	container.add_child(length_label)

	shape_length_input = SpinBox.new()
	shape_length_input.min_value = 1.0
	shape_length_input.max_value = 5.0
	shape_length_input.step = 0.1
	shape_length_input.value = 1.0
	container.add_child(shape_length_input)

	# Shape height
	var height_label = Label.new()
	height_label.text = "Shape Height (1=circle/square, 2-5=tall ellipse/rectangle):"
	container.add_child(height_label)

	shape_height_input = SpinBox.new()
	shape_height_input.min_value = 1.0
	shape_height_input.max_value = 5.0
	shape_height_input.step = 0.1
	shape_height_input.value = 1.0
	container.add_child(shape_height_input)

	# Info about arena size connection
	var connection_info = Label.new()
	connection_info.text = "✅ Boundary shape automatically uses Arena Size above (150x150)"
	connection_info.add_theme_font_size_override("font_size", 10)
	connection_info.modulate = Color(0.2, 0.8, 0.2)
	container.add_child(connection_info)

	# arena_base_size removed - boundary system is now single source of truth

	# Tree spacing in pixels - horizontal
	var spacing_h_label = Label.new()
	spacing_h_label.text = "Tree Spacing Horizontal (pixels, 16-128):"
	container.add_child(spacing_h_label)

	tree_spacing_horizontal_input = SpinBox.new()
	tree_spacing_horizontal_input.min_value = 16
	tree_spacing_horizontal_input.max_value = 128
	tree_spacing_horizontal_input.step = 8
	tree_spacing_horizontal_input.value = 48
	container.add_child(tree_spacing_horizontal_input)

	# Tree spacing in pixels - vertical
	var spacing_v_label = Label.new()
	spacing_v_label.text = "Tree Spacing Vertical (pixels, 16-128):"
	container.add_child(spacing_v_label)

	tree_spacing_vertical_input = SpinBox.new()
	tree_spacing_vertical_input.min_value = 16
	tree_spacing_vertical_input.max_value = 128
	tree_spacing_vertical_input.step = 8
	tree_spacing_vertical_input.value = 32
	container.add_child(tree_spacing_vertical_input)

	# Tree row count
	var row_count_label = Label.new()
	row_count_label.text = "Tree Rows Outside Arena (1-6):"
	container.add_child(row_count_label)

	tree_row_count_input = SpinBox.new()
	tree_row_count_input.min_value = 1
	tree_row_count_input.max_value = 6
	tree_row_count_input.value = 3
	container.add_child(tree_row_count_input)

	# Tree density
	var density_label = Label.new()
	density_label.text = "Tree Density (0.1-1.0, 0.95+ recommended):"
	container.add_child(density_label)

	tree_density_input = SpinBox.new()
	tree_density_input.min_value = 0.1
	tree_density_input.max_value = 1.0
	tree_density_input.step = 0.05
	tree_density_input.value = 0.95
	container.add_child(tree_density_input)

func _create_natural_placement_controls(container: VBoxContainer) -> void:
	"""Create natural placement controls for staggered and random placement"""
	var natural_title = Label.new()
	natural_title.text = "Natural Placement Settings"
	natural_title.add_theme_font_size_override("font_size", 12)
	container.add_child(natural_title)

	# Enable staggered placement toggle
	enable_staggered_toggle = CheckBox.new()
	enable_staggered_toggle.text = "Enable Net-like Staggered Placement"
	enable_staggered_toggle.button_pressed = true
	container.add_child(enable_staggered_toggle)

	# Placement randomness
	var randomness_label = Label.new()
	randomness_label.text = "Placement Randomness (0=perfect grid, 1=high variation):"
	container.add_child(randomness_label)

	placement_randomness_input = SpinBox.new()
	placement_randomness_input.min_value = 0.0
	placement_randomness_input.max_value = 1.0
	placement_randomness_input.step = 0.1
	placement_randomness_input.value = 0.3
	container.add_child(placement_randomness_input)

	# Maximum random offset
	var offset_label = Label.new()
	offset_label.text = "Max Random Offset (pixels, 0-16):"
	container.add_child(offset_label)

	max_random_offset_input = SpinBox.new()
	max_random_offset_input.min_value = 0
	max_random_offset_input.max_value = 16
	max_random_offset_input.step = 2
	max_random_offset_input.value = 8
	container.add_child(max_random_offset_input)

func _create_natural_coverage_controls(container: VBoxContainer) -> void:
	"""Create natural coverage extension controls"""
	var coverage_title = Label.new()
	coverage_title.text = "Natural Coverage Extension"
	coverage_title.add_theme_font_size_override("font_size", 12)
	container.add_child(coverage_title)

	# Ground extension beyond boundaries
	var ground_label = Label.new()
	ground_label.text = "Ground Extension Beyond Boundaries (tiles):"
	container.add_child(ground_label)

	ground_extension_input = SpinBox.new()
	ground_extension_input.min_value = 0
	ground_extension_input.max_value = 30
	ground_extension_input.value = 10
	container.add_child(ground_extension_input)

	# Spawn layer controls
	spawn_layer_toggle = CheckBox.new()
	spawn_layer_toggle.text = "Enable Natural Spawn Layer"
	spawn_layer_toggle.button_pressed = true
	container.add_child(spawn_layer_toggle)

	var spawn_spacing_label = Label.new()
	spawn_spacing_label.text = "Spawn Border Spacing from Boundaries (tiles):"
	container.add_child(spawn_spacing_label)

	spawn_border_spacing_input = SpinBox.new()
	spawn_border_spacing_input.min_value = 1
	spawn_border_spacing_input.max_value = 15
	spawn_border_spacing_input.value = 5
	container.add_child(spawn_border_spacing_input)

	# Info label
	var info_label = Label.new()
	info_label.text = "✅ Ground and spawn areas naturally follow boundary shape"
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.modulate = Color(0.2, 0.8, 0.2)
	container.add_child(info_label)

func _create_info_labels(container: VBoxContainer) -> void:
	"""Create information and help labels"""
	# Note about simplified system
	var simple_note_label = Label.new()
	simple_note_label.text = "✅ Using new simplified boundary system"
	simple_note_label.add_theme_font_size_override("font_size", 10)
	simple_note_label.modulate = Color(0.2, 0.8, 0.2)
	container.add_child(simple_note_label)

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

	# Update generator settings via GenerationParams resource (simplified version)
	if generator.generation_params:
		generator.generation_params.generation_seed = int(seed_input.value)
		generator.generation_params.arena_size = Vector2i(int(arena_size_x.value), int(arena_size_y.value))

		# Apply natural coverage settings directly to boundary config
		if generator.generation_params.simple_boundary_config:
			var boundary_config = generator.generation_params.simple_boundary_config
			boundary_config.ground_extension = int(ground_extension_input.value)
			boundary_config.spawn_border_spacing = int(spawn_border_spacing_input.value)

		# Apply spawn layer setting to generation params
		generator.generation_params.enable_spawn_layer = spawn_layer_toggle.button_pressed

		# Enable simplified boundaries
		generator.generation_params.use_simplified_boundaries = true

		# Update the SimpleBoundaryConfig resource if it exists
		if generator.generation_params.simple_boundary_config:
			var boundary_config = generator.generation_params.simple_boundary_config

			# Apply simplified boundary settings
			boundary_config.base_shape = "Circle" if boundary_shape_option.selected == 0 else "Rectangle"
			boundary_config.shape_length = shape_length_input.value
			boundary_config.shape_height = shape_height_input.value
			# arena_base_size removed - boundary system is now single source of truth
			boundary_config.tree_spacing_horizontal = int(tree_spacing_horizontal_input.value)
			boundary_config.tree_spacing_vertical = int(tree_spacing_vertical_input.value)
			boundary_config.tree_row_count = int(tree_row_count_input.value)
			boundary_config.tree_density = tree_density_input.value

			# Apply natural placement settings
			boundary_config.enable_staggered_placement = enable_staggered_toggle.button_pressed
			boundary_config.placement_randomness = placement_randomness_input.value
			boundary_config.max_random_offset = int(max_random_offset_input.value)

	# Generate!
	var current_seed = generator.generation_params.generation_seed if generator.generation_params else 0
	print("🌲 Generating simplified arena with seed: ", current_seed)
	generator.generate_arena()

	# Update UI to show the incremented seed
	if generator.generation_params:
		seed_input.value = generator.generation_params.generation_seed

	# Mark scene as modified so user can save
	EditorInterface.mark_scene_as_unsaved()

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