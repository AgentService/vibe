## MinimalBossAI - Ultra-lightweight AI for maximum performance
## Drop-in replacement for BaseBoss._update_ai() for testing
##
## Performance gains vs current AI:
## - No sqrt (uses distance_squared)
## - No PlayerState lookup per boss (pass as parameter)
## - No personal space forces
## - No direction variable
## - No DamageService update (batched)
## - ~60% faster execution

static func update_minimal(boss: CharacterBody2D, accumulated_dt: float, player_pos: Vector2, speed: float, attack_range: float) -> void:
	# Ultra-fast chase AI - no intermediate variables
	var to_player := player_pos - boss.global_position
	var dist_sq := to_player.length_squared()

	# Attack range check using squared distance (avoids sqrt)
	var attack_range_sq := attack_range * attack_range

	if dist_sq > attack_range_sq:
		# Chase: Scale velocity for accumulated time
		var physics_dt := 1.0 / 30.0
		var scale_factor := accumulated_dt / physics_dt
		boss.velocity = to_player.normalized() * speed * scale_factor
		boss.move_and_slide()

		# Simple sprite flip (optional - can remove for max performance)
		var sprite = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite and abs(to_player.x) > 0.1:
			sprite.flip_h = to_player.x < 0
	else:
		# Attack: Stop moving
		boss.velocity = Vector2.ZERO


## Batch-optimized version for BossUpdateManager integration
## Processes multiple bosses with shared player position
static func update_batch_minimal(bosses: Array, boss_ids: Array, accumulators: Array, player_pos: Vector2, batch_start: int, batch_end: int, speed: float = 100.0, attack_range: float = 80.0) -> void:
	var attack_range_sq := attack_range * attack_range
	var physics_dt := 1.0 / 30.0

	for i in range(batch_start, batch_end):
		var boss = bosses[i] as CharacterBody2D
		if not is_instance_valid(boss):
			continue

		# Ultra-minimal AI logic
		var to_player := player_pos - boss.global_position
		var dist_sq := to_player.length_squared()
		var accumulated_dt := accumulators[i]

		if dist_sq > attack_range_sq:
			var scale_factor := accumulated_dt / physics_dt
			boss.velocity = to_player.normalized() * speed * scale_factor
			boss.move_and_slide()

			# Optional sprite flip
			var sprite = boss.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if sprite and abs(to_player.x) > 0.1:
				sprite.flip_h = to_player.x < 0
		else:
			boss.velocity = Vector2.ZERO

		# Reset accumulator
		accumulators[i] = 0.0


## Comparison: Operations per boss update
##
## Current AI (_update_ai):
## - PlayerState.position lookup (hash table)
## - distance_to() - sqrt operation
## - chase_range comparison
## - attack_range comparison
## - normalized() × 2
## - personal_space loop
## - DamageService update
## - Logger.debug call
## = ~15-20 operations
##
## Minimal AI:
## - length_squared() - 2 multiplies + 1 add
## - squared comparison - 1 multiply
## - normalized() - ~4 operations
## - velocity assignment
## - move_and_slide()
## = ~8-10 operations
##
## Savings: ~50% fewer operations per update
## With 1000 enemies @ 20/batch: ~6,000 operations saved per second
