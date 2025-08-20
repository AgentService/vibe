# LESSONS_LEARNED.md

## Purpose
This document tracks Godot coding basics, patterns, concepts, and learnings discovered during task completion. **ALWAYS CHECK THIS FIRST** before starting new tasks to avoid repeating mistakes and leverage previous insights.

## Basic Rules

### 1. **ALWAYS CHECK BEFORE STARTING TASKS**
- Review relevant sections of this document before beginning any coding task
- Look for existing patterns, solutions, or warnings related to your task
- If you find relevant learnings, apply them immediately

### 2. **ADD LEARNINGS AFTER TASK COMPLETION**
- After completing any task, reflect on what you learned
- Add new findings, patterns, or concepts discovered during the task
- Include code examples, warnings, and best practices
- Update this document with any "aha moments" or solutions to problems

### 3. **What to Document**
- **Godot-specific patterns**: Scene structure, signal connections, autoload usage
- **Performance insights**: What works fast, what causes slowdowns
- **Common pitfalls**: Errors you encountered and how you solved them
- **Best practices**: Code organization, naming conventions, architecture decisions
- **Engine quirks**: Unexpected behavior, workarounds, gotchas
- **Testing strategies**: How to test specific Godot features effectively

### 4. **Documentation Format**
Use clear, searchable headings and include:
- **Problem/Context**: What you were trying to accomplish
- **Solution/Pattern**: How you solved it or what pattern emerged
- **Code Example**: Relevant code snippets (if applicable)
- **Why It Works**: Brief explanation of the underlying principle
- **Related Concepts**: Links to other learnings or documentation

## Godot-Specific Learnings

### Scene Management
**Problem/Context**: UI elements (HUD, popups) not visible when added directly to Node2D scenes
**Solution/Pattern**: Use CanvasLayer for UI elements to ensure proper rendering order
**Code Example**:
```gdscript
# Wrong - UI gets buried under world elements:
add_child(hud)

# Right - UI renders on top:
var ui_layer: CanvasLayer = CanvasLayer.new()
add_child(ui_layer)
ui_layer.add_child(hud)
```
**Why It Works**: CanvasLayer provides separate rendering context that renders above Node2D elements
**Related Concepts**: UI hierarchy, rendering layers, scene organization

### Signal System
**Problem/Context**: Implementing event-driven architecture with cross-system communication
**Solution/Pattern**: Use EventBus autoload for global signals and local signals for component communication
**Code Example**:
```gdscript
# EventBus.gd - Global signals
signal enemy_killed(pos: Vector2, xp_value: int)
signal level_up(new_level: int)

# System emits to EventBus
EventBus.enemy_killed.emit(death_pos, 1)

# Other systems connect to EventBus
EventBus.level_up.connect(_on_level_up)
```
**Why It Works**: EventBus provides decoupled communication; systems don't need direct references to each other
**Related Concepts**: Observer pattern, loose coupling, system architecture

### Autoloads
*[Add learnings about autoload usage, when to use them, and best practices]*

### Performance
*[Add learnings about optimization, bottlenecks, and efficient patterns]*

### Testing
**Problem/Context**: Implementing schema validation for JSON data loading with hot-reload support
**Solution/Pattern**: Handle JSON numeric type ambiguity and provide comprehensive debug logging for validation failures
**Code Example**:
```gdscript
# JSON often returns integers as floats (4 becomes 4.0)
# Allow float-to-int conversion for whole numbers
if expected_type == TYPE_INT and actual_type == TYPE_FLOAT:
    var float_val: float = data[field_name]
    if float_val == floor(float_val):
        pass  # Accept whole number floats as valid integers
    else:
        push_error("Expected integer, got float with decimal: " + str(float_val))
```
**Why It Works**: JSON parsers commonly represent all numbers as floats; validation must be flexible while still catching actual type errors
**Related Concepts**: Always test validation with real JSON files; ensure schemas include all optional fields; use debug logging to trace validation failures

## Architecture Patterns

### Data Flow
*[Add learnings about how data flows between systems, scenes, and autoloads]*

### System Design
**Problem/Context**: Creating modular systems that communicate without tight coupling
**Solution/Pattern**: Use constructor injection for required dependencies, signals for events, and autoloads for shared state
**Code Example**:
```gdscript
# XpSystem needs arena reference for spawning orbs
class_name XpSystem
var _arena_node: Node

func _init(arena: Node) -> void:
    _arena_node = arena  # Constructor injection

# Wave director needs player reference for AI
func set_player_reference(player: Node2D) -> void:
    player_ref = player  # Setter injection

# Global state in autoloads
RunManager.stats["projectile_count_add"] += 2
```
**Why It Works**: Clear dependency injection makes requirements explicit; signals keep communication loose; autoloads manage shared state
**Related Concepts**: Dependency injection, separation of concerns, SOLID principles

### Error Handling
*[Add learnings about robust error handling in Godot]*

## Common Pitfalls & Solutions

### Type Inference Issues
**Problem/Context**: Godot's strict typing can fail to infer types when accessing Dictionary values or chained method calls
**Solution/Pattern**: Add explicit type annotations when accessing Dictionary values or method results
**Code Example**: 
```gdscript
# This fails type inference:
var dist_to_center := enemy["pos"].distance_to(arena_center)
var direction := (target_pos - enemy["pos"]).normalized()
var speed := enemy["vel"].length()

# This works:
var dist_to_center: float = enemy["pos"].distance_to(arena_center)
var direction: Vector2 = (target_pos - enemy["pos"]).normalized()
var speed: float = enemy["vel"].length()
```
**Why It Works**: Dictionary access returns Variant type, and complex expressions with method chaining can't be properly inferred by the compiler
**Related Concepts**: Always use explicit typing for Dictionary value operations and complex expressions

### Memory Management
*[Add learnings about memory leaks, object lifecycle, and cleanup]*

### Signal Connection Syntax
**Problem/Context**: Godot 4.x changed signal connection syntax from Godot 3.x, causing "Could not start subprocesses" errors
**Solution/Pattern**: Use new dot notation for signal connections instead of string-based connections
**Code Example**:
```gdscript
# Old Godot 3.x syntax (causes errors in Godot 4.x):
EventBus.connect("combat_step", Callable(self, "_on_combat_step"))

# New Godot 4.x syntax:
EventBus.combat_step.connect(_on_combat_step)
```
**Why It Works**: Godot 4.x uses direct signal references for type safety and better performance
**Related Concepts**: Always update signal connections when migrating from Godot 3.x to 4.x

### Theme System Visual Updates
**Problem/Context**: Theme changes worked logically (console output) but no visual change occurred
**Solution/Pattern**: Connect theme change signals to update visual components; cache-clearing doesn't automatically update existing instances
**Code Example**:
```gdscript
# Connect theme changes to visual updates
texture_theme_system.theme_changed.connect(_update_multimesh_textures)

func _update_multimesh_textures() -> void:
    # Manually update each MultiMesh texture
    mm_walls.texture = texture_theme_system.get_texture("walls")
    mm_terrain.texture = texture_theme_system.get_texture("terrain")
```
**Why It Works**: Changing theme data doesn't automatically update existing MultiMesh instances; they need manual texture reassignment
**Related Concepts**: Visual system updates, MultiMesh texture management, signal-driven UI updates

### Array Type Inference with Dictionary Keys
**Problem/Context**: `themes.keys()` returns generic Array, but function signature expects `Array[String]`
**Solution/Pattern**: Manually construct typed array from Dictionary keys
**Code Example**:
```gdscript
# Wrong - type mismatch:
func get_available_themes() -> Array[String]:
    return themes.keys()  # Returns Array, not Array[String]

# Right - explicit type conversion:
func get_available_themes() -> Array[String]:
    var theme_keys: Array[String] = []
    for key in themes.keys():
        theme_keys.append(key as String)
    return theme_keys
```
**Why It Works**: Dictionary.keys() returns untyped Array; Godot can't infer the element type even if all keys are strings
**Related Concepts**: Type system limitations, explicit type conversion, Dictionary operations

### Missing Signal Definitions
**Problem/Context**: Trying to emit signals that don't exist in EventBus causes "Can't emit non-existing signal" errors
**Solution/Pattern**: Always define signals in EventBus before trying to emit them from other systems
**Code Example**:
```gdscript
# EventBus.gd - Must define all signals used:
signal damage_applied(enemy_idx: int, damage: float, is_crit: bool, tags: Array)

# DamageSystem.gd - Can then safely emit:
EventBus.emit_signal("damage_applied", actual_enemy_idx, damage, false, ["projectile"])
```
**Why It Works**: Godot requires explicit signal declarations before emission
**Related Concepts**: Event-driven architecture, signal contracts

### Signal Declaration Formatting
**Problem/Context**: Multi-line signal declarations cause "Unexpected '(' in class body" syntax errors
**Solution/Pattern**: Keep signal declarations on a single line
**Code Example**:
```gdscript
# Wrong - causes syntax error:
signal enemies_updated
(alive_enemies: Array[Dictionary])

# Right - single line:
signal enemies_updated(alive_enemies: Array[Dictionary])
```
**Why It Works**: GDScript parser expects signal parameters on the same line as the signal keyword
**Related Concepts**: GDScript syntax rules, signal formatting

### Control vs Panel Nodes for UI Visibility
**Problem/Context**: Control nodes using _draw() for custom rendering were invisible despite working logic
**Solution/Pattern**: Use Panel node as base for UI elements that need visible backgrounds
**Code Example**:
```gdscript
# Wrong - Control with _draw() has no visible background:
extends Control
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color.RED)  # Invisible!

# Right - Panel provides visible background:
extends Panel
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color.RED)  # Visible!
```
**Why It Works**: Panel nodes have built-in StyleBox background rendering; Control nodes are transparent containers
**Related Concepts**: UI element visibility, custom drawing, Panel styling with StyleBoxFlat

### Property Existence Checking
**Problem/Context**: Using `has_property()` method causes "nonexistent function" errors in Godot
**Solution/Pattern**: Use the `"property_name" in object` operator to check property existence
**Code Example**:
```gdscript
# Wrong - has_property() doesn't exist:
if arena.has_property("wave_director"):
    var wd = arena.wave_director

# Right - use "in" operator:
if "wave_director" in arena:
    var wd = arena.wave_director
```
**Why It Works**: The `in` operator checks if a property/method exists on an object
**Related Concepts**: Dynamic property checking, runtime object introspection

### UI Configuration Should Use JSON, Not @export
**Problem/Context**: UI components with @export variables violate project's JSON-first content rule
**Solution/Pattern**: Move UI configuration values to JSON files in `/vibe/data/ui/`; load via ContentDB
**Code Example**:
```gdscript
# Wrong - hardcoded @export values:
@export var radar_range: float = 1500.0
@export var enemy_color: Color = Color(0.8, 0.2, 0.2, 1.0)

# Right - JSON configuration:
# /vibe/data/ui/radar.json
{"radar_range": 1500.0, "colors": {"enemy": {"r": 0.8, "g": 0.2, "b": 0.2, "a": 1.0}}}

# Load in _ready():
var config = ContentDB.load_json("ui/radar")
radar_range = config.get("radar_range", 1500.0)
```
**Why It Works**: Follows project's Decision 2C rule; enables runtime tuning without recompilation
**Related Concepts**: Always check if UI values affect gameplay experience; use JSON for user-facing configuration

### Signal Disconnections
*[Add learnings about proper signal management and avoiding memory leaks]*

### Scene Loading
*[Add learnings about scene loading, unloading, and resource management]*

### Variable Shadowing
**Problem/Context**: Using local variable names that match built-in properties causes shadowing warnings
**Solution/Pattern**: Use descriptive variable names that don't conflict with built-in properties
**Code Example**:
```gdscript
# Wrong - shadows Node2D.transform property:
var transform := Transform2D()

# Right - descriptive and unique:
var proj_transform := Transform2D()
var enemy_transform := Transform2D()
```
**Why It Works**: Avoids confusion between local variables and inherited properties
**Related Concepts**: Variable naming conventions, property inheritance

### Scene Node References
**Problem/Context**: Script references scene nodes with @onready but nodes are missing from .tscn file
**Solution/Pattern**: Always ensure all @onready node references exist in the scene file before running
**Code Example**: 
```gdscript
# Script has this:
@onready var mm_enemies: MultiMeshInstance2D = $MM_Enemies

# But .tscn file is missing:
[node name="MM_Enemies" type="MultiMeshInstance2D" parent="."]
```
**Why It Works**: @onready variables become null if the referenced node path doesn't exist, causing "base object of type null" errors when accessing properties
**Related Concepts**: Always verify scene structure matches script expectations; use scene dock to validate node paths

### Typed Signal Contracts
**Problem/Context**: EventBus signals using loose parameters lack compile-time guarantees and IDE support
**Solution/Pattern**: Use typed payload classes for all signal arguments to provide compile-time safety
**Code Example**:
```gdscript
# Old approach - loose parameters
signal damage_requested(source_id: EntityId, target_id: EntityId, damage: float, tags: PackedStringArray)
EventBus.damage_requested.emit(source_id, target_id, 10.0, ["fire"])

# New approach - typed payload
signal damage_requested(payload)
var payload := EventBus.DamageRequestPayload.new(source_id, target_id, 10.0, ["fire"])
EventBus.damage_requested.emit(payload)

# Handler receives typed payload
func _on_damage_requested(payload) -> void:
    # payload.source_id, payload.target_id, etc. have full IDE support
```
**Why It Works**: Typed classes provide compile-time validation, better IDE support, and self-documenting signal contracts
**Related Concepts**: Payload classes in `/scripts/domain/signal_payloads/`; accessed via EventBus preloads to avoid dependency issues

### Godot Class Dependencies and Autoloads
**Problem/Context**: Using class_name declarations in separate files can cause compilation dependency issues with autoloads
**Solution/Pattern**: Access payload classes through EventBus preload constants rather than direct class_name references
**Code Example**:
```gdscript
# EventBus.gd (autoload)
const CombatStepPayload = preload("res://scripts/domain/signal_payloads/CombatStepPayload.gd")

# Other files access via EventBus
var payload := EventBus.CombatStepPayload.new(delta_time)

# Not: var payload := CombatStepPayload.new(delta_time)  # May fail compilation
```
**Why It Works**: Preloads in autoloads are guaranteed to be available before other scripts compile; avoids circular dependencies
**Related Concepts**: Godot compilation order; autoload availability; payload class organization

## Performance Insights

### Rendering
*[Add learnings about rendering optimization, MultiMesh, and visual performance]*

### Logic
*[Add learnings about computational efficiency, algorithms, and system design]*

### Memory
*[Add learnings about memory usage patterns and optimization]*

---

**Remember**: This document is a living reference. Keep it updated with every task completion to build a comprehensive knowledge base for future development.
