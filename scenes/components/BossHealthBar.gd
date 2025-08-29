extends ProgressBar

## Reusable boss health bar component
## Subscribes to parent boss health_changed signal for decoupled UI updates
## Follows .clinerules pattern: boss emits signal → UI component subscribes

class_name BossHealthBar

func _ready() -> void:
	# Subscribe to parent boss health_changed signal
	var boss := get_parent() as BaseBoss
	if boss:
		boss.health_changed.connect(_on_health_changed)
		Logger.debug("BossHealthBar connected to " + boss.entity_id, "bosses")
	else:
		Logger.warn("BossHealthBar parent is not a BaseBoss - no health updates will occur", "bosses")

func _on_health_changed(current: float, max_health: float) -> void:
	if max_health > 0.0:
		var health_percentage = (current / max_health) * 100.0
		value = health_percentage
		Logger.debug("Boss health updated: %.1f/%.1f (%.0f%%)" % [current, max_health, health_percentage], "bosses")
	else:
		Logger.warn("Invalid max_health in boss health update: " + str(max_health), "bosses")