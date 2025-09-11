extends BaseBoss

## Demon Overlord Boss - Inherits from BaseBoss with custom stats and attack behavior

class_name DemonOverlord

func _ready() -> void:
    # Set custom demon overlord stats
    max_health = 400.0
    current_health = 400.0
    damage = 45.0
    speed = 80.0
    attack_damage = 45.0
    attack_cooldown = 1.8
    attack_range = 90.0
    chase_range = 400.0
    animation_prefix = "scary_walk"  # Uses scary_walk_north, scary_walk_south, etc.
    
    # Call parent _ready() to handle all base initialization
    super._ready()

func get_boss_name() -> String:
    return "DemonOverlord"

func _perform_attack() -> void:
    Logger.debug("DemonOverlord unleashes demonic fury for %.1f damage!" % attack_damage, "bosses")
    
    # Apply fire/demon damage to player
    var distance_to_player: float = global_position.distance_to(target_position)
    if distance_to_player <= attack_range:
        var source_name = "boss_demon_overlord"
        var damage_tags = ["fire", "boss", "demon"]
        DamageService.apply_damage("player", attack_damage, source_name, damage_tags)

# Custom demon overlord behavior can be added here
func _update_ai(dt: float) -> void:
    # Call base AI first (handles chase, movement, directional animations)
    super._update_ai(dt)
    
    # Add any custom demon overlord AI behavior here
    # For example: special attacks, phase changes, etc.