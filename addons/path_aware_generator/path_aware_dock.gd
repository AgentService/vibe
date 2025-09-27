@tool
extends Control

var generate_button: Button
var seed_input: SpinBox

# Path Network Configuration
var enable_path_aware_toggle: CheckBox
var arena_size_input: SpinBox
var min_point_distance_input: SpinBox

# Path Configuration
var path_width_input: SpinBox
var boundary_thickness_input: SpinBox
var path_smoothing_input: SpinBox

# Tree Configuration
var tree_spacing_input: SpinBox
var tree_density_input: SpinBox
var enable_staggered_placement_toggle: CheckBox
var max_random_offset_input: SpinBox

# Natural Generation
var enable_variation_toggle: CheckBox
var max_variation_input: SpinBox
var enable_waypoints_toggle: CheckBox
var waypoint_probability_input: SpinBox

# Ground Coverage
var ground_extension_input: SpinBox

func _init():
	name = "Path-Aware Generator"
	# Expand to fill available dock space
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Set minimum size to ensure content is visible
	set_custom_minimum_size(Vector2(280, 400))

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
	title.text = "Path-Aware Arena Generator"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "POC: Natural Path-Following Boundaries"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Basic Controls section
	_create_basic_controls(vbox)
	vbox.add_child(HSeparator.new())

	# Path Network section
	_create_path_network_controls(vbox)
	vbox.add_child(HSeparator.new())

	# Path Configuration section
	_create_path_config_controls(vbox)
	vbox.add_child(HSeparator.new())

	# Tree Configuration section
	_create_tree_config_controls(vbox)
	vbox.add_child(HSeparator.new())

	# Natural Generation section
	_create_natural_generation_controls(vbox)
	vbox.add_child(HSeparator.new())

	# Ground Coverage section
	_create_ground_coverage_controls(vbox)
	vbox.add_child(HSeparator.new())

	# Generate button
	generate_button = Button.new()
	generate_button.text = "Generate Path-Aware Arena"
	generate_button.pressed.connect(_on_generate_pressed)
	vbox.add_child(generate_button)

	# Info labels
	_create_info_labels(vbox)

func _create_basic_controls(container: VBoxContainer) -> void:
	"""Create basic generation controls"""
	var basic_title = Label.new()
	basic_title.text = "Basic Configuration"
	basic_title.add_theme_font_size_override("font_size", 12)
	container.add_child(basic_title)

	# Seed control
	var seed_label = Label.new()
	seed_label.text = "Generation Seed:"
	container.add_child(seed_label)

	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 999999
	seed_input.value = 54321
	container.add_child(seed_input)

func _create_path_network_controls(container: VBoxContainer) -> void:
	"""Create path network configuration controls"""
	var network_title = Label.new()
	network_title.text = "Path Network Setup"
	network_title.add_theme_font_size_override("font_size", 12)
	container.add_child(network_title)

	# Enable path-aware generation
	enable_path_aware_toggle = CheckBox.new()
	enable_path_aware_toggle.text = "Enable Path-Aware Boundaries"
	enable_path_aware_toggle.button_pressed = true
	container.add_child(enable_path_aware_toggle)

	# Arena size
	var arena_size_label = Label.new()
	arena_size_label.text = "Arena Size (pixels):"
	container.add_child(arena_size_label)

	arena_size_input = SpinBox.new()
	arena_size_input.min_value = 100
	arena_size_input.max_value = 500
	arena_size_input.step = 20
	arena_size_input.value = 300
	container.add_child(arena_size_input)

	# Hub extension distance (was min point distance)
	var point_distance_label = Label.new()
	point_distance_label.text = "Hub Extension Distance (pixels):"
	container.add_child(point_distance_label)

	min_point_distance_input = SpinBox.new()
	min_point_distance_input.min_value = 50
	min_point_distance_input.max_value = 200
	min_point_distance_input.step = 10
	min_point_distance_input.value = 80
	container.add_child(min_point_distance_input)

func _create_path_config_controls(container: VBoxContainer) -> void:
	"""Create path configuration controls"""
	var path_title = Label.new()
	path_title.text = "Path Configuration"
	path_title.add_theme_font_size_override("font_size", 12)
	container.add_child(path_title)

	# Path width
	var path_width_label = Label.new()
	path_width_label.text = "Path Width (pixels):"
	container.add_child(path_width_label)

	path_width_input = SpinBox.new()
	path_width_input.min_value = 32
	path_width_input.max_value = 128
	path_width_input.step = 8
	path_width_input.value = 64
	container.add_child(path_width_input)

	# Boundary thickness
	var boundary_thickness_label = Label.new()
	boundary_thickness_label.text = "Boundary Thickness (pixels):"
	container.add_child(boundary_thickness_label)

	boundary_thickness_input = SpinBox.new()
	boundary_thickness_input.min_value = -5000
	boundary_thickness_input.max_value = 6400
	boundary_thickness_input.step = 50
	boundary_thickness_input.value = 50
	container.add_child(boundary_thickness_input)

	# Path smoothing
	var smoothing_label = Label.new()
	smoothing_label.text = "Path Smoothing (0=angular, 1=smooth):"
	container.add_child(smoothing_label)

	path_smoothing_input = SpinBox.new()
	path_smoothing_input.min_value = 0.0
	path_smoothing_input.max_value = 111.0
	path_smoothing_input.step = 0.1
	path_smoothing_input.value = 0.4
	container.add_child(path_smoothing_input)

func _create_tree_config_controls(container: VBoxContainer) -> void:
	"""Create tree configuration controls"""
	var tree_title = Label.new()
	tree_title.text = "Tree Configuration"
	tree_title.add_theme_font_size_override("font_size", 12)
	container.add_child(tree_title)

	# Tree spacing
	var spacing_label = Label.new()
	spacing_label.text = "Tree Spacing (pixels):"
	container.add_child(spacing_label)

	tree_spacing_input = SpinBox.new()
	tree_spacing_input.min_value = 16
	tree_spacing_input.max_value = 128
	tree_spacing_input.step = 4
	tree_spacing_input.value = 88
	container.add_child(tree_spacing_input)

	# Tree density
	var density_label = Label.new()
	density_label.text = "Tree Density (0.5-1.0):"
	container.add_child(density_label)

	tree_density_input = SpinBox.new()
	tree_density_input.min_value = 0.5
	tree_density_input.max_value = 1.0
	tree_density_input.step = 0.05
	tree_density_input.value = 0.95
	container.add_child(tree_density_input)

	# Enable staggered placement (zigzag effect)
	enable_staggered_placement_toggle = CheckBox.new()
	enable_staggered_placement_toggle.text = "Enable Zigzag Placement (Natural Look)"
	enable_staggered_placement_toggle.button_pressed = true
	container.add_child(enable_staggered_placement_toggle)

	# Max random offset
	var offset_label = Label.new()
	offset_label.text = "Random Offset Amount (pixels):"
	container.add_child(offset_label)

	max_random_offset_input = SpinBox.new()
	max_random_offset_input.min_value = 0
	max_random_offset_input.max_value = 32
	max_random_offset_input.step = 2
	max_random_offset_input.value = 8
	container.add_child(max_random_offset_input)
	
func _create_natural_generation_controls(container: VBoxContainer) -> void:
	"""Create natural generation controls"""
	var natural_title = Label.new()
	natural_title.text = "Natural Generation"
	natural_title.add_theme_font_size_override("font_size", 12)
	container.add_child(natural_title)

	# Enable path variation
	enable_variation_toggle = CheckBox.new()
	enable_variation_toggle.text = "Enable Path Variation"
	enable_variation_toggle.button_pressed = true
	container.add_child(enable_variation_toggle)

	# Max path variation
	var variation_label = Label.new()
	variation_label.text = "Max Path Variation (degrees):"
	container.add_child(variation_label)

	max_variation_input = SpinBox.new()
	max_variation_input.min_value = 10
	max_variation_input.max_value = 45
	max_variation_input.step = 5
	max_variation_input.value = 20
	container.add_child(max_variation_input)

	# Enable waypoints
	enable_waypoints_toggle = CheckBox.new()
	enable_waypoints_toggle.text = "Add Intermediate Waypoints"
	enable_waypoints_toggle.button_pressed = true
	container.add_child(enable_waypoints_toggle)

	# Waypoint probability
	var waypoint_label = Label.new()
	waypoint_label.text = "Waypoint Probability (0.0-1.0):"
	container.add_child(waypoint_label)

	waypoint_probability_input = SpinBox.new()
	waypoint_probability_input.min_value = 0.0
	waypoint_probability_input.max_value = 1.0
	waypoint_probability_input.step = 0.1
	waypoint_probability_input.value = 0.6
	container.add_child(waypoint_probability_input)

func _create_ground_coverage_controls(container: VBoxContainer) -> void:
	"""Create ground coverage controls"""
	var ground_title = Label.new()
	ground_title.text = "Ground Coverage"
	ground_title.add_theme_font_size_override("font_size", 12)
	container.add_child(ground_title)

	# Ground extension
	var ground_label = Label.new()
	ground_label.text = "Ground Extension (tiles):"
	container.add_child(ground_label)

	ground_extension_input = SpinBox.new()
	ground_extension_input.min_value = 5
	ground_extension_input.max_value = 50
	ground_extension_input.step = 5
	ground_extension_input.value = 20
	container.add_child(ground_extension_input)

func _create_info_labels(container: VBoxContainer) -> void:
	"""Create information and help labels"""
	# POC note
	var poc_note_label = Label.new()
	poc_note_label.text = "🧪 POC: Natural path-following boundaries"
	poc_note_label.add_theme_font_size_override("font_size", 10)
	poc_note_label.modulate = Color(0.2, 0.6, 1.0)
	container.add_child(poc_note_label)

	# Info label
	var info_label = Label.new()
	info_label.text = "Generates single outward-extending path chain: center → point1 → point2 → point3. Creates natural winding corridor with organic boundaries. Open PathAwareTestArena.tscn or add PathAwareArenaGenerator to any scene, then click Generate."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 10)
	container.add_child(info_label)

	# Technical note
	var tech_label = Label.new()
	tech_label.text = "Creates single linear chain extending outward from center with natural directional variation."
	tech_label.add_theme_font_size_override("font_size", 9)
	tech_label.modulate = Color(0.8, 0.8, 0.8)
	container.add_child(tech_label)

func _on_generate_pressed():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()

	# Look for ProceduralArenaGenerator in the current scene
	var current_scene = EditorInterface.get_edited_scene_root()
	if not current_scene:
		push_error("No scene is currently open")
		return

	var generator = _find_arena_generator(current_scene)
	if not generator:
		push_error("No arena generator found in current scene. Please open PathAwareTestArena.tscn or add PathAwareArenaGenerator to your scene.")
		return

	# Check if this is the old generator that needs resources
	if generator.has_method("generate_arena") and not generator.has_method("generate_path_aware_arena"):
		# This is the old ProceduralArenaGenerator - check for required resources
		if "generation_params" in generator and not generator.generation_params:
			push_error("Generator is missing GenerationParams resource. Please assign it in the inspector.")
			return

		if "biome_config" in generator and not generator.biome_config:
			push_error("Generator is missing BiomeConfig resource. Please assign it in the inspector.")
			return
	elif generator.has_method("generate_path_aware_arena"):
		# This is PathAwareArenaGenerator - check for PathAwareBoundaryConfig
		if "path_config" in generator and not generator.path_config:
			push_error("PathAwareArenaGenerator is missing PathAwareBoundaryConfig resource. Please assign it in the inspector.")
			return

	# Create and configure PathAwareBoundaryConfig
	var path_config = PathAwareBoundaryConfig.new()

	# Apply settings from UI
	path_config.enable_path_aware_boundaries = enable_path_aware_toggle.button_pressed
	path_config.arena_size = arena_size_input.value
	path_config.min_point_distance = min_point_distance_input.value
	path_config.path_width = path_width_input.value
	path_config.boundary_thickness = boundary_thickness_input.value
	path_config.path_smoothing = path_smoothing_input.value
	path_config.enable_path_variation = enable_variation_toggle.button_pressed
	path_config.max_path_variation = max_variation_input.value
	path_config.add_intermediate_waypoints = enable_waypoints_toggle.button_pressed
	path_config.waypoint_probability = waypoint_probability_input.value
	path_config.ground_extension = int(ground_extension_input.value)

	# Apply tree configuration to generator's tree_config if it exists
	if "tree_config" in generator and generator.tree_config:
		generator.tree_config.tree_spacing = tree_spacing_input.value
		generator.tree_config.tree_density = tree_density_input.value
		generator.tree_config.enable_staggered_placement = enable_staggered_placement_toggle.button_pressed
		generator.tree_config.max_random_offset = max_random_offset_input.value
		print("🌲 Applied tree configuration: spacing=", tree_spacing_input.value, ", density=", tree_density_input.value, ", zigzag=", enable_staggered_placement_toggle.button_pressed, ", offset=", max_random_offset_input.value)

	# Set seed for old generator
	if "generation_params" in generator and generator.generation_params:
		generator.generation_params.generation_seed = int(seed_input.value)

	# Set seed for new generator
	if "generation_seed" in generator:
		generator.generation_seed = int(seed_input.value)

	# Generate with path-aware boundaries
	var current_seed = int(seed_input.value)
	print("🛤️ Generating path-aware arena with seed: ", current_seed)

	# Call generation method (automatically increments seed)
	_generate_path_aware_arena(generator, path_config)

	# Update UI to show the incremented seed
	if "generation_params" in generator and generator.generation_params:
		seed_input.value = generator.generation_params.generation_seed
	elif "generation_seed" in generator:
		seed_input.value = generator.generation_seed

	# Mark scene as modified so user can save
	EditorInterface.mark_scene_as_unsaved()

func _generate_path_aware_arena(generator: Node, path_config: PathAwareBoundaryConfig) -> void:
	"""Generate arena using path-aware boundaries"""
	print("🛤️ Path-aware generation starting...")
	print("  - Arena size: ", path_config.arena_size)
	print("  - Path width: ", path_config.path_width)
	print("  - Boundary thickness: ", path_config.boundary_thickness)

	# Check if this is a PathAwareArenaGenerator
	if generator.has_method("generate_path_aware_arena"):
		# Use the new path-aware generator with automatic seed incrementing
		generator.path_config = path_config
		generator.generation_seed = int(seed_input.value)
		generator.generate_with_new_seed()  # This automatically increments seed
		print("🛤️ Path-aware generation completed using PathAwareArenaGenerator")
	else:
		# Fallback to existing generator
		generator.generate_arena()
		print("🛤️ Path-aware generation completed (using fallback method)")

func _find_arena_generator(node: Node) -> Node:
	"""Recursively find any arena generator in the scene tree"""
	# Check if this node has generation methods
	if node.has_method("generate_arena") or node.has_method("generate_path_aware_arena"):
		var script = node.get_script()
		if script:
			# Check if it's any arena generator script
			var script_path = str(script.resource_path)
			if "ArenaGenerator" in script_path:
				return node

	# Search children
	for child in node.get_children():
		var result = _find_arena_generator(child)
		if result:
			return result

	return null
