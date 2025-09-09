# Limbo Console Integration System

## Overview
LimboConsole plugin provides an in-game developer console for runtime debugging, balance tuning, and system interaction.

## Plugin Details
- **Location:** `addons/limbo_console/`
- **Version:** 0.4.1
- **Autoload:** `LimboConsole` singleton
- **Toggle Key:** `^` (circumflex)

## Key Features
- Command interpreter with auto-completion
- Runtime balance parameter adjustment
- Custom command registration
- Command history and search
- Integration with Logger system

## Input Actions
```gdscript
# Toggle console
limbo_console_toggle: ^ (circumflex key)

# Autocomplete
Tab: Forward autocomplete
Shift+Tab: Reverse autocomplete

# History
Up/Down: Navigate command history
Ctrl+R: Search command history
```

## Command Registration Pattern
```gdscript
func _ready() -> void:
    if LimboConsole:
        LimboConsole.register_command(balance_command, "balance", "Adjust balance values")
        Logger.info("Console commands registered", "console")

func balance_command(system: String, value: float) -> void:
    # Adjust balance parameters at runtime
    LimboConsole.info("Balance adjusted: " + system + " = " + str(value))
```

## Integration Points
- **BalanceDB:** Real-time balance tuning
- **WaveDirector:** Spawn rate/pattern adjustments  
- **RNG:** Seed manipulation for testing
- **EventBus:** Command-triggered events
- **Logger:** Console output integration
- **DamageSystem:** Zero-allocation queue monitoring and control

## Development Workflow
1. Register commands for critical systems
2. Use during playtesting for live tuning
3. Test balance changes without restart
4. Debug system states in real-time

## Architecture Benefits
- Maintains separation of concerns (console ↔ systems via commands)
- Non-intrusive debugging overlay
- Preserves deterministic gameplay when not in use
- Complements existing Logger/CheatSystem architecture

## Current Damage System Commands

### Available Commands
- `damage_queue_stats` - **Primary command**: Show current queue metrics, performance, and capacity usage
- `damage_queue_reset` - Reset queue metrics and counters (for testing)
- `damage_queue_enable` - Enable zero-allocation queue processing
- `damage_queue_disable` - Disable queue (fallback to direct processing)
- `damage_queue_toggle` - Toggle between enabled/disabled states

### Usage Examples
```
> damage_queue_stats
Queue enabled: true
Current count: 12/4096 (0.3%)
Total processed: 568
Overflows: 0
Processing rate: 30Hz (0.0ms avg)

> damage_queue_reset
Queue metrics reset. Total processed: 0, Overflows: 0
```

### Recommended Usage
- **Primary**: Use `damage_queue_stats` for monitoring performance and capacity
- **Debugging**: Toggle commands available but zero-allocation queue is the recommended mode
- **Testing**: Reset command useful for clean metric collection during performance tests

## Future Enhancements
- Balance preset loading/saving
- Monte Carlo test triggers
- System state inspection commands
- Performance profiling integration
- Real-time queue capacity visualization