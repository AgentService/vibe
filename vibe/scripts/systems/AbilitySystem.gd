extends Node

## Ability system managing projectile logic via pooled structs.
## Updates on fixed combat step (30 Hz) for deterministic behavior.

class_name AbilitySystem

var projectiles: Array[Dictionary] = []
var max_projectiles: int
var arena_bounds: float

signal projectiles_updated(alive_projectiles: Array[Dictionary])

func _ready() -> void:
	_load_balance_values()
	EventBus.combat_step.connect(_on_combat_step)
	_initialize_pool()
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)

func _load_balance_values() -> void:
	max_projectiles = BalanceDB.get_abilities_value("max_projectiles")
	arena_bounds = BalanceDB.get_abilities_value("arena_bounds")

func _on_balance_reloaded() -> void:
	_load_balance_values()
	_initialize_pool()
	Logger.info("Reloaded ability balance values", "abilities")

func _initialize_pool() -> void:
	projectiles.resize(max_projectiles)
	for i in range(max_projectiles):
		projectiles[i] = {
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"ttl": 0.0,
			"alive": false
		}

func spawn_projectile(pos: Vector2, dir: Vector2, speed: float, ttl: float) -> void:
	var free_idx := _find_free_projectile()
	if free_idx == -1:
		Logger.warn("No free projectile slots available", "abilities")
		return

	var projectile := projectiles[free_idx]
	projectile["pos"] = pos
	projectile["vel"] = dir.normalized() * speed
	projectile["ttl"] = ttl
	projectile["alive"] = true

func _find_free_projectile() -> int:
	for i in range(max_projectiles):
		if not projectiles[i]["alive"]:
			return i
	return -1

func _on_combat_step(payload) -> void:
	_update_projectiles(payload.dt)
	var alive_projectiles := _get_alive_projectiles()
	projectiles_updated.emit(alive_projectiles)

func _update_projectiles(dt: float) -> void:
	for projectile in projectiles:
		if not projectile["alive"]:
			continue

		projectile["pos"] += projectile["vel"] * dt
		projectile["ttl"] -= dt

		if projectile["ttl"] <= 0.0 or _is_out_of_bounds(projectile["pos"]):
			projectile["alive"] = false

func _is_out_of_bounds(pos: Vector2) -> bool:
	return abs(pos.x) > arena_bounds or abs(pos.y) > arena_bounds

func _get_alive_projectiles() -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	for projectile in projectiles:
		if projectile["alive"]:
			alive.append(projectile)
	return alive
