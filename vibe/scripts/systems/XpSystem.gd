extends Node
class_name XpSystem

## Manages player experience, levels, and XP orb spawning.
## Uses configurable level curve loaded from data/xp_curves.json.

const XP_ORB_SCENE: PackedScene = preload("res://scenes/arena/XPOrb.tscn")

var current_xp: int = 0
var current_level: int = 1
var next_level_xp: int = 30

var _arena_node: Node
var _xp_curve_data: Dictionary = {}
var _curve_config: Dictionary = {}

func _init(arena: Node) -> void:
	_arena_node = arena

func _ready() -> void:
	_load_xp_curve_data()
	EventBus.combat_step.connect(_on_combat_step)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	if BalanceDB:
		BalanceDB.balance_reloaded.connect(_on_balance_reloaded)
	_update_next_level_xp()

func _on_balance_reloaded() -> void:
	_load_xp_curve_data()
	_update_next_level_xp()
	Logger.info("XpSystem: Reloaded XP curve data", "player")

func _load_xp_curve_data() -> void:
	var file_path: String = "res://data/xp_curves.json"
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		push_error("Failed to load XP curve data from: " + file_path + ". Using fallback values.")
		_use_fallback_curve()
		return
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse XP curve JSON. Using fallback values.")
		_use_fallback_curve()
		return
	
	_xp_curve_data = json.data
	var active_curve: String = _xp_curve_data.get("active_curve", "default")
	_curve_config = _xp_curve_data.get("curves", {}).get(active_curve, {})
	
	if _curve_config.is_empty():
		push_error("No valid curve configuration found. Using fallback values.")
		_use_fallback_curve()

func _use_fallback_curve() -> void:
	_curve_config = {
		"base_multiplier": 50.0,
		"exponent": 1.5,
		"min_first_level": 30
	}

func _on_combat_step(payload) -> void:
	pass

func _on_enemy_killed(payload) -> void:
	_spawn_xp_orb(payload.pos, payload.xp_value)

func _spawn_xp_orb(pos: Vector2, xp_value: int) -> void:
	var orb: XPOrb = XP_ORB_SCENE.instantiate()
	orb.global_position = pos
	orb.xp_value = xp_value
	orb.collected.connect(_on_xp_collected)
	_arena_node.add_child(orb)

func _on_xp_collected(amount: int) -> void:
	add_xp(amount)

func add_xp(amount: int) -> void:
	current_xp += amount
	var xp_payload := EventBus.XpChangedPayload.new(current_xp, next_level_xp)
	EventBus.xp_changed.emit(xp_payload)
	
	while current_xp >= next_level_xp:
		_level_up()

func _level_up() -> void:
	current_xp -= next_level_xp
	current_level += 1
	_update_next_level_xp()
	
	# Update RunManager level for card system
	RunManager.stats["level"] = current_level
	
	Logger.info("Level up! New level: " + str(current_level), "player")
	var level_payload := EventBus.LevelUpPayload.new(current_level)
	EventBus.level_up.emit(level_payload)
	var xp_payload := EventBus.XpChangedPayload.new(current_xp, next_level_xp)
	EventBus.xp_changed.emit(xp_payload)

func _update_next_level_xp() -> void:
	if current_level == 1:
		next_level_xp = _curve_config.get("min_first_level", 30)
	else:
		var base_multiplier: float = _curve_config.get("base_multiplier", 50.0)
		var exponent: float = _curve_config.get("exponent", 1.5)
		next_level_xp = floor(base_multiplier * pow(current_level, exponent))
