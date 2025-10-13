# Scenes Layer - CLAUDE.md
> Context-specific documentation for scenes/ - UI & visual components

**Parent Documentation:** [Main CLAUDE.md](../CLAUDE.md) | **Layer:** UI & View Components

## Quick Reference

| Scene Category | Purpose | Key Entry Points | System Integration |
|----------------|---------|-----------------|-------------------|
| **main/Main.tscn** | Application entry point | StateManager boot flow | Dynamic scene loading |
| **ui/MainMenu.tscn** | Menu navigation | Character selection flow | StateManager transitions |
| **arena/Arena.tscn** | Game arena coordinator | System injection point | GameOrchestrator bridge |
| **core/Hideout.tscn** | Hub scene | MapDevice interactions | StateManager flow |
| **bosses/*.tscn** | Scene-based boss entities | BaseBoss inheritance | EventBus death signals |
| **ui/hud/components/** | Modular HUD system | HUDManager coordination | EventBus subscriptions |
| **ui/components/** | Reusable UI elements | Modal/overlay patterns | Theme system |

## Scene Architecture Patterns

### 🏗️ **Scene Layer Rules**

**Scene Script Constraints:**
```gdscript
extends Control  # or Node2D, CharacterBody2D
class_name SceneName

# ✅ Scenes may call systems via injection
var _damage_system: DamageSystem
var _card_system: CardSystem

# ✅ Scenes may emit to EventBus
EventBus.menu_transition_requested.emit(target_scene)

# ✅ Scenes use @onready for UI references
@onready var health_bar: ProgressBar = $UI/HealthBar

# ❌ Scenes must not import domain classes directly
# ❌ Scenes must not create system instances
# ❌ Scenes must not access other scenes via get_node()
```

### 🎮 **Main Scene Dynamic Loading**

**Boot Flow Pattern:**
```gdscript
# Main.gd - Entry point with dynamic scene loading
extends Node2D

var current_scene: Node
var debug_config: DebugConfig

func _ready() -> void:
    _setup_scene_transition_manager()
    _load_debug_config()
    _setup_initial_state()

func _setup_initial_state() -> void:
    # Boot directly to configured scene
    match debug_config.start_mode:
        "menu":
            StateManager.go_to_menu()
        "hideout":
            StateManager.go_to_hideout()
        "arena":
            StateManager.go_to_arena()
```

**Scene Transition Pattern:**
```gdscript
# SceneTransitionManager integration
func _on_scene_transition_requested(scene_path: String) -> void:
    if current_scene:
        current_scene.queue_free()

    var new_scene = load(scene_path).instantiate()
    add_child(new_scene)
    current_scene = new_scene
```

### 🖥️ **UI Scene Patterns**

**Menu Navigation Pattern:**
```gdscript
# MainMenu.gd - State-driven navigation
extends Control

func _on_continue_button_pressed() -> void:
    var character = CharacterManager.get_most_recent_character()
    if character:
        CharacterManager.select_character(character.character_id)
        StateManager.go_to_hideout()

func _on_new_character_button_pressed() -> void:
    StateManager.go_to_character_select()

# Never use direct scene loading:
# ❌ get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn")
```

**Modal Integration Pattern:**
```gdscript
# UI scenes integrate with UIManager for modals
func _show_character_deletion_modal(character_id: String) -> void:
    var modal_data = {
        "title": "Delete Character",
        "message": "Are you sure you want to delete this character?",
        "confirm_text": "Delete",
        "cancel_text": "Cancel"
    }

    UIManager.show_confirmation_modal(modal_data, _on_delete_confirmed.bind(character_id))
```

### 🎯 **Arena Scene Coordination**

**System Injection Pattern:**
```gdscript
# Arena.gd - Central game coordinator
extends Node2D

# Injected systems from GameOrchestrator
var _card_system: CardSystem
var _spawn_director: SpawnDirector
var _damage_system: DamageSystem

func setup_systems(injected_systems: Dictionary) -> void:
    # Receive fully-initialized systems
    _card_system = injected_systems.card_system
    _spawn_director = injected_systems.spawn_director
    _damage_system = injected_systems.damage_system

    # Arena coordinates but doesn't own systems
    _connect_system_signals()

func _connect_system_signals() -> void:
    # Connect to system events for UI updates
    _spawn_director.enemy_spawned.connect(_on_enemy_spawned)
    _card_system.card_selection_started.connect(_on_card_selection)
```

**Player Integration Pattern:**
```gdscript
# Arena spawns and manages player
func _spawn_player() -> void:
    var player_scene = preload("res://scenes/arena/Player.tscn")
    var player = player_scene.instantiate()

    # Position at spawn point
    var spawn_point = get_node("PlayerSpawnPoint")
    player.global_position = spawn_point.global_position

    add_child(player)
    _player_reference = player
```

### 🎭 **Component-Based HUD Architecture**

**HUD Component Pattern:**
```gdscript
# BaseHUDComponent.gd - Foundation for all HUD elements
extends Control
class_name BaseHUDComponent

# EventBus integration
func _ready() -> void:
    _subscribe_to_events()

func _subscribe_to_events() -> void:
    # Override in derived components
    pass

# Example: HealthBarComponent
func _subscribe_to_events() -> void:
    EventBus.health_changed.connect(_on_health_changed)
    EventBus.player_died.connect(_on_player_died)

func _on_health_changed(payload: EventBus.HealthChangedPayload_Type) -> void:
    _update_health_display(payload.current_health, payload.max_health)
```

**HUD Manager Integration:**
```gdscript
# HUDManager autoload coordinates components
func register_component(component: BaseHUDComponent, config: Dictionary) -> void:
    _active_components.append(component)
    _apply_component_layout(component, config)

# Components register themselves
func _ready() -> void:
    super._ready()
    HUDManager.register_component(self, {"anchor": "bottom_right"})
```

### 🏰 **Boss Scene Patterns**

**BaseBoss Inheritance:**
```gdscript
# AncientLich.gd - Scene-based boss entity
extends BaseBoss

func _ready() -> void:
    super._ready()  # BaseBoss handles shadows, scaling, spawn effects, registration

    # Boss-specific initialization (after spawn completes)
    _setup_lich_abilities()
    _configure_death_animation()

func _update_ai(_dt: float) -> void:
    # IMPORTANT: Always check spawn state first when overriding AI
    if _is_spawning or ai_paused or _is_dying:
        return

    # Boss-specific AI logic
    _update_lich_ai(_dt)
    _check_phase_transitions()

# Death integration with EventBus
func _die() -> void:
    super._die()  # BaseBoss emits standard death events

    # Boss-specific death behavior
    _trigger_death_explosion()
    _spawn_loot()
```

**Spawn System Pattern:**
```gdscript
# BaseBoss centralizes all spawn behavior - DON'T duplicate in child classes

# ✅ CORRECT: Let BaseBoss handle spawn effect
func _ready() -> void:
    super._ready()  # Handles spawn dissolve, group management, state flags
    # Note: Spawn dissolve effect already applied by BaseBoss._ready()
    _setup_boss_specific_behavior()

# ❌ WRONG: Don't duplicate spawn effect in child class
func _ready() -> void:
    super._ready()
    EnemySpawnEffect.apply_spawn_effect(animated_sprite, get_tree())  # ❌ DUPLICATE!
    _setup_boss_specific_behavior()

# ✅ CORRECT: Check spawn state when overriding _update_ai()
func _update_ai(_dt: float) -> void:
    if _is_spawning or ai_paused or _is_dying:
        return  # Pause AI during spawn animation (0.5s)

    # Your custom AI logic here
    super._update_ai(_dt)

# Spawn lifecycle (managed by BaseBoss):
# 1. _ready() → add_to_group("spawning") - NOT targetable
# 2. 0.5s dissolve animation with cyan edge glow
# 3. Animation complete → remove_from_group("spawning") + add_to_group("targetable")
# 4. _is_spawning = false → AI resumes

# Targeting integration:
# - AbilityController queries "targetable" group (filters spawning enemies)
# - Auto-targeting abilities (Heartseeker) skip spawning enemies
```

**Boss Factory Integration:**
```gdscript
# Boss scenes work with SpawnDirector
func spawn_boss_scene(boss_id: String, position: Vector2) -> Node2D:
    var boss_template = ContentDB.get_enemy_template(boss_id)
    var boss_scene = load(boss_template.boss_scene)
    var boss = boss_scene.instantiate()

    boss.global_position = position
    get_tree().current_scene.add_child(boss)

    # Registration handled by BaseBoss
    return boss
```

## UI Framework Patterns

### 🎨 **Theme System Integration**

**Theme-Aware Components:**
```gdscript
# UI components integrate with ThemeManager
extends Control

var main_theme: MainTheme

func _ready() -> void:
    _load_theme_from_manager()
    ThemeManager.add_theme_listener(_on_theme_changed)

func _load_theme_from_manager() -> void:
    if ThemeManager and ThemeManager.main_theme:
        main_theme = ThemeManager.main_theme
        _apply_theme()

func _apply_theme() -> void:
    # Apply theme colors, fonts, styles
    modulate = main_theme.primary_color
    add_theme_stylebox_override("panel", main_theme.panel_style)
```

**Enhanced Button Pattern:**
```gdscript
# EnhancedButton.gd - Reusable themed button
extends Button

@export var button_style: EnhancedButton.ButtonStyle = ButtonStyle.PRIMARY
@export var use_theme_colors: bool = true

func _ready() -> void:
    if use_theme_colors:
        _apply_theme_styling()
    _setup_hover_effects()
    _configure_focus_behavior()
```

### 📱 **Modal System Integration**

**BaseModal Pattern:**
```gdscript
# Modal scenes extend BaseModal for consistency
extends BaseModal

func _ready() -> void:
    super._ready()  # BaseModal handles overlay, ESC, animation

    # Modal-specific setup
    _configure_modal_content()
    _setup_modal_buttons()

func _configure_modal_content() -> void:
    title_label.text = "Character Deletion"
    message_label.text = "This action cannot be undone."
```

**Modal Factory Usage:**
```gdscript
# Scenes request modals through UIManager
func _show_settings_modal() -> void:
    var settings_modal = UIManager.create_modal("SettingsModal")
    settings_modal.settings_saved.connect(_on_settings_saved)
    UIManager.show_modal(settings_modal)
```

## Performance Considerations

### ⚡ **Scene Optimization**

**Efficient Node References:**
```gdscript
# Use @onready for UI references
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var ability_buttons: Array[Button] = [
    $UI/AbilityBar/Ability1,
    $UI/AbilityBar/Ability2,
    $UI/AbilityBar/Ability3
]

# Avoid repeated get_node() calls
# ❌ get_node("UI/HealthBar").value = new_health
# ✅ health_bar.value = new_health
```

**Canvas Layer Organization:**
```gdscript
# Proper UI layer separation
# Layer 0: Game world (Arena, Player, Enemies)
# Layer 1: Game UI (HUD components)
# Layer 10: Modals and overlays
# Layer 100: Debug panels

# Set in scene or code
canvas_layer.layer = 1  # For HUD
canvas_layer.layer = 10  # For modals
```

### 🔄 **Memory Management**

**Scene Instance Pooling:**
```gdscript
# XPOrb pooling pattern for frequently created scenes
var _xp_orb_pool: Array[XPOrb] = []
var _max_pool_size: int = 50

func spawn_xp_orb(position: Vector2, xp_value: int) -> void:
    var orb: XPOrb

    if _xp_orb_pool.is_empty():
        var orb_scene = preload("res://scenes/arena/XPOrb.tscn")
        orb = orb_scene.instantiate()
    else:
        orb = _xp_orb_pool.pop_back()

    orb.setup(position, xp_value)
    add_child(orb)
```

### 🎬 **Pooled Scene Animation Patterns**

**Two-Phase Animation System:**
```gdscript
# Fireball.tscn example - build-up → sustained loop animation
# Used for abilities, VFX, or any pooled entity with multi-phase visuals

# Scene configuration (in .tscn):
# - "default" animation: Build-up phase (loop=false)
# - "repeat" animation: Sustained phase (loop=true)

# Implementation in AbilityProjectile.gd (or similar pooled entity):
func initialize(data: Dictionary) -> void:
    # ... other initialization ...

    # Start animation for AnimatedSprite2D (pooled entities don't call _ready again)
    if sprite is AnimatedSprite2D:
        sprite.play("default")

        # Connect to animation_finished for two-phase animation (build-up → loop)
        # Check if signal is not already connected to avoid duplicate connections
        if not sprite.animation_finished.is_connected(_on_animation_finished):
            sprite.animation_finished.connect(_on_animation_finished)

## Transitions from build-up animation to sustained loop animation
func _on_animation_finished() -> void:
    if sprite and sprite is AnimatedSprite2D:
        # After initial "default" animation completes, loop the "repeat" animation
        if sprite.animation == "default" and sprite.sprite_frames.has_animation("repeat"):
            sprite.play("repeat")

## Resets animation state for pool recycling
func reset() -> void:
    # ... other reset logic ...

    # Reset animation to frame 0 for AnimatedSprite2D (ensures consistent animation start)
    if sprite and sprite is AnimatedSprite2D:
        sprite.frame = 0
        sprite.stop()  # Stop animation, will restart on next initialize()
```

**Animation Lifecycle with Pooling:**
```gdscript
# Key considerations for pooled scene animations:
# 1. Pooled entities don't call _ready() on reuse - autoplay won't trigger
# 2. Explicitly start animations in initialize() method
# 3. Connect signals with is_connected() check to prevent duplicates
# 4. Reset animation state in reset() to ensure consistent start frame
# 5. Use animation_finished signal for state machine transitions

# Example: Fireball animation phases
# Phase 1: "default" (5 frames at 5 FPS, loop=false) - charging visual
# Phase 2: "repeat" (2 frames at 3 FPS, loop=true) - sustained pulsing
# Result: Fireball charges up over ~1 second, then pulses until impact
```

**Reusable Multi-Phase Pattern:**
```gdscript
# This pattern can be applied to any pooled scene with lifecycle stages:
# - Lightning: charge → strike → dissipate
# - Explosion: expand → sustain → fade
# - Poison cloud: spawn → grow → sustain
# - Enemy spawn: materialize → idle → despawn

# Implementation steps:
# 1. Create AnimatedSprite2D with multiple named animations
# 2. Set loop=false for transitional phases, loop=true for sustained phases
# 3. Connect animation_finished signal in initialize()
# 4. Transition between animations in callback
# 5. Reset animation state in reset() for pooling
```

## State Management Integration

### 🔄 **StateManager Flow**

**Scene Transition Coordination:**
```gdscript
# Scenes work with StateManager for navigation
func _on_play_button_pressed() -> void:
    # Scene validates action
    if not _can_start_game():
        _show_error_message()
        return

    # Request state transition
    StateManager.go_to_arena()

# StateManager handles the actual scene loading
```

**State-Aware Behavior:**
```gdscript
# Scenes react to state changes
func _ready() -> void:
    StateManager.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: StateManager.GameState) -> void:
    match new_state:
        StateManager.GameState.MENU:
            _setup_menu_mode()
        StateManager.GameState.ARENA:
            _setup_arena_mode()
```

## Troubleshooting Guide

### 🚨 **Common Issues**

1. **UI not updating:** Check EventBus signal connections and payload types
2. **Scenes not loading:** Verify StateManager integration and scene paths
3. **Theme not applying:** Check ThemeManager connection and theme loading
4. **Modal not showing:** Verify UIManager integration and canvas layers
5. **Boss not spawning:** Check BaseBoss inheritance and scene instantiation

### 🔧 **Debug Patterns**

```gdscript
# Scene-specific logging
Logger.info("MainMenu initialized", "ui")
Logger.debug("Character selected: {id}".format({"id": character_id}), "ui")
Logger.warn("Invalid scene transition requested", "navigation")

# UI debugging
func _ready() -> void:
    Logger.debug("Scene node count: {count}".format({"count": get_child_count()}), "debug")
    Logger.debug("Theme loaded: {loaded}".format({"loaded": main_theme != null}), "debug")
```

### 📊 **Architecture Validation**

Scene layer rules:
- ✅ **May use:** System injection, EventBus signals, @onready references
- ✅ **May call:** StateManager, UIManager, ThemeManager autoloads
- ❌ **Must not:** Create system instances, import domain classes directly
- ❌ **Must not:** Reference other scenes via get_node paths
- ❌ **Must not:** Handle business logic (delegate to systems)

## Migration Notes

When creating new scenes:
1. **Follow layer constraints** - scenes coordinate, systems handle logic
2. **Use system injection** for accessing game systems
3. **Connect to EventBus** for cross-system communication
4. **Integrate with StateManager** for navigation
5. **Apply theme system** for visual consistency
6. **Use HUDManager** for UI components
7. **Update this documentation** with new patterns

---
**See Also:** [System Coordination](../scripts/systems/CLAUDE.md) | [UI Framework](../scripts/ui_framework/CLAUDE.md) | [State Management](../autoload/CLAUDE.md)