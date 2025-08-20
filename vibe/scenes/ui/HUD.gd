extends Control
class_name HUD

## Heads-up display showing level, XP bar, and other player stats.

@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var xp_bar: ProgressBar = $VBoxContainer/XPBar
@onready var enemy_radar: Panel = $EnemyRadar

func _ready() -> void:
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.level_up.connect(_on_level_up)
	
	# Initialize display
	_update_level_display(1)
	_update_xp_display(0, 30)

func _on_xp_changed(payload) -> void:
	_update_xp_display(payload.current_xp, payload.next_level_xp)

func _on_level_up(payload) -> void:
	_update_level_display(payload.new_level)

func _update_level_display(level: int) -> void:
	if level_label:
		level_label.text = "Level: " + str(level)

func _update_xp_display(current_xp: int, next_level_xp: int) -> void:
	if xp_bar:
		xp_bar.max_value = next_level_xp
		xp_bar.value = current_xp