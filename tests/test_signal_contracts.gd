extends RefCounted

## Test script to verify EventBus signal contracts.
## Validates signal emissions match the documented Signals Matrix.

class_name TestSignalContracts

static func run_test() -> void:
	print("=== Signal Contracts Validation Test ===")
	
	# Check if EventBus is available (only in full project context)
	if not is_instance_valid(EventBus):
		print("⚠️  SKIP: Signal contracts test requires full project context with autoloads")
		print("   Run via: godot --headless tests/run_tests.tscn")
		return
	
	# Create a signal tracker to monitor EventBus
	var tracker := SignalTracker.new()
	tracker.connect_to_eventbus()
	
	# Run minimal game simulation for signal generation
	print("\nRunning minimal game simulation...")
	_run_minimal_simulation(tracker)
	
	# Validate tracked signals
	print("\nValidating signal contracts...")
	var validation_passed := tracker.validate_signals()
	
	if validation_passed:
		print("✓ SUCCESS: All signal contracts validated")
	else:
		print("✗ FAILURE: Signal contract violations detected")
	
	tracker.disconnect_from_eventbus()

static func _run_minimal_simulation(tracker: SignalTracker) -> void:
	# Create minimal systems for signal generation
	var run_manager: Node = load("res://autoload/RunManager.gd").new()
	# TODO: Phase 2 - Replace with AbilityModule autoload testing
	# var ability_system: Node = load("res://scripts/systems/AbilitySystem.gd").new()
	var wave_director: Node = load("res://scripts/systems/WaveDirector.gd").new()
	var damage_system: Node = load("res://scripts/systems/DamageSystem.gd").new()
	var player_state: Node = load("res://autoload/PlayerState.gd").new()
	
	# Set up basic dependencies (AbilitySystem removed in Phase 1)
	damage_system.set_references(wave_director)
	player_state.position = Vector2(400, 300)
	
	# Simulate a few combat steps
	for i in range(10):
		# Emit combat step signal
		var combat_payload: CombatStepPayload = CombatStepPayload.new(1.0 / 30.0)
		EventBus.combat_step.emit(combat_payload)
		
		# Simulate some damage using DamageService directly (single entry point)
		if i % 3 == 0:
			var target_id = "enemy_0"
			var damage_amount = 10.0
			var source_name = "projectile_0"
			var damage_tags = ["projectile"]
			DamageService.apply_damage(target_id, damage_amount, source_name, damage_tags)
		
		# Simulate XP gain
		if i % 5 == 0:
			var xp_payload: XpChangedPayload = XpChangedPayload.new(i * 10, (i + 1) * 100)
			EventBus.xp_changed.emit(xp_payload)
	
	# Simulate a level up
	var level_payload: LevelUpPayload = LevelUpPayload.new(2)
	EventBus.level_up.emit(level_payload)
	
	# Simulate pause state change
	var pause_payload: GamePausedChangedPayload = GamePausedChangedPayload.new(true)
	EventBus.game_paused_changed.emit(pause_payload)
	pause_payload = GamePausedChangedPayload.new(false)
	EventBus.game_paused_changed.emit(pause_payload)
	
	# Simulate additional signals for comprehensive coverage
	var arena_bounds_payload: ArenaBoundsChangedPayload = ArenaBoundsChangedPayload.new(Rect2(0, 0, 800, 600))
	EventBus.arena_bounds_changed.emit(arena_bounds_payload)
	
	var player_pos_payload: PlayerPositionChangedPayload = PlayerPositionChangedPayload.new(Vector2(400, 300))
	EventBus.player_position_changed.emit(player_pos_payload)
	
	var damage_dealt_payload: DamageDealtPayload = DamageDealtPayload.new(25.0, "player", "enemy")
	EventBus.damage_dealt.emit(damage_dealt_payload)
	
	var interaction_payload: InteractionPromptChangedPayload = InteractionPromptChangedPayload.new("chest_001", "chest", true)
	EventBus.interaction_prompt_changed.emit(interaction_payload)
	
	var loot_payload: LootGeneratedPayload = LootGeneratedPayload.new("chest_001", "chest", {"items": ["sword", "potion"]})
	EventBus.loot_generated.emit(loot_payload)
	
	# Test some edge cases
	var entity_killed_payload: EntityKilledPayload = EntityKilledPayload.new(EntityId.enemy(0), Vector2(200, 150), {"xp": 10, "gold": 5})
	EventBus.entity_killed.emit(entity_killed_payload)
	
	var damage_applied_payload: DamageAppliedPayload = DamageAppliedPayload.new(EntityId.enemy(0), 15.0, true, PackedStringArray(["fire", "crit"]))
	EventBus.damage_applied.emit(damage_applied_payload)

class SignalTracker:
	var signal_counts := {}
	var signal_args := {}
	var validation_errors := []
	
	func connect_to_eventbus() -> void:
		# Connect to all documented signals
		EventBus.combat_step.connect(_on_combat_step)
		EventBus.damage_applied.connect(_on_damage_applied)
		EventBus.damage_batch_applied.connect(_on_damage_batch_applied)
		EventBus.entity_killed.connect(_on_entity_killed)
		EventBus.enemy_killed.connect(_on_enemy_killed)
		EventBus.xp_changed.connect(_on_xp_changed)
		EventBus.level_up.connect(_on_level_up)
		EventBus.game_paused_changed.connect(_on_game_paused_changed)
		EventBus.arena_bounds_changed.connect(_on_arena_bounds_changed)
		EventBus.player_position_changed.connect(_on_player_position_changed)
		EventBus.damage_dealt.connect(_on_damage_dealt)
		EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
		EventBus.loot_generated.connect(_on_loot_generated)
	
	func disconnect_from_eventbus() -> void:
		EventBus.combat_step.disconnect(_on_combat_step)
		EventBus.damage_applied.disconnect(_on_damage_applied)
		EventBus.damage_batch_applied.disconnect(_on_damage_batch_applied)
		EventBus.entity_killed.disconnect(_on_entity_killed)
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
		EventBus.xp_changed.disconnect(_on_xp_changed)
		EventBus.level_up.disconnect(_on_level_up)
		EventBus.game_paused_changed.disconnect(_on_game_paused_changed)
		EventBus.arena_bounds_changed.disconnect(_on_arena_bounds_changed)
		EventBus.player_position_changed.disconnect(_on_player_position_changed)
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
		EventBus.interaction_prompt_changed.disconnect(_on_interaction_prompt_changed)
		EventBus.loot_generated.disconnect(_on_loot_generated)
	
	func _track_signal(signal_name: String, args: Array) -> void:
		if not signal_counts.has(signal_name):
			signal_counts[signal_name] = 0
			signal_args[signal_name] = []
		
		signal_counts[signal_name] += 1
		signal_args[signal_name].append(args)
	
	func _on_combat_step(payload) -> void:
		_track_signal("combat_step", [payload])
		_validate_arg_type("combat_step", 0, payload, TYPE_OBJECT)
		_validate_arg_type("combat_step_dt", 0, payload.dt, TYPE_FLOAT)
	
	func _on_damage_applied(payload) -> void:
		_track_signal("damage_applied", [payload])
		_validate_arg_type("damage_applied", 0, payload, TYPE_OBJECT)
		_validate_arg_type("damage_applied_target", 0, payload.target_id, TYPE_OBJECT)
		_validate_arg_type("damage_applied_damage", 0, payload.final_damage, TYPE_FLOAT)
		_validate_arg_type("damage_applied_crit", 0, payload.is_crit, TYPE_BOOL)
		_validate_arg_type("damage_applied_tags", 0, payload.tags, TYPE_PACKED_STRING_ARRAY)
	
	func _on_damage_batch_applied(payload) -> void:
		_track_signal("damage_batch_applied", [payload])
		_validate_arg_type("damage_batch_applied", 0, payload, TYPE_OBJECT)
		_validate_arg_type("damage_batch_instances", 0, payload.damage_instances, TYPE_ARRAY)
	
	func _on_entity_killed(payload) -> void:
		_track_signal("entity_killed", [payload])
		_validate_arg_type("entity_killed", 0, payload, TYPE_OBJECT)
		_validate_arg_type("entity_killed_id", 0, payload.entity_id, TYPE_OBJECT)
		_validate_arg_type("entity_killed_pos", 0, payload.death_pos, TYPE_VECTOR2)
		_validate_arg_type("entity_killed_rewards", 0, payload.rewards, TYPE_DICTIONARY)
	
	func _on_enemy_killed(pos: Vector2, xp_value: int) -> void:
		_track_signal("enemy_killed", [pos, xp_value])
		_validate_arg_type("enemy_killed_pos", 0, pos, TYPE_VECTOR2)
		_validate_arg_type("enemy_killed_xp", 1, xp_value, TYPE_INT)
	
	func _on_xp_changed(payload) -> void:
		_track_signal("xp_changed", [payload])
		_validate_arg_type("xp_changed", 0, payload, TYPE_OBJECT)
		_validate_arg_type("xp_changed_current", 0, payload.current_xp, TYPE_INT)
		_validate_arg_type("xp_changed_next", 0, payload.next_level_xp, TYPE_INT)
	
	func _on_level_up(payload) -> void:
		_track_signal("level_up", [payload])
		_validate_arg_type("level_up", 0, payload, TYPE_OBJECT)
		_validate_arg_type("level_up_level", 0, payload.new_level, TYPE_INT)
	
	func _on_game_paused_changed(payload) -> void:
		_track_signal("game_paused_changed", [payload])
		_validate_arg_type("game_paused_changed", 0, payload, TYPE_OBJECT)
		_validate_arg_type("game_paused_value", 0, payload.is_paused, TYPE_BOOL)
	
	func _on_arena_bounds_changed(payload) -> void:
		_track_signal("arena_bounds_changed", [payload])
		_validate_arg_type("arena_bounds_changed", 0, payload, TYPE_OBJECT)
		_validate_arg_type("arena_bounds_rect", 0, payload.bounds, TYPE_RECT2)
	
	func _on_player_position_changed(payload) -> void:
		_track_signal("player_position_changed", [payload])
		_validate_arg_type("player_position_changed", 0, payload, TYPE_OBJECT)
		_validate_arg_type("player_position_pos", 0, payload.position, TYPE_VECTOR2)
	
	func _on_damage_dealt(payload) -> void:
		_track_signal("damage_dealt", [payload])
		_validate_arg_type("damage_dealt", 0, payload, TYPE_OBJECT)
		_validate_arg_type("damage_dealt_damage", 0, payload.damage, TYPE_FLOAT)
		_validate_arg_type("damage_dealt_source", 0, payload.source, TYPE_STRING)
		_validate_arg_type("damage_dealt_target", 0, payload.target, TYPE_STRING)
	
	func _on_interaction_prompt_changed(payload) -> void:
		_track_signal("interaction_prompt_changed", [payload])
		_validate_arg_type("interaction_prompt_changed", 0, payload, TYPE_OBJECT)
		_validate_arg_type("interaction_prompt_id", 0, payload.object_id, TYPE_STRING)
		_validate_arg_type("interaction_prompt_type", 0, payload.object_type, TYPE_STRING)
		_validate_arg_type("interaction_prompt_show", 0, payload.show, TYPE_BOOL)
	
	func _on_loot_generated(payload) -> void:
		_track_signal("loot_generated", [payload])
		_validate_arg_type("loot_generated", 0, payload, TYPE_OBJECT)
		_validate_arg_type("loot_generated_source", 0, payload.source_id, TYPE_STRING)
		_validate_arg_type("loot_generated_type", 0, payload.source_type, TYPE_STRING)
		_validate_arg_type("loot_generated_data", 0, payload.loot_data, TYPE_DICTIONARY)
	
	func _validate_arg_type(signal_name: String, arg_index: int, value: Variant, expected_type: Variant.Type) -> void:
		var actual_type := typeof(value)
		if actual_type != expected_type:
			validation_errors.append("Signal '%s' arg[%d] expected %s, got %s" % [
				signal_name, arg_index, _type_to_string(expected_type), _type_to_string(actual_type)
			])
	
	func _type_to_string(type: Variant.Type) -> String:
		match type:
			TYPE_NIL: return "NIL"
			TYPE_BOOL: return "bool"
			TYPE_INT: return "int"
			TYPE_FLOAT: return "float"
			TYPE_STRING: return "String"
			TYPE_VECTOR2: return "Vector2"
			TYPE_VECTOR2I: return "Vector2i"
			TYPE_RECT2: return "Rect2"
			TYPE_RECT2I: return "Rect2i"
			TYPE_VECTOR3: return "Vector3"
			TYPE_VECTOR3I: return "Vector3i"
			TYPE_TRANSFORM2D: return "Transform2D"
			TYPE_VECTOR4: return "Vector4"
			TYPE_VECTOR4I: return "Vector4i"
			TYPE_PLANE: return "Plane"
			TYPE_QUATERNION: return "Quaternion"
			TYPE_AABB: return "AABB"
			TYPE_BASIS: return "Basis"
			TYPE_TRANSFORM3D: return "Transform3D"
			TYPE_PROJECTION: return "Projection"
			TYPE_COLOR: return "Color"
			TYPE_STRING_NAME: return "StringName"
			TYPE_NODE_PATH: return "NodePath"
			TYPE_RID: return "RID"
			TYPE_OBJECT: return "Object"
			TYPE_CALLABLE: return "Callable"
			TYPE_SIGNAL: return "Signal"
			TYPE_DICTIONARY: return "Dictionary"
			TYPE_ARRAY: return "Array"
			TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
			TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
			TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
			TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
			TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
			TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
			TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
			TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
			TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
			_: return "Unknown"
	
	func validate_signals() -> bool:
		print("\nSignal emission summary:")
		for signal_name in signal_counts:
			print("  %s: %d emissions" % [signal_name, signal_counts[signal_name]])
		
		# Check for validation errors
		if validation_errors.size() > 0:
			print("\nValidation errors:")
			for error in validation_errors:
				print("  ✗ " + error)
			return false
		
		# Validate expected signals were emitted
		var required_signals := [
			"combat_step", "damage_applied", "entity_killed", 
			"xp_changed", "level_up", "game_paused_changed", "arena_bounds_changed",
			"player_position_changed", "damage_dealt", "interaction_prompt_changed", 
			"loot_generated"
		]
		for required in required_signals:
			if not signal_counts.has(required) or signal_counts[required] == 0:
				print("  ✗ Required signal '%s' was not emitted" % required)
				return false
		
		# Validate payload structure for some key signals
		if not _validate_payload_structures():
			return false
		
		print("\n  ✓ All signal types validated")
		print("  ✓ All argument types correct")
		print("  ✓ All required signals emitted")
		print("  ✓ All payload structures valid")
		
		return true
	
	func _validate_payload_structures() -> bool:
		# Check specific payload structures by examining first emission of each signal
		var tests_passed := true
		
		# Test CombatStepPayload structure
		if signal_args.has("combat_step") and signal_args["combat_step"].size() > 0:
			var combat_payload = signal_args["combat_step"][0][0]
			if not _has_property(combat_payload, "dt"):
				print("  ✗ CombatStepPayload missing 'dt' property")
				tests_passed = false
		
		
		# Test XpChangedPayload structure
		if signal_args.has("xp_changed") and signal_args["xp_changed"].size() > 0:
			var xp_payload = signal_args["xp_changed"][0][0]
			for prop in ["current_xp", "next_level_xp"]:
				if not _has_property(xp_payload, prop):
					print("  ✗ XpChangedPayload missing '%s' property" % prop)
					tests_passed = false
		
		# Test LevelUpPayload structure
		if signal_args.has("level_up") and signal_args["level_up"].size() > 0:
			var level_payload = signal_args["level_up"][0][0]
			if not _has_property(level_payload, "new_level"):
				print("  ✗ LevelUpPayload missing 'new_level' property")
				tests_passed = false
		
		return tests_passed
	
	func _has_property(object: Object, property_name: String) -> bool:
		# Safe property checking for payload objects
		if object == null:
			return false
		var property_list = object.get_property_list()
		for property in property_list:
			if property.name == property_name:
				return true
		return false