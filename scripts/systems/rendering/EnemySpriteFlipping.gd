## EnemySpriteFlipping - Generic utility for enemy sprite direction handling
## Provides consistent sprite flipping behavior for all enemy types
##
## This is a static utility class - all methods are static

class_name EnemySpriteFlipping

## Flip an AnimatedSprite2D or Sprite2D based on movement direction
## Used by scene-based bosses and individual enemies
static func flip_sprite_for_direction(sprite: Node, direction: Vector2) -> void:
	if not sprite:
		return
		
	# Handle both AnimatedSprite2D and Sprite2D
	if sprite is AnimatedSprite2D or sprite is Sprite2D:
		if direction.x < 0:
			sprite.flip_h = true  # Moving left
		elif direction.x > 0:
			sprite.flip_h = false # Moving right
		# If direction.x == 0 (moving straight up/down), keep current orientation

## Update MultiMesh sprite flipping for pooled enemies
## This requires modifying the MultiMesh transform data
static func update_multimesh_flipping(multimesh: MultiMesh, enemy_data: Array, target_pos: Vector2) -> void:
	if not multimesh or enemy_data.is_empty():
		return
	
	# Update each enemy's transform to include flipping
	for i in range(enemy_data.size()):
		var enemy = enemy_data[i]
		if not enemy or not enemy.has("pos") or not enemy.has("alive") or not enemy.alive:
			continue
			
		var direction: Vector2 = (target_pos - enemy.pos).normalized()
		var transform := Transform2D()
		
		# Position
		transform.origin = enemy.pos
		
		# Scale with flipping
		if direction.x < 0:
			transform.x = Vector2(-1, 0)  # Flip horizontally
		else:
			transform.x = Vector2(1, 0)   # Normal
		transform.y = Vector2(0, 1)
		
		# Update the MultiMesh instance transform
		multimesh.set_instance_transform_2d(i, transform)

## Simplified flip function for direction-based flipping without sprite reference
## Returns true if should be flipped (facing left), false if normal (facing right)
static func should_flip_for_direction(direction: Vector2) -> bool:
	return direction.x < 0
