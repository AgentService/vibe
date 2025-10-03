extends VBoxContainer
class_name Leaderboard

## Reusable Leaderboard component with Global/Friends tabs
## Manages tab switching, data loading, and entry population
## Used in MainMenu, post-game results, profile screens

const LeaderboardEntryScene = preload("res://scenes/ui/components/LeaderboardEntry.tscn")

# Daily reset configuration (24 hours in seconds)
const RESET_INTERVAL_SECONDS: int = 24 * 60 * 60

@onready var tab_bar: TabBar = $VBoxContainer/HBoxContainer/TabBar
@onready var global_container: VBoxContainer = $VBoxContainer3/Stats/MarginContainer/VBoxContainer/VBoxContainer_Global
@onready var friends_container: VBoxContainer = $VBoxContainer3/Stats/MarginContainer/VBoxContainer/VBoxContainer_Friends
@onready var reset_label: Label = $VBoxContainer3/Header/MarginContainer/HBoxContainer/ResetContainer/ResetLabel

# Optional callbacks for data loading
var _global_data_provider: Callable
var _friends_data_provider: Callable

# Timer for updating reset countdown
var _update_timer: float = 0.0

func _ready() -> void:
	# Connect tab switching
	if tab_bar:
		tab_bar.tab_changed.connect(_on_tab_changed)
		# Don't load data yet - wait for setup_data_providers()

	# Initialize reset timer display
	if reset_label:
		_update_reset_timer()
	else:
		Logger.warn("Leaderboard: Reset label not found - timer display disabled", "ui")

func _process(delta: float) -> void:
	"""Update reset timer every second."""
	_update_timer += delta
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_update_reset_timer()

func setup_data_providers(global_provider: Callable, friends_provider: Callable) -> void:
	"""Configure data loading callbacks and initialize with Global tab.

	Args:
		global_provider: Callable that returns Array[Dictionary] with global leaderboard data
		friends_provider: Callable that returns Array[Dictionary] with friends leaderboard data
	"""
	_global_data_provider = global_provider
	_friends_data_provider = friends_provider

	# Load initial data for Global tab (index 0)
	if tab_bar:
		tab_bar.current_tab = 0
	_on_tab_changed(0)

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

# ============================================================================
# RESET TIMER (Mock Weekly Reset)
# ============================================================================

func _update_reset_timer() -> void:
	"""Update the reset countdown display."""
	if not reset_label:
		return

	var seconds_until_reset = _calculate_seconds_until_reset()
	reset_label.text = _format_time_remaining(seconds_until_reset)

func _calculate_seconds_until_reset() -> int:
	"""Calculate seconds until next daily reset.

	Uses a fixed epoch (2025-01-01 00:00:00 UTC) as the starting point
	for consistent daily resets across all clients at midnight UTC.
	"""
	# Fixed epoch: January 1, 2025, 00:00:00 UTC (Unix timestamp: 1735689600)
	const EPOCH_TIMESTAMP: int = 1735689600

	# Get current Unix timestamp
	var current_time: int = int(Time.get_unix_time_from_system())

	# Calculate seconds since epoch
	var seconds_since_epoch: int = current_time - EPOCH_TIMESTAMP

	# Calculate seconds into current day
	var seconds_into_day: int = seconds_since_epoch % RESET_INTERVAL_SECONDS

	# Calculate seconds until next reset (midnight UTC)
	var seconds_until_reset: int = RESET_INTERVAL_SECONDS - seconds_into_day

	return seconds_until_reset

func _format_time_remaining(seconds: int) -> String:
	"""Format seconds into readable time string (e.g., '6d 23h', '5h 30m', '45m')."""
	var days: int = seconds / (24 * 60 * 60)
	var hours: int = (seconds % (24 * 60 * 60)) / (60 * 60)
	var minutes: int = (seconds % (60 * 60)) / 60

	if days > 0:
		return "%dd %dh" % [days, hours]
	elif hours > 0:
		return "%dh %dm" % [hours, minutes]
	else:
		return "%dm" % minutes
