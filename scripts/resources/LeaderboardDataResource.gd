extends Resource
class_name LeaderboardDataResource

## Resource class for saving/loading leaderboard data
## Used by LocalLeaderboard autoload to persist personal best scores

@export var data: Dictionary = {}

func set_data(new_data: Dictionary) -> void:
	data = new_data

func get_data() -> Dictionary:
	return data
