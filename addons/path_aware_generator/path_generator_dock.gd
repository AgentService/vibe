@tool
extends Control
class_name PathGeneratorDock

# UI Controls
var generate_button: Button
var seed_input: SpinBox
var path_count_input: SpinBox
# arena_size_input removed
var corridor_width_input: SpinBox
var tree_spacing_input: SpinBox
# arena_base_radius_input removed
var chain_length_input: SpinBox
var min_distance_input: SpinBox
# point_radius_input removed
# path_extension_width_input removed
# path_extension_width2_input removed
# boundary_distance_input removed
var status_label: Label

# Dynamic branching controls
var enable_branching_checkbox: CheckBox
var branch_probability_input: SpinBox
var min_branch_length_input: SpinBox
var max_branch_length_input: SpinBox
var branch_curve_intensity_input: SpinBox
var min_branches_per_point_input: SpinBox
var max_branches_per_point_input: SpinBox

# Tree boundary controls
# boundary_thickness_input removed
var tree_boundary_width_input: SpinBox
var use_path_radius_checkbox: CheckBox


# Performance optimization controls
var use_prebuilt_tree_field_checkbox: CheckBox

# Gradient density controls removed

# Tree randomization controls
var placement_randomness_input: SpinBox
var max_random_offset_input: SpinBox


# Generator reference
var path_generator: DungeonPathGenerator
var tree_generator: TreeBoundaryGenerator

# Configuration resources (untyped to avoid class resolution issues at startup)
var path_config
var tree_config

func _init():
	# Set dock name and minimum size (smaller since we now have scrolling)
	name = "Path Generator"
	custom_minimum_size = Vector2(480, 600)
	
	_build_ui()
	_load_default_configs()
	_connect_signals()

func _build_ui():
	# Create scroll container for all controls
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_container)

	# Create vertical layout inside scroll container
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)  # Compact spacing
	scroll_container.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Path-Aware Generator"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# === GENERATION SETTINGS GROUP ===
	var generation_group = VBoxContainer.new()
	generation_group.add_theme_constant_override("separation", 4)
	vbox.add_child(generation_group)

	# Group title
	var gen_title = Label.new()
	gen_title.text = "⚙️ Generation Settings"
	gen_title.add_theme_font_size_override("font_size", 11)
	gen_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	generation_group.add_child(gen_title)

	# Separator
	var gen_sep = HSeparator.new()
	generation_group.add_child(gen_sep)

	var gen_vbox = VBoxContainer.new()
	gen_vbox.add_theme_constant_override("separation", 4)
	generation_group.add_child(gen_vbox)

	# Seed control - compact layout
	var seed_hbox = HBoxContainer.new()
	gen_vbox.add_child(seed_hbox)

	var seed_label = Label.new()
	seed_label.text = "Seed:"
	seed_label.custom_minimum_size.x = 80
	seed_hbox.add_child(seed_label)

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

	# Connection Points - compact layout
	var points_hbox = HBoxContainer.new()
	gen_vbox.add_child(points_hbox)

	var path_count_label = Label.new()
	path_count_label.text = "Points:"
	path_count_label.custom_minimum_size.x = 80
	points_hbox.add_child(path_count_label)

	path_count_input = SpinBox.new()
	path_count_input.min_value = 2
	path_count_input.max_value = 8
	path_count_input.value = 3
	path_count_input.step = 1
	path_count_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_hbox.add_child(path_count_input)
	
	# === PATH & TREE SETTINGS GROUP ===
	var path_group = VBoxContainer.new()
	path_group.add_theme_constant_override("separation", 4)
	vbox.add_child(path_group)

	# Group title
	var path_title = Label.new()
	path_title.text = "🛤️ Path & Tree Settings"
	path_title.add_theme_font_size_override("font_size", 11)
	path_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	path_group.add_child(path_title)

	# Separator
	var path_sep = HSeparator.new()
	path_group.add_child(path_sep)

	var path_vbox = VBoxContainer.new()
	path_vbox.add_theme_constant_override("separation", 4)
	path_group.add_child(path_vbox)

	# Corridor width - compact layout
	var corridor_hbox = HBoxContainer.new()
	path_vbox.add_child(corridor_hbox)

	var corridor_width_label = Label.new()
	corridor_width_label.text = "Width:"
	corridor_width_label.custom_minimum_size.x = 80
	corridor_hbox.add_child(corridor_width_label)

	corridor_width_input = SpinBox.new()
	corridor_width_input.min_value = 50
	corridor_width_input.max_value = 5000
	corridor_width_input.value = 1500
	corridor_width_input.step = 50
	corridor_width_input.suffix = "px"
	corridor_width_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corridor_hbox.add_child(corridor_width_input)

	# Tree spacing - compact layout
	var spacing_hbox = HBoxContainer.new()
	path_vbox.add_child(spacing_hbox)

	var tree_spacing_label = Label.new()
	tree_spacing_label.text = "Spacing:"
	tree_spacing_label.custom_minimum_size.x = 80
	spacing_hbox.add_child(tree_spacing_label)

	tree_spacing_input = SpinBox.new()
	tree_spacing_input.min_value = 1
	tree_spacing_input.max_value = 150
	tree_spacing_input.value = 22
	tree_spacing_input.step = 15
	tree_spacing_input.suffix = "px"
	tree_spacing_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacing_hbox.add_child(tree_spacing_input)

	# Tree boundary width - compact layout
	var boundary_hbox = HBoxContainer.new()
	path_vbox.add_child(boundary_hbox)

	var tree_boundary_width_label = Label.new()
	tree_boundary_width_label.text = "Boundary:"
	tree_boundary_width_label.custom_minimum_size.x = 80
	boundary_hbox.add_child(tree_boundary_width_label)

	tree_boundary_width_input = SpinBox.new()
	tree_boundary_width_input.min_value = 50
	tree_boundary_width_input.max_value = 99999
	tree_boundary_width_input.value = 300
	tree_boundary_width_input.step = 50
	tree_boundary_width_input.suffix = "px"
	tree_boundary_width_input.tooltip_text = "Tree boundary width (outward extension)"
	tree_boundary_width_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boundary_hbox.add_child(tree_boundary_width_input)

	# Tree randomization controls - compact layout
	var randomness_hbox = HBoxContainer.new()
	path_vbox.add_child(randomness_hbox)
	var randomness_label = Label.new()
	randomness_label.text = "Randomness:"
	randomness_label.custom_minimum_size.x = 80
	randomness_hbox.add_child(randomness_label)
	placement_randomness_input = SpinBox.new()
	placement_randomness_input.min_value = 0.0
	placement_randomness_input.max_value = 100.0
	placement_randomness_input.step = 0.5
	placement_randomness_input.value = 0.1
	placement_randomness_input.tooltip_text = "Tree placement randomness (0=grid, 1=organic)"
	placement_randomness_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	randomness_hbox.add_child(placement_randomness_input)

	# Max random offset - compact layout
	var offset_hbox = HBoxContainer.new()
	path_vbox.add_child(offset_hbox)
	var offset_label = Label.new()
	offset_label.text = "Max Offset:"
	offset_label.custom_minimum_size.x = 80
	offset_hbox.add_child(offset_label)
	max_random_offset_input = SpinBox.new()
	max_random_offset_input.min_value = -2222
	max_random_offset_input.max_value = 22224
	max_random_offset_input.step = 2
	max_random_offset_input.value = 8
	max_random_offset_input.suffix = "px"
	max_random_offset_input.tooltip_text = "Maximum random offset distance"
	max_random_offset_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offset_hbox.add_child(max_random_offset_input)

	# Chain length - compact layout
	var chain_hbox = HBoxContainer.new()
	path_vbox.add_child(chain_hbox)

	var chain_length_label = Label.new()
	chain_length_label.text = "Chain Len:"
	chain_length_label.custom_minimum_size.x = 80
	chain_hbox.add_child(chain_length_label)

	chain_length_input = SpinBox.new()
	chain_length_input.min_value = 2
	chain_length_input.max_value = 15
	chain_length_input.value = 5
	chain_length_input.step = 1
	chain_length_input.suffix = " pts"
	chain_length_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chain_hbox.add_child(chain_length_input)

	# Min distance - compact layout
	var distance_hbox = HBoxContainer.new()
	path_vbox.add_child(distance_hbox)

	var min_distance_label = Label.new()
	min_distance_label.text = "Min Dist:"
	min_distance_label.custom_minimum_size.x = 80
	distance_hbox.add_child(min_distance_label)

	min_distance_input = SpinBox.new()
	min_distance_input.min_value = 100
	min_distance_input.max_value = 2600
	min_distance_input.value = 800
	min_distance_input.step = 100
	min_distance_input.suffix = "px"
	min_distance_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance_hbox.add_child(min_distance_input)

	# === DYNAMIC BRANCHING GROUP ===
	var branching_group = VBoxContainer.new()
	branching_group.add_theme_constant_override("separation", 4)
	vbox.add_child(branching_group)

	# Group title
	var branch_title = Label.new()
	branch_title.text = "🌿 Dynamic Branching"
	branch_title.add_theme_font_size_override("font_size", 11)
	branch_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	branching_group.add_child(branch_title)

	# Separator
	var branch_sep = HSeparator.new()
	branching_group.add_child(branch_sep)

	var branch_vbox = VBoxContainer.new()
	branch_vbox.add_theme_constant_override("separation", 4)
	branching_group.add_child(branch_vbox)

	# Enable branching checkbox
	enable_branching_checkbox = CheckBox.new()
	enable_branching_checkbox.text = "Enable Dynamic Branching"
	enable_branching_checkbox.button_pressed = true
	branch_vbox.add_child(enable_branching_checkbox)

	# Branch probability - compact layout
	var prob_hbox = HBoxContainer.new()
	branch_vbox.add_child(prob_hbox)

	var branch_prob_label = Label.new()
	branch_prob_label.text = "Probability:"
	branch_prob_label.custom_minimum_size.x = 80
	prob_hbox.add_child(branch_prob_label)

	branch_probability_input = SpinBox.new()
	branch_probability_input.min_value = 0
	branch_probability_input.max_value = 100
	branch_probability_input.value = 80
	branch_probability_input.step = 5
	branch_probability_input.suffix = "%"
	branch_probability_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prob_hbox.add_child(branch_probability_input)

	# Branches per point - compact layout
	var branches_per_point_label = Label.new()
	branches_per_point_label.text = "Per Point (Min-Max):"
	branch_vbox.add_child(branches_per_point_label)

	var branches_hbox = HBoxContainer.new()
	branch_vbox.add_child(branches_hbox)

	min_branches_per_point_input = SpinBox.new()
	min_branches_per_point_input.min_value = 1
	min_branches_per_point_input.max_value = 40
	min_branches_per_point_input.value = 1
	min_branches_per_point_input.step = 1
	branches_hbox.add_child(min_branches_per_point_input)

	var to_label = Label.new()
	to_label.text = " to "
	branches_hbox.add_child(to_label)

	max_branches_per_point_input = SpinBox.new()
	max_branches_per_point_input.min_value = 1
	max_branches_per_point_input.max_value = 40
	max_branches_per_point_input.value = 2
	max_branches_per_point_input.step = 1
	branches_hbox.add_child(max_branches_per_point_input)

	# Branch length - compact layout
	var branch_length_label = Label.new()
	branch_length_label.text = "Length (Min-Max px):"
	branch_vbox.add_child(branch_length_label)

	var length_hbox = HBoxContainer.new()
	branch_vbox.add_child(length_hbox)

	min_branch_length_input = SpinBox.new()
	min_branch_length_input.min_value = 50
	min_branch_length_input.max_value = 5000
	min_branch_length_input.value = 500
	min_branch_length_input.step = 25
	min_branch_length_input.suffix = "px"
	length_hbox.add_child(min_branch_length_input)

	var to_label2 = Label.new()
	to_label2.text = " to "
	length_hbox.add_child(to_label2)

	max_branch_length_input = SpinBox.new()
	max_branch_length_input.min_value = 200
	max_branch_length_input.max_value = 5000
	max_branch_length_input.value = 1500
	max_branch_length_input.step = 50
	max_branch_length_input.suffix = "px"
	length_hbox.add_child(max_branch_length_input)

	# Branch curve intensity - compact layout
	var curve_hbox = HBoxContainer.new()
	branch_vbox.add_child(curve_hbox)

	var curve_label = Label.new()
	curve_label.text = "Curve:"
	curve_label.custom_minimum_size.x = 80
	curve_hbox.add_child(curve_label)

	branch_curve_intensity_input = SpinBox.new()
	branch_curve_intensity_input.min_value = -550.0
	branch_curve_intensity_input.max_value = 1001.0
	branch_curve_intensity_input.value = 333
	branch_curve_intensity_input.step = 111
	branch_curve_intensity_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	curve_hbox.add_child(branch_curve_intensity_input)

	# === TREE BOUNDARY OPTIONS GROUP ===
	var tree_options_group = VBoxContainer.new()
	tree_options_group.add_theme_constant_override("separation", 4)
	vbox.add_child(tree_options_group)

	# Group title
	var tree_title = Label.new()
	tree_title.text = "🌲 Tree Options"
	tree_title.add_theme_font_size_override("font_size", 11)
	tree_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	tree_options_group.add_child(tree_title)

	# Separator
	var tree_sep = HSeparator.new()
	tree_options_group.add_child(tree_sep)

	var tree_vbox = VBoxContainer.new()
	tree_vbox.add_theme_constant_override("separation", 4)
	tree_options_group.add_child(tree_vbox)

	# Path-radius generation checkbox
	use_path_radius_checkbox = CheckBox.new()
	use_path_radius_checkbox.text = "Use Path-Radius Generation (Efficient)"
	use_path_radius_checkbox.button_pressed = true
	use_path_radius_checkbox.tooltip_text = "Generate trees only around actual paths"
	tree_vbox.add_child(use_path_radius_checkbox)

	# Pre-built tree field checkbox (keep checkbox only)
	use_prebuilt_tree_field_checkbox = CheckBox.new()
	use_prebuilt_tree_field_checkbox.text = "Use Pre-built Tree Field (Faster)"
	use_prebuilt_tree_field_checkbox.button_pressed = false
	use_prebuilt_tree_field_checkbox.tooltip_text = "Use pre-built tree field for better performance"
	tree_vbox.add_child(use_prebuilt_tree_field_checkbox)





	# === GENERATION BUTTON ===
	generate_button = Button.new()
	generate_button.text = "🌱 Generate Path Arena"
	generate_button.custom_minimum_size.y = 35
	generate_button.add_theme_font_size_override("font_size", 12)
	vbox.add_child(generate_button)
	
	# Status label
	status_label = Label.new()
	status_label.text = "Ready to generate"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status_label)

func _load_default_configs():
	# Load default path configuration
	path_config = load("res://data/content/DefaultPathConfiguration.tres")
	if not path_config:
		Logger.warn("Could not load DefaultPathConfiguration, creating new one", "plugin")
		# Create new PathConfiguration by loading the script directly
		var path_config_script = load("res://scripts/resources/PathConfiguration.gd")
		if path_config_script:
			path_config = path_config_script.new()
		else:
			Logger.error("Could not load PathConfiguration script", "plugin")
			return

	# Load default tree boundary configuration
	tree_config = load("res://data/content/DefaultTreeBoundaryConfiguration.tres")
	if not tree_config:
		Logger.warn("Could not load DefaultTreeBoundaryConfiguration, creating new one", "plugin")
		# Create new TreeBoundaryConfiguration by loading the script directly
		var tree_config_script = load("res://scripts/resources/TreeBoundaryConfiguration.gd")
		if tree_config_script:
			tree_config = tree_config_script.new()
		else:
			Logger.error("Could not load TreeBoundaryConfiguration script", "plugin")
			return


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
		# arena_size parameter removed
		generator.path_config.path_width = corridor_width_input.value
		if chain_length_input:
			generator.path_config.chain_length = int(chain_length_input.value)
		if min_distance_input:
			generator.path_config.min_point_distance = min_distance_input.value
		# point_space_radius parameter removed
		# path_extension_width parameter removed
		# path_extension_width2 parameter removed

		# Dynamic branching settings
		if enable_branching_checkbox:
			generator.path_config.enable_dynamic_branching = enable_branching_checkbox.button_pressed
		if branch_probability_input:
			generator.path_config.branch_probability = branch_probability_input.value / 100.0  # Convert % to decimal
		if min_branches_per_point_input:
			generator.path_config.min_branches_per_point = int(min_branches_per_point_input.value)
		if max_branches_per_point_input:
			generator.path_config.max_branches_per_point = int(max_branches_per_point_input.value)
		if min_branch_length_input:
			generator.path_config.min_branch_length = min_branch_length_input.value
		if max_branch_length_input:
			generator.path_config.max_branch_length = max_branch_length_input.value
		# branch_curve_intensity parameter removed

	# Update tree configuration
	if generator.tree_config:
		generator.tree_config.tree_spacing = tree_spacing_input.value
		if tree_boundary_width_input:
			generator.tree_config.tree_boundary_width = tree_boundary_width_input.value
		if use_path_radius_checkbox:
			generator.tree_config.use_path_radius_generation = use_path_radius_checkbox.button_pressed

		# Tree randomization settings
		if placement_randomness_input:
			generator.tree_config.placement_randomness = placement_randomness_input.value
		if max_random_offset_input:
			generator.tree_config.max_random_offset = max_random_offset_input.value

		# Performance optimization settings
		if use_prebuilt_tree_field_checkbox:
			generator.tree_config.use_prebuilt_tree_field = use_prebuilt_tree_field_checkbox.button_pressed


	# Arena base radius parameter removed

	Logger.debug("Updated generator settings: seed=%d, points=%d, corridor=%.1f, spacing=%.1f, boundary_width=%.1f, chain=%d, min_dist=%.1f" % [
		generator.generation_seed,
		int(path_count_input.value),
		corridor_width_input.value,
		tree_spacing_input.value,
		tree_boundary_width_input.value,
		int(chain_length_input.value),
		min_distance_input.value
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
