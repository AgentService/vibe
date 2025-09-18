extends SceneTree

func _initialize():
	print("=== Available Breach Passive IDs ===")
	print("Copy these IDs into the 'Passive Id' field in the Inspector for each SkillNode")
	print()

	# Wait a frame for autoloads to initialize
	await process_frame

	if not EventMasterySystem or not EventMasterySystem.mastery_system_instance:
		print("ERROR: EventMasterySystem not available")
		quit()
		return

	var mastery_system = EventMasterySystem.mastery_system_instance

	# List all breach passives with their details
	print("Available Breach Passive IDs:")
	print("=" * 50)

	var breach_passives = []
	for passive_id in mastery_system.passive_definitions:
		var passive_def = mastery_system.passive_definitions[passive_id]
		if passive_def.event_type == "breach":
			breach_passives.append({
				"id": passive_id,
				"name": passive_def.get("name", "Unknown"),
				"description": passive_def.get("description", "No description"),
				"max_level": passive_def.get("max_level", 3),
				"cost_per_level": passive_def.get("cost_per_level", [1])
			})

	# Sort by ID for consistency
	breach_passives.sort_custom(func(a, b): return a.id < b.id)

	var counter = 1
	for passive in breach_passives:
		print("%d. ID: \"%s\"" % [counter, passive.id])
		print("   Name: %s" % passive.name)
		print("   Max Level: %d" % passive.max_level)
		print("   Cost: %s" % str(passive.cost_per_level))
		print("   Description: %s" % passive.description)
		print()
		counter += 1

	print("=" * 50)
	print("INSTRUCTIONS:")
	print("1. Open EventSkillTree.tscn in the editor")
	print("2. Select each SkillButton node (B1, B2, etc.)")
	print("3. In the Inspector, find the 'Passive Id' field")
	print("4. Enter one of the IDs above (copy exactly)")
	print("5. Save the scene")
	print("6. Each node will then be mapped to that specific passive")
	print()
	print("Example mapping suggestions for current tree:")
	print("- Root nodes: breach_density, breach_mastery, breach_capacity")
	print("- Mid-tier: breach_duration, breach_rewards, breach_catalyst")
	print("- High-tier: breach_chaos, breach_stability, breach_overlord")

	quit()