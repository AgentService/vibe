extends Control
## UnlockShopScene wrapper - handles navigation and metadata loading
##
## Flow: MainMenu → **UnlockShopScene** ← (Back button)
##
## Features:
## - Loads ItemMetadata from /data/content/{items,tomes,skills}/*.tres
## - Provides metadata to UnlockShop component via Callable providers
## - Handles back navigation to MainMenu
## - Integrates with MetaProgression for discovery/unlock state

@onready var unlock_shop: UnlockShop = %UnlockShop
@onready var back_button: Button = %BackButton
@onready var admin_panel: ShopAdminPanel = %ShopAdminPanel

# Item metadata cache (loaded from /data/content/*/*.tres)
var item_metadata_cache: Dictionary = {}  # {item_id: ItemMetadata}

func _ready() -> void:
	# Load item metadata first
	_load_item_metadata()

	# Setup back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		Logger.warn("UnlockShopScene: BackButton not found", "ui")

	# Setup UnlockShop with data providers
	if unlock_shop:
		unlock_shop.setup_data_providers(
			_fetch_items_data,
			_fetch_tomes_data,
			_fetch_skills_data,
			_fetch_characters_data
		)
		Logger.info("UnlockShopScene initialized with %d items loaded" % item_metadata_cache.size(), "ui")
	else:
		Logger.error("UnlockShopScene: UnlockShop component not found", "ui")

	# Setup admin panel with same data providers
	if admin_panel:
		admin_panel.setup_data_providers(
			_fetch_items_data,
			_fetch_tomes_data,
			_fetch_skills_data,
			_fetch_characters_data
		)
		# Connect signal to refresh shop when admin changes state
		admin_panel.admin_state_changed.connect(_on_admin_state_changed)
		Logger.info("UnlockShopScene: Admin panel initialized", "ui")
	else:
		Logger.warn("UnlockShopScene: Admin panel not found", "ui")

func _load_item_metadata() -> void:
	"""Load item metadata from /data/content/{items,tomes,abilities,characters}/*.tres"""
	var categories = [
		"res://data/content/items/",
		"res://data/content/tomes/",
		"res://data/content/abilities/",  # Combat abilities for skills tab
		"res://data/content/characters/"
	]

	for category_dir in categories:
		_load_from_directory_recursive(category_dir)

	Logger.info("UnlockShopScene: Loaded %d items from data files" % item_metadata_cache.size(), "ui")

func _load_from_directory_recursive(dir_path: String) -> void:
	"""Recursively load .tres files from directory and subdirectories."""
	var dir = DirAccess.open(dir_path)
	if not dir:
		Logger.warn("UnlockShopScene: Directory not found: %s" % dir_path, "ui")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var file_path = dir_path + file_name

		# Recursively load subdirectories
		if dir.current_is_dir():
			_load_from_directory_recursive(file_path + "/")
		elif file_name.ends_with(".tres"):
			var resource = load(file_path)

			# Accept unified resources (BaseItem, BaseTome, BaseAbility) and legacy (ItemMetadata)
			if resource is ItemMetadata or resource is BaseTome or resource is BaseItem or resource is BaseAbility:
				# Duck typing: Extract ID from different resource types
				var item_id_key: String = ""
				if resource is BaseTome:
					item_id_key = resource.tome_id
				elif resource is BaseItem:
					item_id_key = resource.item_id
				elif resource is BaseAbility:
					item_id_key = resource.ability_id
				else:  # ItemMetadata
					item_id_key = resource.item_id

				item_metadata_cache[item_id_key] = resource
				Logger.debug("UnlockShopScene: Loaded item metadata: %s (%s)" % [item_id_key, resource.get_class()], "ui")
			else:
				Logger.debug("UnlockShopScene: Skipped non-shop resource: %s" % file_path, "ui")

		file_name = dir.get_next()

	dir.list_dir_end()

func _fetch_items_data() -> Array:
	"""Callback for UnlockShop component - provides items unlock data.

	Returns:
		Array: Untyped array containing ItemMetadata or BaseItem resources for "items" category
	"""
	var category_items: Array = []  # Untyped to hold both ItemMetadata and BaseItem

	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]

		# Check if it's an item (BaseItem type OR ItemMetadata with category="items")
		var is_item = (metadata is BaseItem) or (metadata.category == "items")

		if is_item:
			category_items.append(metadata)

	# Sort by rarity using duck typing (handles both enum and string)
	category_items.sort_custom(func(a, b) -> bool:
		return _get_rarity_value(a) < _get_rarity_value(b)
	)

	return category_items

func _fetch_tomes_data() -> Array:
	"""Callback for UnlockShop component - provides tomes unlock data.

	Returns:
		Array: Untyped array containing ItemMetadata and/or BaseTome resources for "tomes" category
	"""
	var category_items: Array = []  # Untyped to hold both ItemMetadata and BaseTome

	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]

		# Check if it's a tome (BaseTome type OR ItemMetadata with category="tomes")
		var is_tome = (metadata is BaseTome) or (metadata.category == "tomes")

		if is_tome:
			category_items.append(metadata)

	# Sort by rarity (Common → Legendary) using duck typing
	category_items.sort_custom(func(a, b) -> bool:
		return _get_rarity_value(a) < _get_rarity_value(b)
	)

	return category_items

func _get_rarity_value(item) -> int:
	"""Get numeric rarity value for sorting (handles both enum and string)."""
	if item.rarity is int:
		return item.rarity  # ItemMetadata.Rarity enum
	else:
		# BaseTome uses string: "common", "uncommon", "rare", etc.
		match item.rarity:
			"common": return 0
			"uncommon": return 1
			"rare": return 2
			"epic": return 3
			"legendary": return 4
			_: return 0

func _fetch_skills_data() -> Array:
	"""Callback for UnlockShop component - provides skills unlock data.

	Returns:
		Array: Untyped array containing ItemMetadata or BaseAbility resources for "skills" category
	"""
	var category_items: Array = []  # Untyped to hold both ItemMetadata and BaseAbility

	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]

		# Check if it's a skill (BaseAbility type OR ItemMetadata with category="skills")
		var is_skill = (metadata is BaseAbility) or (metadata.category == "skills")

		if is_skill:
			category_items.append(metadata)

	# Sort by rarity using duck typing (handles both enum and string)
	category_items.sort_custom(func(a, b) -> bool:
		return _get_rarity_value(a) < _get_rarity_value(b)
	)

	return category_items

func _fetch_characters_data() -> Array[ItemMetadata]:
	"""Callback for UnlockShop component - provides characters unlock data.

	Returns:
		Array[ItemMetadata]: Item metadata resources for "characters" category
	"""
	var category_items: Array[ItemMetadata] = []

	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]
		if metadata.category == "characters":
			category_items.append(metadata)

	# Sort by rarity (Common → Legendary)
	category_items.sort_custom(func(a: ItemMetadata, b: ItemMetadata) -> bool:
		return a.rarity < b.rarity
	)

	return category_items

func _on_admin_state_changed(item_id: String, category: String, new_state: String) -> void:
	"""Handle admin panel state changes - refresh the shop display."""
	Logger.info("UnlockShopScene: Admin changed %s to %s" % [item_id, new_state], "ui")

	# Refresh the shop to show updated state
	if unlock_shop:
		unlock_shop.refresh_current_tab()
		unlock_shop._update_tab_notification_badges()

func _on_back_pressed() -> void:
	"""Return to MainMenu via SceneTransitionManager"""
	Logger.info("Back pressed - returning to MainMenu", "ui")

	if EventBus:
		EventBus.request_enter_map.emit({
			"map_id": "main_menu",
			"source": "unlock_shop"
		})
	else:
		Logger.error("EventBus not available - cannot return to main menu", "ui")
