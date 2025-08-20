extends Node2D

## Main scene that manages the game state.
## References RunManager autoload for combat timing.

func _ready() -> void:
	# Connect to combat step for debug purposes
	EventBus.combat_step.connect(_on_combat_step)
	Logger.info("Main scene ready - Arena loaded with multimesh projectiles")

func _on_combat_step(payload) -> void:
	# Main scene just passes through - Arena handles projectile logic
	pass
