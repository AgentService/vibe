extends MarginContainer
class_name LeaderboardEntry

## Reusable leaderboard entry component
## Displays player rank, name, score/kills, and character icon
## Used for both Friends and Global leaderboards

@onready var rank_label: Label = $Frame/MarginContainer/HboxEntry/Rank
@onready var name_label: Label = $Frame/MarginContainer/HboxEntry/PlayerName
@onready var score_label: Label = $Frame/MarginContainer/HboxEntry/Stats/Score
@onready var character_icon: TextureRect = $Frame/MarginContainer/HboxEntry/Stats/CharacterIcon

# Store data if setup() is called before _ready()
var _pending_rank: int = 0
var _pending_name: String = ""
var _pending_score: String = ""
var _pending_icon: Texture2D = null

func _ready() -> void:
	# Apply pending data if setup() was called before _ready()
	if _pending_rank > 0:
		_apply_data(_pending_rank, _pending_name, _pending_score, _pending_icon)
		_pending_rank = 0

func setup(rank: int, player_name: String, score: String, char_icon: Texture2D = null) -> void:
	"""Initialize the leaderboard entry with player data.

	Args:
		rank: Player's ranking position (1, 2, 3, etc.)
		player_name: Player's display name
		score: Formatted score string (e.g., "1.2M kills", "Wave 45")
		char_icon: Optional character portrait texture
	"""
	# If nodes are ready, apply immediately
	if rank_label and name_label and score_label:
		_apply_data(rank, player_name, score, char_icon)
	else:
		# Store for later (will be applied in _ready())
		_pending_rank = rank
		_pending_name = player_name
		_pending_score = score
		_pending_icon = char_icon

func _apply_data(rank: int, player_name: String, score: String, char_icon: Texture2D) -> void:
	"""Apply leaderboard data to UI label elements.

	Internal helper called by setup() or deferred from _ready().
	Assumes all UI nodes are ready.

	Args:
		rank: Player's ranking position (1-based)
		player_name: Display name for player
		score: Pre-formatted score string (e.g., "1.2M")
		char_icon: Optional character portrait texture
	"""
	rank_label.text = "#%d" % rank
	name_label.text = player_name
	score_label.text = score

	if char_icon and character_icon:
		character_icon.texture = char_icon
		character_icon.visible = true
	elif character_icon:
		character_icon.visible = false

func set_highlight(highlighted: bool) -> void:
	"""Highlight this entry (e.g., for current player's score)."""
	if highlighted:
		modulate = Color(1.2, 1.2, 1.0)  # Slight yellow tint
	else:
		modulate = Color.WHITE
