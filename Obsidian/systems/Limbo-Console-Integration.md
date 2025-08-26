# Limbo Console Integration System

## Overview
LimboConsole plugin provides an in-game developer console for runtime debugging, balance tuning, and system interaction.

## Plugin Details
- **Location:** `vibe/addons/limbo_console/`
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

## Future Enhancements
- Balance preset loading/saving
- Monte Carlo test triggers
- System state inspection commands
- Performance profiling integration