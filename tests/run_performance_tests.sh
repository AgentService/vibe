#!/bin/bash

# Performance Test Runner
# Runs all performance stress tests with proper command syntax

echo "=== PERFORMANCE STRESS TEST SUITE ==="
echo "Running architecture validation tests for 500+ enemy performance"
echo

# Test configuration
GODOT_CMD="./Godot_v4.4.1-stable_win64_console.exe"
TEST_DIR="tests"
RESULTS_DIR="tests/baselines"

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

echo "Test Results Directory: $RESULTS_DIR"
echo

# Test 1: Simple baseline test
echo "=== Test 1: Simple Performance Baseline ==="
echo "Command: $GODOT_CMD --headless $TEST_DIR/test_performance_simple.tscn --quit-after 15"
if "$GODOT_CMD" --headless "$TEST_DIR/test_performance_simple.tscn" --quit-after 15; then
    echo "✓ Simple baseline test completed successfully"
else
    echo "✗ Simple baseline test failed with exit code $?"
fi
echo

# Test 2: Arena scene performance test  
echo "=== Test 2: Arena Scene Performance ==="
echo "Command: $GODOT_CMD --headless $TEST_DIR/test_performance_arena_scene.tscn --quit-after 35 --no-debug"
if "$GODOT_CMD" --headless "$TEST_DIR/test_performance_arena_scene.tscn" --quit-after 35 --no-debug; then
    echo "✓ Arena scene test completed successfully"
else
    echo "✗ Arena scene test failed with exit code $?"
fi
echo

# Test 3: 500 enemy stress test (main architecture validation)
echo "=== Test 3: 500 Enemy Architecture Stress Test ==="
echo "Command: $GODOT_CMD --headless $TEST_DIR/test_performance_500_enemies.tscn --quit-after 60 --no-debug"
if "$GODOT_CMD" --headless "$TEST_DIR/test_performance_500_enemies.tscn" --quit-after 60 --no-debug; then
    echo "✓ 500 enemy stress test completed successfully"
else
    echo "✗ 500 enemy stress test failed with exit code $?"
fi
echo

echo "=== PERFORMANCE TEST SUITE COMPLETED ==="
echo "Results saved to: $RESULTS_DIR"
echo
echo "To run individual tests:"
echo "  Simple:     $GODOT_CMD --headless $TEST_DIR/test_performance_simple.tscn --quit-after 15"
echo "  Arena:      $GODOT_CMD --headless $TEST_DIR/test_performance_arena_scene.tscn --quit-after 35 --no-debug"
echo "  Stress:     $GODOT_CMD --headless $TEST_DIR/test_performance_500_enemies.tscn --quit-after 60 --no-debug"