@tool
extends Control

var generate_button: Button
var seed_input: SpinBox
var arena_size_x: SpinBox
var arena_size_y: SpinBox
var tree_spacing_min_input: SpinBox
var tree_spacing_max_input: SpinBox
var tree_chance_input: SpinBox

func _init():
	name = "Forest Generator"
	set_custom_minimum_size(Vector2(200, 300))

	# Create UI
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Forest Arena Generator"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Seed control
	var seed_label = Label.new()
	seed_label.text = "Generation Seed:"
	vbox.add_child(seed_label)

	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 999999
	seed_input.value = 12345
	vbox.add_child(seed_input)

	# Arena size controls
	var size_label = Label.new()
	size_label.text = "Arena Size:"
	vbox.add_child(size_label)

	var size_hbox = HBoxContainer.new()
	vbox.add_child(size_hbox)

	arena_size_x = SpinBox.new()
	arena_size_x.min_value = 10
	arena_size_x.max_value = 100
	arena_size_x.value = 40
	size_hbox.add_child(arena_size_x)

	var x_label = Label.new()
	x_label.text = " x "
	size_hbox.add_child(x_label)

	arena_size_y = SpinBox.new()
	arena_size_y.min_value = 10
	arena_size_y.max_value = 100
	arena_size_y.value = 30
	size_hbox.add_child(arena_size_y)

	# Tree spacing controls
	var spacing_label = Label.new()
	spacing_label.text = "Tree Spacing (Min - Max):"
	vbox.add_child(spacing_label)

	var spacing_hbox = HBoxContainer.new()
	vbox.add_child(spacing_hbox)

	tree_spacing_min_input = SpinBox.new()
	tree_spacing_min_input.min_value = 1
	tree_spacing_min_input.max_value = 10
	tree_spacing_min_input.value = 2
	spacing_hbox.add_child(tree_spacing_min_input)

	var dash_label = Label.new()
	dash_label.text = " - "
	spacing_hbox.add_child(dash_label)

	tree_spacing_max_input = SpinBox.new()
	tree_spacing_max_input.min_value = 1
	tree_spacing_max_input.max_value = 10
	tree_spacing_max_input.value = 5
	spacing_hbox.add_child(tree_spacing_max_input)

	# Tree placement chance
	var chance_label = Label.new()
	chance_label.text = "Tree Placement (0.0-1.0):"
	vbox.add_child(chance_label)

	tree_chance_input = SpinBox.new()
	tree_chance_input.min_value = 0.0
	tree_chance_input.max_value = 1.0
	tree_chance_input.step = 0.1
	tree_chance_input.value = 0.6
	vbox.add_child(tree_chance_input)

	vbox.add_child(HSeparator.new())

	# Generate button
	generate_button = Button.new()
	generate_button.text = "Generate Forest Arena"
	generate_button.pressed.connect(_on_generate_pressed)
	vbox.add_child(generate_button)

	# Note about auto-seeding
	var auto_seed_label = Label.new()
	auto_seed_label.text = "Note: Seed auto-increments each generation"
	auto_seed_label.add_theme_font_size_override("font_size", 9)
	auto_seed_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(auto_seed_label)

	# Info label
	var info_label = Label.new()
	info_label.text = "Select ForestArena scene in editor, then click Generate."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(info_label)

func _on_generate_pressed():
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()

	# Look for ForestArenaGenerator in the current scene
	var current_scene = EditorInterface.get_edited_scene_root()
	if not current_scene:
		push_error("No scene is currently open")
		return


	var generator = _find_forest_generator(current_scene)
	if not generator:
		push_error("No ForestArenaGenerator found in current scene. Please open ForestArena.tscn")
		return

	# Update generator settings
	generator.generation_seed = int(seed_input.value)
	generator.arena_size = Vector2i(int(arena_size_x.value), int(arena_size_y.value))
	generator.tree_spacing_min = int(tree_spacing_min_input.value)
	generator.tree_spacing_max = int(tree_spacing_max_input.value)
	generator.tree_placement_chance = tree_chance_input.value

	# Generate!
	print("🌲 Generating forest arena with seed: ", generator.generation_seed)
	generator.generate_arena()

	# Mark scene as modified so user can save
	EditorInterface.mark_scene_as_unsaved()

# Removed random seed function - auto-incrementing now

func _find_forest_generator(node: Node) -> Node:
	"""Recursively find ForestArenaGenerator in the scene tree"""
	# Check if this node has the generate_arena method (our script)
	if node.has_method("generate_arena"):
		var script = node.get_script()
		if script:
			# Check if it's the ForestArenaGenerator script
			var script_path = str(script.resource_path)
			if "ForestArenaGenerator" in script_path:
				return node

	# Search children
	for child in node.get_children():
		var result = _find_forest_generator(child)
		if result:
			return result

	return null