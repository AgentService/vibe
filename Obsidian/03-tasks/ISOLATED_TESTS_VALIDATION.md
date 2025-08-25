# Isolated Tests Validation Task

## Overview
Review and validate the 8 isolated test scenes created for the GameOrchestrator refactor. Some tests may not be working correctly and need debugging.

## Test Scenes to Validate

### Working Tests (verified)
- [x] CoreLoop_Isolated.tscn - Basic player movement, camera, HUD, pause
- [x] EnemySystem_Isolated.tscn - Enemy spawning with 300 enemies in grid
- [x] CardSystem_Isolated.tscn - Card selection UI and application

### Tests Requiring Validation
- [ ] **CameraSystem_Isolated.tscn** - Camera following, zoom, bounds
  - Check if CameraSystem class exists and methods work
  - Validate camera setup and following logic
  
- [ ] **AbilitySystem_Isolated.tscn** - Projectile spawning and management
  - Verify AbilitySystem class and projectile pooling
  - Test MultiMesh projectile rendering
  
- [ ] **WaveDirector_Isolated.tscn** - Wave spawning and management
  - Check WaveDirector class implementation
  - Validate enemy wave progression logic
  
- [ ] **MeleeSystem_Isolated.tscn** - Melee attacks and enemy interactions
  - Verify MeleeSystem class exists
  - Test melee attack mechanics and collision
  
- [ ] **DamageSystem_Isolated.tscn** - Damage calculation and application
  - Check DamageSystem implementation
  - Validate damage types and resistance calculations

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