extends VBoxContainer
class_name Leaderboard

## Reusable Leaderboard component with Global/Friends tabs
## Manages tab switching, data loading, and entry population
## Used in MainMenu, post-game results, profile screens

const LeaderboardEntryScene = preload("res://scenes/ui/components/LeaderboardEntry.tscn")

@onready var tab_bar: TabBar = $TabBar
@onready var global_container: VBoxContainer = $TabContent/VBoxContainer_Global
@onready var friends_container: VBoxContainer = $TabContent/VBoxContainer_Friends

# Optional callbacks for data loading
var _global_data_provider: Callable
var _friends_data_provider: Callable

func _ready() -> void:
	# Connect tab switching
	if tab_bar:
		tab_bar.tab_changed.connect(_on_tab_changed)
		# Initialize with first tab
		_on_tab_changed(0)

func setup_data_providers(global_provider: Callable, friends_provider: Callable) -> void:
	"""Configure data loading callbacks.

	Args:
		global_provider: Callable that returns Array[Dictionary] with global leaderboard data
		friends_provider: Callable that returns Array[Dictionary] with friends leaderboard data
	"""
	_global_data_provider = global_provider
	_friends_data_provider = friends_provider

func _on_tab_changed(tab_index: int) -> void:
	"""Switch between Global and Friends views."""
	if not global_container or not friends_container:
		return

	match tab_index:
		0: # Global tab
			global_container.visible = true
			friends_container.visible = false
			load_global_data()
		1: # Friends tab
			global_container.visible = false
			friends_container.visible = true
			load_friends_data()

func load_global_data(data: Array[Dictionary] = []) -> void:
	"""Load global leaderboard data.

	Args:
		data: Optional array of leaderboard entries. If empty, uses data provider callback.
	"""
	var leaderboard_data = data
	if leaderboard_data.is_empty() and _global_data_provider.is_valid():
		leaderboard_data = _global_data_provider.call()

	_populate_leaderboard(global_container, leaderboard_data)

func load_friends_data(data: Array[Dictionary] = []) -> void:
	"""Load friends leaderboard data.

	Args:
		data: Optional array of leaderboard entries. If empty, uses data provider callback.
	"""
	var leaderboard_data = data
	if leaderboard_data.is_empty() and _friends_data_provider.is_valid():
		leaderboard_data = _friends_data_provider.call()

	_populate_leaderboard(friends_container, leaderboard_data)

func _populate_leaderboard(container: VBoxContainer, data: Array) -> void:
	"""Populate leaderboard container with entry components."""
	if not container:
		return

	# Clear existing entries
	for child in container.get_children():
		child.queue_free()

	# Create new entries using component template
	for entry_data in data:
		var entry: LeaderboardEntry = LeaderboardEntryScene.instantiate()

		# Get character icon (already loaded as Texture2D)
		var char_icon: Texture2D = entry_data.get("character_icon", null)

		# Setup entry with data
		entry.setup(
			entry_data.rank,
			entry_data.name,
			entry_data.score,  # Pre-formatted score string
			char_icon
		)

		# Highlight if marked as current player
		if entry_data.get("is_current_player", false):
			entry.set_highlight(true)

		container.add_child(entry)

func switch_to_global() -> void:
	"""Programmatically switch to Global tab."""
	if tab_bar:
		tab_bar.current_tab = 0

func switch_to_friends() -> void:
	"""Programmatically switch to Friends tab."""
	if tab_bar:
		tab_bar.current_tab = 1

func refresh_current_tab() -> void:
	"""Reload data for currently visible tab."""
	if tab_bar:
		_on_tab_changed(tab_bar.current_tab)
