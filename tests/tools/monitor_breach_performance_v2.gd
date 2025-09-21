extends "res://tests/tools/monitor_event_performance_base.gd"
class_name BreachEventMonitor

## Breach Event Performance Monitor
## Specialized monitoring for Breach events using the base event monitoring template

func _init():
	event_handler_group = "breach_handlers"
	event_type_name = "Breach"
	handler_property_name = "breach_handler"

## Get breach-specific monitoring data
func get_event_specific_data(breach_handler) -> Dictionary:
	var data = {}

	# Monitor active breaches
	data["active_events"] = breach_handler.get_active_breach_count()
	data["pending_events"] = breach_handler.get_pending_breach_count()

	# Monitor RingBuffer trackers
	if breach_handler.has_method("get") and "breach_trackers" in breach_handler:
		var trackers = breach_handler.breach_trackers

		if trackers.size() == 0:
			data["trackers_count"] = 0
			data["total_entities"] = 0
			data["total_capacity"] = 0
			data["total_rejections"] = 0
		else:
			data["trackers_count"] = trackers.size()

			var total_enemies = 0
			var total_capacity = 0
			var total_rejections = 0
			var tracker_details = []

			for breach_id in trackers:
				var tracker = trackers[breach_id]
				var debug_info = tracker.get_debug_info()

				total_enemies += debug_info.active_count
				total_capacity += debug_info.capacity
				total_rejections += debug_info.add_rejections

				tracker_details.append({
					"id_suffix": breach_id.substr(-8),  # Last 8 chars of ID
					"active_count": debug_info.active_count,
					"capacity": debug_info.capacity,
					"marked_for_removal": debug_info.marked_for_removal,
					"rejections": debug_info.add_rejections
				})

			data["total_entities"] = total_enemies
			data["total_capacity"] = total_capacity
			data["total_rejections"] = total_rejections
			data["tracker_details"] = tracker_details
			data["memory_efficiency"] = _format_percentage(total_enemies, total_capacity)

	return data

## Format breach-specific performance summary
func format_event_summary(handler_data: Dictionary) -> String:
	var summary = ""

	if handler_data.has("trackers_count"):
		if handler_data.trackers_count == 0:
			summary += "📈 No active breach trackers (no enemies spawned yet)\n"
		else:
			summary += "🎯 RingBuffer Trackers Active: %d\n" % handler_data.trackers_count

			# Display individual tracker details
			if handler_data.has("tracker_details"):
				for tracker in handler_data.tracker_details:
					summary += "  🔸 Breach %s: %d/%d enemies (%d marked, %d rejections)\n" % [
						tracker.id_suffix,
						tracker.active_count,
						tracker.capacity,
						tracker.marked_for_removal,
						tracker.rejections
					]

			# Display totals
			if handler_data.has("total_entities") and handler_data.has("trackers_count"):
				summary += "📊 TOTALS: %d enemies across %d trackers\n" % [
					handler_data.total_entities,
					handler_data.trackers_count
				]

			# Display memory efficiency
			if handler_data.has("memory_efficiency"):
				summary += "💾 Memory efficiency: %s capacity used\n" % handler_data.memory_efficiency

			# Display capacity overflow status
			if handler_data.has("total_rejections"):
				if handler_data.total_rejections > 0:
					summary += "⚠️  Capacity overflows: %d total rejections\n" % handler_data.total_rejections
				else:
					summary += "✅ Zero capacity overflows - optimal performance\n"

	return summary