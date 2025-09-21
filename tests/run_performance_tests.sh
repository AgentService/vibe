#!/bin/bash

# Performance Test Runner
# Runs all working performance stress tests with proper command syntax

echo "=== PERFORMANCE STRESS TEST SUITE ==="
echo "Running architecture validation tests for boss spawning and radar performance"
echo

# Test configuration
GODOT_CMD="../Godot_v4.4.1-stable_win64_console.exe"
PERF_DIR="tests/performance"
RESULTS_DIR="tests/baselines"

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

echo "Test Results Directory: $RESULTS_DIR"
echo

# Test 1: Banana Boss Performance Stress Test
echo "=== Test 1: Banana Boss Performance Stress Test ==="
echo "Command: $GODOT_CMD --headless $PERF_DIR/test_performance_banana_bosses.tscn --quit-after 30"
if "$GODOT_CMD" --headless "$PERF_DIR/test_performance_banana_bosses.tscn" --quit-after 30; then
    echo "✓ Banana boss stress test completed successfully"
else
    echo "✗ Banana boss stress test failed with exit code $?"
fi
echo

# Test 2: Radar Performance Simple Test
echo "=== Test 2: Radar Performance Simple Test ==="
echo "Command: $GODOT_CMD --headless $PERF_DIR/test_radar_performance_simple.tscn --quit-after 20"
if "$GODOT_CMD" --headless "$PERF_DIR/test_radar_performance_simple.tscn" --quit-after 20; then
    echo "✓ Radar performance simple test completed successfully"
else
    echo "✗ Radar performance simple test failed with exit code $?"
fi
echo

# Test 3: Radar Performance 1000 Entities Test
echo "=== Test 3: Radar Performance 1000 Entities Test ==="
echo "Command: $GODOT_CMD --headless $PERF_DIR/test_radar_performance_1000_entities.tscn --quit-after 30"
if "$GODOT_CMD" --headless "$PERF_DIR/test_radar_performance_1000_entities.tscn" --quit-after 30; then
    echo "✓ Radar performance 1000 entities test completed successfully"
else
    echo "✗ Radar performance 1000 entities test failed with exit code $?"
fi
echo

# Test 4: Boss Performance Integration Test
echo "=== Test 4: Boss Performance Integration Test ==="
echo "Command: $GODOT_CMD --headless $PERF_DIR/BossPerformance_integration_test.tscn --quit-after 30"
if "$GODOT_CMD" --headless "$PERF_DIR/BossPerformance_integration_test.tscn" --quit-after 30; then
    echo "✓ Boss performance integration test completed successfully"
else
    echo "✗ Boss performance integration test failed with exit code $?"
fi
echo

echo "=== PERFORMANCE TEST SUITE COMPLETED ==="
echo "Results saved to: $RESULTS_DIR"
echo
echo "To run individual tests:"
echo "  Banana Bosses:   $GODOT_CMD --headless $PERF_DIR/test_performance_banana_bosses.tscn --quit-after 30"
echo "  Radar Simple:    $GODOT_CMD --headless $PERF_DIR/test_radar_performance_simple.tscn --quit-after 20"
echo "  Radar 1000:      $GODOT_CMD --headless $PERF_DIR/test_radar_performance_1000_entities.tscn --quit-after 30"
echo "  Boss Integration: $GODOT_CMD --headless $PERF_DIR/BossPerformance_integration_test.tscn --quit-after 30"