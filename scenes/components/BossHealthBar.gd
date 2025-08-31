extends ProgressBar

## Reusable boss health bar component
## Updates directly via parent boss calling update_health()
## Simple direct-call pattern for boss health updates

class_name BossHealthBar

func update_health(current: float, max_health: float) -> void:
	if max_health > 0.0:
		var health_percentage = (current / max_health) * 100.0
		value = health_percentage
		Logger.debug("Boss health updated: %.1f/%.1f (%.0f%%)" % [current, max_health, health_percentage], "bosses")
	else:
		Logger.warn("Invalid max_health in boss health update: " + str(max_health), "bosses")
