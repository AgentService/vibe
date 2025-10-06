extends Window

## Ability Testing Popup
## Allows equipping abilities to player slots for testing without hardcoding
## Opened via button in DebugPanel

# Slot dropdowns
@onready var slot_dropdowns: Array[OptionButton] = [
	$PanelContainer/MarginContainer/VBoxContainer/Slot1Container/Slot1Dropdown,
	$PanelContainer/MarginContainer/VBoxContainer/Slot2Container/Slot2Dropdown,
	$PanelContainer/MarginContainer/VBoxContainer/Slot3Container/Slot3Dropdown,
	$PanelContainer/MarginContainer/VBoxContainer/Slot4Container/Slot4Dropdown
]

# Level-up buttons
@onready var level_up_buttons: Array[Button] = [
	$PanelContainer/MarginContainer/VBoxContainer/Slot1Container/LevelUpBtn,
	$PanelContainer/MarginContainer/VBoxContainer/Slot2Container/LevelUpBtn,
	$PanelContainer/MarginContainer/VBoxContainer/Slot3Container/LevelUpBtn,
	$PanelContainer/MarginContainer/VBoxContainer/Slot4Container/LevelUpBtn
]

# Action buttons
@onready var equip_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/EquipButton
@onready var clear_all_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/ClearAllButton

# Info display
@onready var equipped_info: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/EquippedInfo

# State
var selected_ability_ids: Array[String] = ["", "", "", ""]  # ability_id per slot


func _ready() -> void:
	# Populate dropdowns with available abilities
	_populate_dropdowns()

	# Connect signals
	for i in range(slot_dropdowns.size()):
		slot_dropdowns[i].item_selected.connect(_on_slot_dropdown_selected.bind(i))
		level_up_buttons[i].pressed.connect(_on_level_up_pressed.bind(i))

	equip_button.pressed.connect(_on_equip_button_pressed)
	clear_all_button.pressed.connect(_on_clear_all_pressed)

	# Defer refresh until player is available (popup may open before player spawns)
	call_deferred("_refresh_equipped_display")

	Logger.info("AbilityTestingPopup initialized", "debug")


## Populates all slot dropdowns with available abilities from AbilityManager
func _populate_dropdowns() -> void:
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
			display_text += "[b]Slot %d:[/b] %s (Lv %d)\n" % [i + 1, ability.ability_name, ability.ability_level]
		else:
			display_text += "[b]Slot %d:[/b] [color=gray](Empty)[/color]\n" % (i + 1)

	equipped_info.text = display_text


## Gets player reference
func _get_player() -> Node:
	var player = get_tree().get_first_node_in_group("player")  # Note: singular "player" group
	if not player:
		# Debug-level log only (player may not be spawned yet when popup opens)
		Logger.debug("Player not found for ability testing", "debug")
	return player
