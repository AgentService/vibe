extends Node

## Enemy Animation System - Phase 7 Arena Refactoring
## PERFORMANCE MODE: All animation and texture functionality removed
## Simplified system for maximum performance during stress testing

class_name EnemyAnimationSystem

# MultiMesh references for applying animations
var mm_enemies_swarm: MultiMeshInstance2D
var mm_enemies_regular: MultiMeshInstance2D
var mm_enemies_elite: MultiMeshInstance2D
var mm_enemies_boss: MultiMeshInstance2D

func setup(multimesh_refs: Dictionary) -> void:
	mm_enemies_swarm = multimesh_refs.get("swarm")
	mm_enemies_regular = multimesh_refs.get("regular") 
	mm_enemies_elite = multimesh_refs.get("elite")
	mm_enemies_boss = multimesh_refs.get("boss")
	
	Logger.info("EnemyAnimationSystem setup complete (PERFORMANCE MODE - all animations removed)", "animations")

func animate_frames(delta: float) -> void:
	# PERFORMANCE MODE: All animation functionality removed
	pass
