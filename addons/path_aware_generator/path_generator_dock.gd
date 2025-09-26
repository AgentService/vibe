@tool
extends Control
class_name PathGeneratorDock

# UI Controls
var generate_button: Button
var seed_input: SpinBox
var path_count_input: SpinBox
var arena_size_input: SpinBox
var corridor_width_input: SpinBox
var tree_spacing_input: SpinBox
var arena_base_radius_input: SpinBox
var chain_length_input: SpinBox
var min_distance_input: SpinBox
var point_radius_input: SpinBox
var path_extension_width_input: SpinBox
var boundary_distance_input: SpinBox
var status_label: Label

# Generator reference
var path_generator: DungeonPathGenerator
var tree_generator: TreeBoundaryGenerator

# Configuration resources
var path_config: PathConfiguration
var tree_config: TreeBoundaryConfiguration

func _init():
	# Set dock name and minimum size
	name = "Path Generator"
	custom_minimum_size = Vector2(200, 300)
	
	_build_ui()
	_load_default_configs()
	_connect_signals()

func _build_ui():
	# Create vertical layout
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Path-Aware Generator"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	# Separator
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Seed control
	var seed_label = Label.new()
	seed_label.text = "Seed:"
	vbox.add_child(seed_label)

	# Seed input and random button in horizontal container
	var seed_hbox = HBoxContainer.new()
	vbox.add_child(seed_hbox)

	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 999999
	seed_input.value = 54321
	seed_input.step = 1
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_hbox.add_child(seed_input)

	# Random seed button
	var random_seed_button = Button.new()
	random_seed_button.text = "🎲"
	random_seed_button.tooltip_text = "Generate Random Seed"
	random_seed_button.custom_minimum_size.x = 30
	random_seed_button.pressed.connect(_generate_random_seed)
	seed_hbox.add_child(random_seed_button)
	
	# Path count control
	var path_count_label = Label.new()
	path_count_label.text = "Connection Points:"
	vbox.add_child(path_count_label)
	
	path_count_input = SpinBox.new()
	path_count_input.min_value = 2
	path_count_input.max_value = 8
	path_count_input.value = 3
	path_count_input.step = 1
	vbox.add_child(path_count_input)
	
	# Arena size control
	var arena_size_label = Label.new()
	arena_size_label.text = "Arena Size:"
	vbox.add_child(arena_size_label)

	arena_size_input = SpinBox.new()
	arena_size_input.min_value = 200
	arena_size_input.max_value = 800
	arena_size_input.value = 300
	arena_size_input.step = 50
	vbox.add_child(arena_size_input)

	# Corridor width control (unlimited)
	var corridor_width_label = Label.new()
	corridor_width_label.text = "Corridor Width:"
	vbox.add_child(corridor_width_label)

	corridor_width_input = SpinBox.new()
	corridor_width_input.min_value = 50
	corridor_width_input.max_value = 5000  # Unlimited
	corridor_width_input.value = 900
	corridor_width_input.step = 50
	corridor_width_input.suffix = "px"
	vbox.add_child(corridor_width_input)

	# Tree spacing control
	var tree_spacing_label = Label.new()
	tree_spacing_label.text = "Tree Spacing:"
	vbox.add_child(tree_spacing_label)

	tree_spacing_input = SpinBox.new()
	tree_spacing_input.min_value = 20
	tree_spacing_input.max_value = 150
	tree_spacing_input.value = 30
	tree_spacing_input.step = 1
	tree_spacing_input.suffix = "px"
	vbox.add_child(tree_spacing_input)

	# Arena base radius control
	var arena_base_radius_label = Label.new()
	arena_base_radius_label.text = "Arena Base Radius:"
	vbox.add_child(arena_base_radius_label)

	arena_base_radius_input = SpinBox.new()
	arena_base_radius_input.min_value = 200
	arena_base_radius_input.max_value = 999999  # No limits
	arena_base_radius_input.value = 1800
	arena_base_radius_input.step = 50
	arena_base_radius_input.suffix = "px"
	vbox.add_child(arena_base_radius_input)

	# Chain length control
	var chain_length_label = Label.new()
	chain_length_label.text = "Chain Length:"
	vbox.add_child(chain_length_label)

	chain_length_input = SpinBox.new()
	chain_length_input.min_value = 2
	chain_length_input.max_value = 15
	chain_length_input.value = 7
	chain_length_input.step = 1
	chain_length_input.suffix = " points"
	vbox.add_child(chain_length_input)

	# Min distance control
	var min_distance_label = Label.new()
	min_distance_label.text = "Min Point Distance:"
	vbox.add_child(min_distance_label)

	min_distance_input = SpinBox.new()
	min_distance_input.min_value = 100
	min_distance_input.max_value = 1600
	min_distance_input.value = 800
	min_distance_input.step = 100
	min_distance_input.suffix = "px"
	vbox.add_child(min_distance_input)

	# Point radius control
	var point_radius_label = Label.new()
	point_radius_label.text = "Point Space Radius:"
	vbox.add_child(point_radius_label)

	point_radius_input = SpinBox.new()
	point_radius_input.min_value = 50
	point_radius_input.max_value = 200
	point_radius_input.value = 100
	point_radius_input.step = 10
	point_radius_input.suffix = "px"
	vbox.add_child(point_radius_input)

	# Path extension width control
	var path_extension_width_label = Label.new()
	path_extension_width_label.text = "Path Extension Width:"
	vbox.add_child(path_extension_width_label)

	path_extension_width_input = SpinBox.new()
	path_extension_width_input.min_value = 0
	path_extension_width_input.max_value = 1000  # Unlimited extension width
	path_extension_width_input.value = 60
	path_extension_width_input.step = 10
	path_extension_width_input.suffix = "px"
	vbox.add_child(path_extension_width_input)


	# Boundary distance control
	var boundary_distance_label = Label.new()
	boundary_distance_label.text = "Boundary Distance:"
	boundary_distance_label.tooltip_text = "Distance from paths to tree boundaries. Negative values allow tree overlap."
	vbox.add_child(boundary_distance_label)

	boundary_distance_input = SpinBox.new()
	boundary_distance_input.min_value = -500  # Allow negative values for tree overlap
	boundary_distance_input.max_value = 500  # Unlimited boundary distance
	boundary_distance_input.value = -150
	boundary_distance_input.step = 50
	boundary_distance_input.suffix = "px"
	vbox.add_child(boundary_distance_input)

	# Separator
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Generate button
	generate_button = Button.new()
	generate_button.text = "Generate Random Paths"
	generate_button.custom_minimum_size.y = 30
	vbox.add_child(generate_button)
	
	# Status label
	status_label = Label.new()
	status_label.text = "Ready to generate"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)
	
	# Spacer to push controls to top
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

func _load_default_configs():
	# Load default path configuration
	path_config = load("res://data/content/DefaultPathConfiguration.tres")
	if not path_config:
		Logger.warn("Could not load DefaultPathConfiguration, creating new one", "plugin")
		path_config = PathConfiguration.new()
	
	# Load default tree boundary configuration
	tree_config = load("res://data/content/DefaultTreeBoundaryConfiguration.tres")
	if not tree_config:
		Logger.warn("Could not load DefaultTreeBoundaryConfiguration, creating new one", "plugin")
		tree_config = TreeBoundaryConfiguration.new()

func _connect_signals():
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)

func _on_generate_pressed():
	Logger.info("Starting path generation from editor plugin", "plugin")

	# Auto-increment seed for different results each time
	seed_input.value += 1

	# Update status
	status_label.text = "Generating paths..."

	# Get current scene
	var current_scene = EditorInterface.get_edited_scene_root()
	if not current_scene:
		_show_error("No scene is currently open")
		return

	# Look for PathAwareArenaGenerator in the scene
	var generator = _find_path_generator(current_scene)
	if not generator:
		_show_error("No PathAwareArenaGenerator found in current scene")
		return

	# Update generator settings from UI
	_update_generator_settings(generator)

	# Trigger generation
	generator.generate_path_aware_arena()

	# Update status with seed info
	status_label.text = "Generated! (Seed: %d)" % int(seed_input.value)

	Logger.info("Path generation completed from editor plugin with seed: %d" % int(seed_input.value), "plugin")

func _find_path_generator(node: Node) -> PathAwareArenaGenerator:
	# Check if current node is the generator
	if node is PathAwareArenaGenerator:
		return node as PathAwareArenaGenerator
	
	# Recursively search children
	for child in node.get_children():
		var result = _find_path_generator(child)
		if result:
			return result
	
	return null

func _update_generator_settings(generator: PathAwareArenaGenerator):
	# Update generator seed
	generator.generation_seed = int(seed_input.value)

	# Update path configuration
	if generator.path_config:
		generator.path_config.connection_points = int(path_count_input.value)
		generator.path_config.arena_size = arena_size_input.value
		generator.path_config.path_width = corridor_width_input.value
		if chain_length_input:
			generator.path_config.chain_length = int(chain_length_input.value)
		if min_distance_input:
			generator.path_config.min_point_distance = min_distance_input.value
		if point_radius_input:
			generator.path_config.point_space_radius = point_radius_input.value
		if path_extension_width_input:
			generator.path_config.path_extension_width = path_extension_width_input.value

	# Update tree configuration
	if generator.tree_config:
		generator.tree_config.tree_spacing = tree_spacing_input.value
		if boundary_distance_input:
			generator.tree_config.boundary_distance = boundary_distance_input.value

	# Update arena base radius
	generator.arena_base_radius = arena_base_radius_input.value

	Logger.debug("Updated generator settings: seed=%d, points=%d, size=%.1f, corridor=%.1f, spacing=%.1f, base_radius=%.1f, chain=%d, min_dist=%.1f, point_radius=%.1f, ext1=%.1f, boundary=%.1f" % [
		generator.generation_seed,
		int(path_count_input.value),
		arena_size_input.value,
		corridor_width_input.value,
		tree_spacing_input.value,
		arena_base_radius_input.value,
		int(chain_length_input.value if chain_length_input else 4),
		min_distance_input.value if min_distance_input else 80.0,
		point_radius_input.value if point_radius_input else 100.0,
		path_extension_width_input.value if path_extension_width_input else 48.0,
		boundary_distance_input.value if boundary_distance_input else 96.0
	], "plugin")

func _show_error(message: String):
	status_label.text = "Error: " + message
	Logger.warn("Plugin error: " + message, "plugin")

# Utility function to get current editor selection
func get_selected_nodes() -> Array[Node]:
	var selection = EditorInterface.get_selection()
	return selection.get_selected_nodes()

# Random seed generation
func _generate_random_seed():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	seed_input.value = rng.randi_range(1000, 99999)
	Logger.debug("Generated random seed: %d" % int(seed_input.value), "plugin")
