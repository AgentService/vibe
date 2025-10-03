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

@onready var unlock_shop: UnlockShop = $UnlockShop
@onready var back_button: Button = $BackButton
@onready var admin_panel: ShopAdminPanel = $ShopAdminPanel

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
	"""Load item metadata from /data/content/{items,tomes,skills,characters}/*.tres"""
	var categories = ["items", "tomes", "skills", "characters"]

	for category in categories:
		var category_dir = "res://data/content/%s/" % category
		var dir = DirAccess.open(category_dir)

		if not dir:
			Logger.warn("UnlockShopScene: Category directory not found: %s" % category_dir, "ui")
			continue

		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tres"):
				var file_path = category_dir + file_name
				var resource = load(file_path)

				if resource is ItemMetadata:
					item_metadata_cache[resource.item_id] = resource
					Logger.debug("UnlockShopScene: Loaded item metadata: %s" % resource.item_id, "ui")
				else:
					Logger.warn("UnlockShopScene: Invalid ItemMetadata resource: %s" % file_path, "ui")

			file_name = dir.get_next()

		dir.list_dir_end()

	Logger.info("UnlockShopScene: Loaded %d items from data files" % item_metadata_cache.size(), "ui")

func _fetch_items_data() -> Array[ItemMetadata]:
	"""Callback for UnlockShop component - provides items unlock data.

	Returns:
		Array[ItemMetadata]: Item metadata resources for "items" category
	"""
	var category_items: Array[ItemMetadata] = []

	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]
		if metadata.category == "items":
			category_items.append(metadata)

	# Sort by rarity (Common → Legendary)
	category_items.sort_custom(func(a: ItemMetadata, b: ItemMetadata) -> bool:
		return a.rarity < b.rarity
	)

	return category_items

func _fetch_tomes_data() -> Array[ItemMetadata]:
	"""Callback for UnlockShop component - provides tomes unlock data.

	Returns:
		Array[ItemMetadata]: Item metadata resources for "tomes" category
	"""
	var category_items: Array[ItemMetadata] = []

	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]
		if metadata.category == "tomes":
			category_items.append(metadata)

	# Sort by rarity (Common → Legendary)
	category_items.sort_custom(func(a: ItemMetadata, b: ItemMetadata) -> bool:
		return a.rarity < b.rarity
	)

	return category_items

func _fetch_skills_data() -> Array[ItemMetadata]:
	"""Callback for UnlockShop component - provides skills unlock data.

	Returns:
		Array[ItemMetadata]: Item metadata resources for "skills" category
	"""
	var category_items: Array[ItemMetadata] = []

	for item_id in item_metadata_cache.keys():
		var metadata = item_metadata_cache[item_id]
		if metadata.category == "skills":
			category_items.append(metadata)

	# Sort by rarity (Common → Legendary)
	category_items.sort_custom(func(a: ItemMetadata, b: ItemMetadata) -> bool:
		return a.rarity < b.rarity
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
