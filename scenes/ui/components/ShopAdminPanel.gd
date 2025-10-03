extends VBoxContainer
class_name ShopAdminPanel
## Admin/debug panel for testing UnlockShop item states
## Allows toggling items between Undiscovered/Discovered/Unlocked states

signal admin_state_changed(item_id: String, category: String, new_state: String)

# Data provider callables (same as UnlockShop)
var _items_data_provider: Callable
var _tomes_data_provider: Callable
var _skills_data_provider: Callable
var _characters_data_provider: Callable

# Current tab
var _current_category: String = "items"

# Node references
@onready var tab_bar: TabBar = $TabBar
@onready var items_list: VBoxContainer = $ScrollContainer/ItemLists/ItemsList_Items
@onready var tomes_list: VBoxContainer = $ScrollContainer/ItemLists/ItemsList_Tomes
@onready var skills_list: VBoxContainer = $ScrollContainer/ItemLists/ItemsList_Skills
@onready var characters_list: VBoxContainer = $ScrollContainer/ItemLists/ItemsList_Characters

func _ready() -> void:
	if tab_bar:
		tab_bar.tab_changed.connect(_on_tab_changed)

	Logger.debug("ShopAdminPanel initialized", "ui")

func setup_data_providers(items: Callable, tomes: Callable, skills: Callable, characters: Callable) -> void:
	"""Setup data provider callables for each category."""
	_items_data_provider = items
	_tomes_data_provider = tomes
	_skills_data_provider = skills
	_characters_data_provider = characters

	# Load initial tab
	_load_category_items("items")

func _on_tab_changed(tab: int) -> void:
	"""Handle tab switching."""
	match tab:
		0: _load_category_items("items")
		1: _load_category_items("tomes")
		2: _load_category_items("skills")
		3: _load_category_items("characters")

func _load_category_items(category: String) -> void:
	"""Load items for the given category and populate the list."""
	_current_category = category

	# Hide all lists
	items_list.visible = false
	tomes_list.visible = false
	skills_list.visible = false
	characters_list.visible = false

	# Get data provider and target list
	var data_provider: Callable
	var target_list: VBoxContainer

	match category:
		"items":
			data_provider = _items_data_provider
			target_list = items_list
		"tomes":
			data_provider = _tomes_data_provider
			target_list = tomes_list
		"skills":
			data_provider = _skills_data_provider
			target_list = skills_list
		"characters":
			data_provider = _characters_data_provider
			target_list = characters_list
		_:
			Logger.warn("ShopAdminPanel: Unknown category: %s" % category, "ui")
			return

	if not data_provider.is_valid():
		Logger.warn("ShopAdminPanel: No data provider for category: %s" % category, "ui")
		return

	# Clear existing items
	for child in target_list.get_children():
		child.queue_free()

	# Get items from data provider
	var items_array: Array = data_provider.call()

	# Create entry for each item
	for item_metadata in items_array:
		if item_metadata is ItemMetadata:
			_create_admin_item_entry(target_list, item_metadata)

	# Show the target list
	target_list.visible = true

func _create_admin_item_entry(container: VBoxContainer, item_metadata: ItemMetadata) -> void:
	"""Create an admin entry for a single item with state cycling button."""
	if not MetaProgression:
		Logger.warn("ShopAdminPanel: MetaProgression not available", "ui")
		return

	# Create row container
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Item name label
	var name_label := Label.new()
	name_label.text = item_metadata.display_name
	name_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(name_label)

	# Current state label
	var state_label := Label.new()
	state_label.custom_minimum_size = Vector2(120, 0)
	_update_state_label(state_label, item_metadata)
	row.add_child(state_label)

	# Cycle state button
	var cycle_button := Button.new()
	cycle_button.text = "Cycle State"
	cycle_button.custom_minimum_size = Vector2(100, 0)
	cycle_button.pressed.connect(_on_cycle_state_pressed.bind(item_metadata, state_label))
	row.add_child(cycle_button)

	container.add_child(row)

func _update_state_label(label: Label, item_metadata: ItemMetadata) -> void:
	"""Update the state label to reflect current item state."""
	var is_discovered := MetaProgression.is_item_discovered(item_metadata.category, item_metadata.item_id)
	var is_unlocked := MetaProgression.is_item_unlocked(item_metadata.category, item_metadata.item_id)

	if not is_discovered and not is_unlocked:
		label.text = "❌ Undiscovered"
		label.modulate = Color(0.7, 0.7, 0.7)
	elif is_discovered and not is_unlocked:
		label.text = "🔒 Discovered"
		label.modulate = Color(1.0, 0.8, 0.4)
	else:  # unlocked
		label.text = "✅ Unlocked"
		label.modulate = Color(0.4, 1.0, 0.4)

func _on_cycle_state_pressed(item_metadata: ItemMetadata, state_label: Label) -> void:
	"""Cycle item through states: Undiscovered → Discovered → Unlocked → Undiscovered."""
	if not MetaProgression:
		return

	var is_discovered := MetaProgression.is_item_discovered(item_metadata.category, item_metadata.item_id)
	var is_unlocked := MetaProgression.is_item_unlocked(item_metadata.category, item_metadata.item_id)

	var new_state: String = ""

	# State machine: Undiscovered → Discovered → Unlocked → Undiscovered
	if not is_discovered and not is_unlocked:
		# Undiscovered → Discovered
		MetaProgression.discover_item(item_metadata.category, item_metadata.item_id)
		new_state = "discovered"
		Logger.info("ShopAdminPanel: Set %s to DISCOVERED" % item_metadata.item_id, "ui")

	elif is_discovered and not is_unlocked:
		# Discovered → Unlocked
		MetaProgression.unlock_item(item_metadata.category, item_metadata.item_id)
		new_state = "unlocked"
		Logger.info("ShopAdminPanel: Set %s to UNLOCKED" % item_metadata.item_id, "ui")

	else:  # unlocked
		# Unlocked → Undiscovered (remove from both arrays)
		MetaProgression._remove_item_from_discovered(item_metadata.category, item_metadata.item_id)
		MetaProgression._remove_item_from_unlocked(item_metadata.category, item_metadata.item_id)
		new_state = "undiscovered"
		Logger.info("ShopAdminPanel: Set %s to UNDISCOVERED" % item_metadata.item_id, "ui")

	# Save changes
	MetaProgression.save()

	# Update label
	_update_state_label(state_label, item_metadata)

	# Emit signal for shop to refresh
	admin_state_changed.emit(item_metadata.item_id, item_metadata.category, new_state)

func refresh_current_tab() -> void:
	"""Refresh the currently visible tab."""
	_load_category_items(_current_category)
