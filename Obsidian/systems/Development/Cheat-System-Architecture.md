# Cheat System Architecture

## Overview
The CheatSystem is a debug/development singleton that provides runtime cheats for testing and development purposes. It operates as an autoload and uses signal-based communication to coordinate with other systems.

## Core Components

### CheatSystem.gd (`autoload/CheatSystem.gd`)
- **Type**: Autoload singleton
- **Process Mode**: `PROCESS_MODE_ALWAYS` (works during pause)
- **Purpose**: Debug functionality for development and testing

### CheatTogglePayload.gd (`scripts/domain/signal_payloads/CheatTogglePayload.gd`)
- **Type**: Resource payload class
- **Purpose**: Signal payload for cheat state changes
- **Fields**: `cheat_name: String`, `enabled: bool`

## Available Cheats

### God Mode (Ctrl+1)
- **Function**: `toggle_god_mode()`
- **State**: `god_mode: bool`
- **Effect**: Blocks all damage to player
- **Integration**: Player.gd checks `CheatSystem.is_god_mode_active()` in `_on_damage_taken()` at scenes/arena/Player.gd:214

### Spawn Control (Ctrl+2)
- **Function**: `toggle_spawn_disabled()`
- **State**: `spawn_disabled: bool`
- **Effect**: Toggles enemy spawning on/off
- **Integration**: WaveDirector.gd checks `CheatSystem.is_spawn_disabled()` in `_handle_spawning()` at scripts/systems/WaveDirector.gd:132

### Silent Pause (F10)
- **Function**: `toggle_silent_pause()`
- **Effect**: Pauses game without showing pause UI overlay
- **Integration**: Uses PauseManager.silent_pause() if available

## Signal Communication

### EventBus Integration
- **Signal**: `EventBus.cheat_toggled`
- **Payload**: `CheatTogglePayload`
- **Emitted**: When god_mode or spawn_disabled toggles
- **Usage**: Allows other systems to react to cheat state changes

## Input Handling
All cheat inputs are processed in `_input()` with proper event handling:
- Uses `InputEventKey` type checking
- Validates `event.pressed` to prevent repeat triggers
- Calls `get_viewport().set_input_as_handled()` to consume events

## Integration Points

### Player System
```gdscript
# scenes/arena/Player.gd:214
if CheatSystem and CheatSystem.is_god_mode_active():
    return
```

### Wave System
```gdscript
# scripts/systems/WaveDirector.gd:132
if CheatSystem and CheatSystem.is_spawn_disabled():
    return
```

## Development Notes
- All cheat actions are logged via Logger with "debug" category
- System follows signal-based architecture patterns
- Null-safe checks (`if CheatSystem and ...`) prevent crashes if system unavailable
- No direct scene references - uses proper autoload access pattern

## Configuration
- No external configuration files
- All keybindings are hardcoded for development use
- States reset on game restart (not persistent)

## Future Considerations
- Additional cheats can follow the same pattern: toggle function → emit signal → integrate via getter
- Consider adding configuration file for custom keybindings if needed
- Could extend with parameter-based cheats (not just boolean toggles)

## Related Systems

### Limbo Console Integration
For more flexible runtime debugging, see **Limbo Console** (F1 key):
- **Command-based**: More flexible than hardcoded hotkeys
- **Parameter support**: Can pass values to commands (e.g., set damage multiplier)
- **Runtime registration**: Systems can register their own debug commands
- **Balance tuning**: Perfect for adjusting balance parameters during gameplay
- **Complementary**: CheatSystem for simple toggles, Console for complex debugging