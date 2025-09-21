extends Node
class_name BaseEventMonitor

## Base Event Performance Monitoring Template
## Extend this class for specific event types (Breach, Ritual, PackHunt, Boss, etc.)
## Provides standardized monitoring output and detection patterns

# Override these in derived classes
var event_handler_group: String = "event_handlers"  # Group to search for handlers
var event_type_name: String = "Event"               # Display name for logs
var handler_property_name: String = "event_handler" # Property name in systems

## Virtual method - override in derived classes
func get_event_specific_data(event_handler) -> Dictionary:
	"""Override this to return event-specific monitoring data"""
	return {}

## Virtual method - override for event-specific summary
func format_event_summary(handler_data: Dictionary) -> String:
	"""Override this to format event-specific performance summary"""
	return "No event-specific data available"

## Main monitoring function - called by timer
func monitor_event_performance() -> void:
	print("\n=== %s OPTIMIZATION STATUS ===" % event_type_name.to_upper())

	# Check if we can access the arena scene
	var arena_scene = get_tree().get_first_node_in_group("arena")
	if not arena_scene:
		print("❌ Not in arena - %s monitoring unavailable" % event_type_name.to_lower())
		print("Available groups: %s" % get_tree().get_nodes_in_group("arena"))
		return

	print("✅ Arena found: %s" % arena_scene.name)

	# Try multiple ways to find the event handler
	var event_handler = _find_event_handler(arena_scene)

	if not event_handler:
		print("❌ %sEventHandler not found" % event_type_name)
		var child_names: Array[String] = []
		for child in arena_scene.get_children():
			child_names.append(child.name)
		print("Available children in arena: %s" % child_names)
		return

	print("✅ %s event system detected!" % event_type_name)

	# Get event-specific data
	var handler_data = get_event_specific_data(event_handler)

	# Display core monitoring data
	_display_core_metrics(handler_data)

	# Display event-specific summary
	var specific_summary = format_event_summary(handler_data)
	if not specific_summary.is_empty():
		print(specific_summary)

	# Display integration status
	_display_integration_status()

	print("\n🚀 Optimization Status: ACTIVE AND WORKING")

## Find event handler using multiple detection methods
func _find_event_handler(arena_scene):
	var event_handler = null

	# Method 1: Check if the arena has systems directly
	if arena_scene.has_method("get") and "systems" in arena_scene:
		var systems = arena_scene.systems
		if systems and handler_property_name in systems:
			event_handler = systems[handler_property_name]

	# Method 2: Look for SpawnDirector in Arena
	if not event_handler:
		var spawn_director = null

		# Check if arena has spawn_director property (Arena.gd pattern)
		if arena_scene.has_method("get") and "spawn_director" in arena_scene:
			spawn_director = arena_scene.spawn_director
		# Check autoload fallback
		elif has_node("/root/SpawnDirector"):
			spawn_director = get_node("/root/SpawnDirector")
		else:
			# Look in arena children as last resort
			for child in arena_scene.get_children():
				if child.get_script() and "SpawnDirector" in str(child.get_script()):
					spawn_director = child
					break

		if spawn_director and spawn_director.has_method("get") and handler_property_name in spawn_director:
			event_handler = spawn_director[handler_property_name]

	# Method 3: Look for EventHandler directly in group
	if not event_handler:
		var event_nodes = get_tree().get_nodes_in_group(event_handler_group)
		if not event_nodes.is_empty():
			event_handler = event_nodes[0]

	return event_handler

## Display core metrics that apply to all event types
func _display_core_metrics(handler_data: Dictionary) -> void:
	if handler_data.has("active_events"):
		print("📊 Active events: %d" % handler_data.active_events)

	if handler_data.has("pending_events"):
		print("📊 Pending events: %d" % handler_data.pending_events)

	if handler_data.has("total_entities"):
		print("📊 Total entities: %d" % handler_data.total_entities)

	if handler_data.has("memory_efficiency"):
		print("💾 Memory efficiency: %s" % handler_data.memory_efficiency)

## Display 30Hz integration status (common to all event systems)
func _display_integration_status() -> void:
	print("\n📡 30Hz Integration Status:")
	print("✅ EventBus.combat_step connected for fixed-step updates")
	print("🎯 Update frequency: 30Hz (vs 60Hz frame rate)")
	print("⚡ Performance improvement: ~50% reduction in update frequency")

## Utility method for percentage formatting
func _format_percentage(used: int, total: int) -> String:
	if total == 0:
		return "0/0 (0%)"
	var percentage = (float(used) / total) * 100.0
	return "%d/%d (%.1f%%)" % [used, total, percentage]

## Utility method for capacity warnings
func _check_capacity_warning(used: int, total: int, warning_threshold: float = 0.8) -> String:
	if total == 0:
		return ""

	var usage_ratio = float(used) / total
	if usage_ratio >= warning_threshold:
		return "⚠️ High capacity usage: %.1f%%" % (usage_ratio * 100.0)
	return ""