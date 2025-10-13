## PlayerStats.gd
## Runtime player stat modifications (tomes, items, buffs)
##
## Separates base configuration (PlayerType.tres) from runtime modifiers.
## Base values sync from PlayerType on init, preserving hot-reload.
## Tomes and items modify mult/bonus fields for stat changes.

extends Resource
class_name PlayerStats


## Base values synced from PlayerType.tres on init
var base_movement_speed: float = 110.0
var base_max_health: int = 199
var base_pickup_radius: float = 12.0
var base_damage: float = 25.0

## Runtime modifiers (applied by tomes/items/buffs)
var movement_speed_mult: float = 1.0
var max_hp_bonus: int = 0
var pickup_radius_mult: float = 1.0
var damage_mult: float = 1.0
var crit_chance_bonus: float = 0.0


## Sync base values from PlayerType (preserves hot-reload)
func sync_from_player_type(player_type: Resource) -> void:
	if not player_type:
		Logger.warn("PlayerStats: Cannot sync from null player_type", "player")
		return

	# Sync base values directly from PlayerType.tres properties
	# Note: PlayerType uses "move_speed" not "movement_speed"
	base_movement_speed = player_type.move_speed
	base_max_health = player_type.max_health
	base_pickup_radius = player_type.pickup_radius
	# PlayerType doesn't have base_damage - keep default value

	Logger.debug("PlayerStats synced from player_type: speed={speed}, hp={hp}, radius={radius}".format({
		"speed": base_movement_speed,
		"hp": base_max_health,
		"radius": base_pickup_radius
	}), "player")


## Computed effective values (base * mult + bonus)
func get_effective_move_speed() -> float:
	return base_movement_speed * movement_speed_mult


func get_effective_max_health() -> int:
	return base_max_health + max_hp_bonus


func get_effective_pickup_radius() -> float:
	return base_pickup_radius * pickup_radius_mult


func get_effective_damage() -> float:
	return base_damage * damage_mult


func get_effective_crit_chance() -> float:
	# Get base crit chance from BalanceDB (default 0.1 = 10%)
	var base_crit: float = BalanceDB.get_combat_value("crit_chance") if BalanceDB else 0.1
	return base_crit + crit_chance_bonus


## Reset all modifiers to default (for run restart)
func reset_modifiers() -> void:
	movement_speed_mult = 1.0
	max_hp_bonus = 0
	pickup_radius_mult = 1.0
	damage_mult = 1.0
	crit_chance_bonus = 0.0

	Logger.debug("PlayerStats modifiers reset to defaults", "player")


## Debug representation
func _to_string() -> String:
	return "PlayerStats(speed={speed:.1f}, hp={hp}, radius={radius:.1f}, dmg={dmg:.1f})".format({
		"speed": get_effective_move_speed(),
		"hp": get_effective_max_health(),
		"radius": get_effective_pickup_radius(),
		"dmg": get_effective_damage()
	})
