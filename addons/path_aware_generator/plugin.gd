@tool
extends EditorPlugin

const PathGeneratorDock = preload("res://addons/path_aware_generator/path_generator_dock.gd")
var dock_instance

func _enter_tree():
	# Create dock instance
	dock_instance = PathGeneratorDock.new()
	dock_instance.name = "Path Generator"
	
	# Add dock to editor
	add_control_to_dock(DOCK_SLOT_LEFT_BL, dock_instance)
	
	Logger.info("Path-Aware Generator plugin activated", "plugin")

func _exit_tree():
	# Clean up dock
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()
		dock_instance = null
	
	Logger.info("Path-Aware Generator plugin deactivated", "plugin")

func get_plugin_name():
	return "Path-Aware Arena Generator"
