extends BaseBoss

## Ancient Lich Boss - V2 Enemy System Integration
## Scene-based boss with AnimatedSprite2D for proper visual workflow
## Extends BaseBoss for unified boss logic and signals

class_name AncientLich

func _ready() -> void:
	# Call parent _ready() first to setup BaseBoss functionality
	super._ready()
	Logger.info("AncientLich boss ready", "bosses")

# BaseBoss handles _exit_tree and setup_from_spawn_config

# BaseBoss handles _on_combat_step and base _update_ai
# Override _update_custom_ai for AncientLich-specific behavior

# BaseBoss handles _perform_attack - use _perform_custom_attack for AncientLich-specific attacks
func _perform_custom_attack() -> void:
	# Add any AncientLich-specific attack behavior here
	Logger.debug("AncientLich custom attack executed!", "bosses")

# BaseBoss handles all health methods, death, aggro, and animation logic
# AncientLich is now a clean extension with only custom behavior
