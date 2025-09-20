# Tests Layer - CLAUDE.md
> Context-specific documentation for tests/ - Monte-Carlo sims & validation

**Parent Documentation:** [Main CLAUDE.md](../CLAUDE.md) | **Layer:** Testing & Validation

## Quick Reference

| Test Type | Purpose | Execution Method | Key Files |
|-----------|---------|------------------|-----------|
| **Monte-Carlo Sims** | DPS/TTK validation | `./Godot_v4.4.1-stable_win64_console.exe --headless tests/run_tests.tscn` | `balance_sims.gd` |
| **Isolated System Tests** | Component validation | `./Godot_v4.4.1-stable_win64_console.exe --headless tests/SystemName_Isolated.tscn` | `*_Isolated.tscn` |
| **Integration Tests** | Cross-system validation | Scene-based execution | `*_integration_test.tscn` |
| **Architecture Tests** | Boundary validation | `./Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_architecture_boundaries.gd` | `test_architecture_boundaries.gd` |
| **Signal Contract Tests** | EventBus validation | Included in `run_tests.tscn` | `test_signal_contracts.gd` |

## Testing Architecture Patterns

### 🏗️ **Test Script vs Scene Pattern**

**Critical Rule from CLAUDE.md:**
```gdscript
# Tests WITH autoload dependencies → Use .tscn scene
# - EventBus, RNG, ContentDB, BalanceDB, any autoload
# - Uses: "./Godot_v4.4.1-stable_win64_console.exe --headless tests/TestName.tscn"

# Tests WITHOUT autoloads → Use .gd script
# - Pure logic, mathematics, algorithms
# - Uses: "./Godot_v4.4.1-stable_win64_console.exe --headless --script tests/test_name.gd"
```

**Scene-Based Test Template:**
```gdscript
# CoreLoop_Isolated.tscn + CoreLoop_Isolated.gd
extends Node2D

func _ready() -> void:
    print("=== Test Started ===")

    # Autoloads are available
    StateManager.current_state = StateManager.State.ARENA
    EventBus.combat_step.connect(_on_combat_step)
    var balance_data = BalanceDB.get_combat_value("base_damage")

    _run_test_suite()

    # Exit after test completion
    if DisplayServer.get_name() == "headless":
        get_tree().quit()
```

**Standalone Script Template:**
```gdscript
# test_math_utils.gd - Pure logic testing
extends SceneTree

func _initialize() -> void:
    print("=== Pure Logic Test ===")

    # No autoload dependencies
    _test_math_functions()
    _test_algorithms()

    print("Test completed.")
    quit()
```

### 🎯 **Monte-Carlo Simulation Pattern**

**Balance Validation Framework:**
```gdscript
# balance_sims.gd - Statistical validation
extends RefCounted
class_name BalanceSims

const COMBAT_DT := 1.0 / 30.0  # Match game's fixed timestep
const DEFAULT_TRIALS := 10000

static func run_baseline_simulation(trials: int, seed_value: int) -> SimResult:
    var results: Array[float] = []
    var ttk_results: Array[float] = []

    # Use game's actual RNG system
    RNG.seed_run(seed_value)

    # Load game's actual balance data
    var base_damage = BalanceDB.get_combat_value("base_damage")
    var crit_chance = BalanceDB.get_combat_value("crit_chance")

    # Run simulation trials
    for trial in range(trials):
        var dps = _simulate_combat_encounter(base_damage, crit_chance)
        results.append(dps)

    # Statistical analysis
    return _analyze_results(results)
```

**DPS/TTK Validation:**
```gdscript
# Validate DPS stays within acceptable bounds
func _validate_dps_bounds(sim_result: SimResult) -> bool:
    var expected_dps_min = 45.0  # Based on design
    var expected_dps_max = 55.0

    if sim_result.dps_mean < expected_dps_min:
        print("ERROR: DPS too low (%.2f < %.2f)" % [sim_result.dps_mean, expected_dps_min])
        return false

    if sim_result.dps_mean > expected_dps_max:
        print("ERROR: DPS too high (%.2f > %.2f)" % [sim_result.dps_mean, expected_dps_max])
        return false

    return true
```

### 🔧 **Isolated System Testing**

**Two Test Patterns Available:**

**1. Automated Validation Tests (CI-Compatible):**
```gdscript
# CharacterManager_Isolated.tscn/gd - For CI/CD pipelines
extends Node

func _ready() -> void:
    print("=== CharacterManager Isolated Test ===")

    # Auto-quit for headless mode
    if DisplayServer.get_name() == "headless":
        _run_automated_test()
    # Interactive mode continues with user controls

func _run_automated_test() -> void:
    # Test all CRUD operations
    _test_character_creation()
    _test_character_loading()
    _test_character_deletion()
    _test_persistence()
    _test_progression_sync()

    print("CharacterManager tests completed successfully")
    get_tree().quit()
```

**2. Interactive Debug Tests (Manual Debugging):**
```gdscript
# SystemName_Interactive.tscn/gd - For visual debugging
extends Node2D

func _ready() -> void:
    print("=== Interactive System Debug ===")
    print("Controls: Space to test, R to reset, 1-3 for variants")

    _setup_debug_environment()
    # No auto-quit - waits for user input

func _unhandled_input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_SPACE: _run_test_cycle()
            KEY_R: _reset_system()
```

func _test_character_creation() -> void:
    var character_id = CharacterManager.create_character("TestKnight", "knight")
    assert(character_id != "", "Character creation failed")
    print("✓ Character creation successful")

func _test_persistence() -> void:
    # Create character
    var char_id = CharacterManager.create_character("PersistenceTest", "ranger")

    # Modify character
    var character = CharacterManager.get_character(char_id)
    character.level = 5
    character.total_xp = 1500.0
    CharacterManager.save_character(character)

    # Reload and verify
    var reloaded = CharacterManager.load_character(char_id)
    assert(reloaded.level == 5, "Level not persisted")
    assert(reloaded.total_xp == 1500.0, "XP not persisted")
    print("✓ Character persistence working")
```

### 🏛️ **Architecture Boundary Testing**

**Boundary Validation Pattern:**
```gdscript
# test_architecture_boundaries.gd - Standalone script
extends SceneTree

func _initialize() -> void:
    print("=== Architecture Boundary Validation ===")

    var violations = _check_layer_violations()

    if violations.is_empty():
        print("✓ No architecture violations found")
    else:
        print("❌ Architecture violations detected:")
        for violation in violations:
            print("  - %s" % violation)

    quit()

func _check_layer_violations() -> Array[String]:
    var violations: Array[String] = []

    # Check domain layer purity
    violations.append_array(_check_domain_layer())

    # Check system dependencies
    violations.append_array(_check_system_layer())

    # Check scene constraints
    violations.append_array(_check_scene_layer())

    return violations

func _check_domain_layer() -> Array[String]:
    # Scan domain files for forbidden imports
    var forbidden_patterns = ["EventBus", "get_node", "autoload"]
    return _scan_files_for_patterns("scripts/domain/", forbidden_patterns)
```

### 📊 **Integration Testing Patterns**

**Cross-System Validation:**
```gdscript
# BossPerformance_integration_test.tscn/gd
extends Node2D

func _ready() -> void:
    print("=== Boss Performance Integration Test ===")

    # Setup test environment
    _setup_arena_environment()
    _initialize_boss_systems()

    # Spawn test bosses
    var boss_count = 50
    _spawn_test_bosses(boss_count)

    # Run performance monitoring
    _monitor_performance(5.0)  # 5 second test

    get_tree().quit()

func _monitor_performance(duration: float) -> void:
    var start_time = Time.get_ticks_msec()
    var frame_times: Array[float] = []

    while (Time.get_ticks_msec() - start_time) < (duration * 1000):
        var frame_start = Time.get_ticks_msec()
        await get_tree().process_frame
        var frame_time = Time.get_ticks_msec() - frame_start
        frame_times.append(frame_time)

    _analyze_performance_results(frame_times)
```

## Test Execution Guide

### 🚀 **Command Line Execution**

**Main Test Runner:**
```bash
# Run all core tests (RNG, signal contracts, balance sims)
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn

# Run specific isolated system test
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/CharacterManager_Isolated.tscn

# Run architecture boundary validation
"./Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/test_architecture_boundaries.gd

# Run balance simulation with specific parameters
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/balance_sims_custom.tscn
```

**CI/CD Integration:**
```yaml
# GitHub Actions example
- name: Run Tests
  run: |
    "./Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn
    "./Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/test_architecture_boundaries.gd
```

### 📈 **Performance Testing**

**Boss Performance Validation:**
```gdscript
# Monitor boss system performance
func _validate_boss_performance() -> bool:
    var target_fps = 60.0
    var boss_count = 50

    _spawn_bosses(boss_count)

    var performance_data = _monitor_fps(5.0)  # 5 second monitoring

    if performance_data.average_fps < target_fps:
        print("FAIL: Average FPS %.1f < %.1f" % [performance_data.average_fps, target_fps])
        return false

    print("✓ Boss performance test passed (%.1f FPS with %d bosses)" % [performance_data.average_fps, boss_count])
    return true
```

**Memory Leak Detection:**
```gdscript
func _test_memory_stability() -> void:
    var initial_memory = _get_memory_usage()

    # Spawn and destroy entities repeatedly
    for cycle in range(10):
        _spawn_test_entities(100)
        await _wait_seconds(1.0)
        _clear_all_entities()
        await _wait_seconds(1.0)

    var final_memory = _get_memory_usage()
    var memory_growth = final_memory - initial_memory

    if memory_growth > 50:  # MB threshold
        print("WARN: Memory growth detected: %.1f MB" % memory_growth)
    else:
        print("✓ Memory stability test passed")
```

## Test Data Management

### 🎲 **Deterministic Testing**

**Seeded RNG Usage:**
```gdscript
# Always use seeded RNG for reproducible tests
func _setup_test_rng() -> void:
    var test_seed = 12345
    RNG.seed_run(test_seed)

    print("Test RNG seeded with: %d" % test_seed)

# Validate RNG reproducibility
func _test_rng_reproducibility() -> void:
    RNG.seed_run(42)
    var first_sequence = []
    for i in range(10):
        first_sequence.append(RNG.stream("test").randf())

    RNG.seed_run(42)
    var second_sequence = []
    for i in range(10):
        second_sequence.append(RNG.stream("test").randf())

    assert(first_sequence == second_sequence, "RNG not reproducible")
    print("✓ RNG reproducibility validated")
```

### 📋 **Test Configuration**

**Balance Test Configuration:**
```gdscript
# Test-specific balance data
const TEST_BALANCE = {
    "base_damage": 25.0,
    "crit_chance": 0.1,
    "enemy_hp": 100.0,
    "attack_speed": 1.5
}

func _override_balance_for_test() -> void:
    # Temporarily override balance data
    BalanceDB._test_overrides = TEST_BALANCE
    print("Balance overrides applied for testing")

func _restore_balance_after_test() -> void:
    BalanceDB._test_overrides = {}
    print("Balance overrides cleared")
```

## Troubleshooting Guide

### 🚨 **Common Test Issues**

1. **"Autoload not available":** Use `.tscn` scene instead of `--script`
2. **Test hangs in headless mode:** Missing `get_tree().quit()` call or waiting for user input
   - **Solution:** Add `if DisplayServer.get_name() == "headless": _run_automated_test()` pattern
   - **Interactive tests:** Use `_unhandled_input()` only for manual debugging, not CI/CD
3. **Non-deterministic results:** Check RNG seeding and timing
4. **Memory leaks in tests:** Verify entity cleanup after each test
5. **Performance test flakiness:** Run multiple iterations and average results
6. **Debug initialization hangs:** Interactive tests designed for visual debugging, not automation

### 🔧 **Debug Test Execution**

**Test Debug Logging:**
```gdscript
# Always use print() in tests, not Logger (per CLAUDE.md)
print("=== Starting Test: %s ===" % test_name)
print("Setup: Spawning %d entities" % entity_count)
print("Result: DPS = %.2f (expected: %.2f)" % [actual_dps, expected_dps])
print("✓ Test passed" if success else "❌ Test failed")
```

**Conditional Test Output:**
```gdscript
# More verbose output when not in headless mode
func _print_debug(message: String) -> void:
    if DisplayServer.get_name() != "headless":
        print("[DEBUG] %s" % message)

# Always print test results
func _print_result(test_name: String, success: bool) -> void:
    var status = "✓" if success else "❌"
    print("%s %s" % [status, test_name])
```

### 📊 **Test Coverage Guidelines**

**When to Add Tests:**
1. **New core systems** - Always add isolated system test
2. **Balance changes** - Update Monte-Carlo simulation bounds
3. **Performance optimizations** - Add performance regression test
4. **Architecture changes** - Update boundary validation
5. **Signal contracts** - Add payload validation

**Test Categories:**
- **Unit Tests:** Pure logic, no autoloads (`--script` execution)
- **System Tests:** Single system isolation (`.tscn` execution)
- **Integration Tests:** Cross-system validation (`.tscn` execution)
- **Performance Tests:** Regression detection (`.tscn` execution)
- **Balance Tests:** Monte-Carlo validation (`.tscn` execution)

## Migration Notes

When adding new tests:
1. **Choose correct pattern:** `.tscn` for autoload dependencies, `--script` for pure logic
2. **Use deterministic seeds** for reproducible results
3. **Include performance bounds** for regression detection
4. **Add to CI pipeline** if testing critical functionality
5. **Document test purpose** and expected outcomes
6. **Use print() for output** (not Logger system)
7. **Update this documentation** with new test patterns

---
**See Also:** [System Testing](../scripts/systems/CLAUDE.md) | [Architecture Validation](../ARCHITECTURE.md) | [Balance Configuration](../data/README.md)