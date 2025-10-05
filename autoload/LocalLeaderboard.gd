extends Node

const LeaderboardDataResource = preload("res://scripts/resources/LeaderboardDataResource.gd")

## LocalLeaderboard - Personal best scores per map+tier combination (Task 04 Phase 3)
##
## Stores the top N runs for each map+tier combination locally.
## No global leaderboards, no networking - purely local tracking for player progression.
##
## Storage Structure:
##   _leaderboard_data[map_id][tier] = Array[LeaderboardEntry]
##
## Entry Format:
##   {
##     "character_id": String,
##     "timestamp": int (Unix time),
##     "stage_reached": int,
##     "kills": int,
##     "damage_dealt": int,
##     "time_survived": float,
##     "final_swarm_entered": bool,
##     "rift_fragments_earned": int
##   }

const SAVE_PATH := "user://local_leaderboard.tres"
const MAX_ENTRIES_PER_TIER := 10  # Top 10 runs per map+tier

# Nested dictionary: map_id -> tier -> Array[Dictionary]
var _leaderboard_data: Dictionary = {}

func _ready() -> void:
	# Load existing leaderboard data
	_load_leaderboard()

	Logger.info("LocalLeaderboard initialized with %d maps" % _leaderboard_data.size(), "progression")

## Add a new run entry to the leaderboard
## Returns the rank (1-10) if it made the leaderboard, or -1 if it didn't qualify
func add_run(map_id: String, tier: int, run_data: Dictionary) -> int:
	# Ensure map exists in leaderboard
	if not _leaderboard_data.has(map_id):
		_leaderboard_data[map_id] = {}

	# Ensure tier exists for this map
	if not _leaderboard_data[map_id].has(tier):
		_leaderboard_data[map_id][tier] = []

	var entries: Array = _leaderboard_data[map_id][tier]

	# Add new entry
	var new_entry = {
		"character_id": run_data.get("character_id", "unknown"),
		"timestamp": int(Time.get_unix_time_from_system()),
		"stage_reached": run_data.get("stage_reached", 1),
		"kills": run_data.get("kills", 0),
		"damage_dealt": run_data.get("damage_dealt", 0),
		"time_survived": run_data.get("time_survived", 0.0),
		"final_swarm_entered": run_data.get("final_swarm_entered", false),
		"rift_fragments_earned": run_data.get("rift_fragments_earned", 0)
	}

	entries.append(new_entry)

	# Sort by rift fragments earned (primary), then stage reached (secondary)
	entries.sort_custom(func(a, b):
		if a.rift_fragments_earned != b.rift_fragments_earned:
			return a.rift_fragments_earned > b.rift_fragments_earned
		return a.stage_reached > b.stage_reached
	)

	# Trim to top N entries
	if entries.size() > MAX_ENTRIES_PER_TIER:
		entries.resize(MAX_ENTRIES_PER_TIER)
		_leaderboard_data[map_id][tier] = entries

	# Find rank of new entry (or -1 if not in top N)
	var rank := -1
	for i in range(entries.size()):
		if entries[i].timestamp == new_entry.timestamp:
			rank = i + 1  # 1-indexed rank
			break

	# Save to disk
	_save_leaderboard()

	# Emit signal
	EventBus.leaderboard_updated.emit(map_id, tier, rank)

	if rank > 0:
		Logger.info("New leaderboard entry: Rank #%d on %s Tier %d" % [rank, map_id, tier], "progression")
	else:
		Logger.debug("Run did not qualify for leaderboard on %s Tier %d" % [map_id, tier], "progression")

	return rank

## Get the leaderboard for a specific map+tier
func get_leaderboard(map_id: String, tier: int) -> Array:
	if not _leaderboard_data.has(map_id):
		return []
	if not _leaderboard_data[map_id].has(tier):
		return []
	return _leaderboard_data[map_id][tier].duplicate()  # Return copy for safety

## Get the personal best for a specific map+tier (top entry)
func get_personal_best(map_id: String, tier: int) -> Dictionary:
	var leaderboard = get_leaderboard(map_id, tier)
	if leaderboard.is_empty():
		return {}
	return leaderboard[0].duplicate()

## Check if a run would qualify for the leaderboard (without adding it)
func would_qualify(map_id: String, tier: int, rift_fragments_earned: int) -> bool:
	var leaderboard = get_leaderboard(map_id, tier)

	# If less than max entries, always qualifies
	if leaderboard.size() < MAX_ENTRIES_PER_TIER:
		return true

	# Check if better than worst entry
	var worst_entry = leaderboard[-1]
	return rift_fragments_earned > worst_entry.rift_fragments_earned

## Get all maps with leaderboard entries
func get_maps_with_entries() -> Array[String]:
	var maps: Array[String] = []
	for map_id in _leaderboard_data.keys():
		maps.append(map_id)
	return maps

## Get all tiers for a specific map that have entries
func get_tiers_with_entries(map_id: String) -> Array[int]:
	var tiers: Array[int] = []
	if _leaderboard_data.has(map_id):
		for tier in _leaderboard_data[map_id].keys():
			tiers.append(tier)
	tiers.sort()
	return tiers

## Clear all leaderboard data
func clear_all() -> void:
	_leaderboard_data.clear()
	_save_leaderboard()
	Logger.warn("LocalLeaderboard cleared", "progression")

## Clear leaderboard data for a specific map
func clear_map(map_id: String) -> void:
	if _leaderboard_data.has(map_id):
		_leaderboard_data.erase(map_id)
		_save_leaderboard()
		Logger.info("Cleared leaderboard for map: %s" % map_id, "progression")

## Clear leaderboard data for a specific map+tier
func clear_tier(map_id: String, tier: int) -> void:
	if _leaderboard_data.has(map_id) and _leaderboard_data[map_id].has(tier):
		_leaderboard_data[map_id].erase(tier)
		if _leaderboard_data[map_id].is_empty():
			_leaderboard_data.erase(map_id)  # Remove map if no tiers left
		_save_leaderboard()
		Logger.info("Cleared leaderboard for %s Tier %d" % [map_id, tier], "progression")

## Load leaderboard data from disk
func _load_leaderboard() -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		Logger.info("No existing leaderboard data found, starting fresh", "progression")
		return

	var loaded_data = ResourceLoader.load(SAVE_PATH)

	if not loaded_data:
		Logger.warn("ResourceLoader.load() returned null", "progression")
		return

	if not loaded_data is Resource:
		Logger.warn("Loaded data is not a Resource (type: %s)" % typeof(loaded_data), "progression")
		return

	# Try to access the 'data' property from the loaded resource
	# The .tres file stores data as: data = { "forest_arena": { ... } }

	if loaded_data.has_method("get_data"):
		# Proper LeaderboardDataResource class with get_data() method
		_leaderboard_data = loaded_data.get_data()
		Logger.debug("Retrieved data via get_data() method", "progression")
	elif loaded_data is LeaderboardDataResource:
		# Direct access to LeaderboardDataResource.data property
		_leaderboard_data = loaded_data.data
		Logger.debug("Retrieved data via LeaderboardDataResource.data", "progression")
	else:
		# Old/incompatible save file format - start fresh
		Logger.warn("Incompatible leaderboard save file format detected, starting fresh", "progression")
		_leaderboard_data = {}
		# Force save with new format
		_save_leaderboard()
		return

	if _leaderboard_data == null or not _leaderboard_data is Dictionary:
		Logger.warn("Loaded data is not a valid Dictionary", "progression")
		_leaderboard_data = {}
		return

	Logger.info("Loaded local leaderboard with %d entries across %d maps" % [get_total_entries(), _leaderboard_data.size()], "progression")

## Save leaderboard data to disk
func _save_leaderboard() -> void:
	var resource = LeaderboardDataResource.new()
	resource.set_data(_leaderboard_data)

	var save_error = ResourceSaver.save(resource, SAVE_PATH)
	if save_error != OK:
		Logger.error("Failed to save leaderboard data: Error %d" % save_error, "progression")
	else:
		if Logger.is_level_enabled(Logger.LogLevel.DEBUG):
			Logger.debug("Leaderboard data saved successfully", "progression")

## Get total number of entries across all maps and tiers
func get_total_entries() -> int:
	var total := 0
	for map_id in _leaderboard_data.keys():
		for tier in _leaderboard_data[map_id].keys():
			total += _leaderboard_data[map_id][tier].size()
	return total

## Get summary statistics for debugging
func get_stats() -> Dictionary:
	return {
		"total_maps": _leaderboard_data.size(),
		"total_entries": get_total_entries(),
		"maps": get_maps_with_entries()
	}

## TODO(UI-phase2): Get total runs for a specific map (across all tiers)
## Currently returns count of leaderboard entries (max 10 per tier)
## Should track actual total runs played separately
func get_total_runs_for_map(map_id: String) -> int:
	if not _leaderboard_data.has(map_id):
		return 0

	var total := 0
	for tier in _leaderboard_data[map_id].keys():
		total += _leaderboard_data[map_id][tier].size()

	# PLACEHOLDER: This counts leaderboard entries, not actual total runs
	# Future: Add separate _total_runs_data[map_id] = count tracking
	return total

## TODO(UI-phase2): Get best run for a specific map (across all tiers)
## Currently returns best from Tier 1, should check all tiers
func get_best_run_for_map(map_id: String) -> Dictionary:
	if not _leaderboard_data.has(map_id):
		return {}

	# PLACEHOLDER: Only checks Tier 1
	# Future: Loop through all tiers and find absolute best
	var best_entry := {}
	var best_fragments := -1

	if _leaderboard_data[map_id].has(1):
		var tier1_entries = _leaderboard_data[map_id][1]
		if not tier1_entries.is_empty():
			best_entry = tier1_entries[0]  # Already sorted by fragments

	return best_entry
