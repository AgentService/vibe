extends CharacterBody2D

## BaseBoss - Base class for all scene-based bosses
## Provides unified damage integration, performance optimization, and directional animation logic

class_name BaseBoss

signal died

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: BossHealthBar = $BossHealthBar

# Boss configuration (override in child classes)
var spawn_config: SpawnConfig
var max_health: float = 300.0
var current_health: float = 300.0
var damage: float = 40.0
var speed: float = 60.0
var attack_damage: float = 40.0
var attack_cooldown: float = 2.0
var last_attack_time: float = 0.0

# AI configuration (override in child classes)
var target_position: Vector2
var attack_range: float = 80.0
var chase_range: float = 300.0
var ai_paused: bool = false

# Animation configuration
var current_direction: Vector2 = Vector2.DOWN
var animation_prefix: String = "walk"  # Override in child classes (e.g., "scary_walk")

# Child classes should override these methods
func get_boss_name() -> String:
    return "BaseBoss"

func _perform_attack() -> void:
    Logger.debug(get_boss_name() + " attacks for %.1f damage!" % attack_damage, "bosses")
    # Child classes should implement specific attack behavior

func _ready() -> void:
    Logger.info(get_boss_name() + " spawned with " + str(max_health) + " HP", "bosses")
    
    # Start default animation if available
    if animated_sprite and animated_sprite.sprite_frames:
        var default_anim = animation_prefix + "_south"
        if animated_sprite.sprite_frames.has_animation(default_anim):
            animated_sprite.play(default_anim)
            Logger.debug(get_boss_name() + " animation started: " + default_anim, "bosses")
    
    # BOSS PERFORMANCE V2: Register with centralized BossUpdateManager
    var boss_id = "boss_" + str(get_instance_id())
    BossUpdateManager.register_boss(self, boss_id)
    Logger.debug(get_boss_name() + " registered with BossUpdateManager as " + boss_id, "performance")
    
    # Connect to signals
    if EventBus:
        # DAMAGE V3: Listen for unified damage sync events
        EventBus.damage_entity_sync.connect(_on_damage_entity_sync)
        # DEBUG: Listen for cheat toggles (AI pause)
        EventBus.cheat_toggled.connect(_on_cheat_toggled)
    
    # DAMAGE V3: Register with both DamageService and EntityTracker
    var entity_id = "boss_" + str(get_instance_id())
    var entity_data = {
        "id": entity_id,
        "type": "boss",
        "hp": current_health,
        "max_hp": max_health,
        "alive": true,
        "pos": global_position
    }
    
    # Register with both systems for unified damage V3
    DamageService.register_entity(entity_id, entity_data)
    EntityTracker.register_entity(entity_id, entity_data)
    Logger.debug(get_boss_name() + " registered with DamageService and EntityTracker as " + entity_id, "bosses")
    
    # Initialize health bar
    _update_health_bar()

func _exit_tree() -> void:
    # BOSS PERFORMANCE V2: Unregister from BossUpdateManager
    var boss_id = "boss_" + str(get_instance_id())
    BossUpdateManager.unregister_boss(boss_id)
    
    # Clean up signal connections
    if EventBus and EventBus.damage_entity_sync.is_connected(_on_damage_entity_sync):
        EventBus.damage_entity_sync.disconnect(_on_damage_entity_sync)
    if EventBus and EventBus.cheat_toggled.is_connected(_on_cheat_toggled):
        EventBus.cheat_toggled.disconnect(_on_cheat_toggled)
    
    # DAMAGE V3: Unregister from both systems
    var entity_id = "boss_" + str(get_instance_id())
    DamageService.unregister_entity(entity_id)
    EntityTracker.unregister_entity(entity_id)

func setup_from_spawn_config(config: SpawnConfig) -> void:
    spawn_config = config
    max_health = config.health
    current_health = config.health
    damage = config.damage
    speed = config.speed
    attack_damage = config.damage
    
    # Set position
    global_position = config.position
    
    # Apply visual config
    scale = Vector2.ONE * config.size_scale
    
    Logger.info(get_boss_name() + " configured: HP=%.1f DMG=%.1f SPD=%.1f" % [max_health, damage, speed], "bosses")

## BOSS PERFORMANCE V2: Batch AI interface called by BossUpdateManager
func _update_ai_batch(dt: float) -> void:
    _update_ai(dt)
    last_attack_time += dt

## Base AI logic - child classes can override or extend
func _update_ai(_dt: float) -> void:
    # Skip AI updates if paused by debug system
    if ai_paused:
        return
    
    # Get player position from PlayerState
    if not PlayerState.has_player_reference():
        return
    
    target_position = PlayerState.position
    var distance_to_player: float = global_position.distance_to(target_position)
    
    # Chase behavior when player is in range
    if distance_to_player <= chase_range:
        if distance_to_player > attack_range:
            # Move toward player
            var direction: Vector2 = (target_position - global_position).normalized()
            velocity = direction * speed
            move_and_slide()
            
            # Update directional animation automatically
            _update_directional_animation(direction)
            current_direction = direction
            
            # Update position in damage system
            var entity_id = "boss_" + str(get_instance_id())
            DamageService.update_entity_position(entity_id, global_position)
        else:
            # In attack range - stop and attack
            velocity = Vector2.ZERO
            if last_attack_time >= attack_cooldown:
                _perform_attack()
                last_attack_time = 0.0

## DIRECTIONAL ANIMATION SYSTEM
## Automatically converts movement direction to appropriate 8-directional animation
func _update_directional_animation(direction: Vector2) -> void:
    if not animated_sprite or not animated_sprite.sprite_frames:
        return
        
    # Convert direction to 8-directional animation
    var angle = direction.angle()
    var animation_name = animation_prefix + "_"
    
    # Convert angle to 8 directions
    if angle >= -PI/8 and angle < PI/8:
        animation_name += "east"
    elif angle >= PI/8 and angle < 3*PI/8:
        animation_name += "south_east"
    elif angle >= 3*PI/8 and angle < 5*PI/8:
        animation_name += "south"
    elif angle >= 5*PI/8 and angle < 7*PI/8:
        animation_name += "south_west"
    elif angle >= 7*PI/8 or angle < -7*PI/8:
        animation_name += "west"
    elif angle >= -7*PI/8 and angle < -5*PI/8:
        animation_name += "north_west"
    elif angle >= -5*PI/8 and angle < -3*PI/8:
        animation_name += "north"
    else:  # -3*PI/8 to -PI/8
        animation_name += "north_east"
    
    # Only change animation if it's different and exists
    if animated_sprite.animation != animation_name and animated_sprite.sprite_frames.has_animation(animation_name):
        animated_sprite.play(animation_name)

## DAMAGE V3: Handle unified damage sync events for scene bosses
func _on_damage_entity_sync(payload: Dictionary) -> void:
    var entity_id: String = payload.get("entity_id", "")
    var entity_type: String = payload.get("entity_type", "")
    var new_hp: float = payload.get("new_hp", 0.0)
    var is_death: bool = payload.get("is_death", false)
    
    # Only handle boss entities matching this instance
    if entity_type != "boss":
        return
    
    var expected_entity_id = "boss_" + str(get_instance_id())
    if entity_id != expected_entity_id:
        return
    
    # Update boss HP
    current_health = new_hp
    _update_health_bar()
    
    # Handle death
    if is_death:
        Logger.info("V3: Boss %s killed via damage sync" % [entity_id], "combat")
        _die()
    else:
        # Update EntityTracker health data
        var tracker_data = EntityTracker.get_entity(entity_id)
        if tracker_data.has("id"):
            tracker_data["hp"] = new_hp

func _die() -> void:
    Logger.info(get_boss_name() + " has been defeated!", "bosses")
    died.emit()
    queue_free()

# Public interface for damage system integration
func get_max_health() -> float:
    return max_health

func get_current_health() -> float:
    return current_health

func set_current_health(new_health: float) -> void:
    var old_health = current_health
    current_health = new_health
    _update_health_bar()
    
    # Check for death
    if current_health <= 0.0 and is_alive():
        _die()

func is_alive() -> bool:
    return current_health > 0.0

func _update_health_bar() -> void:
    if health_bar:
        health_bar.update_health(current_health, max_health)

func _on_cheat_toggled(payload: CheatTogglePayload) -> void:
    # Handle AI pause/unpause cheat toggle
    if payload.cheat_name == "ai_paused":
        ai_paused = payload.enabled