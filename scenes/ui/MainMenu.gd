extends Control

## MainMenu - Character/Map/Tier Selection + Unlocks Shop
## Four screens: Main Menu → Character Select → Map/Tier Select → Arena
##              Main Menu → Unlocks Shop → Main Menu

# Screen containers
@onready var main_menu_container: Control = $BackgroundPanel/MainMenuContainer
@onready var character_select_container: Control = $BackgroundPanel/CharacterSelectContainer
@onready var map_select_container: Control = $BackgroundPanel/MapSelectContainer
@onready var unlocks_shop_container: Control = $BackgroundPanel/UnlocksShopContainer

# Main Menu elements
@onready var title_label: Label = $BackgroundPanel/MainMenuContainer/CenterContainer/VBoxContainer/TitleLabel
@onready var rift_fragments_value: Label = $BackgroundPanel/MainMenuContainer/CenterContainer/VBoxContainer/RiftFragmentsContainer/RiftFragmentsValue
@onready var play_button: Button = $BackgroundPanel/MainMenuContainer/CenterContainer/VBoxContainer/PlayButton
@onready var shop_button: Button = $BackgroundPanel/MainMenuContainer/CenterContainer/VBoxContainer/ShopButton
@onready var quit_button: Button = $BackgroundPanel/MainMenuContainer/CenterContainer/VBoxContainer/QuitButton

# Character Select elements
@onready var char_title: Label = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharTitle
@onready var knight_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharacterButtons/KnightButton
@onready var ranger_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharacterButtons/RangerButton
@onready var char_info_label: Label = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharInfoLabel
@onready var char_confirm_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharConfirmButton
@onready var char_back_button: Button = $BackgroundPanel/CharacterSelectContainer/VBoxContainer/CharBackButton

# Map Select elements
@onready var map_title: Label = $BackgroundPanel/MapSelectContainer/VBoxContainer/MapTitle
@onready var tier1_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierButtons/Tier1Button
@onready var tier2_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierButtons/Tier2Button
@onready var tier3_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierButtons/Tier3Button
@onready var tier_info_label: Label = $BackgroundPanel/MapSelectContainer/VBoxContainer/TierInfoLabel
@onready var map_start_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/MapStartButton
@onready var map_back_button: Button = $BackgroundPanel/MapSelectContainer/VBoxContainer/MapBackButton

# Leaderboard elements
@onready var leaderboard_list: VBoxContainer = $BackgroundPanel/MainMenuContainer/LeaderboardPanel/VBoxContainer/LeaderboardList

# Unlocks Shop elements
@onready var shop_rift_fragments_value: Label = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/RiftFragmentsDisplay/RiftFragmentsValue
@onready var items_tab: Button = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/CategoryTabs/ItemsTab
@onready var tomes_tab: Button = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/CategoryTabs/TomesTab
@onready var skills_tab: Button = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/CategoryTabs/SkillsTab
@onready var shop_item_list: GridContainer = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemListScroll/ItemList
@onready var shop_item_details_panel: PanelContainer = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemDetailsPanel
@onready var shop_item_name: Label = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemName
@onready var shop_item_description: Label = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemDescription
@onready var shop_item_stats: Label = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemStats
@onready var shop_item_flavor: Label = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/LeftPanel/ItemFlavorText
@onready var shop_quest_progress: Label = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/RightPanel/QuestProgress
@onready var shop_unlock_button: Button = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ItemDetailsPanel/MarginContainer/HBoxContainer/RightPanel/UnlockButton
@onready var shop_back_button: Button = $BackgroundPanel/UnlocksShopContainer/VBoxContainer/ShopBackButton

# Selection state
var selected_character: String = ""
var selected_tier: int = 1
var selected_shop_category: String = "items"

# Character data
var character_types: Dictionary = {}

# Item metadata cache (loaded from /data/content/items/*.tres)
var item_metadata_cache: Dictionary = {}  # {item_id: ItemMetadata}

func _ready() -> void:
	Logger.info("MainMenu initialized", "ui")

	_load_character_types()
	_load_item_metadata()
	_show_main_menu()
	_connect_signals()
	_update_rift_fragments_display()

	# Defer leaderboard display to ensure LocalLeaderboard has loaded
	call_deferred("_update_leaderboard_display")

	# Connect to EventBus for Rift Fragments updates
	if EventBus:
		EventBus.rift_fragments_changed.connect(_on_rift_fragments_changed)
		EventBus.leaderboard_updated.connect(_on_leaderboard_updated)
		EventBus.item_unlocked.connect(_on_item_unlocked)

func _load_character_types() -> void:
	"""Load character types from data file."""
	var character_data = load("res://data/core/character-types.tres")
	if character_data and character_data.character_types:
		character_types = character_data.character_types
		Logger.info("Loaded %d character types" % character_types.size(), "ui")
	else:
		Logger.error("Failed to load character-types.tres", "ui")

func _load_item_metadata() -> void:
	"""Load item metadata from /data/content/{items,tomes,skills}/*.tres"""
	var categories = ["items", "tomes", "skills"]

	for category in categories:
		var category_dir = "res://data/content/%s/" % category
		var dir = DirAccess.open(category_dir)

		if not dir:
			Logger.warn("Failed to open %s directory: %s" % [category, category_dir], "ui")
			continue

		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			# Only load .tres files (skip README.md, etc.)
			if file_name.ends_with(".tres"):
				var path = category_dir + file_name
				var item_metadata = load(path) as ItemMetadata
				if item_metadata:
					item_metadata_cache[item_metadata.item_id] = item_metadata
					Logger.debug("Loaded %s metadata: %s" % [category, item_metadata.item_id], "ui")
				else:
					Logger.warn("Failed to load metadata from: %s" % path, "ui")

			file_name = dir.get_next()

		dir.list_dir_end()

	Logger.info("Loaded %d total metadata entries across all categories" % item_metadata_cache.size(), "ui")

func _connect_signals() -> void:
	"""Connect all button signals."""
	# Main Menu
	play_button.pressed.connect(_on_play_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Character Select
	knight_button.pressed.connect(func(): _on_character_selected("knight"))
	ranger_button.pressed.connect(func(): _on_character_selected("ranger"))
	char_confirm_button.pressed.connect(_on_char_confirm_pressed)
	char_back_button.pressed.connect(_show_main_menu)

	# Map Select
	tier1_button.pressed.connect(func(): _on_tier_selected(1))
	tier2_button.pressed.connect(func(): _on_tier_selected(2))
	tier3_button.pressed.connect(func(): _on_tier_selected(3))
	map_start_button.pressed.connect(_on_start_run_pressed)
	map_back_button.pressed.connect(_show_character_select)

	# Unlocks Shop
	items_tab.pressed.connect(func(): _on_shop_category_selected("items"))
	tomes_tab.pressed.connect(func(): _on_shop_category_selected("tomes"))
	skills_tab.pressed.connect(func(): _on_shop_category_selected("skills"))
	shop_back_button.pressed.connect(_show_main_menu)

# ============================================================================
# SCREEN NAVIGATION
# ============================================================================

func _show_main_menu() -> void:
	"""Show main menu, hide other screens."""
	main_menu_container.visible = true
	character_select_container.visible = false
	map_select_container.visible = false
	unlocks_shop_container.visible = false
	play_button.grab_focus()
	_update_rift_fragments_display()
	Logger.debug("Showing main menu", "ui")

func _show_character_select() -> void:
	"""Show character select screen."""
	main_menu_container.visible = false
	character_select_container.visible = true
	map_select_container.visible = false
	unlocks_shop_container.visible = false

	# Reset selection
	selected_character = ""
	_update_character_ui()
	knight_button.grab_focus()
	Logger.debug("Showing character select", "ui")

func _show_map_select() -> void:
	"""Show map/tier select screen."""
	main_menu_container.visible = false
	character_select_container.visible = false
	map_select_container.visible = true
	unlocks_shop_container.visible = false

	# Default to Tier 1
	selected_tier = 1
	_update_tier_ui()
	tier1_button.grab_focus()
	Logger.debug("Showing map select", "ui")

func _show_unlocks_shop() -> void:
	"""Show unlocks shop screen."""
	main_menu_container.visible = false
	character_select_container.visible = false
	map_select_container.visible = false
	unlocks_shop_container.visible = true

	# Update shop display
	selected_shop_category = "items"
	_update_shop_ui()
	items_tab.grab_focus()
	Logger.debug("Showing unlocks shop", "ui")

# ============================================================================
# MAIN MENU HANDLERS
# ============================================================================

func _on_play_pressed() -> void:
	"""Handle Play button - go to character select."""
	Logger.info("Play pressed", "ui")
	_show_character_select()

func _on_shop_pressed() -> void:
	"""Handle Shop button - go to unlocks shop."""
	Logger.info("Shop pressed", "ui")
	_show_unlocks_shop()

func _on_quit_pressed() -> void:
	"""Handle Quit button."""
	Logger.info("Quit pressed", "ui")
	get_tree().quit()

# ============================================================================
# CHARACTER SELECT HANDLERS
# ============================================================================

func _on_character_selected(character: String) -> void:
	"""Handle character button press."""
	selected_character = character
	_update_character_ui()
	Logger.info("Character selected: %s" % character, "ui")

func _update_character_ui() -> void:
	"""Update character selection UI."""
	# Update button states
	knight_button.disabled = (selected_character == "knight")
	ranger_button.disabled = (selected_character == "ranger")

	# Update info label
	if selected_character.is_empty():
		char_info_label.text = "Select a character"
		char_confirm_button.disabled = true
	else:
		if character_types.has(selected_character):
			var char_type = character_types[selected_character]
			char_info_label.text = "%s\n%s\nHP: %.0f | Damage: %.0f | Speed: %.1f" % [
				char_type.display_name,
				char_type.description,
				char_type.base_hp,
				char_type.base_damage,
				char_type.base_speed
			]
		else:
			char_info_label.text = "Character data not found"
		char_confirm_button.disabled = false

func _on_char_confirm_pressed() -> void:
	"""Confirm character selection and move to map select."""
	if selected_character.is_empty():
		Logger.warn("No character selected", "ui")
		return

	Logger.info("Character confirmed: %s" % selected_character, "ui")
	_show_map_select()

# ============================================================================
# MAP SELECT HANDLERS
# ============================================================================

func _on_tier_selected(tier: int) -> void:
	"""Handle tier button press."""
	selected_tier = tier
	_update_tier_ui()
	Logger.info("Tier selected: %d" % tier, "ui")

func _update_tier_ui() -> void:
	"""Update tier selection UI."""
	# Update button states
	tier1_button.disabled = (selected_tier == 1)
	tier2_button.disabled = (selected_tier == 2)
	tier3_button.disabled = (selected_tier == 3)

	# Update info label
	match selected_tier:
		1:
			tier_info_label.text = "Tier 1: Normal difficulty\nBase Rift Fragments"
		2:
			tier_info_label.text = "Tier 2: Hard difficulty\n+10% Rift Fragments"
		3:
			tier_info_label.text = "Tier 3: Expert difficulty\n+20% Rift Fragments"

func _on_start_run_pressed() -> void:
	"""Start the run with selected character and tier."""
	if selected_character.is_empty():
		Logger.error("No character selected", "ui")
		return

	Logger.info("Starting run: %s on Tier %d" % [selected_character, selected_tier], "ui")

	# Start run through SessionState
	if SessionState:
		SessionState.start_run(selected_character, "forest_arena", selected_tier)

	# Prepare context like hideout MapDevice does
	var context = {
		"character": selected_character,
		"spawn_point": "PlayerSpawnPoint",
		"source": "main_menu_selection",
		"tier": selected_tier,
		"character_data": {}  # Empty for now, player will spawn fresh
	}

	# Transition to PathAware arena (same as hideout flow)
	if StateManager:
		StateManager.start_run(&"pathgen_arena", context)

# ============================================================================
# RIFT FRAGMENTS DISPLAY
# ============================================================================

func _update_rift_fragments_display() -> void:
	"""Update the Rift Fragments display."""
	if MetaProgression:
		var balance = MetaProgression.get_rift_fragments()
		rift_fragments_value.text = str(balance)
		Logger.debug("Updated Rift Fragments: %d" % balance, "ui")
	else:
		rift_fragments_value.text = "0"

func _on_rift_fragments_changed(new_balance: int) -> void:
	"""Handle Rift Fragments balance changes."""
	rift_fragments_value.text = str(new_balance)
	Logger.debug("Rift Fragments updated to: %d" % new_balance, "ui")

# ============================================================================
# LEADERBOARD DISPLAY
# ============================================================================

func _update_leaderboard_display() -> void:
	"""Update the leaderboard with personal bests for each character."""
	# Clear existing entries
	for child in leaderboard_list.get_children():
		child.queue_free()

	if not LocalLeaderboard:
		Logger.warn("LocalLeaderboard not available", "ui")
		return

	# Debug: Check what maps exist
	var maps = LocalLeaderboard.get_maps_with_entries()
	Logger.debug("Maps with entries: %s" % str(maps), "ui")

	# For each character type, find their personal best across all maps/tiers
	for char_id in character_types.keys():
		var best_kills = _get_character_best_kills(char_id)

		# Create label for this character
		var label = Label.new()
		if best_kills > 0:
			var char_name = character_types[char_id].display_name if character_types.has(char_id) else char_id.capitalize()
			label.text = "%s: %d kills" % [char_name, best_kills]
			Logger.debug("Character %s: %d kills" % [char_id, best_kills], "ui")
		else:
			var char_name = character_types[char_id].display_name if character_types.has(char_id) else char_id.capitalize()
			label.text = "%s: No runs yet" % char_name
			Logger.debug("Character %s: No runs found" % char_id, "ui")

		leaderboard_list.add_child(label)

	Logger.debug("Leaderboard display updated", "ui")

func _get_character_best_kills(char_id: String) -> int:
	"""Get the highest kill count for a character across all maps and tiers."""
	var best_kills = 0

	# Check all maps
	var maps = LocalLeaderboard.get_maps_with_entries()
	for map_id in maps:
		# Check all tiers for this map
		var tiers = LocalLeaderboard.get_tiers_with_entries(map_id)
		for tier in tiers:
			# Get leaderboard for this map+tier
			var leaderboard = LocalLeaderboard.get_leaderboard(map_id, tier)

			# Find best run for this character
			for entry in leaderboard:
				if entry.character_id == char_id:
					var kills = entry.get("kills", 0)
					if kills > best_kills:
						best_kills = kills

	return best_kills

func _on_leaderboard_updated(_map_id: String, _tier: int, _rank: int) -> void:
	"""Handle leaderboard updates to refresh display."""
	_update_leaderboard_display()

# ============================================================================
# UNLOCKS SHOP HANDLERS
# ============================================================================

func _on_shop_category_selected(category: String) -> void:
	"""Handle category tab selection."""
	selected_shop_category = category

	# Update tab button states
	items_tab.button_pressed = (category == "items")
	tomes_tab.button_pressed = (category == "tomes")
	skills_tab.button_pressed = (category == "skills")

	_update_shop_ui()
	Logger.debug("Shop category selected: %s" % category, "ui")

func _update_shop_ui() -> void:
	"""Update shop display with ALL items (showing locked/discovered/unlocked states)."""
	# Clear existing items
	for child in shop_item_list.get_children():
		child.queue_free()

	# Update Rift Fragments display
	if MetaProgression:
		var balance = MetaProgression.get_rift_fragments()
		shop_rift_fragments_value.text = str(balance)

	if not MetaProgression:
		Logger.warn("MetaProgression not available", "ui")
		return

	# Get ALL items for this category from metadata cache
	var category_items: Array[ItemMetadata] = []
	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]
		if metadata.category == selected_shop_category:
			category_items.append(metadata)

	# Sort by rarity (Common → Legendary)
	category_items.sort_custom(func(a: ItemMetadata, b: ItemMetadata) -> bool:
		return a.rarity < b.rarity
	)

	# Show message if no items exist for this category
	if category_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No %s available yet." % selected_shop_category
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_item_list.add_child(empty_label)
		# Keep details panel visible but show placeholder
		_show_empty_details()
		return

	# Create item entry for each item (regardless of discovery state)
	for item_metadata in category_items:
		_create_shop_item_entry(item_metadata)

	# Auto-select first item to show details
	if not category_items.is_empty():
		_show_item_details(category_items[0])

func _create_shop_item_entry(item_metadata: ItemMetadata) -> void:
	"""Create icon-based shop item card with state visualization."""
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

	# Icon (placeholder for now - will be TextureRect later)
	var icon_label = Label.new()
	icon_label.custom_minimum_size = Vector2(64, 64)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# State-based icon appearance
	if is_unlocked or (is_discovered and is_unlocked):
		# UNLOCKED: Full color icon
		icon_label.text = "🎯"  # Placeholder - will be actual icon texture
		icon_label.modulate = ItemMetadata.get_rarity_color(item_metadata.rarity)
		center_container.add_child(icon_label)

	elif not is_discovered and not is_unlocked:
		# UNDISCOVERED + LOCKED: Black silhouette only
		icon_label.text = "❓"  # Placeholder - will be black silhouette texture
		icon_label.modulate = Color(0.2, 0.2, 0.2)
		center_container.add_child(icon_label)

	elif is_discovered and not is_unlocked:
		# DISCOVERED + LOCKED: Full color icon with full-rect overlay modal
		icon_label.text = "🎯"  # Placeholder - will be actual icon texture
		icon_label.modulate = ItemMetadata.get_rarity_color(item_metadata.rarity)
		center_container.add_child(icon_label)

		# Full-rect semi-transparent dimming overlay (mini modal)
		var overlay_container = Control.new()
		overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry_container.add_child(overlay_container)

		# Dark background panel (full rect)
		var overlay_bg = ColorRect.new()
		overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_bg.color = Color(0, 0, 0, 0.75)  # More dimming (0.75 alpha)
		overlay_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_container.add_child(overlay_bg)

		# Cost display centered on overlay (white text)
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

	# Make entry clickable for ALL states (including undiscovered)
	entry_container.mouse_filter = Control.MOUSE_FILTER_STOP
	entry_container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_item_details(item_metadata)
	)

	shop_item_list.add_child(entry_container)

func _on_unlock_item_pressed(item_metadata: ItemMetadata) -> void:
	"""Handle unlock button press."""
	if not MetaProgression:
		return

	# Check affordability
	if not MetaProgression.can_afford(item_metadata.unlock_cost):
		Logger.warn("Cannot afford item: %s" % item_metadata.display_name, "ui")
		return

	# Spend Rift Fragments
	if MetaProgression.spend_rift_fragments(item_metadata.unlock_cost):
		# Unlock the item
		MetaProgression.unlock_item(selected_shop_category, item_metadata.item_id)

		Logger.info("Unlocked item: %s for %d Rift Fragments" % [
			item_metadata.display_name, item_metadata.unlock_cost
		], "ui")

		# Refresh shop display
		_update_shop_ui()

func _on_item_unlocked(_category: String, _item_id: String) -> void:
	"""Handle item unlock event."""
	# Refresh shop if visible
	if unlocks_shop_container.visible:
		_update_shop_ui()

func _show_item_details(item_metadata: ItemMetadata) -> void:
	"""Display item details based on discovery/unlock state."""
	var is_discovered = MetaProgression.is_item_discovered(item_metadata.category, item_metadata.item_id)
	var is_unlocked = MetaProgression.is_item_unlocked(item_metadata.category, item_metadata.item_id)
	var can_afford = MetaProgression.can_afford(item_metadata.unlock_cost)

	# UNDISCOVERED + LOCKED: Show only name and quest with progress tracking
	if not is_discovered and not is_unlocked:
		# Left panel
		shop_item_name.text = "???"
		shop_item_name.modulate = Color(0.6, 0.6, 0.6)

		shop_item_description.text = "[Hidden until discovered]"
		shop_item_description.modulate = Color(0.5, 0.5, 0.5)

		shop_item_stats.text = ""
		shop_item_stats.visible = false

		shop_item_flavor.text = ""
		shop_item_flavor.visible = false

		# Right panel - Quest progress
		shop_quest_progress.text = item_metadata.discovery_requirement
		shop_quest_progress.modulate = Color(1.0, 0.8, 0.3)
		shop_quest_progress.visible = true

		shop_unlock_button.visible = false

	# DISCOVERED + LOCKED: Show full details with unlock button in right panel
	elif is_discovered and not is_unlocked:
		var rarity_name = ItemMetadata.get_rarity_name(item_metadata.rarity)

		# Left panel
		shop_item_name.text = item_metadata.display_name + " (" + rarity_name + ")"
		shop_item_name.modulate = ItemMetadata.get_rarity_color(item_metadata.rarity)

		shop_item_description.text = item_metadata.description
		shop_item_description.modulate = Color.WHITE

		shop_item_stats.text = item_metadata.stat_summary
		shop_item_stats.modulate = Color(0.6, 1.0, 0.6)
		shop_item_stats.visible = true

		if item_metadata.flavor_text.is_empty():
			shop_item_flavor.text = ""
			shop_item_flavor.visible = false
		else:
			shop_item_flavor.text = "\"" + item_metadata.flavor_text + "\""
			shop_item_flavor.modulate = Color(0.7, 0.7, 0.8)
			shop_item_flavor.visible = true

		# Right panel - Replace quest with cost + buy button
		shop_quest_progress.visible = false

		shop_unlock_button.text = "%d 💎\nUNLOCK" % item_metadata.unlock_cost
		shop_unlock_button.disabled = not can_afford
		shop_unlock_button.visible = true

		# Reconnect button signal
		if shop_unlock_button.pressed.get_connections().is_empty():
			shop_unlock_button.pressed.connect(_on_unlock_item_pressed.bind(item_metadata))

	# UNLOCKED: Show full details
	else:
		var rarity_name = ItemMetadata.get_rarity_name(item_metadata.rarity)

		# Left panel
		shop_item_name.text = item_metadata.display_name + " (" + rarity_name + ")"
		shop_item_name.modulate = ItemMetadata.get_rarity_color(item_metadata.rarity)

		shop_item_description.text = item_metadata.description
		shop_item_description.modulate = Color.WHITE

		shop_item_stats.text = item_metadata.stat_summary
		shop_item_stats.modulate = Color(0.6, 1.0, 0.6)
		shop_item_stats.visible = true

		if item_metadata.flavor_text.is_empty():
			shop_item_flavor.text = ""
			shop_item_flavor.visible = false
		else:
			shop_item_flavor.text = "\"" + item_metadata.flavor_text + "\""
			shop_item_flavor.modulate = Color(0.7, 0.7, 0.8)
			shop_item_flavor.visible = true

		# Right panel - Hide quest and button
		shop_quest_progress.visible = false
		shop_unlock_button.visible = false

	shop_item_details_panel.visible = true
	Logger.debug("Showing details for: %s (discovered: %s, unlocked: %s)" % [item_metadata.display_name, is_discovered, is_unlocked], "ui")

func _show_empty_details() -> void:
	"""Show placeholder text in details panel when no item selected."""
	# Left panel
	shop_item_name.text = "Select an item"
	shop_item_name.modulate = Color(0.7, 0.7, 0.7)

	shop_item_description.text = "Choose an item from the list to view details"
	shop_item_description.modulate = Color(0.6, 0.6, 0.6)

	shop_item_stats.text = ""
	shop_item_stats.visible = false

	shop_item_flavor.text = ""
	shop_item_flavor.visible = false

	# Right panel
	shop_quest_progress.text = ""
	shop_quest_progress.visible = false

	shop_unlock_button.visible = false
