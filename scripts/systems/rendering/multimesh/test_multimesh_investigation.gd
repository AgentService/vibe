extends Node

## Quick test script to run MultiMesh investigation steps
## Usage: Call from test scene or manually set investigation step

func _ready() -> void:
	# Check command line arguments for step number
	var args = OS.get_cmdline_args()
	var investigation_step = 0
	
	for i in range(args.size()):
		if args[i] == "--investigation-step" and i + 1 < args.size():
			investigation_step = args[i + 1].to_int()
			break
	
	if investigation_step > 0:
		print("=== MULTIMESH INVESTIGATION STEP %d ===" % investigation_step)
		configure_investigation_step(investigation_step)

func configure_investigation_step(step_number: int) -> void:
	# Find MultiMeshManager in the scene tree
	var multimesh_manager = find_multimesh_manager()
	if multimesh_manager == null:
		print("ERROR: MultiMeshManager not found in scene tree")
		return
	
	# Configure the investigation step
	multimesh_manager.set_investigation_step(step_number)
	print("✓ Investigation step %d configured" % step_number)
	
	# Print what this step does
	_print_step_description(step_number)

func find_multimesh_manager() -> Node:
	# Try autoload first
	var root = get_tree().get_root()
	var mm_autoload = root.get_node_or_null("/root/MultiMeshManager")
	if mm_autoload:
		return mm_autoload
	
	# Search in current scene tree
	return _find_node_recursive(get_tree().current_scene, "MultiMeshManager")

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if not node:
		return null
	
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, target_name)
		if result:
			return result
	
	return null

func _print_step_description(step_number: int) -> void:
	match step_number:
		1:
			print("Step 1: Per-instance colors disabled (already implemented)")
		2:
			print("Step 2: Early preallocation to avoid mid-phase buffer resizes")
		3:
			print("Step 3: 30Hz transform update frequency (vs 60Hz)")
		4:
			print("Step 4: Bypass grouping overhead - direct flat array updates")
		5:
			print("Step 5: Single MultiMesh for all enemies (collapse tiers)")
		6:
			print("Step 6: No textures, simple QuadMesh geometry only")
		7:
			print("Step 7: Position-only transforms (no rotation/scaling)")
		8:
			print("Step 8: Static transforms (render-only, no per-frame updates)")
		9:
			print("Step 9: Minimal baseline (all optimizations combined)")
		_:
			print("Unknown step: %d" % step_number)