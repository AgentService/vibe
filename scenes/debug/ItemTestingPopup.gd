extends Window

## Item Testing Popup
## Simple item management tool for testing item acquisition and equipping
## Opened via button in DebugPanel

# ============================================================================
# UI REFERENCES
# ============================================================================

# Item selection dropdown
@onready var item_dropdown: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ItemSelectionContainer/ItemDropdown

# Action buttons
@onready var equip_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/EquipButton
@onready var clear_all_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ActionButtons/ClearAllButton

# Equipped items display
@onready var equipped_items_list: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/EquippedItemsContainer/EquippedItemsList

# ============================================================================
# STATE
# ============================================================================

## Map of item_id → category for organization
var item_categories: Dictionary = {}

## Currently selected item_id from dropdown
var selected_item_id: String = ""

## Refresh timer for equipped items display
var refresh_timer: Timer

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Populate item dropdown
	_populate_item_dropdown()

	# Connect signals
	item_dropdown.item_selected.connect(_on_item_dropdown_selected)
	equip_button.pressed.connect(_on_equip_button_pressed)
	clear_all_button.pressed.connect(_on_clear_all_button_pressed)

	# Setup periodic refresh of equipped items list
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 0.5  # Refresh every 0.5 seconds
	refresh_timer.timeout.connect(_refresh_equipped_items_display)
	add_child(refresh_timer)
	refresh_timer.start()

	# Initial display update
	_refresh_equipped_items_display()

	Logger.info("ItemTestingPopup initialized", "debug")


# ============================================================================
# ITEM DROPDOWN POPULATION
# ============================================================================

## Populates dropdown with all available items from ItemManager
func _populate_item_dropdown() -> void:
	if not ItemManager:
		Logger.warn("ItemManager not available", "debug")
		return

	item_dropdown.clear()
	item_dropdown.add_item("(Select an item to equip)")

	# Get all item IDs from ItemManager
	var all_item_ids: Array[String] = ItemManager.get_all_item_ids()

	# Organize items by category for better UX
	var items_by_category: Dictionary = {}
	for item_id in all_item_ids:
		var category := ItemManager.get_category(item_id)
		if not items_by_category.has(category):
			items_by_category[category] = []
		items_by_category[category].append(item_id)

	# Add items organized by category
	var category_order := ["proc", "stat_boost", "utility"]
	for category in category_order:
		if items_by_category.has(category):
			# Add category separator
			var separator_text := "─── %s ───" % category.to_upper()
			item_dropdown.add_separator(separator_text)

			# Add items in this category
			for item_id in items_by_category[category]:
				var metadata = ItemManager.get_item_metadata(item_id)
				var display_name: String = metadata.display_name if metadata else item_id
				item_dropdown.add_item(display_name)
				item_dropdown.set_item_metadata(item_dropdown.item_count - 1, item_id)
				item_categories[item_id] = category

	Logger.debug("Loaded %d items into dropdown" % all_item_ids.size(), "debug")


## Handles item dropdown selection
func _on_item_dropdown_selected(item_index: int) -> void:
	if item_index == 0:
		# "(Select an item to equip)" selected
		selected_item_id = ""
		equip_button.disabled = true
		return

	# Extract item_id from metadata
	var item_id = item_dropdown.get_item_metadata(item_index)
	if item_id:
		selected_item_id = item_id
		equip_button.disabled = false
		Logger.debug("Selected item: %s" % item_id, "debug")
	else:
		# Separator selected (no metadata)
		selected_item_id = ""
		equip_button.disabled = true


# ============================================================================
# ITEM EQUIPPING
# ============================================================================

## Equips selected item via EventBus.item_acquired signal
func _on_equip_button_pressed() -> void:
	if selected_item_id.is_empty():
		Logger.warn("No item selected for equip", "debug")
		return

	# Emit item_acquired signal (ItemManager will handle equipping)
	EventBus.item_acquired.emit(selected_item_id, "debug")

	Logger.info("Emitted item_acquired for: %s" % selected_item_id, "debug")

	# Refresh display immediately
	_refresh_equipped_items_display()


## Clears all equipped items (removes all stacks)
func _on_clear_all_button_pressed() -> void:
	if not ItemManager:
		return

	# Get all equipped items and unequip all stacks
	var equipped := ItemManager.get_equipped_items()
	for item_entry in equipped:
		if item_entry and "item_id" in item_entry and "stack_count" in item_entry:
			# Unequip all stacks at once
			for i in range(item_entry.stack_count):
				ItemManager.unequip_item(item_entry.item_id)

	Logger.info("Cleared all equipped items", "debug")

	# Refresh display
	_refresh_equipped_items_display()


# ============================================================================
# EQUIPPED ITEMS DISPLAY
# ============================================================================

## Refreshes the equipped items list display
func _refresh_equipped_items_display() -> void:
	if not equipped_items_list or not ItemManager:
		return

	var equipped := ItemManager.get_equipped_items()

	if equipped.is_empty():
		equipped_items_list.text = "[center][color=#888888]No items equipped[/color][/center]"
		return

	# Build equipped items table with stack counts
	var display_text := "[table=4]"
	display_text += "[cell][b]Item[/b][/cell][cell][b]Stack[/b][/cell][cell][b]Category[/b][/cell][cell][b]Effects[/b][/cell]"

	for item_entry in equipped:
		if not item_entry or not "item_id" in item_entry:
			continue

		var item_id: String = item_entry.item_id
		var item: BaseItem = item_entry.item
		var stack_count: int = item_entry.stack_count
		var metadata = ItemManager.get_item_metadata(item_id)
		var category: String = item_categories.get(item_id, "unknown")

		# Item name
		var display_name: String = metadata.display_name if metadata else item_id
		display_text += "[cell]%s[/cell]" % display_name

		# Stack count
		display_text += "[cell][b]x%d[/b][/cell]" % stack_count

		# Category
		var category_color := _get_category_color(category)
		display_text += "[cell][color=%s]%s[/color][/cell]" % [category_color, category]

		# Effects summary
		var effects := _get_item_effects_summary(item)
		display_text += "[cell][color=#AAAAAA]%s[/color][/cell]" % effects

	display_text += "[/table]"
	equipped_items_list.text = display_text


## Returns color for category display
func _get_category_color(category: String) -> String:
	match category:
		"proc":
			return "#FFD700"  # Gold
		"stat_boost":
			return "#4A90E2"  # Blue
		"utility":
			return "#50C878"  # Green
		_:
			return "#888888"  # Gray


## Returns a summary string of item effects
func _get_item_effects_summary(item: BaseItem) -> String:
	var effects: Array[String] = []

	# Stat bonuses
	if item.max_hp_bonus != 0:
		effects.append("+%d HP" % item.max_hp_bonus)
	if item.movement_speed_mult != 1.0:
		var percent := int((item.movement_speed_mult - 1.0) * 100)
		effects.append("%+d%% Speed" % percent)
	if item.damage_mult != 1.0:
		var percent := int((item.damage_mult - 1.0) * 100)
		effects.append("%+d%% Damage" % percent)
	if item.pickup_radius_mult != 1.0:
		var percent := int((item.pickup_radius_mult - 1.0) * 100)
		effects.append("%+d%% Pickup" % percent)

	# Procs
	if item.on_hit_lightning:
		effects.append("⚡Lightning")
	if item.on_hit_explosion:
		effects.append("💥Explosion")
	if item.on_hit_freeze:
		effects.append("❄Freeze")

	return ", ".join(effects) if not effects.is_empty() else "No effects"


# ============================================================================
# CLEANUP
# ============================================================================

func _exit_tree() -> void:
	if refresh_timer:
		refresh_timer.stop()
		refresh_timer.queue_free()

	Logger.debug("ItemTestingPopup cleaned up", "debug")
