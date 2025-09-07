# Hardcoded Values Audit & Data-Driven Migration

**Status:** ✅ COMPLETED  
**Priority:** MEDIUM  
**Category:** Data-Driven Architecture  
**Created:** 2025-09-07  

## Objective

Identify and migrate hardcoded game values to data-driven configuration files to fully comply with Phase 3 of the architecture checklist.

## Current Findings

### Critical Hardcoded Values Found

#### Character Creation Stats (CharacterSelect.gd:23-34)
```gdscript
var character_data = {
	"knight": {
		"stats": {"hp": 100, "damage": 25, "speed": 1.0}
	},
	"ranger": {
		"stats": {"hp": 75, "damage": 30, "speed": 1.2}
	}
}
```
**Issue:** Character base stats hardcoded in UI component  
**Solution:** Move to `data/content/player/character_types.tres`

#### XP Progression Fallbacks (PlayerProgression.gd:14,116)
```gdscript
var xp_to_next: float = 100.0
xp_to_next = 100.0  # Fallback
```
**Issue:** XP curve fallback values hardcoded  
**Solution:** Define in `data/progression/xp_curve.tres` with proper error handling

#### Boss Scaling Values (DebugManager.gd:295-296)
```gdscript
boss_config.health *= 3.0
boss_config.damage *= 1.5
```
**Issue:** Debug boss scaling hardcoded  
**Solution:** Move to `data/debug/boss_scaling.tres`

#### Visual Feedback Timing (BossHitFeedback.gd:23-24)
```gdscript
@export var flash_duration_override: float = 0.2
@export var flash_intensity_override: float = 15.0
```
**Issue:** Boss hit feedback values should be configurable  
**Solution:** Reference `data/balance/visual_feedback.tres`

### Medium Priority Hardcoded Values

#### Performance Limits (BossHitFeedback.gd:300)
```gdscript
if boss_knockback_effects.size() > 50:  # Lower limit for bosses
```

#### Timer Values (BossHitFeedback.gd:58)
```gdscript
boss_scanner.wait_time = 3.0  # Check every 3 seconds
```

## Migration Plan

### Phase 1: Character System Data-Driven
- Create `data/content/player/character_types.tres`
- Define CharacterType resource class
- Update CharacterSelect.gd to load from data
- Validate character creation still works

### Phase 2: XP Progression Configuration
- Enhance `data/progression/xp_curve.tres`
- Add fallback values to resource
- Update PlayerProgression error handling
- Test level-up scenarios

### Phase 3: Boss & Combat Values
- Create `data/debug/boss_scaling.tres`
- Move visual feedback overrides to balance data
- Update DebugManager to load configurations
- Test debug mode functionality

### Phase 4: Performance Configuration
- Create `data/balance/performance_limits.tres`
- Define performance thresholds as data
- Update systems to reference configuration
- Validate performance behavior unchanged

## Resource Schema Changes

### New Resource: CharacterType
```gdscript
extends Resource
class_name CharacterType

@export var id: StringName
@export var display_name: String
@export var description: String
@export var base_hp: float
@export var base_damage: float
@export var base_speed: float
@export var starting_abilities: Array[StringName]
```

### Enhanced Resource: XPCurve
```gdscript
# Add fallback configurations
@export var base_xp_required: float = 100.0
@export var xp_scaling_factor: float = 1.5
@export var max_level_xp_required: float = 0.0  # 0 = unlimited
```

### New Resource: BossScaling
```gdscript
extends Resource
class_name BossScaling

@export var health_multiplier: float = 3.0
@export var damage_multiplier: float = 1.5
@export var speed_multiplier: float = 1.0
```

## Files to Create/Modify

### New Files
- `data/content/player/character_types.tres`
- `data/debug/boss_scaling.tres`
- `data/balance/performance_limits.tres`
- `scripts/domain/CharacterType.gd`
- `scripts/domain/BossScaling.gd`

### Modified Files
- `scenes/ui/CharacterSelect.gd` (load from data)
- `autoload/PlayerProgression.gd` (enhanced error handling)
- `autoload/DebugManager.gd` (load configurations)
- `scripts/systems/BossHitFeedback.gd` (reference balance data)

## Validation Tests

### Test Character Creation
```bash
# Ensure character creation works with new data-driven approach
"./Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/test_character_creation.gd
```

### Test XP Progression Edge Cases
```bash
# Validate XP curve fallbacks and error handling
"./Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/test_xp_edge_cases.gd
```

### Test Debug Boss Scaling
```bash
# Confirm boss scaling still works with configuration
"./Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/test_boss_debug_scaling.gd
```

## Success Criteria

- ✅ All character stats loaded from `.tres` files
- ✅ No hardcoded XP values in progression system
- ✅ Boss scaling fully configurable
- ✅ Visual feedback timing externalized
- ✅ All existing functionality preserved
- ✅ Hot-reload works for all new configurations

## Documentation Updates Required

- Update `/data/content/player/README.md` with CharacterType schema
- Update `/data/debug/README.md` with debug configurations
- Update CHANGELOG.md with data-driven migration notes