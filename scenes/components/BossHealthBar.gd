extends ProgressBar

## Boss health bar that only appears after taking damage for the first time
## Starts hidden and becomes visible when boss first takes damage
## Updates directly via parent boss calling update_health()

class_name BossHealthBar

var has_taken_damage: bool = false

func _ready() -> void:
	# Start hidden - only show after first damage
	visible = false

func update_health(current: float, max_health: float) -> void:
	if max_health > 0.0:
		var health_percentage = (current / max_health) * 100.0
		value = health_percentage
		
		# Show health bar after first damage (when HP is below max)
		if not has_taken_damage and current < max_health:
			has_taken_damage = true
			visible = true
			Logger.debug("Boss health bar now visible after first damage", "bosses")
		
		Logger.debug("Boss health updated: %.1f/%.1f (%.0f%%)" % [current, max_health, health_percentage], "bosses")
	else:
		Logger.warn("Invalid max_health in boss health update: " + str(max_health), "bosses")
