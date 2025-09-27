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
var path_extension_width2_input: SpinBox
var boundary_distance_input: SpinBox
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
var boundary_thickness_input: SpinBox
var use_path_radius_checkbox: CheckBox
# Gradient density controls
var min_density_near_path_input: SpinBox
var max_density_near_path_input: SpinBox
var min_density_at_edges_input: SpinBox
var density_falloff_curve_input: SpinBox

# Random offset controls (zigzag effect)
var enable_staggered_placement_checkbox: CheckBox
var max_random_offset_input: SpinBox


# Generator reference
var path_generator: DungeonPathGenerator
var tree_generator: TreeBoundaryGenerator

# Configuration resources
var path_config: PathConfiguration
var tree_config: TreeBoundaryConfiguration

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
	scroll_container.add_child(vbox)
	
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
	path_count_input.value = 3  # From DefaultPathConfiguration.tres
	path_count_input.step = 1
	vbox.add_child(path_count_input)
	
	# Arena size control
	var arena_size_label = Label.new()
	arena_size_label.text = "Arena Size:"
	vbox.add_child(arena_size_label)

	arena_size_input = SpinBox.new()
	arena_size_input.min_value = 200
	arena_size_input.max_value = 6000
	arena_size_input.value = 500  # From DefaultPathConfiguration.tres
	arena_size_input.step = 50
	vbox.add_child(arena_size_input)

	# Corridor width control (unlimited)
	var corridor_width_label = Label.new()
	corridor_width_label.text = "Corridor Width:"
	vbox.add_child(corridor_width_label)

	corridor_width_input = SpinBox.new()
	corridor_width_input.min_value = 50
	corridor_width_input.max_value = 5000  # Unlimited
	corridor_width_input.value = 500  # Current plugin default
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
	tree_spacing_input.value = 88
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
	path_extension_width_input.value = 2  # Current plugin default
	path_extension_width_input.step = 1
	path_extension_width_input.suffix = "px"
	vbox.add_child(path_extension_width_input)

	# Second path extension width control
	var path_extension_width2_label = Label.new()
	path_extension_width2_label.text = "Dark Extension Width:"
	vbox.add_child(path_extension_width2_label)

	path_extension_width2_input = SpinBox.new()
	path_extension_width2_input.min_value = 0
	path_extension_width2_input.max_value = 1000  # Unlimited extension width
	path_extension_width2_input.value = 1  # Current plugin default
	path_extension_width2_input.step = 1
	path_extension_width2_input.suffix = "px"
	vbox.add_child(path_extension_width2_input)

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

	# Dynamic Branching Section
	var branching_title = Label.new()
	branching_title.text = "Dynamic Branching"
	branching_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(branching_title)

	# Enable branching checkbox
	enable_branching_checkbox = CheckBox.new()
	enable_branching_checkbox.text = "Enable Dynamic Branching"
	enable_branching_checkbox.button_pressed = true  # Default enabled
	vbox.add_child(enable_branching_checkbox)

	# Branch probability
	var branch_prob_label = Label.new()
	branch_prob_label.text = "Branch Probability (%):"
	vbox.add_child(branch_prob_label)

	branch_probability_input = SpinBox.new()
	branch_probability_input.min_value = 0
	branch_probability_input.max_value = 100
	branch_probability_input.value = 80  # 60% default
	branch_probability_input.step = 5
	branch_probability_input.suffix = "%"
	vbox.add_child(branch_probability_input)

	# Branches per point
	var branches_per_point_label = Label.new()
	branches_per_point_label.text = "Branches per Point (Min-Max):"
	vbox.add_child(branches_per_point_label)

	var branches_hbox = HBoxContainer.new()
	vbox.add_child(branches_hbox)

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

	# Branch length
	var branch_length_label = Label.new()
	branch_length_label.text = "Branch Length (Min-Max px):"
	vbox.add_child(branch_length_label)

	var length_hbox = HBoxContainer.new()
	vbox.add_child(length_hbox)

	min_branch_length_input = SpinBox.new()
	min_branch_length_input.min_value = 50
	min_branch_length_input.max_value = 5000
	min_branch_length_input.value = 2100
	min_branch_length_input.step = 25
	min_branch_length_input.suffix = "px"
	length_hbox.add_child(min_branch_length_input)

	var to_label2 = Label.new()
	to_label2.text = " to "
	length_hbox.add_child(to_label2)

	max_branch_length_input = SpinBox.new()
	max_branch_length_input.min_value = 200
	max_branch_length_input.max_value = 5000
	max_branch_length_input.value = 2500
	max_branch_length_input.step = 50
	max_branch_length_input.suffix = "px"
	length_hbox.add_child(max_branch_length_input)

	# Branch curve intensity
	var curve_label = Label.new()
	curve_label.text = "Branch Curve Intensity:"
	vbox.add_child(curve_label)

	branch_curve_intensity_input = SpinBox.new()
	branch_curve_intensity_input.min_value = 0.0
	branch_curve_intensity_input.max_value = 100.0
	branch_curve_intensity_input.value = 0.3
	branch_curve_intensity_input.step = 0.1
	vbox.add_child(branch_curve_intensity_input)

	# Another separator
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)

	# Tree Boundary Section
	var boundary_title = Label.new()
	boundary_title.text = "Tree Boundaries"
	boundary_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(boundary_title)

	# Boundary thickness control
	var boundary_thickness_label = Label.new()
	boundary_thickness_label.text = "Boundary Thickness (px):"
	boundary_thickness_label.tooltip_text = "Controls how much outer tree space is generated around paths"
	vbox.add_child(boundary_thickness_label)

	boundary_thickness_input = SpinBox.new()
	boundary_thickness_input.min_value = -5000
	boundary_thickness_input.max_value = 2000
	boundary_thickness_input.value = 775  # Default value
	boundary_thickness_input.step = 25
	boundary_thickness_input.suffix = "px"
	vbox.add_child(boundary_thickness_input)

	# Path-radius generation checkbox
	use_path_radius_checkbox = CheckBox.new()
	use_path_radius_checkbox.text = "Use Path-Radius Generation (Efficient)"
	use_path_radius_checkbox.button_pressed = true  # Default to new efficient method
	use_path_radius_checkbox.tooltip_text = "Generate trees only around actual paths (eliminates massive unused forest areas)"
	vbox.add_child(use_path_radius_checkbox)

	# Gradient density controls
	var density_title = Label.new()
	density_title.text = "Gradient Density"
	density_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(density_title)

	# Min density near path (baseline)
	var min_density_near_label = Label.new()
	min_density_near_label.text = "Min Density Near Path:"
	min_density_near_label.tooltip_text = "Baseline density near paths (always maintained, 0.01 = sparse baseline)"
	vbox.add_child(min_density_near_label)

	min_density_near_path_input = SpinBox.new()
	min_density_near_path_input.min_value = 0.01
	min_density_near_path_input.max_value = 1.0
	min_density_near_path_input.value = 0.01
	min_density_near_path_input.step = 0.01
	vbox.add_child(min_density_near_path_input)

	# Max density near path
	var max_density_label = Label.new()
	max_density_label.text = "Max Density Near Path:"
	max_density_label.tooltip_text = "Peak density closest to paths (1.0 = full density)"
	vbox.add_child(max_density_label)

	max_density_near_path_input = SpinBox.new()
	max_density_near_path_input.min_value = 0.05
	max_density_near_path_input.max_value = 1.0
	max_density_near_path_input.value = 0.05
	max_density_near_path_input.step = 0.05
	vbox.add_child(max_density_near_path_input)

	# Min density at edges
	var min_density_label = Label.new()
	min_density_label.text = "Min Density at Edges:"
	min_density_label.tooltip_text = "Density at boundary edges (0.1 = sparse, 0.5 = moderate)"
	vbox.add_child(min_density_label)

	min_density_at_edges_input = SpinBox.new()
	min_density_at_edges_input.min_value = 0.05
	min_density_at_edges_input.max_value = 500
	min_density_at_edges_input.value = 1
	min_density_at_edges_input.step = 0.05
	vbox.add_child(min_density_at_edges_input)

	# Density falloff curve
	var falloff_curve_label = Label.new()
	falloff_curve_label.text = "Density Falloff Curve:"
	falloff_curve_label.tooltip_text = "Gradient steepness (1.0 = linear, 2.0 = steep, 0.5 = gentle)"
	vbox.add_child(falloff_curve_label)

	density_falloff_curve_input = SpinBox.new()
	density_falloff_curve_input.min_value = -50.0
	density_falloff_curve_input.max_value = 55.0
	density_falloff_curve_input.value = 0.1
	density_falloff_curve_input.step = 0.001
	vbox.add_child(density_falloff_curve_input)

	# Random offset controls (Natural Placement)
	var offset_section_label = Label.new()
	offset_section_label.text = "🎲 Natural Placement"
	offset_section_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(offset_section_label)

	# Enable zigzag placement
	enable_staggered_placement_checkbox = CheckBox.new()
	enable_staggered_placement_checkbox.text = "Enable Zigzag Tree Placement"
	enable_staggered_placement_checkbox.button_pressed = true
	enable_staggered_placement_checkbox.tooltip_text = "Adds random offset to eliminate grid patterns for natural appearance"
	vbox.add_child(enable_staggered_placement_checkbox)

	# Random offset amount
	var offset_label = Label.new()
	offset_label.text = "Random Offset Amount (px):"
	offset_label.tooltip_text = "Maximum random displacement in pixels for natural zigzag effect"
	vbox.add_child(offset_label)

	max_random_offset_input = SpinBox.new()
	max_random_offset_input.min_value = -550.0
	max_random_offset_input.max_value = 732.0
	max_random_offset_input.value = 54.0
	max_random_offset_input.step = 1.0
	vbox.add_child(max_random_offset_input)

	# Final separator
	var separator4 = HSeparator.new()
	vbox.add_child(separator4)

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
		if path_extension_width2_input:
			generator.path_config.path_extension_width2 = path_extension_width2_input.value

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
		if branch_curve_intensity_input:
			generator.path_config.branch_curve_intensity = branch_curve_intensity_input.value

	# Update tree configuration
	if generator.tree_config:
		generator.tree_config.tree_spacing = tree_spacing_input.value
		if boundary_distance_input:
			generator.tree_config.boundary_distance = boundary_distance_input.value
		if boundary_thickness_input:
			generator.tree_config.boundary_thickness = boundary_thickness_input.value
		if use_path_radius_checkbox:
			generator.tree_config.use_path_radius_generation = use_path_radius_checkbox.button_pressed
		# Update gradient density parameters
		if min_density_near_path_input:
			generator.tree_config.min_density_near_path = min_density_near_path_input.value
		if max_density_near_path_input:
			generator.tree_config.max_density_near_path = max_density_near_path_input.value
		if min_density_at_edges_input:
			generator.tree_config.min_density_at_edges = min_density_at_edges_input.value
		if density_falloff_curve_input:
			generator.tree_config.density_falloff_curve = density_falloff_curve_input.value
		# Update random offset controls
		if enable_staggered_placement_checkbox:
			generator.tree_config.enable_staggered_placement = enable_staggered_placement_checkbox.button_pressed
		if max_random_offset_input:
			generator.tree_config.max_random_offset = max_random_offset_input.value

	# Update arena base radius
	generator.arena_base_radius = arena_base_radius_input.value

	Logger.debug("Updated generator settings: seed=%d, points=%d, size=%.1f, corridor=%.1f, spacing=%.1f, base_radius=%.1f, chain=%d, min_dist=%.1f, point_radius=%.1f, ext1=%.1f, ext2=%.1f, boundary=%.1f" % [
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
		path_extension_width2_input.value if path_extension_width2_input else 48.0,
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
