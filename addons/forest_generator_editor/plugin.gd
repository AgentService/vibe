@tool
extends EditorPlugin

const GeneratorDock = preload("res://addons/forest_generator_editor/generator_dock.gd")

var dock

func _enter_tree():
	# Add the custom dock to the 2D editor
	dock = GeneratorDock.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree():
	# Clean up
	remove_control_from_docks(dock)
	dock = null