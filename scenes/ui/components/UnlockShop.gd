extends Control
class_name UnlockShop

## Reusable Unlock Shop component with Items/Tomes/Skills/Characters tabs
## Manages tab switching and item grid population with icon-based cards
## Integrates with MetaProgression for discovery/unlock states
## Currency display handled by PersistentRiftFragments autoload

@onready var tab_bar: TabBar = %TabBar

# Notification icon
var _notification_icon: Texture2D = null

# Item grid containers (one per tab) - using unique names
@onready var item_grid_items: GridContainer = %ItemsGrid
@onready var item_grid_tomes: GridContainer = %TomesGrid
@onready var item_grid_skills: GridContainer = %SkillsGrid
@onready var item_grid_characters: GridContainer = %CharactersGrid

# Item details panel labels - using unique names
@onready var item_name_label: Label = %ItemName
@onready var item_description_label: Label = %ItemDescription
@onready var item_stats_label: Label = %ItemStats
@onready var item_flavor_label: Label = %ItemFlavorText
@onready var quest_progress_label: Label = %QuestProgress
@onready var unlock_button: Button = %UnlockButton

# Data providers for each category (Callable pattern from Leaderboard)
var _items_data_provider: Callable
var _tomes_data_provider: Callable
var _skills_data_provider: Callable
var _characters_data_provider: Callable

# Currently selected item (can be ItemMetadata, BaseTome, or BaseItem)
var _selected_item: Variant = null

func _ready() -> void:
	# Load notification icon and scale to half size
	var original_icon = load("res://assets/ui/map_markers/attention.png") as Texture2D
	if original_icon:
		var img = original_icon.get_image()
		var new_size = Vector2i(img.get_width() / 2, img.get_height() / 2)
		img.resize(new_size.x, new_size.y, Image.INTERPOLATE_LANCZOS)
		_notification_icon = ImageTexture.create_from_image(img)

	# Connect tab switching
	if tab_bar:
		tab_bar.tab_changed.connect(_on_tab_changed)

	Logger.debug("UnlockShop initialized", "ui")

func _update_tab_notification_badges() -> void:
	"""Update tab icons with notification badge if category has discovered but unlocked items."""
	if not tab_bar or not MetaProgression or not _notification_icon:
		return

	var categories = [
		{"index": 0, "name": "Items", "category": "items"},
		{"index": 1, "name": "Tomes", "category": "tomes"},
		{"index": 2, "name": "Skills", "category": "skills"},
		{"index": 3, "name": "Characters", "category": "characters"}
	]

	for cat in categories:
		var has_discovered = _category_has_discovered_items(cat.category)

		# Reset title to base name
		tab_bar.set_tab_title(cat.index, cat.name)

		# Set icon if has discovered items, otherwise clear icon
		if has_discovered:
			tab_bar.set_tab_icon(cat.index, _notification_icon)
		else:
			tab_bar.set_tab_icon(cat.index, null)

func _category_has_discovered_items(category: String) -> bool:
	"""Check if category has any discovered but not unlocked items."""
	if not MetaProgression:
		return false

	var discovered_array: Array
	var unlocked_array: Array

	match category:
		"items":
			discovered_array = MetaProgression._data.discovered_items
			unlocked_array = MetaProgression._data.unlocked_items
		"tomes":
			discovered_array = MetaProgression._data.discovered_tomes
			unlocked_array = MetaProgression._data.unlocked_tomes
		"skills":
			discovered_array = MetaProgression._data.discovered_skills
			unlocked_array = MetaProgression._data.unlocked_skills
		"characters":
			discovered_array = MetaProgression._data.discovered_characters if "discovered_characters" in MetaProgression._data else []
			unlocked_array = MetaProgression._data.unlocked_characters if "unlocked_characters" in MetaProgression._data else []

	# Check if there are any discovered items that are NOT unlocked
	for item_id in discovered_array:
		if not unlocked_array.has(item_id):
			return true

	return false

func setup_data_providers(items_provider: Callable, tomes_provider: Callable, skills_provider: Callable, characters_provider: Callable) -> void:
	"""Configure data loading callbacks and initialize with Items tab.

	Args:
		items_provider: Callable that returns Array[ItemMetadata] for items category
		tomes_provider: Callable that returns Array[ItemMetadata] for tomes category
		skills_provider: Callable that returns Array[ItemMetadata] for skills category
		characters_provider: Callable that returns Array[ItemMetadata] for characters category
	"""
	_items_data_provider = items_provider
	_tomes_data_provider = tomes_provider
	_skills_data_provider = skills_provider
	_characters_data_provider = characters_provider

	# Load initial data for Items tab (index 0)
	if tab_bar:
		tab_bar.current_tab = 0
	_on_tab_changed(0)

	# Update notification badges
	_update_tab_notification_badges()

func _on_tab_changed(tab_index: int) -> void:
	"""Switch between Items, Tomes, Skills, and Characters tabs."""
	if not item_grid_items or not item_grid_tomes or not item_grid_skills or not item_grid_characters:
		return

	# Hide all grids
	item_grid_items.visible = false
	item_grid_tomes.visible = false
	item_grid_skills.visible = false
	item_grid_characters.visible = false

	# Show selected grid and load data
	match tab_index:
		0: # Items tab
			item_grid_items.visible = true
			_load_and_populate_grid(item_grid_items, _items_data_provider)
		1: # Tomes tab
			item_grid_tomes.visible = true
			_load_and_populate_grid(item_grid_tomes, _tomes_data_provider)
		2: # Skills tab
			item_grid_skills.visible = true
			_load_and_populate_grid(item_grid_skills, _skills_data_provider)
		3: # Characters tab
			item_grid_characters.visible = true
			_load_and_populate_grid(item_grid_characters, _characters_data_provider)

func _load_and_populate_grid(container: GridContainer, data_provider: Callable) -> void:
	"""Load data from provider and populate grid with icon-based item cards.

	Args:
		container: GridContainer to populate
		data_provider: Callable that returns Array[ItemMetadata]
	"""
	if not container or not data_provider.is_valid():
		return

	# Clear existing entries
	for child in container.get_children():
		child.queue_free()

	# Get data from provider
	var item_array: Array = data_provider.call()

	# Show message if no items exist
	if item_array.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No items available yet."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(empty_label)
		_clear_item_details()
		return

	# Create item entry for each metadata (duck typing: ItemMetadata, BaseTome, BaseItem, or BaseAbility)
	for item_metadata in item_array:
		if item_metadata is ItemMetadata or item_metadata is BaseTome or item_metadata is BaseItem or item_metadata is BaseAbility:
			_create_shop_item_entry(container, item_metadata)

	# Auto-select first item
	if not item_array.is_empty():
		_show_item_details(item_array[0])

func _create_shop_item_entry(container: GridContainer, item_metadata: Variant) -> void:
	"""Create shop item card using ShopItemCard component.

	Args:
		container: GridContainer to add entry to
		item_metadata: ItemMetadata, BaseTome, BaseItem, or BaseAbility resource with item data
	"""
	if not MetaProgression:
		Logger.warn("UnlockShop: MetaProgression not available", "ui")
		return

	# Duck typing: Get item_id and category
	var item_id: String = ""
	if item_metadata is BaseTome:
		item_id = item_metadata.tome_id
	elif item_metadata is BaseAbility:
		item_id = item_metadata.ability_id
	elif "item_id" in item_metadata:
		item_id = item_metadata.item_id

	var category: String = item_metadata.category  # All have .category (alias or property)

	# Determine item state
	var is_discovered = MetaProgression.is_item_discovered(category, item_id)
	var is_unlocked = MetaProgression.is_item_unlocked(category, item_id)
	var can_afford = MetaProgression.can_afford(item_metadata.unlock_cost)

	# Instantiate card component
	var card_scene = preload("res://scenes/ui/components/ShopItemCard.tscn")
	var card: ShopItemCard = card_scene.instantiate()

	# Setup card with data and state
	card.setup(item_metadata, is_discovered, is_unlocked, can_afford)

	# Connect signals
	card.item_clicked.connect(_on_item_card_clicked)
	card.item_hovered.connect(_on_item_card_hovered)

	# Add to container
	container.add_child(card)

func _on_item_card_clicked(clicked_item_id: String, clicked_category: String) -> void:
	"""Handle item card click - show details for clicked item.

	Args:
		clicked_item_id: ID of the item that was clicked
		clicked_category: Category of the item (items/tomes/skills/characters)
	"""
	# Find the metadata for this item
	var data_provider: Callable
	match clicked_category:
		"items":
			data_provider = _items_data_provider
		"tomes":
			data_provider = _tomes_data_provider
		"skills":
			data_provider = _skills_data_provider
		"characters":
			data_provider = _characters_data_provider
		_:
			Logger.warn("UnlockShop: Unknown category: %s" % clicked_category, "ui")
			return

	if not data_provider.is_valid():
		return

	# Find matching metadata (duck typing: check all resource types)
	var item_array: Array = data_provider.call()
	for item_metadata in item_array:
		var matches = false
		if item_metadata is BaseTome:
			matches = (item_metadata.tome_id == clicked_item_id)
		elif item_metadata is BaseAbility:
			matches = (item_metadata.ability_id == clicked_item_id)
		elif "item_id" in item_metadata:
			matches = (item_metadata.item_id == clicked_item_id)

		if matches:
			_show_item_details(item_metadata)
			break

func _on_item_card_hovered(hovered_item_id: String, hovered_category: String) -> void:
	"""Handle item card hover - could be used for tooltip preview later.

	Args:
		hovered_item_id: ID of the item being hovered
		hovered_category: Category of the item (items/tomes/skills/characters)
	"""
	# Currently unused - placeholder for future hover preview feature
	pass

func _show_item_details(item_metadata: Variant) -> void:
	"""Display item details based on discovery/unlock state.

	Args:
		item_metadata: ItemMetadata, BaseTome, BaseItem, or BaseAbility resource to display
	"""
	if not MetaProgression:
		return

	_selected_item = item_metadata

	# Duck typing: Get item_id and category
	var item_id: String = ""
	if item_metadata is BaseTome:
		item_id = item_metadata.tome_id
	elif item_metadata is BaseAbility:
		item_id = item_metadata.ability_id
	elif "item_id" in item_metadata:
		item_id = item_metadata.item_id

	var category: String = item_metadata.category

	var is_discovered = MetaProgression.is_item_discovered(category, item_id)
	var is_unlocked = MetaProgression.is_item_unlocked(category, item_id)
	var can_afford = MetaProgression.can_afford(item_metadata.unlock_cost)

	# UNDISCOVERED + LOCKED: Show only quest requirement
	if not is_discovered and not is_unlocked:
		item_name_label.text = "???"
		item_name_label.modulate = Color(0.6, 0.6, 0.6)

		item_description_label.text = "[Hidden until discovered]"
		item_description_label.modulate = Color(0.5, 0.5, 0.5)

		item_stats_label.text = ""
		item_flavor_label.text = ""

		quest_progress_label.text = item_metadata.discovery_requirement
		quest_progress_label.modulate = Color(1.0, 0.8, 0.3)
		quest_progress_label.visible = true

		unlock_button.visible = false

	# DISCOVERED + LOCKED: Show full details with unlock button
	elif is_discovered and not is_unlocked:
		# Duck typing: Both types have .display_name (BaseTome via alias)
		item_name_label.text = item_metadata.display_name
		item_name_label.modulate = _get_rarity_color_for_item(item_metadata)

		item_description_label.text = item_metadata.description
		item_description_label.modulate = Color.WHITE

		item_stats_label.text = item_metadata.stat_summary if "stat_summary" in item_metadata else ""
		item_stats_label.modulate = Color(0.6, 1.0, 0.6)

		item_flavor_label.text = "\"" + item_metadata.flavor_text + "\"" if ("flavor_text" in item_metadata and not item_metadata.flavor_text.is_empty()) else ""
		item_flavor_label.modulate = Color(0.7, 0.7, 0.8)

		quest_progress_label.text = "Cost: %d 💎" % item_metadata.unlock_cost
		quest_progress_label.modulate = Color.WHITE
		quest_progress_label.visible = true

		# Button text is set in scene ("BUY"), no need to override
		unlock_button.disabled = not can_afford
		unlock_button.visible = true

		# Reconnect button (clear old connections first)
		for connection in unlock_button.pressed.get_connections():
			unlock_button.pressed.disconnect(connection.callable)
		unlock_button.pressed.connect(_on_unlock_item_pressed.bind(item_metadata))

	# UNLOCKED: Show full details
	else:
		# Duck typing: Both types have .display_name (BaseTome via alias)
		item_name_label.text = item_metadata.display_name
		item_name_label.modulate = _get_rarity_color_for_item(item_metadata)

		item_description_label.text = item_metadata.description
		item_description_label.modulate = Color.WHITE

		item_stats_label.text = item_metadata.stat_summary if "stat_summary" in item_metadata else ""
		item_stats_label.modulate = Color(0.6, 1.0, 0.6)

		item_flavor_label.text = "\"" + item_metadata.flavor_text + "\"" if ("flavor_text" in item_metadata and not item_metadata.flavor_text.is_empty()) else ""
		item_flavor_label.modulate = Color(0.7, 0.7, 0.8)

		quest_progress_label.text = "[UNLOCKED]"
		quest_progress_label.modulate = Color(0.3, 1.0, 0.3)
		quest_progress_label.visible = true

		unlock_button.visible = false

func _get_rarity_color_for_item(item_metadata: Variant) -> Color:
	"""Get rarity color for all resource types (duck typing)."""
	if item_metadata is ItemMetadata:
		return ItemMetadata.get_rarity_color(item_metadata.rarity)
	elif item_metadata is BaseTome or item_metadata is BaseItem or item_metadata is BaseAbility:
		# Unified resources use string rarity, convert to color
		match item_metadata.rarity:
			"uncommon": return Color(0.3, 0.9, 0.3)  # Green
			"rare": return Color(0.3, 0.5, 1.0)  # Blue
			"epic": return Color(0.7, 0.3, 1.0)  # Purple
			"legendary": return Color(1.0, 0.8, 0.2)  # Gold
			_: return Color(0.6, 0.6, 0.6)  # Common (grey)
	else:
		return Color.WHITE

func _on_unlock_item_pressed(item_metadata: Variant) -> void:
	"""Handle unlock button press - purchase selected item.

	Args:
		item_metadata: ItemMetadata, BaseTome, BaseItem, or BaseAbility resource to unlock
	"""
	if not MetaProgression:
		Logger.error("UnlockShop: MetaProgression not available", "ui")
		return

	# Check affordability
	if not MetaProgression.can_afford(item_metadata.unlock_cost):
		Logger.warn("UnlockShop: Cannot afford item: %s" % item_metadata.display_name, "ui")
		return

	# Duck typing: Get item_id and category
	var item_id: String = ""
	if item_metadata is BaseTome:
		item_id = item_metadata.tome_id
	elif item_metadata is BaseAbility:
		item_id = item_metadata.ability_id
	elif "item_id" in item_metadata:
		item_id = item_metadata.item_id

	var category: String = item_metadata.category

	# Spend Rift Fragments and unlock
	if MetaProgression.spend_rift_fragments(item_metadata.unlock_cost):
		MetaProgression.unlock_item(category, item_id)

		Logger.info("UnlockShop: Unlocked %s for %d Rift Fragments" % [
			item_metadata.display_name, item_metadata.unlock_cost
		], "ui")

		# Refresh display (currency updated by PersistentRiftFragments via EventBus)
		refresh_current_tab()
		_update_tab_notification_badges()  # Update badges when item unlocked

func _clear_item_details() -> void:
	"""Clear the item details panel."""
	item_name_label.text = "Select an item"
	item_description_label.text = "Item description will appear here"
	item_stats_label.text = ""
	item_flavor_label.text = ""
	quest_progress_label.text = "Quest Progress"
	unlock_button.visible = false
	_selected_item = null

func refresh_current_tab() -> void:
	"""Reload data for currently visible tab."""
	if tab_bar:
		_on_tab_changed(tab_bar.current_tab)

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
