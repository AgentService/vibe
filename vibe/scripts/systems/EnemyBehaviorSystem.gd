extends Node

## Enemy behavior system managing AI patterns and decision making.
## Processes enemy behaviors on fixed combat step for deterministic AI.

class_name EnemyBehaviorSystem

var wave_director: WaveDirector

signal behavior_processed()

func _ready() -> void:
	EventBus.combat_step.connect(_on_combat_step)
	Logger.info("Enemy behavior system initialized", "enemies")

func set_wave_director(director: WaveDirector) -> void:
	wave_director = director

func _on_combat_step(payload) -> void:
	if not wave_director:
		return
	
	_process_enemy_behaviors(payload.dt)
	behavior_processed.emit()

func _process_enemy_behaviors(dt: float) -> void:
	var enemies := wave_director.get_alive_enemies()
	var player_pos: Vector2 = PlayerState.position if PlayerState.position != Vector2.ZERO else Vector2.ZERO
	
	for enemy in enemies:
		if not enemy["alive"]:
			continue
		
		var ai_type: String = enemy.get("ai_type", "chase_player")
		var aggro_range: float = enemy.get("aggro_range", 300.0)
		var speed: float = enemy.get("speed", 60.0)
		
		var dist_to_player: float = enemy["pos"].distance_to(player_pos)
		
		# Only process enemies within aggro range
		if dist_to_player <= aggro_range:
			var new_velocity := _calculate_velocity_for_ai_type(enemy, ai_type, player_pos, speed, dt)
			enemy["vel"] = new_velocity

func _calculate_velocity_for_ai_type(enemy: Dictionary, ai_type: String, player_pos: Vector2, speed: float, dt: float) -> Vector2:
	var enemy_pos: Vector2 = enemy["pos"]
	
	match ai_type:
		"chase_player":
			return _chase_player_behavior(enemy_pos, player_pos, speed)
		
		"flee_player":
			return _flee_player_behavior(enemy_pos, player_pos, speed)
		
		"patrol":
			return _patrol_behavior(enemy, speed, dt)
		
		"guard":
			return _guard_behavior(enemy, player_pos, speed)
		
		_:
			# Default to chase behavior
			return _chase_player_behavior(enemy_pos, player_pos, speed)

func _chase_player_behavior(enemy_pos: Vector2, player_pos: Vector2, speed: float) -> Vector2:
	var direction := (player_pos - enemy_pos).normalized()
	return direction * speed

func _flee_player_behavior(enemy_pos: Vector2, player_pos: Vector2, speed: float) -> Vector2:
	var direction := (enemy_pos - player_pos).normalized()
	return direction * speed

func _patrol_behavior(enemy: Dictionary, speed: float, dt: float) -> Vector2:
	# Simple patrol: move in a figure-8 pattern
	var time: float = enemy.get("patrol_time", 0.0)
	time += dt
	enemy["patrol_time"] = time
	
	var angle := sin(time * 0.5) * 2.0
	var direction := Vector2.from_angle(angle)
	return direction * speed * 0.8  # Slower patrol movement

func _guard_behavior(enemy: Dictionary, player_pos: Vector2, speed: float) -> Vector2:
	var enemy_pos: Vector2 = enemy["pos"]
	var guard_pos: Vector2 = enemy.get("guard_position", enemy_pos)
	
	# If no guard position set, use current position
	if not enemy.has("guard_position"):
		enemy["guard_position"] = enemy_pos
		guard_pos = enemy_pos
	
	var dist_to_guard_pos := enemy_pos.distance_to(guard_pos)
	var dist_to_player := enemy_pos.distance_to(player_pos)
	
	# If far from guard position, return to it
	if dist_to_guard_pos > 100.0:
		var direction := (guard_pos - enemy_pos).normalized()
		return direction * speed * 0.6
	
	# If player is close, chase briefly
	if dist_to_player < 150.0:
		var direction := (player_pos - enemy_pos).normalized()
		return direction * speed * 0.4
	
	# Otherwise stay near guard position
	return Vector2.ZERO

func get_available_ai_types() -> Array[String]:
	return ["chase_player", "flee_player", "patrol", "guard"]

func debug_enemy_behavior(enemy_index: int) -> Dictionary:
	if not wave_director:
		return {}
	
	var enemies := wave_director.enemies
	if enemy_index < 0 or enemy_index >= enemies.size():
		return {}
	
	var enemy := enemies[enemy_index]
	if not enemy["alive"]:
		return {}
	
	return {
		"ai_type": enemy.get("ai_type", "chase_player"),
		"aggro_range": enemy.get("aggro_range", 300.0),
		"speed": enemy.get("speed", 60.0),
		"position": enemy["pos"],
		"velocity": enemy["vel"]
	}