extends VBoxContainer
class_name UnlockShop

## Reusable Unlock Shop component with Items/Tomes/Skills/Characters tabs
## Manages tab switching and item grid population with icon-based cards
## Integrates with MetaProgression for discovery/unlock states
## Currency display handled by PersistentRiftFragments autoload

@onready var tab_bar: TabBar = $TabContainer/HBoxContainer/TabBar

# Item grid containers (one per tab)
@onready var item_grid_items: GridContainer = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemGridScroll/ItemGrid_Items
@onready var item_grid_tomes: GridContainer = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemGridScroll/ItemGrid_Tomes
@onready var item_grid_skills: GridContainer = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemGridScroll/ItemGrid_Skills
@onready var item_grid_characters: GridContainer = $ContentContainer/ShopContent/MarginContainer/VBoxContainer/ItemGridScroll/ItemGrid_Characters

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
var _characters_data_provider: Callable

# Currently selected item
var _selected_item: ItemMetadata = null

func _ready() -> void:
	# Connect tab switching
	if tab_bar:
		tab_bar.tab_changed.connect(_on_tab_changed)

	Logger.debug("UnlockShop initialized", "ui")

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

	# Create item entry for each metadata
	for item_metadata in item_array:
		if item_metadata is ItemMetadata:
			_create_shop_item_entry(container, item_metadata)

	# Auto-select first item
	if not item_array.is_empty() and item_array[0] is ItemMetadata:
		_show_item_details(item_array[0])

func _create_shop_item_entry(container: GridContainer, item_metadata: ItemMetadata) -> void:
	"""Create icon-based shop item card with state visualization.

	Args:
		container: GridContainer to add entry to
		item_metadata: ItemMetadata resource with item data
	"""
	if not MetaProgression:
		Logger.warn("UnlockShop: MetaProgression not available", "ui")
		return

	# Determine item state
	var is_discovered = MetaProgression.is_item_discovered(item_metadata.category, item_metadata.item_id)
	var is_unlocked = MetaProgression.is_item_unlocked(item_metadata.category, item_metadata.item_id)
	var can_afford = MetaProgression.can_afford(item_metadata.unlock_cost)

	# Main container - fixed square size
	var entry_container = PanelContainer.new()
	entry_container.custom_minimum_size = Vector2(80, 80)
	entry_container.size_flags_horizontal = 0
	entry_container.size_flags_vertical = 0

	# Center the icon content
	var center_container = CenterContainer.new()
	entry_container.add_child(center_container)

	# Load icon texture if available
	var texture: Texture2D = null
	if not item_metadata.icon_path.is_empty() and ResourceLoader.exists(item_metadata.icon_path):
		texture = load(item_metadata.icon_path)

	# State-based icon appearance
	if is_unlocked:
		# UNLOCKED: Full color icon
		_add_icon_visual(center_container, texture, Color.WHITE, item_metadata.rarity)
	elif not is_discovered:
		# UNDISCOVERED: Black silhouette
		_add_icon_visual(center_container, texture, Color(0.0, 0.0, 0.0), item_metadata.rarity, "❓")
	else:
		# DISCOVERED + LOCKED: Greyscale with cost overlay
		_add_icon_visual(center_container, texture, Color.WHITE, item_metadata.rarity)

		# Add dimming overlay with cost
		var overlay_container = Control.new()
		overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry_container.add_child(overlay_container)

		# Dark background
		var overlay_bg = ColorRect.new()
		overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_bg.color = Color(0, 0, 0, 0.50)
		overlay_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_container.add_child(overlay_bg)

		# Cost label
		var cost_center = CenterContainer.new()
		cost_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		cost_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_container.add_child(cost_center)

		var cost_label = Label.new()
		cost_label.text = "%d 💎" % item_metadata.unlock_cost
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 16)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
		cost_label.add_theme_constant_override("outline_size", 4)
		cost_center.add_child(cost_label)

	# Make entry clickable
	entry_container.mouse_filter = Control.MOUSE_FILTER_STOP
	entry_container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_item_details(item_metadata)
	)

	container.add_child(entry_container)

func _add_icon_visual(parent: CenterContainer, texture: Texture2D, modulate_color: Color, rarity: ItemMetadata.Rarity, fallback_emoji: String = "🎯") -> void:
	"""Add icon visual (texture or emoji fallback) to parent container.

	Args:
		parent: CenterContainer to add visual to
		texture: Texture2D to display (null for fallback)
		modulate_color: Color to modulate texture
		rarity: Item rarity for fallback color
		fallback_emoji: Emoji to show if no texture
	"""
	if texture:
		var icon_texture = TextureRect.new()
		icon_texture.custom_minimum_size = Vector2(64, 64)
		icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_texture.texture = texture
		icon_texture.modulate = modulate_color
		parent.add_child(icon_texture)
	else:
		# Fallback emoji
		var icon_label = Label.new()
		icon_label.text = fallback_emoji
		icon_label.custom_minimum_size = Vector2(64, 64)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.modulate = ItemMetadata.get_rarity_color(rarity) if modulate_color == Color.WHITE else modulate_color
		parent.add_child(icon_label)

func _show_item_details(item_metadata: ItemMetadata) -> void:
	"""Display item details based on discovery/unlock state.

	Args:
		item_metadata: ItemMetadata resource to display
	"""
	if not MetaProgression:
		return

	_selected_item = item_metadata

	var is_discovered = MetaProgression.is_item_discovered(item_metadata.category, item_metadata.item_id)
	var is_unlocked = MetaProgression.is_item_unlocked(item_metadata.category, item_metadata.item_id)
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
		var rarity_name = ItemMetadata.get_rarity_name(item_metadata.rarity)

		item_name_label.text = item_metadata.display_name + " (" + rarity_name + ")"
		item_name_label.modulate = ItemMetadata.get_rarity_color(item_metadata.rarity)

		item_description_label.text = item_metadata.description
		item_description_label.modulate = Color.WHITE

		item_stats_label.text = item_metadata.stat_summary
		item_stats_label.modulate = Color(0.6, 1.0, 0.6)

		item_flavor_label.text = "\"" + item_metadata.flavor_text + "\"" if not item_metadata.flavor_text.is_empty() else ""
		item_flavor_label.modulate = Color(0.7, 0.7, 0.8)

		quest_progress_label.visible = false

		unlock_button.text = "%d 💎\nUNLOCK" % item_metadata.unlock_cost
		unlock_button.disabled = not can_afford
		unlock_button.visible = true

		# Reconnect button (clear old connections first)
		for connection in unlock_button.pressed.get_connections():
			unlock_button.pressed.disconnect(connection.callable)
		unlock_button.pressed.connect(_on_unlock_item_pressed.bind(item_metadata))

	# UNLOCKED: Show full details
	else:
		var rarity_name = ItemMetadata.get_rarity_name(item_metadata.rarity)

		item_name_label.text = item_metadata.display_name + " (" + rarity_name + ")"
		item_name_label.modulate = ItemMetadata.get_rarity_color(item_metadata.rarity)

		item_description_label.text = item_metadata.description
		item_description_label.modulate = Color.WHITE

		item_stats_label.text = item_metadata.stat_summary
		item_stats_label.modulate = Color(0.6, 1.0, 0.6)

		item_flavor_label.text = "\"" + item_metadata.flavor_text + "\"" if not item_metadata.flavor_text.is_empty() else ""
		item_flavor_label.modulate = Color(0.7, 0.7, 0.8)

		quest_progress_label.text = "[UNLOCKED]"
		quest_progress_label.modulate = Color(0.3, 1.0, 0.3)
		quest_progress_label.visible = true

		unlock_button.visible = false

func _on_unlock_item_pressed(item_metadata: ItemMetadata) -> void:
	"""Handle unlock button press - purchase selected item.

	Args:
		item_metadata: ItemMetadata resource to unlock
	"""
	if not MetaProgression:
		Logger.error("UnlockShop: MetaProgression not available", "ui")
		return

	# Check affordability
	if not MetaProgression.can_afford(item_metadata.unlock_cost):
		Logger.warn("UnlockShop: Cannot afford item: %s" % item_metadata.display_name, "ui")
		return

	# Spend Rift Fragments and unlock
	if MetaProgression.spend_rift_fragments(item_metadata.unlock_cost):
		MetaProgression.unlock_item(item_metadata.category, item_metadata.item_id)

		Logger.info("UnlockShop: Unlocked %s for %d Rift Fragments" % [
			item_metadata.display_name, item_metadata.unlock_cost
		], "ui")

		# Refresh display (currency updated by PersistentRiftFragments via EventBus)
		refresh_current_tab()

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
