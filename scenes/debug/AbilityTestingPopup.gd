extends Window

## Ability Testing Popup
## Full ability editor and testing tool for runtime ability development
## Opened via button in DebugPanel

# ============================================================================
# LEFT COLUMN: Ability Editor
# ============================================================================

# Editor controls
@onready var ability_dropdown: OptionButton = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/AbilityDropdown

# Property labels (for visibility control)
@onready var damage_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/DamageLabel
@onready var cooldown_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/CooldownLabel
@onready var count_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/CountLabel
@onready var spread_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/SpreadLabel
@onready var speed_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/SpeedLabel
@onready var pierce_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/PierceLabel
@onready var chain_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/ChainLabel
@onready var chain_radius_label: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/ChainRadiusLabel

# Property spinners (grid layout)
@onready var damage_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/DamageSpinner
@onready var cooldown_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/CooldownSpinner
@onready var count_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/CountSpinner
@onready var spread_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/SpreadSpinner
@onready var speed_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/SpeedSpinner
@onready var pierce_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/PierceSpinner
@onready var chain_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/ChainSpinner
@onready var chain_radius_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/ChainRadiusSpinner
@onready var homing_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/HomingCheck
@onready var homing_strength_spinner: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/PropertiesGrid/HomingStrengthSpinner

# Editor buttons
@onready var save_button: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/EditorButtons/SaveButton
@onready var apply_button: Button = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/EditorButtons/ApplyButton

# Tags display
@onready var tags_display: Label = $PanelContainer/MarginContainer/HBoxContainer/LeftColumn/TagsDisplay

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

	# Prefill slot dropdowns with currently equipped abilities
	call_deferred("_prefill_equipped_abilities")

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
			ability_dropdown.add_item(ability_id)

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

	# Extract ability_id from dropdown text (format: "ability_id")
	var ability_id = ability_dropdown.get_item_text(item_index)
	_load_ability_to_editor(ability_id)


## Loads an ability into the editor fields
func _load_ability_to_editor(ability_id: String) -> void:
	var definition = AbilityManager.get_definition(ability_id)
	if not definition:
		Logger.warn("Failed to load ability: %s" % ability_id, "debug")
		return

	# Duplicate the definition to avoid modifying the shared AbilityManager definition
	current_ability = definition.duplicate(true)
	current_ability_file = ability_file_paths.get(ability_id, "")

	# Configure property visibility based on ability type (duck typing)
	_configure_visible_properties(definition)

	# Populate property values using duck typing (only set if property exists)
	if "base_damage" in definition:
		damage_spinner.value = definition.base_damage

	if "base_cooldown" in definition:
		cooldown_spinner.value = definition.base_cooldown

	if "projectile_count" in definition:
		count_spinner.value = definition.projectile_count

	if "spread_angle" in definition:
		spread_spinner.value = definition.spread_angle

	if "projectile_speed" in definition:
		speed_spinner.value = definition.projectile_speed

	if "pierce_count" in definition:
		pierce_spinner.value = definition.pierce_count

	if "chains_to_enemies" in definition:
		chain_spinner.value = definition.chains_to_enemies

	if "chain_radius" in definition:
		chain_radius_spinner.value = definition.chain_radius

	if "is_homing" in definition:
		homing_check.button_pressed = definition.is_homing

	if "homing_strength" in definition:
		homing_strength_spinner.value = definition.homing_strength

	# Update tags display
	_update_tags_display(definition)

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

	damage_spinner.value = 25.0
	cooldown_spinner.value = 1.5
	count_spinner.value = 3.0
	spread_spinner.value = 40.0
	speed_spinner.value = 800.0
	pierce_spinner.value = 0
	chain_spinner.value = 0
	chain_radius_spinner.value = 150.0
	homing_check.button_pressed = false
	homing_strength_spinner.value = 0.5

	tags_display.text = "(No ability selected)"

	file_path_label.text = "Path: (No ability selected)"
	last_saved_label.text = "Last Saved: Never"


## Updates the tags display with a comma-separated list of tags
func _update_tags_display(ability: BaseAbility) -> void:
	if not ability or not "tags" in ability:
		tags_display.text = "(No tags)"
		return

	var ability_tags: Array = ability.tags
	if ability_tags.is_empty():
		tags_display.text = "(No tags)"
	else:
		# Join tags with comma separator
		tags_display.text = ", ".join(ability_tags)


## Configures property field visibility based on ability's actual properties.
## Uses property introspection to show only relevant fields.
##
## Property Mapping:
## - base_damage (DamageAbility) → damage fields
## - base_cooldown (DamageAbility) → cooldown fields
## - projectile_count (DamageAbility) → count fields
## - spread_angle (ProjectileAbility) → spread fields
## - projectile_speed (ProjectileAbility) → speed fields
## - pierce_count (ProjectileAbility) → pierce fields
## - chains_to_enemies (ProjectileAbility) → chain fields
## - chain_radius (ProjectileAbility) → chain_radius fields
## - is_homing (ProjectileAbility) → homing fields
## - homing_strength (ProjectileAbility) → homing_strength fields
func _configure_visible_properties(ability: BaseAbility) -> void:
	if not ability:
		return

	# Show/hide damage (DamageAbility)
	var has_damage = "base_damage" in ability
	damage_label.visible = has_damage
	damage_spinner.visible = has_damage

	# Show/hide cooldown (DamageAbility)
	var has_cooldown = "base_cooldown" in ability
	cooldown_label.visible = has_cooldown
	cooldown_spinner.visible = has_cooldown

	# Show/hide count (DamageAbility)
	var has_count = "projectile_count" in ability
	count_label.visible = has_count
	count_spinner.visible = has_count

	# Show/hide spread (ProjectileAbility)
	var has_spread = "spread_angle" in ability
	spread_label.visible = has_spread
	spread_spinner.visible = has_spread

	# Show/hide speed (ProjectileAbility)
	var has_speed = "projectile_speed" in ability
	speed_label.visible = has_speed
	speed_spinner.visible = has_speed

	# Show/hide pierce (ProjectileAbility)
	var has_pierce = "pierce_count" in ability
	pierce_label.visible = has_pierce
	pierce_spinner.visible = has_pierce

	# Show/hide chain (ProjectileAbility)
	var has_chain = "chains_to_enemies" in ability
	chain_label.visible = has_chain
	chain_spinner.visible = has_chain

	# Show/hide chain_radius (ProjectileAbility)
	var has_chain_radius = "chain_radius" in ability
	chain_radius_label.visible = has_chain_radius
	chain_radius_spinner.visible = has_chain_radius

	# Show/hide homing (ProjectileAbility)
	var has_homing = "is_homing" in ability
	homing_check.visible = has_homing
	homing_strength_spinner.visible = has_homing

	Logger.debug("Configured property visibility for %s (%s properties visible)" % [
		ability.ability_id,
		[has_damage, has_cooldown, has_count, has_spread, has_speed, has_pierce, has_chain, has_chain_radius, has_homing].count(true)
	], "debug")


## Saves current ability changes to .tres file
func _on_save_button_pressed() -> void:
	if not current_ability:
		Logger.warn("No ability selected for save", "debug")
		return

	if current_ability_file.is_empty():
		Logger.error("Cannot save: file path not found for %s" % current_ability.ability_id, "debug")
		return

	# Update ability data from editor fields using duck typing
	# Only update properties that exist on the ability (visible fields)
	if "base_damage" in current_ability:
		current_ability.base_damage = damage_spinner.value

	if "base_cooldown" in current_ability:
		current_ability.base_cooldown = cooldown_spinner.value

	if "projectile_count" in current_ability:
		current_ability.projectile_count = int(count_spinner.value)

	if "spread_angle" in current_ability:
		current_ability.spread_angle = spread_spinner.value

	if "projectile_speed" in current_ability:
		current_ability.projectile_speed = speed_spinner.value

	if "pierce_count" in current_ability:
		current_ability.pierce_count = int(pierce_spinner.value)

	if "chains_to_enemies" in current_ability:
		current_ability.chains_to_enemies = int(chain_spinner.value)

	if "chain_radius" in current_ability:
		current_ability.chain_radius = chain_radius_spinner.value

	if "is_homing" in current_ability:
		current_ability.is_homing = homing_check.button_pressed

	if "homing_strength" in current_ability:
		current_ability.homing_strength = homing_strength_spinner.value

	# Save to .tres file
	var save_result = ResourceSaver.save(current_ability, current_ability_file)

	if save_result == OK:
		last_save_time = Time.get_ticks_msec() / 1000.0
		last_saved_label.text = "Last Saved: Just now"
		Logger.info("Saved ability: %s to %s" % [current_ability.ability_id, current_ability_file], "debug")
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

	var ability_controller = player.ability_controller
	var applied_count = 0

	# Find equipped slots with this ability
	for i in range(ability_controller.ability_slots.size()):
		var equipped_ability = ability_controller.ability_slots[i]
		if equipped_ability and equipped_ability.ability_id == current_ability.ability_id:
			# Create a new instance from current editor values
			var updated_ability = AbilityManager.create_ability_instance(current_ability.ability_id)

			# Apply editor changes to the new instance using duck typing
			if "base_damage" in updated_ability:
				updated_ability.base_damage = damage_spinner.value

			if "base_cooldown" in updated_ability:
				updated_ability.base_cooldown = cooldown_spinner.value

			if "projectile_count" in updated_ability:
				# Update both projectile_count and _base_projectile_count
				updated_ability.projectile_count = int(count_spinner.value)
				if "_base_projectile_count" in updated_ability:
					updated_ability._base_projectile_count = int(count_spinner.value)

			if "spread_angle" in updated_ability:
				updated_ability.spread_angle = spread_spinner.value

			if "projectile_speed" in updated_ability:
				updated_ability.projectile_speed = speed_spinner.value

			if "pierce_count" in updated_ability:
				updated_ability.pierce_count = int(pierce_spinner.value)

			if "chains_to_enemies" in updated_ability:
				updated_ability.chains_to_enemies = int(chain_spinner.value)

			if "chain_radius" in updated_ability:
				updated_ability.chain_radius = chain_radius_spinner.value

			if "is_homing" in updated_ability:
				updated_ability.is_homing = homing_check.button_pressed

			if "homing_strength" in updated_ability:
				updated_ability.homing_strength = homing_strength_spinner.value

			# Preserve level and tome modifiers from equipped ability
			if equipped_ability.ability_level > 1:
				# Manually set level and recalculate (don't use level_up, that scales base values)
				updated_ability.ability_level = equipped_ability.ability_level

			# Copy tome modifiers from equipped ability
			updated_ability._active_modifiers = equipped_ability._active_modifiers.duplicate(true)

			# Recalculate final stats with new base values + existing modifiers
			updated_ability._recalculate_final_stats()

			# Replace equipped ability
			ability_controller.ability_slots[i] = updated_ability
			applied_count += 1

	if applied_count > 0:
		Logger.info("Applied changes to %d equipped slot(s)" % applied_count, "debug")
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
				dropdown.add_item(ability_id)


## Prefills slot dropdowns with currently equipped abilities
func _prefill_equipped_abilities() -> void:
	var player = _get_player()
	if not player or not "ability_controller" in player or not player.ability_controller:
		Logger.debug("Player not available for prefill", "debug")
		return

	var ability_controller = player.ability_controller

	# Set each dropdown to match equipped ability
	for i in range(ability_controller.ability_slots.size()):
		var equipped_ability = ability_controller.ability_slots[i]

		if equipped_ability:
			# Find the dropdown item index for this ability_id
			var ability_id = equipped_ability.ability_id
			var dropdown = slot_dropdowns[i]

			for item_idx in range(dropdown.item_count):
				if dropdown.get_item_text(item_idx) == ability_id:
					dropdown.selected = item_idx
					selected_ability_ids[i] = ability_id
					Logger.debug("Prefilled slot %d with %s" % [i + 1, ability_id], "debug")
					break
		else:
			# No ability equipped - select "(None)"
			slot_dropdowns[i].selected = 0
			selected_ability_ids[i] = ""


## Handles slot dropdown selection
func _on_slot_dropdown_selected(item_index: int, slot_index: int) -> void:
	if item_index == 0:
		# "(None)" selected
		selected_ability_ids[slot_index] = ""
	else:
		# Extract ability_id from dropdown text (format: "ability_id")
		var ability_id = slot_dropdowns[slot_index].get_item_text(item_index)
		selected_ability_ids[slot_index] = ability_id

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


## Gets player reference
func _get_player() -> Node:
	var player = get_tree().get_first_node_in_group("player")  # Note: singular "player" group
	if not player:
		# Debug-level log only (player may not be spawned yet when popup opens)
		Logger.debug("Player not found for ability testing", "debug")
	return player
