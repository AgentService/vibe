extends Window

## Ability Testing Popup
## Full ability editor and testing tool for runtime ability development
## Opened via button in DebugPanel

# ============================================================================
# LEFT COLUMN: Ability Editor
# ============================================================================

# Editor controls
@onready var ability_dropdown: OptionButton = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/AbilityDropdown
@onready var name_field: LineEdit = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/NameField
@onready var damage_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/DamageSpinner
@onready var cooldown_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/CooldownSpinner
@onready var projectile_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/ProjectileSpinner
@onready var tags_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/TagsLabel

# Editor buttons
@onready var save_button: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/EditorButtons/SaveButton
@onready var apply_button: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/EditorButtons/ApplyButton

# File info
@onready var file_path_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/FilePathLabel
@onready var last_saved_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/LastSavedLabel

# ============================================================================
# RIGHT COLUMN: Slot Equipment
# ============================================================================

# Slot dropdowns
@onready var slot_dropdowns: Array[OptionButton] = [
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot1Container/Slot1Dropdown,
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot2Container/Slot2Dropdown,
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot3Container/Slot3Dropdown,
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot4Container/Slot4Dropdown
]

# Level-up buttons
@onready var level_up_buttons: Array[Button] = [
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot1Container/LevelUpBtn,
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot2Container/LevelUpBtn,
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot3Container/LevelUpBtn,
	$PanelContainer/MarginContainer/HBoxContainer/RightColumn/Slot4Container/LevelUpBtn
]

# Action buttons
@onready var equip_button: Button = $PanelContainer/MarginContainer/HBoxContainer/RightColumn/ActionButtons/EquipButton
@onready var clear_all_button: Button = $PanelContainer/MarginContainer/HBoxContainer/RightColumn/ActionButtons/ClearAllButton
@onready var level_up_all_button: Button = $PanelContainer/MarginContainer/HBoxContainer/RightColumn/TestingButtons/LevelUpAllButton
@onready var refresh_button: Button = $PanelContainer/MarginContainer/HBoxContainer/RightColumn/TestingButtons/RefreshButton

# Info display
@onready var equipped_info: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/RightColumn/EquippedInfo

# ============================================================================
# STATE
# ============================================================================

# Ability editor state
var ability_file_paths: Dictionary = {}  # ability_id -> file_path
var current_ability: BaseAbility = null
var current_ability_file: String = ""
var last_save_time: float = 0.0

# Slot equipment state
var selected_ability_ids: Array[String] = ["", "", "", ""]  # ability_id per slot


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Load all abilities from AbilityManager
	_populate_ability_dropdown()
	_populate_slot_dropdowns()

	# Connect LEFT COLUMN signals
	ability_dropdown.item_selected.connect(_on_ability_dropdown_selected)
	save_button.pressed.connect(_on_save_button_pressed)
	apply_button.pressed.connect(_on_apply_button_pressed)

	# Connect RIGHT COLUMN signals
	for i in range(slot_dropdowns.size()):
		slot_dropdowns[i].item_selected.connect(_on_slot_dropdown_selected.bind(i))
		level_up_buttons[i].pressed.connect(_on_level_up_pressed.bind(i))

	equip_button.pressed.connect(_on_equip_button_pressed)
	clear_all_button.pressed.connect(_on_clear_all_pressed)
	level_up_all_button.pressed.connect(_on_level_up_all_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)

	# Defer refresh until player is available
	call_deferred("_refresh_equipped_display")

	Logger.info("AbilityTestingPopup initialized (full editor mode)", "debug")


# ============================================================================
# LEFT COLUMN: Ability Editor
# ============================================================================

## Populates ability editor dropdown with all available abilities
func _populate_ability_dropdown() -> void:
	if not AbilityManager:
		Logger.warn("AbilityManager not available", "debug")
		return

	ability_dropdown.clear()
	ability_dropdown.add_item("(Select an ability to edit)")

	# Get all available abilities from AbilityManager
	var available_abilities = AbilityManager.get_all_ability_ids()

	for ability_id in available_abilities:
		var definition = AbilityManager.get_definition(ability_id)
		if definition:
			ability_dropdown.add_item("%s - %s" % [definition.ability_name, ability_id])

			# Store file path for saving (scan content directory)
			var file_path = _find_ability_file_path(ability_id)
			if not file_path.is_empty():
				ability_file_paths[ability_id] = file_path

	Logger.info("Loaded %d abilities for editing" % available_abilities.size(), "debug")


## Scans /data/content/abilities/ to find .tres file for given ability_id
func _find_ability_file_path(ability_id: String) -> String:
	# Recursively search subdirectories
	return _scan_directory_for_ability("res://data/content/abilities/", ability_id)


## Recursively scans directory for ability .tres file
func _scan_directory_for_ability(dir_path: String, ability_id: String) -> String:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return ""

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = dir_path.path_join(file_name)

		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recurse into subdirectory
			var found_path = _scan_directory_for_ability(full_path, ability_id)
			if not found_path.is_empty():
				return found_path
		elif file_name.ends_with(".tres"):
			# Check if this .tres file contains our ability_id
			var resource = ResourceLoader.load(full_path)
			if resource and resource is BaseAbility and resource.ability_id == ability_id:
				return full_path

		file_name = dir.get_next()

	dir.list_dir_end()
	return ""


## Handles ability selection in editor dropdown
func _on_ability_dropdown_selected(item_index: int) -> void:
	if item_index == 0:
		# "(Select an ability to edit)" selected
		_clear_editor_fields()
		return

	# Extract ability_id from dropdown text (format: "Name - ability_id")
	var dropdown_text = ability_dropdown.get_item_text(item_index)
	var parts = dropdown_text.split(" - ")
	if parts.size() != 2:
		Logger.warn("Failed to parse ability_id from dropdown: %s" % dropdown_text, "debug")
		return

	var ability_id = parts[1]
	_load_ability_to_editor(ability_id)


## Loads an ability into the editor fields
func _load_ability_to_editor(ability_id: String) -> void:
	var definition = AbilityManager.get_definition(ability_id)
	if not definition:
		Logger.warn("Failed to load ability: %s" % ability_id, "debug")
		return

	current_ability = definition
	current_ability_file = ability_file_paths.get(ability_id, "")

	# Populate editor fields
	name_field.text = definition.ability_name
	damage_spinner.value = definition.base_damage
	cooldown_spinner.value = definition.base_cooldown

	# Projectile count only if ProjectileAbility
	if definition is ProjectileAbility:
		projectile_spinner.value = definition.projectile_count
		projectile_spinner.visible = true
		$PanelContainer/MarginContainer/HBoxContainer/LeftColumn/ProjectileLabel.visible = true
	else:
		projectile_spinner.visible = false
		$PanelContainer/MarginContainer/HBoxContainer/LeftColumn/ProjectileLabel.visible = false

	# Display tags
	tags_label.text = "Tags: " + ", ".join(definition.tags)

	# Update file info
	if not current_ability_file.is_empty():
		file_path_label.text = "Path: " + current_ability_file
	else:
		file_path_label.text = "Path: (File not found for saving)"

	last_saved_label.text = "Last Saved: Not modified"

	Logger.debug("Loaded ability to editor: %s" % ability_id, "debug")


## Clears all editor fields
func _clear_editor_fields() -> void:
	current_ability = null
	current_ability_file = ""

	name_field.text = ""
	damage_spinner.value = 25.0
	cooldown_spinner.value = 1.5
	projectile_spinner.value = 3.0
	tags_label.text = "Tags: (No ability selected)"

	file_path_label.text = "Path: (No ability selected)"
	last_saved_label.text = "Last Saved: Never"


## Saves current ability changes to .tres file
func _on_save_button_pressed() -> void:
	if not current_ability:
		Logger.warn("No ability selected for save", "debug")
		return

	if current_ability_file.is_empty():
		Logger.error("Cannot save: file path not found for %s" % current_ability.ability_id, "debug")
		return

	# Update ability data from editor fields
	current_ability.ability_name = name_field.text
	current_ability.base_damage = damage_spinner.value
	current_ability.base_cooldown = cooldown_spinner.value

	if current_ability is ProjectileAbility:
		current_ability.projectile_count = int(projectile_spinner.value)

	# Save to .tres file
	var save_result = ResourceSaver.save(current_ability, current_ability_file)

	if save_result == OK:
		last_save_time = Time.get_ticks_msec() / 1000.0
		last_saved_label.text = "Last Saved: Just now"
		Logger.info("Saved ability: %s to %s" % [current_ability.ability_name, current_ability_file], "debug")
	else:
		Logger.error("Failed to save ability: %s (error code: %d)" % [current_ability_file, save_result], "debug")


## Applies current ability changes to equipped instances (hot-reload)
func _on_apply_button_pressed() -> void:
	if not current_ability:
		Logger.warn("No ability selected for apply", "debug")
		return

	var player = _get_player()
	if not player or not "ability_controller" in player or not player.ability_controller:
		Logger.warn("Player or AbilityController not found for apply", "debug")
		return

	# Update ability data from editor fields (same as save)
	current_ability.ability_name = name_field.text
	current_ability.base_damage = damage_spinner.value
	current_ability.base_cooldown = cooldown_spinner.value

	if current_ability is ProjectileAbility:
		current_ability.projectile_count = int(projectile_spinner.value)

	var ability_controller = player.ability_controller
	var applied_count = 0

	# Refresh any equipped instances with this ability_id
	for i in range(ability_controller.ability_slots.size()):
		var equipped_ability = ability_controller.ability_slots[i]
		if equipped_ability and equipped_ability.ability_id == current_ability.ability_id:
			# Re-create instance from updated definition
			ability_controller.ability_slots[i] = current_ability.duplicate(true)
			applied_count += 1

	if applied_count > 0:
		Logger.info("Applied changes to %d equipped slot(s)" % applied_count, "debug")
		_refresh_equipped_display()
	else:
		Logger.debug("Ability %s not currently equipped" % current_ability.ability_id, "debug")


# ============================================================================
# RIGHT COLUMN: Slot Equipment
# ============================================================================

## Populates all slot dropdowns with available abilities
func _populate_slot_dropdowns() -> void:
	if not AbilityManager:
		Logger.warn("AbilityManager not available", "debug")
		return

	# Get all available abilities
	var available_abilities = AbilityManager.get_all_ability_ids()

	for dropdown in slot_dropdowns:
		dropdown.clear()
		dropdown.add_item("(None)")  # First option = empty slot

		# Add all abilities
		for ability_id in available_abilities:
			var definition = AbilityManager.get_definition(ability_id)
			if definition:
				dropdown.add_item("%s - %s" % [definition.ability_name, ability_id])


## Handles slot dropdown selection
func _on_slot_dropdown_selected(item_index: int, slot_index: int) -> void:
	if item_index == 0:
		# "(None)" selected
		selected_ability_ids[slot_index] = ""
	else:
		# Extract ability_id from dropdown text (format: "Name - ability_id")
		var dropdown_text = slot_dropdowns[slot_index].get_item_text(item_index)
		var parts = dropdown_text.split(" - ")
		if parts.size() == 2:
			selected_ability_ids[slot_index] = parts[1]
		else:
			Logger.warn("Failed to parse ability_id from dropdown: %s" % dropdown_text, "debug")

	Logger.debug("Slot %d selected: %s" % [slot_index + 1, selected_ability_ids[slot_index]], "debug")


## Equips selected abilities to player
func _on_equip_button_pressed() -> void:
	var player = _get_player()
	if not player:
		return

	if not "ability_controller" in player or not player.ability_controller:
		Logger.warn("Player has no AbilityController!", "debug")
		return

	var ability_controller = player.ability_controller

	# Equip abilities to slots
	for i in range(4):
		var ability_id = selected_ability_ids[i]

		if ability_id.is_empty():
			# Empty slot - clear it
			ability_controller.clear_ability_slot(i)
		else:
			# Equip ability to slot
			ability_controller.equip_ability(ability_id, i)

		Logger.info("Equipped slot %d: %s" % [i, ability_id if not ability_id.is_empty() else "(None)"], "debug")

	# Refresh display
	_refresh_equipped_display()


## Level up ability in specific slot
func _on_level_up_pressed(slot_index: int) -> void:
	var player = _get_player()
	if not player:
		return

	if not "ability_controller" in player or not player.ability_controller:
		return

	var ability_controller = player.ability_controller
	var ability = ability_controller.ability_slots[slot_index]

	if ability:
		ability_controller.level_up_ability(ability.ability_id, 1)
		Logger.info("Leveled up slot %d: %s → Lv%d" % [slot_index + 1, ability.ability_name, ability.ability_level], "debug")
		_refresh_equipped_display()
	else:
		Logger.warn("No ability in slot %d to level up" % (slot_index + 1), "debug")


## Clears all equipped abilities
func _on_clear_all_pressed() -> void:
	var player = _get_player()
	if not player:
		return

	if not "ability_controller" in player or not player.ability_controller:
		return

	var ability_controller = player.ability_controller

	for i in range(4):
		ability_controller.clear_ability_slot(i)

	Logger.info("Cleared all equipped abilities", "debug")
	_refresh_equipped_display()


## Levels up all equipped abilities by 1
func _on_level_up_all_pressed() -> void:
	var player = _get_player()
	if not player:
		return

	if not "ability_controller" in player or not player.ability_controller:
		return

	var ability_controller = player.ability_controller
	var leveled_count = 0

	for i in range(ability_controller.ability_slots.size()):
		var ability = ability_controller.ability_slots[i]
		if ability:
			ability_controller.level_up_ability(ability.ability_id, 1)
			leveled_count += 1

	if leveled_count > 0:
		Logger.info("Leveled up %d equipped abilities" % leveled_count, "debug")
		_refresh_equipped_display()
	else:
		Logger.debug("No equipped abilities to level up", "debug")


## Refreshes all abilities from files (hot-reload)
func _on_refresh_button_pressed() -> void:
	# Reload AbilityManager registry
	if AbilityManager:
		# AbilityManager auto-scans on startup, but we can force refresh by reloading dropdowns
		_populate_ability_dropdown()
		_populate_slot_dropdowns()
		Logger.info("Refreshed abilities from files", "debug")


## Refreshes the "Currently Equipped" display
func _refresh_equipped_display() -> void:
	var player = _get_player()
	if not player:
		equipped_info.text = "[color=gray]Player not spawned yet...[/color]"
		return

	if not "ability_controller" in player or not player.ability_controller:
		equipped_info.text = "[color=red]AbilityController not found[/color]"
		return

	var ability_controller = player.ability_controller
	var display_text = ""

	for i in range(ability_controller.ability_slots.size()):
		var ability = ability_controller.ability_slots[i]
		if ability:
			display_text += "[b]Slot %d:[/b] %s (Lv %d)\\n" % [i + 1, ability.ability_name, ability.ability_level]
		else:
			display_text += "[b]Slot %d:[/b] [color=gray](Empty)[/color]\\n" % (i + 1)

	equipped_info.text = display_text


## Gets player reference
func _get_player() -> Node:
	var player = get_tree().get_first_node_in_group("player")  # Note: singular "player" group
	if not player:
		# Debug-level log only (player may not be spawned yet when popup opens)
		Logger.debug("Player not found for ability testing", "debug")
	return player
