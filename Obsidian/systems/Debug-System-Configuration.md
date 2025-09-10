# Debug System Configuration

## Overview
The debug system provides F12 panel functionality, entity inspection, and performance testing controls. It's designed to be completely disabled during performance testing to avoid interference with metrics.

## Configuration File: `config/debug.tres`

The debug system is controlled via a single configuration file that uses the `DebugConfig` resource:

```gdscript
# DebugConfig resource properties
debug_mode: bool = false              # Menu skipping, direct arena start
debug_panels_enabled: bool = false    # F12 debug panels and entity tracking
start_mode: String = "arena"          # Start location
skip_main_menu: bool = true           # Skip main menu flow
```

### Configuration Separation

**`debug_panels_enabled`** - Debug UI and functionality:
- Enables/disables F12 debug panel creation
- Controls entity tracking (Ctrl+Click)
- Controls debug system instantiation
- When `false`, debug components are never created

## Component Architecture

### 1. DebugManager (Autoload)
**Location**: `autoload/DebugManager.gd`
**Initialization**: Checks `debug_panels_enabled` flag on startup

```gdscript
func _check_debug_config() -> void:
    var config_path: String = "res://config/debug.tres"
    if ResourceLoader.exists(config_path):
        var debug_config: DebugConfig = load(config_path) as DebugConfig
        if debug_config:
            # F12 debug panel functionality controlled by debug_panels_enabled only
            debug_enabled = debug_config.debug_panels_enabled
```

**Key Behavior**:
- When `debug_enabled = false`: No debug UI functionality, normal game behavior

### 2. DebugPanel (UI Component)
**Location**: `scenes/debug/DebugPanel.gd`
**Instantiation**: Conditionally created by `ArenaUIManager`

```gdscript
# ArenaUIManager.gd - Conditional instantiation
var config_path: String = "res://config/debug.tres"
if ResourceLoader.exists(config_path):
    var debug_config: DebugConfig = load(config_path) as DebugConfig
    if debug_config and debug_config.debug_panels_enabled:
        debug_panel = DEBUG_PANEL_SCENE.instantiate()
        # ... setup debug panel
```

**When Disabled**: Debug panel is never instantiated, no UI overhead

### 3. DebugSystemControls (System Component)
**Location**: `scripts/systems/debug/DebugSystemControls.gd`
**Instantiation**: Scene node that removes itself when disabled

```gdscript
func _ready() -> void:
    var config_path: String = "res://config/debug.tres"
    if ResourceLoader.exists(config_path):
        var debug_config: DebugConfig = load(config_path) as DebugConfig
        if debug_config and not debug_config.debug_panels_enabled:
            queue_free()  # Remove entire node
            return
```

### 4. EntitySelector (Debug Component)  
**Location**: `scripts/systems/debug/EntitySelector.gd`
**Instantiation**: Conditionally created by `Arena.gd`

```gdscript
# Arena.gd - Conditional creation
var config_path: String = "res://config/debug.tres"
if ResourceLoader.exists(config_path):
    var debug_config: DebugConfig = load(config_path) as DebugConfig
    if debug_config and debug_config.debug_panels_enabled:
        entity_selector = EntitySelectorScript.new()
        add_child(entity_selector)
```

**When Disabled**: Entity tracking (Ctrl+Click) is completely unavailable

## Performance Testing Configuration

### Recommended Settings for Performance Tests:
```tres
# config/debug.tres
debug_mode = false                    # Normal menu flow
debug_panels_enabled = false         # Disable all debug functionality
start_mode = "arena"                  # Direct to arena (optional)
skip_main_menu = true                 # Skip menu (optional)
```

### What Gets Disabled:
1. **F12 Debug Panel**: Never instantiated, no UI overhead
2. **Entity Tracking**: Ctrl+Click functionality disabled  
3. **Debug System Controls**: Node removes itself from scene
4. **Entity Selector**: Never created, no input processing
5. **Debug Manager**: Runs in passive mode, no debug operations

### Performance Test Commands:

**Correct Usage** (30-second test duration):
```bash
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_performance_500_enemies.tscn
```

**With Safety Guard** (high frame limit):
```bash
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_performance_500_enemies.tscn --quit-after 2000
```

**❌ AVOID**: Small `--quit-after` values (interpreted as frames, not seconds):
```bash
# This terminates after ~15 frames (0.5 seconds), not 15 seconds
"./Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_performance_500_enemies.tscn --quit-after 15
```

## Development Configuration

### Normal Development Settings:
```tres
# config/debug.tres  
debug_mode = true                     # Skip menus, direct to arena
debug_panels_enabled = true          # Enable all debug functionality
start_mode = "arena"                  # Start in arena
skip_main_menu = true                 # Skip main menu
```

### Debug Features Available:
1. **F12 Debug Panel**: Entity spawning, system controls, performance stats
2. **Entity Inspection**: Ctrl+Click to inspect entities
3. **System Controls**: AI pause, entity clearing, session reset
4. **Manual Spawning**: Spawn enemies at cursor or player position

## Architecture Benefits

### Clean Separation
- Debug functionality completely removable via configuration
- No performance overhead when disabled
- Clear distinction between development convenience vs debug functionality

### Zero-Impact Testing
- Performance tests run without any debug interference
- Memory usage unaffected by debug components
- Frame timing unaffected by debug processing

### Maintainable Design
- Single configuration point for all debug behavior  
- Components handle their own disable logic
- No complex detection or flag passing between systems

## Usage Examples

### Enable Debug for Development:
1. Set `debug_panels_enabled = true` in `config/debug.tres`
2. Launch game normally
3. Press F12 to toggle debug panel
4. Use Ctrl+Click for entity inspection

### Disable Debug for Testing:
1. Set `debug_panels_enabled = false` in `config/debug.tres`  
2. Run performance tests with clean environment
3. No debug components will be created or interfere

### Quick Toggle:
```gdscript
# In code, load and modify config
var debug_config: DebugConfig = load("res://config/debug.tres")
debug_config.debug_panels_enabled = false  # Disable for next run
ResourceSaver.save(debug_config, "res://config/debug.tres")
```