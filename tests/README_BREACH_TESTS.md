# Breach Event Testing

## Production Test Suite

**Primary Test:** `test_breach_events_focused.tscn`

### Quick Run
```bash
"../Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_breach_events_focused.tscn
```

### Expected Output
```
=== TEST RESULTS ===
✓ BREACH_LIFECYCLE
✓ RING_DETERMINISM
✓ CONFIG_LOADING
✓ MULTI_BREACH

SUMMARY: 4/4 tests passed
🎉 ALL TESTS PASSED - Breach event core mechanics validated!
```

## When to Run

### Development Workflow
- **Before commits**: Ensure breach system changes don't break core mechanics
- **After balance changes**: Verify BreachEventConfig.tres modifications work correctly
- **During refactoring**: Confirm behavior remains consistent

### Integration Points
- **CI/CD pipelines**: Automated regression detection
- **Pre-merge validation**: Ensure PR changes don't break breach system
- **Performance baselines**: Monitor breach system performance over time

## Test Coverage

### ✅ Breach Lifecycle (Complete)
- Breach creation and activation (WAITING → EXPANDING)
- Natural expansion completion (55px → 600px over 10 seconds)
- Automatic phase transition (EXPANDING → SHRINKING)
- Shrinking mechanics (600px → ~325px over 5+ seconds)

### ✅ Ring Calculation Determinism (Core Logic)
- Deterministic enemy spawn calculations using RNG.stream("waves")
- Consistent ring generation with fixed seeds
- Validates sophisticated spatial mathematics

### ✅ Configuration Loading (Hot-Reload)
- BreachEventConfig.tres parameter validation
- Resource system integration
- Configuration value verification (max_radius: 600.0, etc.)

### ✅ Multi-Breach Independence (Concurrency)
- Unique breach ID generation
- Simultaneous breach support (up to 3)
- No cross-interference between breaches

## Architecture Notes

This test suite **bypasses arena spawn system integration** to focus on core breach mechanics. This design choice:

- ✅ **Enables reliable testing** without complex arena setup
- ✅ **Validates core algorithms** independently
- ✅ **Provides fast feedback** during development
- ✅ **Ensures deterministic results** across environments

The test validates that breach event calculations, lifecycle management, and configuration systems work correctly, providing confidence in the sophisticated PoE-Atlas-style mechanics.

## GitHub Actions Integration

### Available Workflows

**1. PR Breach Validation** (`.github/workflows/pr-breach-validation.yml`)
- Lightweight validation for breach-related changes
- Automatically comments on PRs with test results
- Triggered by changes to breach system files

**2. Comprehensive Godot Tests** (`.github/workflows/godot-tests.yml`)
- Full test suite including breach events
- Matrix strategy for different test categories
- Runs on all PRs and main branch pushes

**3. Breach Event Tests** (`.github/workflows/breach-event-tests.yml`)
- Focused solely on breach event system
- Fast execution for quick feedback

### Setup Instructions

1. **Commit the workflow files** to your repository
2. **Enable GitHub Actions** in repository settings
3. **Create a PR** touching breach system files to see it in action

### Expected CI Output

```
🎯 Breach System Validation

✅ Breach tests passed!
- 🎯 Breach Lifecycle: PASS
- 🔄 Ring Determinism: PASS
- ⚙️ Configuration Loading: PASS
- 🎭 Multi-Breach Independence: PASS

✅ All breach event mechanics validated! Safe to merge.
```

### Path Triggers

The workflows automatically run when these files change:
- `scripts/systems/events/**` - Core breach event logic
- `scripts/resources/BreachEventConfig.gd` - Configuration class
- `data/balance/breach_event_config.tres` - Balance parameters
- `tests/test_breach_events_focused.*` - Test files

## Troubleshooting

### If Tests Fail Locally
1. **Check RNG consistency**: Ensure deterministic behavior with fixed seeds
2. **Verify configuration loading**: Confirm BreachEventConfig.tres is accessible
3. **Review timing issues**: Ensure adequate time for lifecycle phases
4. **Validate EventBus signals**: Check breach activation and phase transitions

### If CI/CD Fails
1. **Check workflow syntax**: Validate YAML formatting
2. **Verify file paths**: Ensure test files exist in expected locations
3. **Review Godot version**: Confirm Godot 4.4.1 compatibility
4. **Check timeout limits**: Tests should complete within 60 seconds

### Performance Monitoring
The test provides timing information for:
- Breach expansion duration (~10 seconds)
- Ring calculation performance
- Configuration loading time
- Multi-breach creation overhead