# Architecture Performance Stress Test

**Status:** Pending  
**Priority:** HIGH  
**Category:** Architecture Validation  
**Created:** 2025-09-07  

## Objective

Create comprehensive performance stress test to validate the Vibe architecture can handle 500+ enemies as required by Phase 4 of the architecture checklist.

## Current Status

- ✅ WaveDirector configured for `max_enemies = 500` in `waves_balance.tres`
- ✅ MultiMeshInstance2D rendering implemented
- ✅ Object pooling for enemies implemented
- ❌ No automated stress test validating 500+ enemy performance

## Requirements

### Core Performance Test
- **File:** `tests/test_performance_500_enemies.gd`
- **Test Duration:** 60 seconds minimum
- **Enemy Count:** Scale from 100 → 500+ enemies
- **Metrics:** FPS stability, memory usage, render performance

### Success Criteria
- FPS remains ≥30Hz during 500+ enemy scenarios
- Memory usage stays stable (no significant leaks)
- MultiMesh rendering handles visual complexity
- Combat calculations remain deterministic at 30Hz fixed step

### Test Scenarios
1. **Gradual Scaling:** 100 → 200 → 300 → 400 → 500+ enemies
2. **Burst Spawning:** Sudden spawn of 500 enemies
3. **Combat Stress:** 500 enemies + projectiles + damage calculations
4. **Visual Stress:** All enemy types (swarm, regular, elite, boss) simultaneously

## Implementation Plan

### Phase 1: Base Test Framework
```gdscript
extends SceneTree
# Base performance monitoring
# FPS tracking with moving average
# Memory usage sampling
# Console output with real-time metrics
```

### Phase 2: Enemy Stress Testing
```gdscript
# Override WaveDirector spawning
# Force spawn to exact counts
# Test different enemy compositions
# Validate MultiMesh performance scaling
```

### Phase 3: Combat Integration
```gdscript
# Add projectile simulation
# Add damage calculation load
# Test collision detection at scale
# Validate 30Hz combat step stability
```

### Phase 4: Automated Validation
```gdscript
# Pass/fail criteria
# Performance regression detection
# Integration with existing test suite
# CLI reporting for CI/CD
```

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| FPS Stability | ≥30 FPS | 500 enemies for 30s |
| Memory Leak | <50MB growth | During full test |
| Frame Time | <33.3ms | 95th percentile |
| Combat Accuracy | 100% | Damage calculations |

## Files to Create/Modify

- `tests/test_performance_500_enemies.gd` (new)
- `tests/test_performance_500_enemies.tscn` (new)
- `tests/tools/performance_metrics.gd` (new)
- `tests/run_tests.gd` (integrate new test)

## Dependencies

- Existing WaveDirector system
- MultiMeshManager functionality
- BalanceDB for configuration
- EventBus for metrics gathering

## Validation Command

```bash
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_performance_500_enemies.tscn --quit-after 60
```