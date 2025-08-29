extends Resource

## Enemy V2 Template system resource definition.
## Supports inheritance via parent_path and deterministic variation ranges.
## Designed for data-driven enemy creation with minimal code changes.

class_name EnemyTemplate

@export var id: StringName = ""
@export var parent_path: String = ""  # Optional inheritance from another template
@export var health_range: Vector2 = Vector2(10.0, 15.0)  # min, max health
@export var damage_range: Vector2 = Vector2(5.0, 8.0)   # min, max damage  
@export var speed_range: Vector2 = Vector2(50.0, 80.0)   # min, max speed
@export var size_factor: float = 1.0                     # Scale multiplier
@export var hue_range: Vector2 = Vector2(0.0, 1.0)       # 0.0-1.0 hue range
@export var tags: Array[StringName] = []                 # For filtering/categorization
@export var weight: float = 1.0                          # Spawn weight (optional if using central table)

# Render tier for pooling system compatibility
@export var render_tier: String = "regular"  # swarm, regular, elite, boss

# Optional visual config for backwards compatibility
@export var visual_config: Dictionary = {}

# Boss scene path for data-driven boss spawning
@export var boss_scene_path: String = ""  # Path to boss scene for boss-tier templates

func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if id.is_empty():
		errors.append("EnemyTemplate must have an id")
	
	if health_range.x <= 0.0 or health_range.y <= 0.0:
		errors.append("Health range values must be greater than 0")
		
	if health_range.x > health_range.y:
		errors.append("Health range: min cannot be greater than max")
	
	if damage_range.x < 0.0 or damage_range.y < 0.0:
		errors.append("Damage range values cannot be negative")
		
	if damage_range.x > damage_range.y:
		errors.append("Damage range: min cannot be greater than max")
	
	if speed_range.x < 0.0 or speed_range.y < 0.0:
		errors.append("Speed range values cannot be negative")
		
	if speed_range.x > speed_range.y:
		errors.append("Speed range: min cannot be greater than max")
	
	if size_factor <= 0.0:
		errors.append("Size factor must be greater than 0")
	
	if hue_range.x < 0.0 or hue_range.x > 1.0 or hue_range.y < 0.0 or hue_range.y > 1.0:
		errors.append("Hue range values must be between 0.0 and 1.0")
		
	if hue_range.x > hue_range.y:
		errors.append("Hue range: min cannot be greater than max")
	
	if weight < 0.0:
		errors.append("Weight cannot be negative")
	
	var valid_tiers: Array[String] = ["swarm", "regular", "elite", "boss"]
	if not render_tier in valid_tiers:
		errors.append("Render tier must be one of: " + str(valid_tiers))
	
	# Validate boss scene path for boss-tier templates
	if render_tier == "boss" and boss_scene_path.is_empty():
		errors.append("Boss-tier templates must have a boss_scene_path")
	
	return errors

## Resolve inheritance by loading and flattening parent template
func resolve_inheritance() -> EnemyTemplate:
	if parent_path.is_empty():
		return self
	
	# Load parent template
	var parent_template: EnemyTemplate = load(parent_path) as EnemyTemplate
	if not parent_template:
		Logger.warn("Failed to load parent template: " + parent_path, "enemies")
		return self
	
	# Recursively resolve parent's inheritance first
	var resolved_parent: EnemyTemplate = parent_template.resolve_inheritance()
	
	# Create flattened template by inheriting from resolved parent
	var flattened: EnemyTemplate = EnemyTemplate.new()
	
	# Copy parent values first
	flattened.id = self.id  # Keep child's ID
	flattened.parent_path = ""  # Clear inheritance after resolving
	flattened.health_range = resolved_parent.health_range
	flattened.damage_range = resolved_parent.damage_range
	flattened.speed_range = resolved_parent.speed_range
	flattened.size_factor = resolved_parent.size_factor
	flattened.hue_range = resolved_parent.hue_range
	flattened.tags = resolved_parent.tags.duplicate()
	flattened.weight = resolved_parent.weight
	flattened.render_tier = resolved_parent.render_tier
	flattened.visual_config = resolved_parent.visual_config.duplicate()
	flattened.boss_scene_path = resolved_parent.boss_scene_path
	
	# Override with child values (only if they differ from defaults)
	if self.health_range != Vector2(10.0, 15.0):
		flattened.health_range = self.health_range
	if self.damage_range != Vector2(5.0, 8.0):
		flattened.damage_range = self.damage_range
	if self.speed_range != Vector2(50.0, 80.0):
		flattened.speed_range = self.speed_range
	if self.size_factor != 1.0:
		flattened.size_factor = self.size_factor
	if self.hue_range != Vector2(0.0, 1.0):
		flattened.hue_range = self.hue_range
	if not self.tags.is_empty():
		flattened.tags = self.tags.duplicate()
	if self.weight != 1.0:
		flattened.weight = self.weight
	if self.render_tier != "regular":
		flattened.render_tier = self.render_tier
	if not self.visual_config.is_empty():
		flattened.visual_config = self.visual_config.duplicate()
	if not self.boss_scene_path.is_empty():
		flattened.boss_scene_path = self.boss_scene_path
	
	return flattened
