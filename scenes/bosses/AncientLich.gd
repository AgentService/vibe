extends BaseBoss

## Ancient Lich Boss - V2 Enemy System Integration  
## Scene-based boss with AnimatedSprite2D for proper visual workflow
## Now inherits from BaseBoss for unified systems support

class_name AncientLich

# AncientLich specific properties
var is_taking_damage: bool = false

func _ready() -> void:
	# Call parent _ready() to handle base initialization (spawn effect + animation)
	super._ready()
	# Note: Wake-up animation (if present) plays during spawn dissolve (0.5s)

	# Connect animation finished for damage animation
	if animated_sprite:
		animated_sprite.connect("animation_finished", _on_animation_finished)

func get_boss_name() -> String:
	return "AncientLich"

# Override _exit_tree to call parent cleanup
func _exit_tree() -> void:
	super._exit_tree()

# Override setup_from_spawn_config to call parent and add specific behavior
func setup_from_spawn_config(config: SpawnConfig) -> void:
	# Call parent setup first
	super.setup_from_spawn_config(config)
	
	# AncientLich specific spawn config handling
	Logger.info("AncientLich boss spawned: HP=%.1f DMG=%.1f SPD=%.1f Scale=%.2fx" % [max_health, damage, speed, config.size_scale], "bosses")
	
	# Note: Scaling is handled by unified scaling system in parent - no additional calls needed

# Override parent _on_damage_entity_sync to add AncientLich specific damage handling
func _on_damage_entity_sync(payload: Dictionary) -> void:
	# Call parent damage sync handling first
	super._on_damage_entity_sync(payload)
	
	# Add AncientLich specific damage response
	var entity_id: String = payload.get("entity_id", "")
	var expected_entity_id = "boss_" + str(get_instance_id())
	if entity_id == expected_entity_id and not payload.get("is_death", false):
		_trigger_damage_animation()

# Override parent AI for AncientLich-specific behavior (optional)
func _update_ai(_dt: float) -> void:
	# IMPORTANT: Check spawn state first (from BaseBoss)
	if _is_spawning or ai_paused or _is_dying:
		return

	# Call parent AI behavior for standard movement and attacks
	super._update_ai(_dt)

	# Add AncientLich specific behavior here if needed

# Override parent attack with AncientLich-specific magic damage
func _perform_attack() -> void:
	Logger.debug("AncientLich attacks for %.1f damage!" % attack_damage, "bosses")
	
	# Apply magic damage to player via unified DamageService
	var distance_to_player: float = global_position.distance_to(target_position)
	if distance_to_player <= attack_range:
		var source_name = "boss_ancient_lich"
		var damage_tags = ["magic", "boss"]  # Magic damage type
		DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# AncientLich specific methods

func _on_animation_finished() -> void:
	# Handle damage animation completion
	if animated_sprite.animation == "damage_taken":
		is_taking_damage = false
		animated_sprite.play("default")

func _trigger_damage_animation() -> void:
	# Trigger damage animation if not already playing
	if not is_taking_damage:
		is_taking_damage = true
		animated_sprite.play("damage_taken")
