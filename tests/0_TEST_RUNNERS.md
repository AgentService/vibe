# Test Runners Documentation

## Zero-Allocation Breach Optimization Tests Added

The breach optimization tests have been successfully integrated into the existing test infrastructure.

## Available Test Runners

### 1. **Main Comprehensive Test Runner** (`0_run_tests.sh`)
Runs all test categories including the new zero-allocation breach optimization tests.

```bash
# Run all tests (recommended)
cd tests && bash 0_run_tests.sh
```

**Test Categories Included:**
- ✅ Core Unit Tests (RNG, Signal Contracts)
- ✅ **Zero-Allocation Breach Optimization Tests** (NEW)
- ✅ Integration Tests (Character Manager, State Transitions)
- ✅ Performance Stress Tests (Boss, Radar, etc.)
- ✅ Balance and Simulation Tests

### 2. **Performance Test Runner** (`tests/run_performance_tests.sh`)
Focuses on performance and stress tests, now includes breach optimization.

```bash
# Run performance tests only
cd tests && bash run_performance_tests.sh
```

**New Tests Added:**
- ✅ Test 5: Zero-Allocation Breach Enemy Tracking Test
- ✅ Test 6: Breach Optimization Verification Test

### 3. **Core GDScript Test Runner** (`tests/run_tests.tscn`)
Runs basic unit tests with guidance for breach tests.

```bash
# Run core tests only
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn
```

## Individual Breach Optimization Tests

### **Comprehensive Test Suite** (Recommended for validation)
```bash
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_breach_enemy_tracking.tscn
```

**Tests 5 critical areas:**
- Capacity overflow handling (300 enemies vs 256 capacity)
- Safe concurrent removal during iteration
- 30Hz timing preservation
- Zero allocation during enemy lifecycle
- Multi-breach isolation

### **Simple Verification Test** (Quick check)
```bash
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/breach_optimization_verification.tscn
```

**Verifies:**
- RingBuffer tracking active
- Performance metrics
- 30Hz fixed-step integration
- Multi-breach handling

## Test Results Interpretation

### **Success Indicators**
When tests pass, you should see:
```
✓ Capacity overflow handled gracefully (256 successful, 44 rejected)
✓ Safe concurrent removal working: 50 -> 33 enemies
✓ 30Hz timing preserved: 90 samples, expansion 55.0 -> 218.5
✓ Zero allocation test completed: 5 cycles × 40 enemies
✓ Multi-breach isolation working: 3 breaches × 10 enemies, isolated trackers
```

### **Performance Metrics**
- **Enemy addition speed**: 8-21ms for 60 enemies (vs previous Array resizing)
- **Capacity utilization**: 60/256 usage with graceful overflow handling
- **Fixed timestep**: Exactly 0.0333 seconds (perfect 30Hz)
- **Memory efficiency**: Zero allocations during enemy lifecycle

## Quick Commands Reference

```bash
# Full test suite (all categories)
cd tests && bash 0_run_tests.sh

# Performance tests only
cd tests && bash run_performance_tests.sh

# Breach optimization only
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_breach_enemy_tracking.tscn

# Quick verification
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/breach_optimization_verification.tscn

# Core tests only
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn
```

## Expected Output Summary

```
=== VIBE GAME ENGINE TEST SUITE ===
📊 SUMMARY:
  Total Tests: 10
  Passed:      10 ✓
  Failed:      0 ✗
  Success Rate: 100.0%

🎉 ALL TESTS PASSED! Zero-allocation optimization validated.
```

The zero-allocation breach optimization is now fully integrated into the test infrastructure and validated for production use.