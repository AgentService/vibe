extends BaseBoss

## DragonLord special boss - V2 Enemy System Integration
## Scene-based boss with AnimatedSprite2D for proper visual workflow
## Extends BaseBoss for unified boss logic and signals

class_name DragonLord

# DragonLord-specific configuration
func _init():
	attack_range = 100.0
	chase_range = 400.0

func _ready() -> void:
	# Call parent _ready() first to setup BaseBoss functionality
	super._ready()
	Logger.info("DragonLord boss ready", "bosses")

# BaseBoss handles all the base functionality
# DragonLord can override _perform_custom_attack for unique dragon abilities
func _perform_custom_attack() -> void:
	# Add any DragonLord-specific attack behavior here
	Logger.debug("DragonLord custom fire breath attack!", "bosses")
