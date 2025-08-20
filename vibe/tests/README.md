# Balance Tests

This directory contains automated tests for the game's balance systems, including RNG determinism and Monte-Carlo combat simulations.

## Test Files

- **`cli_test_runner.gd`** - Command-line test runner (recommended for headless execution)
- **`run_tests.gd`** - Scene-based test runner (requires Godot editor)
- **`balance_sims.gd`** - Monte-Carlo DPS/TTK simulation engine
- **`test_rng_streams.gd`** - RNG stream determinism tests

## Running Tests

### Option 1: CLI Test Runner (Recommended)

Run from the project root directory:

```bash
# Windows
cd vibe
"../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/cli_test_runner.gd

# Or use the batch file
run_tests.bat
```

### Option 2: Scene-based Test Runner

Open `tests/run_tests.tscn` in Godot and run the scene.

## What Gets Tested

### RNG Stream Determinism
- Verifies that RNG streams produce identical sequences when seeded with the same value
- Tests multiple named streams: `crit`, `loot`, `waves`, `ai`, `craft`
- Ensures different seeds produce different results

### Balance Simulation
- Monte-Carlo combat simulation with 1000+ trials
- Calculates DPS (Damage Per Second) and TTK (Time To Kill) statistics
- Uses actual game balance data from JSON files
- Generates statistical baseline for balance validation

## Output

Test results are written to `tests/results/baseline.json` with the following metrics:

- **DPS Statistics**: Mean, P50, P95 percentiles
- **TTK Statistics**: Mean, P50, P95 percentiles  
- **Outliers**: Count and percentage of statistical outliers

## Troubleshooting

### Common Issues

1. **"Class not found" errors**: The CLI test runner handles autoload dependencies automatically
2. **Empty output**: Ensure you're using the CLI test runner for headless execution
3. **File access errors**: Check that the `tests/results/` directory exists

### Why the Original Tests Failed

The original test runner failed because:
- It relied on Godot's autoload system which isn't available in headless mode
- It tried to use `RngService` and `BalanceDB` classes directly without proper initialization
- The scene-based approach doesn't work well with command-line execution

The CLI test runner fixes these issues by:
- Manually loading required classes and creating instances
- Using `SceneTree` instead of `Node` for direct script execution
- Providing fallback initialization for headless environments