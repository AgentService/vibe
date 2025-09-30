extends Resource
class_name PlayerXPCurve

## Player XP curve configuration resource for progression system.
## Defines total XP thresholds required to reach each level with selectable curves.
## Index 0 = XP needed to reach level 2, Index 1 = XP needed to reach level 3, etc.

enum CurveType { NORMAL, FAST, SLOW }

@export var active_curve: CurveType = CurveType.NORMAL
@export_group("Normal Curve (Default)")
@export var normal_thresholds: Array[int] = [100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500]
@export_group("Fast Curve (Quick Testing)")
@export var fast_thresholds: Array[int] = [10, 25, 50, 80, 120, 170, 230, 300, 380, 470]
@export_group("Slow Curve (Extended Play)")
@export var slow_thresholds: Array[int] = [200, 600, 1200, 2000, 3000, 4200, 5600, 7200, 9000, 11000, 13500, 16500, 20000, 24000, 29000]
@export_group("Fallback Configuration")
@export var base_xp_required: float = 100.0
@export var xp_scaling_factor: float = 1.5
@export var max_level_xp_required: float = 0.0  # 0 = unlimited

var thresholds: Array[int]:
	get:
		match active_curve:
			CurveType.FAST:
				return fast_thresholds
			CurveType.SLOW:
				return slow_thresholds
			_:
				return normal_thresholds

## Get XP required to reach the next level from current level
func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0  # Level 1 is starting level, no XP required
	
	var threshold_index: int = level - 2  # Level 2 -> index 0, level 3 -> index 1, etc.
	
	if threshold_index >= 0 and threshold_index < thresholds.size():
		return thresholds[threshold_index]
	else:
		# Beyond defined levels, return -1 to indicate max level reached
		return -1

## Get the maximum level defined by this curve
func get_max_level() -> int:
	return thresholds.size() + 1  # +1 because we start at level 1

## Validate that the curve has valid data
func is_valid() -> bool:
	if thresholds.is_empty():
		return false
	
	# Ensure thresholds are monotonically increasing
	for i in range(1, thresholds.size()):
		if thresholds[i] <= thresholds[i - 1]:
			return false
	
	return true

## Get fallback XP requirement for emergency situations
func get_fallback_xp() -> float:
	return base_xp_required

## Generate fallback curve when no valid thresholds exist
func generate_fallback_curve(max_levels: int = 10) -> Array[int]:
	var fallback_curve: Array[int] = []
	var current_xp: float = base_xp_required
	
	for i in range(max_levels):
		fallback_curve.append(int(current_xp))
		current_xp *= xp_scaling_factor
		
		# Cap at max_level_xp_required if specified
		if max_level_xp_required > 0.0 and current_xp > max_level_xp_required:
			current_xp = max_level_xp_required
	
	return fallback_curve
