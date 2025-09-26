@tool
extends EditorPlugin

var dock

func _enter_tree():
	# Add the path-aware generator dock to side panel (like forest generator)
	dock = preload("res://addons/path_aware_generator/path_aware_dock.gd").new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	# Clean up
	if dock:
		remove_control_from_docks(dock)
		dock = null