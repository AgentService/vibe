extends Resource

class_name XPCurvesResource

## XP curves configuration resource for player leveling
## Replaces xp_curves.json with type-safe resource

@export var active_curve: String = "default"

@export_group("Default Curve")
@export var default_base_multiplier: float = 6.0
@export var default_exponent: int = 1
@export var default_min_first_level: int = 10
@export var default_description: String = "Tripled XP curve: requires 3x more XP to level up"

## Get curves as dictionary for compatibility with existing systems
func get_curves() -> Dictionary:
	return {
		"default": {
			"base_multiplier": default_base_multiplier,
			"exponent": default_exponent,
			"min_first_level": default_min_first_level,
			"description": default_description
		}
	}

## Get active curve configuration
func get_active_curve_config() -> Dictionary:
	var curves = get_curves()
	if curves.has(active_curve):
		return curves[active_curve]
	else:
		# Fallback to default
		return curves["default"]

## Validate active curve exists
func is_valid_active_curve() -> bool:
	return active_curve == "default"  # Only default curve supported for now