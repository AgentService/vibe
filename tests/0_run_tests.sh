#!/bin/bash

# Comprehensive Test Runner for Vibe Game Engine
# Runs all test categories: unit tests, integration tests, performance tests, and breach optimization tests

echo "=== VIBE GAME ENGINE TEST SUITE ==="
echo "Running comprehensive test suite including zero-allocation breach optimization"
echo

# Test configuration
GODOT_CMD="../Godot_v4.4.1-stable_win64_console.exe"
TEST_DIR="."
RESULTS_DIR="results"

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

echo "Godot Engine: $GODOT_CMD"
echo "Test Directory: $TEST_DIR"
echo "Results Directory: $RESULTS_DIR"
echo

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo "=== $test_name ==="
    echo "Command: $test_command"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if eval "$test_command"; then
        echo "✓ $test_name PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "✗ $test_name FAILED (exit code $?)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo
}

# === CORE UNIT TESTS ===
echo "=== CORE UNIT TESTS ==="

run_test "RNG Streams and Signal Contracts" \
    "$GODOT_CMD --headless $TEST_DIR/run_tests.tscn"

run_test "Architecture Boundaries Validation" \
    "$GODOT_CMD --headless --script $TEST_DIR/test_architecture_boundaries.gd"

# === ZERO-ALLOCATION BREACH OPTIMIZATION TESTS ===
echo "=== ZERO-ALLOCATION BREACH OPTIMIZATION TESTS ==="

run_test "Breach Enemy Tracking (Comprehensive)" \
    "$GODOT_CMD --headless $TEST_DIR/test_breach_enemy_tracking.tscn"

run_test "Breach Optimization Verification" \
    "$GODOT_CMD --headless $TEST_DIR/breach_optimization_verification.tscn"

# === INTEGRATION TESTS ===
echo "=== INTEGRATION TESTS ==="

run_test "Character Manager Integration" \
    "$GODOT_CMD --headless $TEST_DIR/CharacterManager_Isolated.tscn"

run_test "State Transition Integration" \
    "$GODOT_CMD --headless $TEST_DIR/StateTransition_Test.tscn"

# === PERFORMANCE STRESS TESTS ===
echo "=== PERFORMANCE STRESS TESTS ==="

run_test "Boss Performance (50 Banana Bosses)" \
    "$GODOT_CMD --headless $TEST_DIR/performance/test_performance_banana_bosses.tscn"

run_test "Radar Performance (500 Entities)" \
    "$GODOT_CMD --headless $TEST_DIR/performance/test_radar_performance_1000_entities.tscn"

run_test "Boss Integration Performance" \
    "$GODOT_CMD --headless $TEST_DIR/performance/BossPerformance_integration_test.tscn"

# === BALANCE AND SIMULATION TESTS ===
echo "=== BALANCE AND SIMULATION TESTS ==="

run_test "Balance Simulation (10k trials)" \
    "$GODOT_CMD --headless --script $TEST_DIR/balance_sims.gd"

# === TEST RESULTS SUMMARY ===
echo "=== TEST SUITE COMPLETED ==="
echo "Results saved to: $RESULTS_DIR"
echo
echo "📊 SUMMARY:"
echo "  Total Tests: $TOTAL_TESTS"
echo "  Passed:      $PASSED_TESTS ✓"
echo "  Failed:      $FAILED_TESTS ✗"
echo "  Success Rate: $(awk "BEGIN {printf \"%.1f%%\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")"
echo

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED! Zero-allocation optimization validated."
    exit 0
else
    echo "⚠️  Some tests failed. Review output above for details."
    exit 1
fi

# === INDIVIDUAL TEST COMMANDS ===
echo "To run individual test categories:"
echo "  Core Tests:        $GODOT_CMD --headless $TEST_DIR/run_tests.tscn"
echo "  Breach Tests:      $GODOT_CMD --headless $TEST_DIR/test_breach_enemy_tracking.tscn"
echo "  Performance Tests: bash $TEST_DIR/run_performance_tests.sh"
echo "  Architecture:      $GODOT_CMD --headless --script $TEST_DIR/test_architecture_boundaries.gd"