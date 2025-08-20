extends Node
class_name InteractableSystem

## Interactable system for managing doors, chests, altars, shops, and other interactive objects.
## Handles activation zones, collision detection, and interaction logic.

signal interactable_activated(interactable_id: String, interactable_type: String)
signal interactables_updated(interactable_transforms: Array[Transform2D])

var interactable_bodies: Array[Area2D] = []
var interactable_transforms: Array[Transform2D] = []
var interactable_data: Dictionary = {}
var interaction_cooldowns: Dictionary = {}

const INTERACTABLE_TEXTURE_PATH: String = "res://assets/sprites/interactables/"
const DEFAULT_INTERACTION_RADIUS: float = 32.0
const INTERACTION_COOLDOWN: float = 0.5  # Prevent spam clicking

func _ready() -> void:
	# Connect to player input for interaction
	pass

func _process(delta: float) -> void:
	_update_interaction_cooldowns(delta)

func load_interactables(interactables_config: Dictionary) -> void:
	clear_interactables()
	interactable_data = interactables_config
	
	var interactables := interactables_config.get("objects", []) as Array
	
	for interactable_data_item in interactables:
		var interactable := interactable_data_item as Dictionary
		_create_interactable(interactable)
	
	_update_interactable_visuals()

func clear_interactables() -> void:
	# Remove interaction bodies
	for body in interactable_bodies:
		if is_instance_valid(body):
			body.queue_free()
	
	interactable_bodies.clear()
	interactable_transforms.clear()
	interactable_data.clear()
	interaction_cooldowns.clear()

func _create_interactable(interactable_config: Dictionary) -> void:
	var position := Vector2(
		interactable_config.get("x", 0.0) as float,
		interactable_config.get("y", 0.0) as float
	)
	var interactable_type := interactable_config.get("type", "chest") as String
	var interactable_id := interactable_config.get("id", "interactable_" + str(interactable_bodies.size())) as String
	var interaction_radius := interactable_config.get("interaction_radius", DEFAULT_INTERACTION_RADIUS) as float
	var rotation := interactable_config.get("rotation", 0.0) as float
	
	# Create interaction area
	_create_interactable_area(position, interaction_radius, rotation, interactable_id, interactable_type, interactable_config)
	
	# Create visual transform
	var transform := Transform2D()
	transform.origin = position
	transform = transform.rotated(rotation)
	interactable_transforms.append(transform)

func _create_interactable_area(pos: Vector2, radius: float, rotation: float, id: String, type: String, config: Dictionary) -> void:
	var area := Area2D.new()
	area.name = "Interactable_" + id
	area.global_position = pos
	area.rotation = rotation
	
	# Set collision layers for player detection
	area.collision_layer = 4  # Interactable layer
	area.collision_mask = 1   # Player layer
	
	var collision := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = radius
	collision.shape = circle_shape
	
	area.add_child(collision)
	
	# Add metadata
	area.set_meta("interactable_id", id)
	area.set_meta("interactable_type", type)
	area.set_meta("config", config)
	area.set_meta("activated", false)
	area.set_meta("can_reactivate", config.get("can_reactivate", false))
	
	# Connect signals
	area.body_entered.connect(_on_interactable_entered.bind(area))
	area.body_exited.connect(_on_interactable_exited.bind(area))
	
	get_parent().add_child(area)
	interactable_bodies.append(area)

func _update_interactable_visuals() -> void:
	interactables_updated.emit(interactable_transforms)

func _update_interaction_cooldowns(delta: float) -> void:
	var to_remove: Array[String] = []
	
	for id in interaction_cooldowns:
		interaction_cooldowns[id] -= delta
		if interaction_cooldowns[id] <= 0.0:
			to_remove.append(id)
	
	for id in to_remove:
		interaction_cooldowns.erase(id)

func _on_interactable_entered(body: Node2D, area: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var interactable_id := area.get_meta("interactable_id", "") as String
	var interactable_type := area.get_meta("interactable_type", "") as String
	
	# Show interaction prompt to player
	_show_interaction_prompt(interactable_id, interactable_type, true)

func _on_interactable_exited(body: Node2D, area: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	
	var interactable_id := area.get_meta("interactable_id", "") as String
	var interactable_type := area.get_meta("interactable_type", "") as String
	
	# Hide interaction prompt
	_show_interaction_prompt(interactable_id, interactable_type, false)

func _show_interaction_prompt(id: String, type: String, show: bool) -> void:
	# Emit signal for UI to show/hide interaction prompt
	var payload := EventBus.InteractionPromptChangedPayload.new(id, type, show)
	EventBus.interaction_prompt_changed.emit(payload)

func try_interact(player_position: Vector2) -> bool:
	# Find closest interactable within range
	var closest_area: Area2D = null
	var closest_distance: float = INF
	
	for area in interactable_bodies:
		var distance := player_position.distance_to(area.global_position)
		var config: Dictionary = area.get_meta("config", {}) as Dictionary
		var interaction_radius := config.get("interaction_radius", DEFAULT_INTERACTION_RADIUS) as float
		
		if distance <= interaction_radius and distance < closest_distance:
			closest_distance = distance
			closest_area = area
	
	if closest_area:
		return _activate_interactable(closest_area)
	
	return false

func _activate_interactable(area: Area2D) -> bool:
	var interactable_id := area.get_meta("interactable_id", "") as String
	var interactable_type := area.get_meta("interactable_type", "") as String
	var activated := area.get_meta("activated", false) as bool
	var can_reactivate := area.get_meta("can_reactivate", false) as bool
	
	# Check cooldown
	if interaction_cooldowns.has(interactable_id):
		return false
	
	# Check if already activated and can't be reactivated
	if activated and not can_reactivate:
		return false
	
	# Activate the interactable
	area.set_meta("activated", true)
	interaction_cooldowns[interactable_id] = INTERACTION_COOLDOWN
	
	# Handle type-specific logic
	match interactable_type:
		"chest":
			_handle_chest_activation(area)
		"door":
			_handle_door_activation(area)
		"altar":
			_handle_altar_activation(area)
		"shop":
			_handle_shop_activation(area)
		"lever":
			_handle_lever_activation(area)
		_:
			pass  # Generic interactable
	
	# Emit activation signal
	interactable_activated.emit(interactable_id, interactable_type)
	return true

func _handle_chest_activation(area: Area2D) -> void:
	var config: Dictionary = area.get_meta("config", {}) as Dictionary
	var loot_table: String = config.get("loot_table", "basic_chest")
	
	# Generate loot based on chest type
	var payload := EventBus.LootGeneratedPayload.new(area.get_meta("interactable_id"), "chest", {"loot_table": loot_table})
	EventBus.loot_generated.emit(payload)

func _handle_door_activation(area: Area2D) -> void:
	var config: Dictionary = area.get_meta("config", {}) as Dictionary
	var target_room: String = config.get("target_room", "")
	
	if not target_room.is_empty():
		# Door will be handled by ArenaSystem
		pass

func _handle_altar_activation(area: Area2D) -> void:
	var config: Dictionary = area.get_meta("config", {}) as Dictionary
	var altar_type: String = config.get("altar_type", "blessing")
	
	# Provide buffs, healing, or other benefits
	EventBus.altar_activated.emit(area.get_meta("interactable_id"), altar_type)

func _handle_shop_activation(area: Area2D) -> void:
	var config: Dictionary = area.get_meta("config", {}) as Dictionary
	var shop_type: String = config.get("shop_type", "general")
	
	# Open shop interface
	EventBus.shop_opened.emit(area.get_meta("interactable_id"), shop_type)

func _handle_lever_activation(area: Area2D) -> void:
	var config: Dictionary = area.get_meta("config", {}) as Dictionary
	var target_mechanism: String = config.get("target_mechanism", "")
	
	# Trigger mechanism (open gates, activate traps, etc.)
	EventBus.mechanism_triggered.emit(area.get_meta("interactable_id"), target_mechanism)

func get_interactable_by_id(interactable_id: String) -> Area2D:
	for area in interactable_bodies:
		if area.get_meta("interactable_id", "") == interactable_id:
			return area
	return null

func deactivate_interactable(interactable_id: String) -> bool:
	var area := get_interactable_by_id(interactable_id)
	if area:
		area.set_meta("activated", false)
		return true
	return false

func cleanup() -> void:
	clear_interactables()

func _exit_tree() -> void:
	cleanup()
