extends Control
## UnlockShopScene wrapper - handles navigation and data provider setup
##
## Flow: MainMenu → **UnlockShopScene** ← (Back button)
##
## Features:
## - Provides data to UnlockShop component via Callable providers
## - Handles back navigation to MainMenu
## - Sets up mock unlock data (TODO: integrate with MetaProgression)

@onready var unlock_shop: UnlockShop = $UnlockShop
@onready var back_button: Button = $BackButton

func _ready() -> void:
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
			_fetch_skills_data
		)
		Logger.info("UnlockShopScene initialized with data providers", "ui")
	else:
		Logger.error("UnlockShopScene: UnlockShop component not found", "ui")

func _fetch_items_data() -> Array[Dictionary]:
	"""Callback for UnlockShop component - provides items unlock data.

	Returns:
		Array[Dictionary]: Item unlock data with keys: id, name, description, cost, is_locked, etc.
	"""
	# TODO(UI-phase2): Fetch from MetaProgression unlock system
	var mock_items: Array[Dictionary] = [
		{
			"id": "sword_t1",
			"name": "Iron Sword",
			"description": "A basic iron sword",
			"cost": 100,
			"is_locked": true,
			"stats": "+10 Attack",
			"flavor_text": "Every hero needs a starting weapon.",
			"quest_progress": {"current": 5, "required": 10}
		},
		{
			"id": "armor_t1",
			"name": "Leather Armor",
			"description": "Simple leather protection",
			"cost": 150,
			"is_locked": false,
			"stats": "+5 Defense",
			"flavor_text": "Better than nothing."
		}
	]

	return mock_items

func _fetch_tomes_data() -> Array[Dictionary]:
	"""Callback for UnlockShop component - provides tomes unlock data.

	Returns:
		Array[Dictionary]: Tome unlock data
	"""
	# TODO(UI-phase2): Fetch from MetaProgression unlock system
	var mock_tomes: Array[Dictionary] = [
		{
			"id": "fireball_tome",
			"name": "Fireball Tome",
			"description": "Learn Fireball ability",
			"cost": 200,
			"is_locked": true,
			"stats": "Damage: 50 Fire",
			"flavor_text": "The classic mage's choice."
		}
	]

	return mock_tomes

func _fetch_skills_data() -> Array[Dictionary]:
	"""Callback for UnlockShop component - provides skills unlock data.

	Returns:
		Array[Dictionary]: Skill unlock data
	"""
	# TODO(UI-phase2): Fetch from MetaProgression unlock system
	var mock_skills: Array[Dictionary] = [
		{
			"id": "critical_strike",
			"name": "Critical Strike",
			"description": "Increase crit chance",
			"cost": 250,
			"is_locked": true,
			"stats": "+10% Crit Chance",
			"flavor_text": "Strike where it hurts most."
		}
	]

	return mock_skills

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
