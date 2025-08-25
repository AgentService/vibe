extends Node
class_name XpSystem

## Manages player experience, levels, and XP orb spawning.
## Uses configurable level curve loaded from data/xp_curves.tres.

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

func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus.combat_step.is_connected(_on_combat_step):
		EventBus.combat_step.disconnect(_on_combat_step)
	if EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)
	if BalanceDB and BalanceDB.balance_reloaded.is_connected(_on_balance_reloaded):
		BalanceDB.balance_reloaded.disconnect(_on_balance_reloaded)
	Logger.debug("XpSystem: Cleaned up signal connections", "systems")

func _on_balance_reloaded() -> void:
	_load_xp_curve_data()
	_update_next_level_xp()
	Logger.info("XpSystem: Reloaded XP curve data", "player")

func _load_xp_curve_data() -> void:
	var xp_curves_resource: XPCurvesResource = load("res://data/xp_curves.tres")
	
	if xp_curves_resource == null:
		push_error("Failed to load XP curve resource. Using fallback values.")
		_use_fallback_curve()
		return
	
	# Validate active curve
	if not xp_curves_resource.is_valid_active_curve():
		push_error("Invalid active curve in XP resource. Using fallback values.")
		_use_fallback_curve()
		return
	
	# Load curve configuration
	_curve_config = xp_curves_resource.get_active_curve_config()
	_xp_curve_data = {
		"active_curve": xp_curves_resource.active_curve,
		"curves": xp_curves_resource.get_curves()
	}
	
	if _curve_config.is_empty():
		push_error("No valid curve configuration found in resource. Using fallback values.")
		_use_fallback_curve()

func _use_fallback_curve() -> void:
	_curve_config = {
		"base_multiplier": 50.0,
		"exponent": 1.5,
		"min_first_level": 30
	}

func _on_combat_step(_payload) -> void:
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
	var xp_payload := EventBus.XpChangedPayload_Type.new(current_xp, next_level_xp)
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
	var level_payload := EventBus.LevelUpPayload_Type.new(current_level)
	EventBus.level_up.emit(level_payload)
	var xp_payload := EventBus.XpChangedPayload_Type.new(current_xp, next_level_xp)
	EventBus.xp_changed.emit(xp_payload)

func _update_next_level_xp() -> void:
	if current_level == 1:
		next_level_xp = _curve_config.get("min_first_level", 30)
	else:
		var base_multiplier: float = _curve_config.get("base_multiplier", 50.0)
		var exponent: float = _curve_config.get("exponent", 1.5)
		next_level_xp = floor(base_multiplier * pow(current_level, exponent))
