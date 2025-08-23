# Configuration Files .tres Migration

**Status**: 📋 **TODO**  
**Priority**: Medium  
**Type**: Config Migration  
**Created**: 2025-08-23  
**Context**: Migrate config JSON files to .tres resources

## Overview

Convert configuration JSON files to .tres resources for type safety and Inspector editing.

## Files to Migrate

- [ ] `vibe/data/debug/log_config.json` → `log_config.tres`
- [ ] `vibe/data/ui/radar.json` → `radar_config.tres`
- [ ] `vibe/data/xp_curves.json` → `xp_curves.tres`

## Implementation Steps

### Phase 1: Create Resource Classes

#### Create LogConfig Resource
- [ ] Create `LogConfig.gd` resource class in `scripts/domain/`
- [ ] Add @export properties:
  - log_level (String) with enum validation
  - categories (Dictionary) for category enable/disable

#### Create RadarConfig Resource
- [ ] Create `RadarConfig.gd` resource class in `scripts/domain/`
- [ ] Add @export properties based on radar.json structure
- [ ] Include any UI positioning, colors, or behavior settings

#### Create XPCurvesConfig Resource
- [ ] Create `XPCurvesConfig.gd` resource class in `scripts/domain/`
- [ ] Add @export properties:
  - active_curve (String)
  - curves (Dictionary) with curve definitions
  - Include base_multiplier, exponent, min_first_level per curve

### Phase 2: Convert Log Config
- [ ] Convert `log_config.json` to `log_config.tres`
- [ ] Update Logger system to load .tres
- [ ] Test log level changes work
- [ ] Test category filtering works
- [ ] Verify F5/F6 hot-reload still functions

### Phase 3: Convert Radar Config  
- [ ] Convert `radar.json` to `radar_config.tres`
- [ ] Update EnemyRadar system to load .tres
- [ ] Test radar display works correctly
- [ ] Verify radar settings apply

### Phase 4: Convert XP Curves
- [ ] Convert `xp_curves.json` to `xp_curves.tres` 
- [ ] Update systems that read XP curves
- [ ] Test XP progression calculations
- [ ] Verify curve switching works

## Systems to Update

### Logger System
- [ ] Update Logger autoload to load `log_config.tres`
- [ ] Maintain hot-reload functionality (F5/F6)
- [ ] Keep runtime category toggling

### EnemyRadar System
- [ ] Update `EnemyRadar.gd` to load `radar_config.tres`
- [ ] Ensure radar positioning/display works

### XP System
- [ ] Update RunManager or XP systems to load `xp_curves.tres`
- [ ] Maintain XP calculation accuracy

## Testing

### Log Config Testing
- [ ] Verify different log levels work
- [ ] Test category filtering
- [ ] Test F5 config reload
- [ ] Test F6 level toggle

### Radar Config Testing  
- [ ] Verify radar displays correctly
- [ ] Test radar positioning
- [ ] Check radar color/size settings

### XP Curves Testing
- [ ] Test XP calculations match original
- [ ] Verify curve switching works
- [ ] Test level progression accuracy

## Success Criteria

- ✅ All 3 config files converted to .tres
- ✅ Resource classes provide type safety
- ✅ Inspector editing works for all configs
- ✅ Hot-reload functionality maintained where applicable
- ✅ All systems function identically to JSON version
- ✅ JSON parsing code removed