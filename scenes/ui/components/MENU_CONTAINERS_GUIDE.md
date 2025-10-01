# Menu Container Templates - Usage Guide

A set of 5 reusable, progressively complex menu container templates with consistent styling.

## Template Hierarchy

```
BaseMenuContainer (border + background)
  └─> TitledMenuContainer (+ title section)
      └─> GridMenuContainer (+ scrollable grid)
          └─> GridWithDetailsContainer (+ toggleable details panel)
              └─> TabbedGridContainer (+ tab navigation)
```

## 1. BaseMenuContainer

**Purpose:** Simple container with border + background
**Use When:** You need a basic styled panel for custom content

### Properties:
- `container_size: Vector2(650, 650)` - Overall size
- `background_color: Color(0, 0.152, 0.24, 1.0)` - Semi-transparent dark blue
- `corner_radius: int = 8` - Rounded corners
- `padding: int = 20` - Internal padding

### Usage:
```gdscript
# In scene or code
var container = preload("res://scenes/ui/components/BaseMenuContainer.tscn").instantiate()
container.container_size = Vector2(500, 400)
container.background_color = Color(0.1, 0.1, 0.15, 0.9)
add_child(container)

# Add custom content
var my_label = Label.new()
my_label.text = "Custom Content"
container.get_content_container().add_child(my_label)
```

---

## 2. TitledMenuContainer

**Purpose:** Container with styled title section
**Use When:** You need a titled panel for character select, settings, etc.

### Properties:
- All BaseMenuContainer properties, plus:
- `title_text: String = "TITLE"` - Title text
- `title_font_size: int = 24` - Title font size
- `title_alignment: HorizontalAlignment = CENTER` - Title alignment

### Usage:
```gdscript
var container = preload("res://scenes/ui/components/TitledMenuContainer.tscn").instantiate()
container.title_text = "CHARACTER SELECT"
container.title_font_size = 28
add_child(container)

# Add content below title
var content = container.get_content_container()
var my_button = Button.new()
my_button.text = "Knight"
content.add_child(my_button)
```

---

## 3. GridMenuContainer

**Purpose:** Container with title + scrollable grid
**Use When:** You need to display a grid of items/buttons (inventory, skill tree)

### Properties:
- All TitledMenuContainer properties, plus:
- `grid_min_size: Vector2(600, 400)` - Grid scroll area size
- `grid_columns: int = 8` - Number of columns
- `grid_h_separation: int = 10` - Horizontal spacing
- `grid_v_separation: int = 10` - Vertical spacing

### Usage:
```gdscript
var container = preload("res://scenes/ui/components/GridMenuContainer.tscn").instantiate()
container.title_text = "INVENTORY"
container.grid_columns = 6
add_child(container)

# Add items to grid
var grid = container.get_grid_container()
for i in range(20):
    var item_button = Button.new()
    item_button.custom_minimum_size = Vector2(80, 80)
    item_button.text = "Item %d" % i
    grid.add_child(item_button)
```

---

## 4. GridWithDetailsContainer

**Purpose:** Grid + toggleable details panel below
**Use When:** You need to show item details when selected (shop, inventory with info)

### Properties:
- All GridMenuContainer properties, plus:
- `details_panel_size: Vector2(600, 140)` - Details panel size
- `details_visible: bool = true` - Show/hide details
- `details_left_panel_width: int = 385` - Left panel width (70%)
- `details_right_panel_width: int = 155` - Right panel width (30%)
- `details_panel_padding: int = 15` - Details internal padding

### Usage:
```gdscript
var container = preload("res://scenes/ui/components/GridWithDetailsContainer.tscn").instantiate()
container.title_text = "SHOP"
container.grid_columns = 8
add_child(container)

# Add items to grid
var grid = container.get_grid_container()
for i in range(10):
    var item = TextureButton.new()
    item.custom_minimum_size = Vector2(80, 80)
    item.pressed.connect(_on_item_selected.bind(i))
    grid.add_child(item)

# Populate details panels
var left_panel = container.get_details_left_panel()
var name_label = Label.new()
name_label.text = "Item Name"
left_panel.add_child(name_label)

var desc_label = Label.new()
desc_label.text = "Description goes here"
desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
left_panel.add_child(desc_label)

var right_panel = container.get_details_right_panel()
var unlock_button = Button.new()
unlock_button.text = "UNLOCK"
right_panel.add_child(unlock_button)

func _on_item_selected(item_id: int) -> void:
    # Update details panel content
    name_label.text = "Item %d" % item_id
    desc_label.text = "Details for item %d" % item_id
```

---

## 5. TabbedGridContainer

**Purpose:** Tabbed interface with separate grids + shared details panel
**Use When:** You need categorized content (Items/Tomes/Skills tabs in shop)

### Properties:
- All GridWithDetailsContainer properties, plus:
- `tab_names: Array[String] = ["Tab 1", "Tab 2", "Tab 3"]` - Tab labels
- `tab_button_size: Vector2(120, 40)` - Tab button size

### Signals:
- `tab_changed(tab_name: String)` - Emitted when tab switches

### Usage:
```gdscript
var container = preload("res://scenes/ui/components/TabbedGridContainer.tscn").instantiate()
container.title_text = "UNLOCKS SHOP"
container.tab_names = ["ITEMS", "TOMES", "SKILLS"]
container.grid_columns = 8
container.tab_changed.connect(_on_tab_changed)
add_child(container)

# Add items to specific tab grids
var items_grid = container.get_tab_grid("ITEMS")
for i in range(5):
    var item = TextureButton.new()
    item.custom_minimum_size = Vector2(80, 80)
    items_grid.add_child(item)

var tomes_grid = container.get_tab_grid("TOMES")
for i in range(3):
    var tome = TextureButton.new()
    tome.custom_minimum_size = Vector2(80, 80)
    tomes_grid.add_child(tome)

# Details panel is shared across all tabs
var left_panel = container.get_details_left_panel()
var name_label = Label.new()
left_panel.add_child(name_label)

func _on_tab_changed(tab_name: String) -> void:
    Logger.debug("Switched to tab: %s" % tab_name, "ui")
    # Update UI based on active tab
    var current_grid = container.get_current_grid()
    Logger.debug("Current tab has %d items" % current_grid.get_child_count(), "ui")
```

---

## Common Patterns

### Pattern 1: Show/Hide Details Panel
```gdscript
# GridWithDetailsContainer or TabbedGridContainer
func _on_item_clicked(item_data) -> void:
    if item_data:
        container.set_details_visible(true)
        _populate_details(item_data)
    else:
        container.set_details_visible(false)
```

### Pattern 2: Dynamic Tab Content
```gdscript
# TabbedGridContainer
func populate_shop_tabs() -> void:
    # Items tab
    var items = MetaProgression.get_all_items()
    var items_grid = container.get_tab_grid("ITEMS")
    for item in items:
        var button = _create_item_button(item)
        items_grid.add_child(button)

    # Tomes tab
    var tomes = MetaProgression.get_all_tomes()
    var tomes_grid = container.get_tab_grid("TOMES")
    for tome in tomes:
        var button = _create_tome_button(tome)
        tomes_grid.add_child(button)
```

### Pattern 3: Custom Styling
```gdscript
# Change colors per instance
var char_select = preload("res://scenes/ui/components/TitledMenuContainer.tscn").instantiate()
char_select.background_color = Color(0, 0.152, 0.239, 1.0)  # Dark blue
char_select.corner_radius = 12

var shop = preload("res://scenes/ui/components/TabbedGridContainer.tscn").instantiate()
shop.background_color = Color(0.1, 0.05, 0.15, 0.95)  # Purple tint
shop.padding = 25
```

---

## Styling Consistency

All templates share these defaults:
- **Background Color:** `Color(0, 0.152, 0.24, 1.0)` (semi-transparent dark blue)
- **Corner Radius:** `8px` (rounded corners)
- **Padding:** `20px` (internal spacing)
- **VBox Separation:** `20px` (spacing between sections)
- **Grid H/V Separation:** `10px` (spacing between grid items)

These can all be customized per instance via @export properties in the Inspector or code.

---

## Migration Example

### Before (Manual Scene Setup):
```gdscript
# MainMenu.tscn - Manual node tree
UnlocksShopContainer (CenterContainer)
  └─ BackgroundPanel (Panel)
      └─ MarginContainer
          └─ VBoxContainer
              ├─ ShopTitle (Label)
              ├─ CategoryTabs (HBoxContainer)
              ├─ ItemListScroll (ScrollContainer)
              │   └─ ItemList (GridContainer)
              └─ ItemDetailsPanel (PanelContainer)
```

### After (Using Template):
```gdscript
# MainMenu.gd
@onready var shop_container: TabbedGridContainer = $BackgroundPanel/UnlocksShopContainer/ShopContainer

func _ready() -> void:
    # All structure created automatically
    var items_grid = shop_container.get_tab_grid("ITEMS")
    var details_left = shop_container.get_details_left_panel()
    # Just add content!
```

---

## Tips

1. **Scene Instancing:** These are scenes, not scripts. Instantiate them like any other scene:
   ```gdscript
   var container = preload("res://scenes/ui/components/TabbedGridContainer.tscn").instantiate()
   ```

2. **Inspector Configuration:** You can set all @export properties in the Inspector when using these as scene instances.

3. **Inheritance:** Each template extends the previous one, so they inherit all parent properties.

4. **Content Access:** Always use the getter functions (`get_grid_container()`, `get_details_left_panel()`, etc.) to add content - don't access internal nodes directly.

5. **Signals:** Connect to `tab_changed` signal for tab-specific logic in TabbedGridContainer.

---

## File Locations

```
scenes/ui/components/
├── BaseMenuContainer.gd/.tscn          # Template 1
├── TitledMenuContainer.gd/.tscn        # Template 2
├── GridMenuContainer.gd/.tscn          # Template 3
├── GridWithDetailsContainer.gd/.tscn   # Template 4
└── TabbedGridContainer.gd/.tscn        # Template 5
```
