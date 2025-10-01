# UI Container Scenes Refactor - Template-Based System

**Goal:** Create standalone scene instances for all UI containers using the 5 menu container templates, then import these pre-built scenes into MainMenu and other game screens.

**Status:** 📋 Planning
**Priority:** High
**Estimated Time:** 2-3 hours

---

## Overview

Instead of manually building UI structure in each scene, we'll create reusable container scene instances that use our template system. Each container will be a complete, self-contained scene that can be instantiated anywhere.

**Benefits:**
- ✅ Consistent styling across all UI
- ✅ Easy to modify (change template, affects all instances)
- ✅ Reduced duplication
- ✅ Faster iteration
- ✅ Cleaner scene hierarchy

---

## Template Selection Guide

**Which template to use?**

| UI Element | Template | Reason |
|------------|----------|--------|
| **Character Select** | `GridMenuContainer` | Grid of character cards with title |
| **Map Select** | `GridMenuContainer` | Grid of map/tier options with title |
| **Character Info** | `TitledMenuContainer` | Title + custom stat display |
| **Map Info** | `TitledMenuContainer` | Title + difficulty details |
| **Unlocks Shop** | `TabbedGridContainer` | Tabs (Items/Tomes/Skills) + details panel |
| **Achievements** | `GridWithDetailsContainer` | Grid of achievements + details on select |
| **Upgrade HUD** | `BaseMenuContainer` | Simple container for upgrade choices |
| **End Result Screen** | `TitledMenuContainer` | Title + custom stat/reward display |

---

## Phase 1: Create Container Scene Instances

### 1.1 Character Select Container
**Scene:** `scenes/ui/containers/CharacterSelectContainer.tscn`
**Template:** `GridMenuContainer`

**Configuration:**
```gdscript
# Inspector settings
title_text = "SELECT CHARACTER"
title_font_size = 28
container_size = Vector2(650, 550)
grid_columns = 2  # Knight | Ranger
grid_min_size = Vector2(600, 300)
grid_h_separation = 20
grid_v_separation = 20
```

**Content Script:** `CharacterSelectContainer.gd`
```gdscript
extends GridMenuContainer

signal character_selected(character_id: String)
signal character_confirmed(character_id: String)

var selected_character: String = ""

func _ready() -> void:
    super._ready()
    _populate_characters()

func _populate_characters() -> void:
    var grid = get_grid_container()

    # Create character cards (Knight, Ranger)
    var characters = ["knight", "ranger"]
    for char_id in characters:
        var card = _create_character_card(char_id)
        grid.add_child(card)

func _create_character_card(char_id: String) -> Button:
    var button = Button.new()
    button.custom_minimum_size = Vector2(250, 120)
    button.text = char_id.capitalize()
    button.pressed.connect(func(): _on_character_pressed(char_id))
    return button

func _on_character_pressed(char_id: String) -> void:
    selected_character = char_id
    character_selected.emit(char_id)
```

---

### 1.2 Character Info Panel
**Scene:** `scenes/ui/containers/CharacterInfoPanel.tscn`
**Template:** `TitledMenuContainer`

**Configuration:**
```gdscript
# Inspector settings
title_text = "CHARACTER INFO"
title_font_size = 20
container_size = Vector2(300, 400)
padding = 15
```

**Content Script:** `CharacterInfoPanel.gd`
```gdscript
extends TitledMenuContainer

var char_name_label: Label
var hp_label: Label
var damage_label: Label
var speed_label: Label
var confirm_button: Button

signal confirm_pressed()

func _ready() -> void:
    super._ready()
    _build_info_ui()

func _build_info_ui() -> void:
    var content = get_content_container()

    char_name_label = Label.new()
    char_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    char_name_label.add_theme_font_size_override("font_size", 18)
    content.add_child(char_name_label)

    hp_label = Label.new()
    content.add_child(hp_label)

    damage_label = Label.new()
    content.add_child(damage_label)

    speed_label = Label.new()
    content.add_child(speed_label)

    confirm_button = Button.new()
    confirm_button.text = "CONFIRM"
    confirm_button.custom_minimum_size = Vector2(200, 50)
    confirm_button.disabled = true
    confirm_button.pressed.connect(func(): confirm_pressed.emit())
    content.add_child(confirm_button)

func update_character(char_data: Dictionary) -> void:
    char_name_label.text = char_data.get("display_name", "Unknown")
    hp_label.text = "HP: %.0f" % char_data.get("base_hp", 0)
    damage_label.text = "Damage: %.0f" % char_data.get("base_damage", 0)
    speed_label.text = "Speed: %.1f" % char_data.get("base_speed", 0)
    confirm_button.disabled = false

func clear() -> void:
    char_name_label.text = "Select a character"
    hp_label.text = ""
    damage_label.text = ""
    speed_label.text = ""
    confirm_button.disabled = true
```

---

### 1.3 Map Select Container
**Scene:** `scenes/ui/containers/MapSelectContainer.tscn`
**Template:** `GridMenuContainer`

**Configuration:**
```gdscript
# Inspector settings
title_text = "SELECT DIFFICULTY"
title_font_size = 28
container_size = Vector2(650, 500)
grid_columns = 3  # Tier 1 | Tier 2 | Tier 3
grid_min_size = Vector2(600, 250)
```

**Content Script:** `MapSelectContainer.gd`
```gdscript
extends GridMenuContainer

signal tier_selected(tier: int)
signal start_run_pressed(tier: int)

var selected_tier: int = 1

func _ready() -> void:
    super._ready()
    _populate_tiers()

func _populate_tiers() -> void:
    var grid = get_grid_container()

    for tier in range(1, 4):
        var card = _create_tier_card(tier)
        grid.add_child(card)

func _create_tier_card(tier: int) -> Button:
    var button = Button.new()
    button.custom_minimum_size = Vector2(180, 100)
    button.text = "TIER %d" % tier
    button.pressed.connect(func(): _on_tier_pressed(tier))
    return button

func _on_tier_pressed(tier: int) -> void:
    selected_tier = tier
    tier_selected.emit(tier)
```

---

### 1.4 Map Info Panel
**Scene:** `scenes/ui/containers/MapInfoPanel.tscn`
**Template:** `TitledMenuContainer`

**Configuration:**
```gdscript
# Inspector settings
title_text = "DIFFICULTY INFO"
title_font_size = 20
container_size = Vector2(300, 300)
```

**Content Script:** `MapInfoPanel.gd`
```gdscript
extends TitledMenuContainer

var map_label: Label
var tier_label: Label
var reward_label: Label
var start_button: Button

signal start_run_pressed()

func _ready() -> void:
    super._ready()
    _build_info_ui()

func _build_info_ui() -> void:
    var content = get_content_container()

    map_label = Label.new()
    map_label.text = "Map: Forest Arena"
    content.add_child(map_label)

    tier_label = Label.new()
    content.add_child(tier_label)

    reward_label = Label.new()
    content.add_child(reward_label)

    start_button = Button.new()
    start_button.text = "START RUN"
    start_button.custom_minimum_size = Vector2(200, 50)
    start_button.pressed.connect(func(): start_run_pressed.emit())
    content.add_child(start_button)

func update_tier(tier: int) -> void:
    tier_label.text = "Tier %d: %s" % [tier, _get_tier_name(tier)]
    reward_label.text = "Rift Fragments: +%d%%" % ((tier - 1) * 10)

func _get_tier_name(tier: int) -> String:
    match tier:
        1: return "Normal"
        2: return "Hard"
        3: return "Expert"
        _: return "Unknown"
```

---

### 1.5 Unlocks Shop Container
**Scene:** `scenes/ui/containers/UnlocksShopContainer.tscn`
**Template:** `TabbedGridContainer`

**Configuration:**
```gdscript
# Inspector settings
title_text = "UNLOCKS SHOP"
title_font_size = 28
container_size = Vector2(650, 700)
tab_names = ["ITEMS", "TOMES", "SKILLS"]
grid_columns = 8
grid_min_size = Vector2(600, 400)
details_visible = true
details_panel_size = Vector2(600, 140)
```

**Content Script:** `UnlocksShopContainer.gd`
```gdscript
extends TabbedGridContainer

signal item_selected(item_metadata: ItemMetadata)
signal unlock_requested(item_metadata: ItemMetadata)

var item_metadata_cache: Dictionary = {}

func _ready() -> void:
    super._ready()
    _load_item_metadata()
    _setup_details_panel()
    tab_changed.connect(_on_tab_changed)

func _load_item_metadata() -> void:
    # Load from res://data/content/{items,tomes,skills}/*.tres
    # Same logic as current MainMenu._load_item_metadata()
    pass

func _on_tab_changed(tab_name: String) -> void:
    var category = tab_name.to_lower()
    _populate_category(category)

func _populate_category(category: String) -> void:
    var grid = get_current_grid()

    # Clear existing
    for child in grid.get_children():
        child.queue_free()

    # Add items for this category
    for item_id in item_metadata_cache.keys():
        var metadata = item_metadata_cache[item_id]
        if metadata.category == category:
            var card = _create_item_card(metadata)
            grid.add_child(card)

func _create_item_card(metadata: ItemMetadata) -> TextureButton:
    var button = TextureButton.new()
    button.custom_minimum_size = Vector2(80, 80)
    button.pressed.connect(func(): _on_item_pressed(metadata))
    return button

func _on_item_pressed(metadata: ItemMetadata) -> void:
    item_selected.emit(metadata)
    _update_details_panel(metadata)

func _setup_details_panel() -> void:
    var left = get_details_left_panel()
    var right = get_details_right_panel()

    # Create labels/buttons (same as current shop)
    # Name, description, stats, flavor on left
    # Quest progress OR unlock button on right

func _update_details_panel(metadata: ItemMetadata) -> void:
    # Update details based on discovery/unlock state
    pass
```

---

### 1.6 Achievements Container
**Scene:** `scenes/ui/containers/AchievementsContainer.tscn`
**Template:** `GridWithDetailsContainer`

**Configuration:**
```gdscript
# Inspector settings
title_text = "ACHIEVEMENTS"
title_font_size = 28
container_size = Vector2(650, 700)
grid_columns = 6
grid_min_size = Vector2(600, 400)
details_visible = true
```

**Content Script:** `AchievementsContainer.gd`
```gdscript
extends GridWithDetailsContainer

signal achievement_selected(achievement_id: String)

func _ready() -> void:
    super._ready()
    _populate_achievements()
    _setup_details_panel()

func _populate_achievements() -> void:
    var grid = get_grid_container()

    # Example achievements
    var achievements = [
        {"id": "first_kill", "name": "First Blood", "icon": "⚔️"},
        {"id": "survive_60s", "name": "Survivor", "icon": "🛡️"},
        {"id": "unlock_5_items", "name": "Collector", "icon": "💎"},
    ]

    for ach in achievements:
        var card = _create_achievement_card(ach)
        grid.add_child(card)

func _create_achievement_card(ach_data: Dictionary) -> Button:
    var button = Button.new()
    button.custom_minimum_size = Vector2(90, 90)
    button.text = ach_data.icon
    button.pressed.connect(func(): _on_achievement_pressed(ach_data))
    return button

func _on_achievement_pressed(ach_data: Dictionary) -> void:
    achievement_selected.emit(ach_data.id)
    _update_details(ach_data)

func _setup_details_panel() -> void:
    var left = get_details_left_panel()

    var name_label = Label.new()
    name_label.name = "AchievementName"
    left.add_child(name_label)

    var desc_label = Label.new()
    desc_label.name = "AchievementDesc"
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    left.add_child(desc_label)

func _update_details(ach_data: Dictionary) -> void:
    var left = get_details_left_panel()
    left.get_node("AchievementName").text = ach_data.name
    left.get_node("AchievementDesc").text = "Achievement description here"
```

---

### 1.7 Upgrade HUD Container (In-Game)
**Scene:** `scenes/ui/containers/UpgradeHUDContainer.tscn`
**Template:** `BaseMenuContainer`

**Configuration:**
```gdscript
# Inspector settings
container_size = Vector2(400, 300)
background_color = Color(0.1, 0.1, 0.15, 0.95)  # More opaque for in-game
padding = 20
```

**Content Script:** `UpgradeHUDContainer.gd`
```gdscript
extends BaseMenuContainer

signal upgrade_selected(upgrade_id: String)

func _ready() -> void:
    super._ready()
    _build_upgrade_ui()

func _build_upgrade_ui() -> void:
    var content = get_content_container()

    var title = Label.new()
    title.text = "CHOOSE UPGRADE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    content.add_child(title)

    # Upgrade choices will be added dynamically

func show_upgrade_choices(choices: Array) -> void:
    var content = get_content_container()

    # Clear previous choices (keep title)
    for i in range(1, content.get_child_count()):
        content.get_child(i).queue_free()

    # Add new choices
    for choice in choices:
        var button = Button.new()
        button.text = choice.display_name
        button.custom_minimum_size = Vector2(350, 60)
        button.pressed.connect(func(): _on_upgrade_pressed(choice.id))
        content.add_child(button)

func _on_upgrade_pressed(upgrade_id: String) -> void:
    upgrade_selected.emit(upgrade_id)
    visible = false  # Auto-hide after selection
```

---

### 1.8 End Result Screen Container
**Scene:** `scenes/ui/containers/EndResultContainer.tscn`
**Template:** `TitledMenuContainer`

**Configuration:**
```gdscript
# Inspector settings
title_text = "RUN COMPLETE"
title_font_size = 32
container_size = Vector2(600, 500)
padding = 25
```

**Content Script:** `EndResultContainer.gd`
```gdscript
extends TitledMenuContainer

signal continue_pressed()
signal retry_pressed()

var kills_label: Label
var time_label: Label
var fragments_label: Label

func _ready() -> void:
    super._ready()
    _build_results_ui()

func _build_results_ui() -> void:
    var content = get_content_container()

    # Stats section
    var stats_container = VBoxContainer.new()
    stats_container.add_theme_constant_override("separation", 15)
    content.add_child(stats_container)

    kills_label = Label.new()
    kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    kills_label.add_theme_font_size_override("font_size", 20)
    stats_container.add_child(kills_label)

    time_label = Label.new()
    time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    time_label.add_theme_font_size_override("font_size", 20)
    stats_container.add_child(time_label)

    fragments_label = Label.new()
    fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    fragments_label.add_theme_font_size_override("font_size", 20)
    stats_container.add_child(fragments_label)

    # Buttons
    var button_box = HBoxContainer.new()
    button_box.alignment = BoxContainer.ALIGNMENT_CENTER
    button_box.add_theme_constant_override("separation", 20)
    content.add_child(button_box)

    var continue_btn = Button.new()
    continue_btn.text = "CONTINUE"
    continue_btn.custom_minimum_size = Vector2(150, 50)
    continue_btn.pressed.connect(func(): continue_pressed.emit())
    button_box.add_child(continue_btn)

    var retry_btn = Button.new()
    retry_btn.text = "RETRY"
    retry_btn.custom_minimum_size = Vector2(150, 50)
    retry_btn.pressed.connect(func(): retry_pressed.emit())
    button_box.add_child(retry_btn)

func display_results(results: Dictionary) -> void:
    kills_label.text = "Kills: %d" % results.get("kills", 0)
    time_label.text = "Time: %.1fs" % results.get("time", 0)
    fragments_label.text = "💎 Rift Fragments: +%d" % results.get("fragments", 0)
```

---

## Phase 2: Integration into Existing Scenes

### 2.1 Update MainMenu.tscn

**Before:**
```
MainMenu
  └─ BackgroundPanel
      ├─ CharacterSelectContainer (CenterContainer)
      │   └─ BackgroundPanel (Panel)
      │       └─ VBoxContainer (manual structure)
      └─ MapSelectContainer (CenterContainer)
          └─ BackgroundPanel (Panel)
              └─ VBoxContainer (manual structure)
```

**After:**
```
MainMenu
  └─ BackgroundPanel
      ├─ CharSelectWrapper (CenterContainer)
      │   ├─ CharacterSelectContainer (instanced scene)
      │   └─ CharacterInfoPanel (instanced scene)
      ├─ MapSelectWrapper (CenterContainer)
      │   ├─ MapSelectContainer (instanced scene)
      │   └─ MapInfoPanel (instanced scene)
      └─ UnlocksShopWrapper (CenterContainer)
          └─ UnlocksShopContainer (instanced scene)
```

**MainMenu.gd Updates:**
```gdscript
# Old references
@onready var knight_button: Button = $BackgroundPanel/CharacterSelectContainer/BackgroundPanel/VBoxContainer/CharacterButtons/KnightButton
@onready var char_info_label: Label = $BackgroundPanel/CharacterSelectContainer/BackgroundPanel/VBoxContainer/CharInfoLabel

# New references
@onready var character_select: CharacterSelectContainer = $BackgroundPanel/CharSelectWrapper/CharacterSelectContainer
@onready var character_info: CharacterInfoPanel = $BackgroundPanel/CharSelectWrapper/CharacterInfoPanel

# Signal connections
func _ready() -> void:
    character_select.character_selected.connect(_on_character_selected)
    character_select.character_confirmed.connect(_on_character_confirmed)
    character_info.confirm_pressed.connect(_on_char_confirm_pressed)

func _on_character_selected(char_id: String) -> void:
    var char_data = character_types.get(char_id, {})
    character_info.update_character(char_data)
```

---

### 2.2 Create Arena Upgrade HUD Scene

**Scene:** `scenes/arena/ui/UpgradeHUD.tscn`

```
UpgradeHUD (CanvasLayer)
  └─ CenterContainer
      └─ UpgradeHUDContainer (instanced scene)
```

**UpgradeHUD.gd:**
```gdscript
extends CanvasLayer

@onready var upgrade_container: UpgradeHUDContainer = $CenterContainer/UpgradeHUDContainer

func _ready() -> void:
    upgrade_container.upgrade_selected.connect(_on_upgrade_selected)
    visible = false  # Hidden until upgrade available

func show_upgrades(choices: Array) -> void:
    upgrade_container.show_upgrade_choices(choices)
    visible = true
    get_tree().paused = true

func _on_upgrade_selected(upgrade_id: String) -> void:
    # Apply upgrade
    get_tree().paused = false
    visible = false
```

---

### 2.3 Create End Result Scene

**Scene:** `scenes/ui/EndResultScreen.tscn`

```
EndResultScreen (Control)
  └─ CenterContainer
      └─ EndResultContainer (instanced scene)
```

**EndResultScreen.gd:**
```gdscript
extends Control

@onready var result_container: EndResultContainer = $CenterContainer/EndResultContainer

func _ready() -> void:
    result_container.continue_pressed.connect(_on_continue)
    result_container.retry_pressed.connect(_on_retry)

func show_results(results: Dictionary) -> void:
    result_container.display_results(results)
    visible = true

func _on_continue() -> void:
    StateManager.go_to_menu()

func _on_retry() -> void:
    # Restart same run
    get_tree().reload_current_scene()
```

---

## Phase 3: Testing & Validation

### 3.1 Test Checklist

- [ ] Character selection flow works with new containers
- [ ] Map/tier selection flow works
- [ ] Unlocks shop tabs switch correctly
- [ ] Achievements display (when implemented)
- [ ] Upgrade HUD shows during runs
- [ ] End result screen displays stats
- [ ] All containers have consistent styling
- [ ] Signals propagate correctly
- [ ] No null reference errors

### 3.2 Visual Validation

Run each screen and verify:
- Border + background display correctly
- Corner radius matches (8px)
- Padding is consistent (20px default)
- Colors match template defaults
- Grids align properly
- Details panels show/hide correctly

---

## Phase 4: Cleanup & Documentation

### 4.1 Remove Old Manual Structure

Once all containers are migrated:

1. Delete old manual Panel/VBoxContainer structures from MainMenu.tscn
2. Remove old @onready references from MainMenu.gd
3. Clean up old signal connections

### 4.2 Update Documentation

- Update `scenes/CLAUDE.md` with new container patterns
- Add migration examples to `MENU_CONTAINERS_GUIDE.md`
- Document signal flows for each container

---

## File Structure Summary

```
scenes/ui/components/
├── BaseMenuContainer.gd/.tscn
├── TitledMenuContainer.gd/.tscn
├── GridMenuContainer.gd/.tscn
├── GridWithDetailsContainer.gd/.tscn
├── TabbedGridContainer.gd/.tscn
└── MENU_CONTAINERS_GUIDE.md

scenes/ui/containers/
├── CharacterSelectContainer.gd/.tscn
├── CharacterInfoPanel.gd/.tscn
├── MapSelectContainer.gd/.tscn
├── MapInfoPanel.gd/.tscn
├── UnlocksShopContainer.gd/.tscn
├── AchievementsContainer.gd/.tscn
├── UpgradeHUDContainer.gd/.tscn
└── EndResultContainer.gd/.tscn

scenes/ui/
├── MainMenu.tscn (updated to use container instances)
└── EndResultScreen.tscn (new scene)

scenes/arena/ui/
└── UpgradeHUD.tscn (new scene)
```

---

## Success Criteria

✅ All UI containers use template-based scenes
✅ No manual Panel/VBoxContainer structures in main scenes
✅ Consistent styling across all UI
✅ Signal-based communication
✅ Reusable, composable containers
✅ Easy to add new containers (just instance template)
✅ All existing functionality preserved

---

## Notes

- **Migration Strategy:** Create new container scenes first, test in isolation, then replace in MainMenu
- **Backwards Compatibility:** Keep old structure until new one is fully tested
- **Signal Naming:** Use consistent naming (e.g., `item_selected`, `character_confirmed`)
- **Error Handling:** Add null checks when accessing MetaProgression, SessionState
- **Theme Integration:** Containers should work with ThemeManager if available

---

**Next Steps:**
1. Create `/scenes/ui/containers/` directory
2. Build CharacterSelectContainer.tscn first (simplest)
3. Test in isolation with demo scene
4. Integrate into MainMenu
5. Repeat for remaining containers
