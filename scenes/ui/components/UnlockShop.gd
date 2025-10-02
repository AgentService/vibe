extends VBoxContainer
class_name UnlockShop

## Reusable Unlock Shop component with Items/Tomes/Skills tabs
## Manages tab switching, currency display, and item grid population
## Used in MainMenu unlocks section

@onready var tab_bar: TabBar = $TabContainer/HBoxContainer/TabBar
@onready var currency_value_label: Label = $ContentContainer/Header/MarginContainer/HBoxContainer/CurrencyContainer/CurrencyValue

# Item grid containers (one per tab)
@onready var item_grid_items: GridContainer = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemGridScroll/ItemGrid_Items
@onready var item_grid_tomes: GridContainer = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemGridScroll/ItemGrid_Tomes
@onready var item_grid_skills: GridContainer = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemGridScroll/ItemGrid_Skills

# Item details panel labels
@onready var item_name_label: Label = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemName
@onready var item_description_label: Label = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemDescription
@onready var item_stats_label: Label = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemStats
@onready var item_flavor_label: Label = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemFlavorText
@onready var quest_progress_label: Label = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/RightPanel/QuestProgress
@onready var unlock_button: Button = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/RightPanel/UnlockButton

# Data providers for each category (Callable pattern from Leaderboard)
var _items_data_provider: Callable
var _tomes_data_provider: Callable
var _skills_data_provider: Callable

# Currently selected item
var _selected_item: Dictionary = {}

func _ready() -> void:
	# Connect tab switching
	if tab_bar:
		tab_bar.tab_changed.connect(_on_tab_changed)
		# Don't load data yet - wait for setup_data_providers()

	# Connect unlock button
	if unlock_button:
		unlock_button.pressed.connect(_on_unlock_button_pressed)

	# Update currency display
	_update_currency_display()

	Logger.debug("UnlockShop initialized", "ui")

func setup_data_providers(items_provider: Callable, tomes_provider: Callable, skills_provider: Callable) -> void:
	"""Configure data loading callbacks and initialize with Items tab.

	Args:
		items_provider: Callable that returns Array[Dictionary] with item unlock data
		tomes_provider: Callable that returns Array[Dictionary] with tome unlock data
		skills_provider: Callable that returns Array[Dictionary] with skill unlock data
	"""
	_items_data_provider = items_provider
	_tomes_data_provider = tomes_provider
	_skills_data_provider = skills_provider

	# Load initial data for Items tab (index 0)
	if tab_bar:
		tab_bar.current_tab = 0
	_on_tab_changed(0)

func _on_tab_changed(tab_index: int) -> void:
	"""Switch between Items, Tomes, and Skills tabs."""
	if not item_grid_items or not item_grid_tomes or not item_grid_skills:
		return

	# Hide all grids
	item_grid_items.visible = false
	item_grid_tomes.visible = false
	item_grid_skills.visible = false

	# Show selected grid and load data
	match tab_index:
		0: # Items tab
			item_grid_items.visible = true
			load_items_data()
		1: # Tomes tab
			item_grid_tomes.visible = true
			load_tomes_data()
		2: # Skills tab
			item_grid_skills.visible = true
			load_skills_data()

func load_items_data(data: Array[Dictionary] = []) -> void:
	"""Load items unlock data.

	Args:
		data: Optional array of unlock entries. If empty, uses data provider callback.
	"""
	var unlock_data = data
	if unlock_data.is_empty() and _items_data_provider.is_valid():
		unlock_data = _items_data_provider.call()

	_populate_grid(item_grid_items, unlock_data)

func load_tomes_data(data: Array[Dictionary] = []) -> void:
	"""Load tomes unlock data.

	Args:
		data: Optional array of unlock entries. If empty, uses data provider callback.
	"""
	var unlock_data = data
	if unlock_data.is_empty() and _tomes_data_provider.is_valid():
		unlock_data = _tomes_data_provider.call()

	_populate_grid(item_grid_tomes, unlock_data)

func load_skills_data(data: Array[Dictionary] = []) -> void:
	"""Load skills unlock data.

	Args:
		data: Optional array of unlock entries. If empty, uses data provider callback.
	"""
	var unlock_data = data
	if unlock_data.is_empty() and _skills_data_provider.is_valid():
		unlock_data = _skills_data_provider.call()

	_populate_grid(item_grid_skills, unlock_data)

func _populate_grid(container: GridContainer, data: Array) -> void:
	"""Populate unlock grid with item buttons.

	Args:
		container: GridContainer to populate
		data: Array of unlock item data dictionaries
	"""
	if not container:
		return

	# Clear existing entries
	for child in container.get_children():
		child.queue_free()

	# Create new item buttons
	# TODO(UI-phase2): Create UnlockItemButton component and instantiate here
	# For now, just add placeholder labels
	for item_data in data:
		var placeholder = Label.new()
		placeholder.text = item_data.get("name", "Item")
		placeholder.custom_minimum_size = Vector2(60, 60)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		container.add_child(placeholder)

	# Clear item details when grid refreshes
	_clear_item_details()

func _update_currency_display() -> void:
	"""Update Rift Fragments currency display from MetaProgression."""
	if not currency_value_label:
		return

	if MetaProgression:
		var fragments = MetaProgression.get_rift_fragments()
		currency_value_label.text = str(fragments)
	else:
		currency_value_label.text = "0"
		Logger.warn("UnlockShop: MetaProgression not available", "ui")

func _clear_item_details() -> void:
	"""Clear the item details panel."""
	if item_name_label:
		item_name_label.text = "Select an item"
	if item_description_label:
		item_description_label.text = "Item description will appear here"
	if item_stats_label:
		item_stats_label.text = ""
	if item_flavor_label:
		item_flavor_label.text = ""
	if quest_progress_label:
		quest_progress_label.text = "Quest Progress"
	if unlock_button:
		unlock_button.visible = false

	_selected_item = {}

func _on_item_selected(item_data: Dictionary) -> void:
	"""Handle item selection from grid.

	Args:
		item_data: Dictionary containing item unlock data
	"""
	_selected_item = item_data

	# Update item details panel
	if item_name_label:
		item_name_label.text = item_data.get("name", "Unknown Item")
	if item_description_label:
		item_description_label.text = item_data.get("description", "")
	if item_stats_label:
		item_stats_label.text = item_data.get("stats", "")
	if item_flavor_label:
		item_flavor_label.text = item_data.get("flavor_text", "")

	# Update quest progress
	if quest_progress_label:
		var progress = item_data.get("quest_progress", {})
		if progress.has("current") and progress.has("required"):
			quest_progress_label.text = "Quest: %d / %d" % [progress.current, progress.required]
		else:
			quest_progress_label.text = ""

	# Show unlock button if item is unlockable
	if unlock_button:
		var is_locked = item_data.get("is_locked", true)
		var can_afford = item_data.get("cost", 0) <= MetaProgression.get_rift_fragments() if MetaProgression else false
		unlock_button.visible = is_locked and can_afford

func _on_unlock_button_pressed() -> void:
	"""Handle unlock button press - purchase selected item."""
	if _selected_item.is_empty():
		Logger.warn("UnlockShop: Unlock pressed with no item selected", "ui")
		return

	var item_id = _selected_item.get("id", "")
	var cost = _selected_item.get("cost", 0)

	if not MetaProgression:
		Logger.error("UnlockShop: MetaProgression not available", "ui")
		return

	if MetaProgression.get_rift_fragments() < cost:
		Logger.warn("UnlockShop: Not enough Rift Fragments to unlock %s" % item_id, "ui")
		return

	# Deduct cost and unlock item
	# TODO(UI-phase2): Implement unlock system in MetaProgression
	# MetaProgression.spend_rift_fragments(cost)
	# MetaProgression.unlock_item(item_id)

	Logger.info("UnlockShop: Item unlocked: %s for %d fragments" % [item_id, cost], "ui")

	# Refresh currency display
	_update_currency_display()

	# Refresh current tab to update unlock states
	refresh_current_tab()

func switch_to_items() -> void:
	"""Programmatically switch to Items tab."""
	if tab_bar:
		tab_bar.current_tab = 0

func switch_to_tomes() -> void:
	"""Programmatically switch to Tomes tab."""
	if tab_bar:
		tab_bar.current_tab = 1

func switch_to_skills() -> void:
	"""Programmatically switch to Skills tab."""
	if tab_bar:
		tab_bar.current_tab = 2

func refresh_current_tab() -> void:
	"""Reload data for currently visible tab."""
	if tab_bar:
		_on_tab_changed(tab_bar.current_tab)
