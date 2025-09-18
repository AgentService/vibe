extends SceneTree

func _initialize():
	print("=== Current Skill Tree Node Names ===")
	print("This shows the current node names in your EventSkillTree.tscn")
	print()

	# Load the EventSkillTree scene to inspect its structure
	var skill_tree_scene = load("res://scenes/ui/skill_tree/EventSkillTree.tscn")
	if not skill_tree_scene:
		print("ERROR: Could not load EventSkillTree.tscn")
		quit()
		return

	var instance = skill_tree_scene.instantiate()
	add_child(instance)

	print("Found SkillButton nodes:")
	print("=" * 50)

	_print_skill_nodes_recursive(instance, 0)

	print()
	print("=" * 50)
	print("NEXT STEPS:")
	print("1. Note the node names above (B1, B2, etc.)")
	print("2. Run list_passive_ids.gd to see available passive IDs")
	print("3. Open EventSkillTree.tscn in editor")
	print("4. For each node, set the 'Passive Id' field in Inspector")
	print("5. Save and test!")

	quit()

func _print_skill_nodes_recursive(node: Node, depth: int):
	var indent = "  ".repeat(depth)

	if node.get_script() and node.get_script().get_global_name() == "SkillNode":
		var passive_id = ""
		if node.has_method("get") and "passive_id" in node:
			passive_id = str(node.passive_id)

		if passive_id == "":
			passive_id = "(not assigned)"

		print("%s- %s (passive_id: %s)" % [indent, node.name, passive_id])

	for child in node.get_children():
		_print_skill_nodes_recursive(child, depth + 1)