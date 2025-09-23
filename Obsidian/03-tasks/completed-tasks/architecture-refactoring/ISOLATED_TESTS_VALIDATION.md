# Isolated Tests Validation Task

## Overview
Review and validate the 8 isolated test scenes created for the GameOrchestrator refactor. Some tests may not be working correctly and need debugging.

## Test Scenes to Validate

### ✅ Completed Tests (all working)
- [x] **CoreLoop_Isolated.tscn** - Basic player movement, camera, HUD, pause
- [x] **EnemySystem_Isolated.tscn** - Enemy spawning with 300 enemies in grid
- [x] **CardSystem_Isolated.tscn** - Card selection UI and application
  - Fixed card display showing "Unknown Card"
  - Fixed modifier key mapping (melee_damage_add → melee_damage)
  - Added support for multiplicative modifiers (*_mult)
- [x] **CameraSystem_Isolated.tscn** - Camera following, zoom, bounds
  - Fixed camera deadzone by separating camera from player parent
  - Added preload statement for CameraSystem class
- [x] **AbilitySystem_Isolated.tscn** - Projectile spawning and management
  - Fixed keycode errors (removed invalid KEY_KP_PLUS constants)
  - Added proper numpad support (KEY_KP_ADD, KEY_KP_SUBTRACT)
  - Added preload statement for AbilitySystem class
- [x] **WaveDirector_Isolated.tscn** - Wave spawning and management
  - Fixed signal connection errors (added has_signal checks)
- [x] **MeleeSystem_Isolated.tscn** - Melee attacks and enemy interactions
  - Fixed system reference setup (updated method names)
  - Fixed signal connection errors
- [x] **DamageSystem_Isolated.tscn** - Damage calculation and application
  - Fixed system reference setup (updated method names)
  - Fixed signal connection errors

### 🔧 Issues Identified
1. **Real Game Camera System** - Needs deadzone fix (separate task)
2. **Mouse Firing in AbilitySystem** - May need core system implementation (separate task)

## Common Issues to Check

### System Class Dependencies
- Verify all system classes exist in `scripts/systems/`
- Check if systems have required methods called by tests
- Validate signal connections and method signatures

### GameOrchestrator Integration
- Ensure systems work both in isolation and with GameOrchestrator
- Check if dependency injection affects system behavior
- Validate autoload initialization order

### Test Implementation Issues
- Check for missing method calls or incorrect assumptions
- Verify MultiMesh setup and rendering logic
- Validate input handling and UI updates

## Validation Process

1. **Run Each Test Scene**
   ```bash
   "./Godot_v4.4.1-stable_win64_console.exe" --headless tests/[TestName].tscn --quit-after 5
   ```

2. **Check for Errors**
   - Look for missing class errors
   - Check for null reference exceptions
   - Validate method call errors

3. **Fix Issues Found**
   - Update system class implementations if needed
   - Fix method signatures and signal connections
   - Correct test assumptions about system behavior

4. **Manual Testing**
   - Run tests interactively to verify functionality
   - Test controls and visual feedback
   - Validate system interactions

## Success Criteria
- All 8 test scenes load without errors
- Interactive controls work as documented
- Systems behave correctly in isolation
- Tests provide useful debugging information

## Priority
**High** - These tests are critical for system validation during the refactor process.

## Estimated Time
2-3 hours for full validation and fixes.