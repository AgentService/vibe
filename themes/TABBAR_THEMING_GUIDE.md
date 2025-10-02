# TabBar Theming Guide

## Overview

TabBar styling has been integrated into the `MainTheme` system to ensure consistent tab appearance across all UI scenes. This guide explains how to use the theming system for both texture-based and programmatic tab styles.

## Theme Properties

The following standardized properties are available in `MainTheme`:

| Property | Default Value | Description |
|----------|--------------|-------------|
| `tab_min_height` | 50 | Minimum height for all tabs |
| `tab_content_margin_horizontal` | 12 | Left/right padding inside tabs |
| `tab_content_margin_vertical` | 6 | Top/bottom padding inside tabs |
| `tab_separation` | 50 | Space between adjacent tabs |
| `tab_icon_separation` | 8 | Space between icon and text within a tab |
| `tab_icon_max_width` | 22 | Maximum width for tab icons |

## Usage Patterns

### Pattern 1: Programmatic Styling (StyleBoxFlat)

Use this approach for modern, scalable UI that doesn't require pixel-art textures.

**In GDScript (_ready method):**

```gdscript
extends Control

var main_theme: MainTheme

func _ready() -> void:
	# Load theme from ThemeManager
	if ThemeManager and ThemeManager.main_theme:
		main_theme = ThemeManager.main_theme

		# Get TabBar reference
		var tab_bar = $VBoxContainer/HBoxContainer/TabBar

		# Apply theme (creates StyleBoxFlat automatically)
		main_theme.apply_tabbar_theme(tab_bar)
```

**What this does:**
- Sets `custom_minimum_size` to `Vector2(0, 50)`
- Applies spacing constants (h_separation, icon_separation, icon_max_width)
- Creates and applies StyleBoxFlat for all tab states (unselected, selected, focus)
- Uses theme colors (background_medium, selected_color, primary_color)

### Pattern 2: Texture-Based Styling (Current Approach)

Use this approach when using 9-slice sprite textures like `raven_starter.png` for pixel-art aesthetics.

**In Scene Editor (.tscn):**

1. **Create StyleBoxTexture SubResources** (as you currently have):
   ```tres
   [sub_resource type="StyleBoxTexture" id="StyleBoxTexture_tab_unselected"]
   content_margin_left = 12.0
   content_margin_top = 6.0
   content_margin_right = 12.0
   content_margin_bottom = 6.0
   texture = ExtResource("raven_starter.png")
   texture_margin_left = 3.0
   texture_margin_top = 2.0
   texture_margin_right = 3.0
   texture_margin_bottom = 1.0
   region_rect = Rect2(192, 32, 16, 15)
   ```

2. **Configure TabBar Node:**
   ```tres
   [node name="TabBar" type="TabBar"]
   z_index = 1
   custom_minimum_size = Vector2(0, 50)
   theme_override_styles/tab_unselected = SubResource("StyleBoxTexture_tab_unselected")
   theme_override_styles/tab_selected = SubResource("StyleBoxTexture_tab_selected")
   theme_override_styles/tab_focus = SubResource("StyleBoxTexture_tab_focus")
   ```

3. **Optional: Apply spacing from theme in GDScript:**
   ```gdscript
   func _ready() -> void:
   	if ThemeManager and ThemeManager.main_theme:
   		var tab_bar = $TabBar
   		var theme = ThemeManager.main_theme

   		# Apply spacing constants only (keep texture styles from scene)
   		tab_bar.add_theme_constant_override("h_separation", theme.tab_separation)
   		tab_bar.add_theme_constant_override("icon_separation", theme.tab_icon_separation)
   		tab_bar.add_theme_constant_override("icon_max_width", theme.tab_icon_max_width)
   ```

### Pattern 3: Hybrid Approach (Recommended)

Combine scene-based textures with theme-driven sizing for maximum flexibility.

**Setup Steps:**

1. **In Scene Editor:** Create StyleBoxTexture SubResources with **only texture properties** (no content_margin yet)
2. **In GDScript:** Apply all spacing and margin values from theme

```gdscript
extends Control

@onready var tab_bar: TabBar = $VBoxContainer/HBoxContainer/TabBar

func _ready() -> void:
	_apply_theme_to_tabs()

func _apply_theme_to_tabs() -> void:
	"""Apply MainTheme values to tabs while preserving texture styles"""
	if not ThemeManager or not ThemeManager.main_theme:
		return

	var theme = ThemeManager.main_theme

	# Apply sizing
	tab_bar.custom_minimum_size = Vector2(0, theme.tab_min_height)

	# Apply spacing constants
	tab_bar.add_theme_constant_override("h_separation", theme.tab_separation)
	tab_bar.add_theme_constant_override("icon_separation", theme.tab_icon_separation)
	tab_bar.add_theme_constant_override("icon_max_width", theme.tab_icon_max_width)

	# Apply content margins to existing StyleBoxTexture resources
	for state in ["tab_unselected", "tab_selected", "tab_focus"]:
		var style: StyleBoxTexture = tab_bar.get_theme_stylebox(state)
		if style:
			style.content_margin_left = theme.tab_content_margin_horizontal
			style.content_margin_top = theme.tab_content_margin_vertical
			style.content_margin_right = theme.tab_content_margin_horizontal
			style.content_margin_bottom = theme.tab_content_margin_vertical
```

**Benefits:**
- Preserves pixel-art aesthetic from textures
- All sizing values driven by MainTheme (single source of truth)
- Easy to adjust spacing across all tabs by changing theme values

## Migration Guide

### Converting Existing TabBars to Theme-Based

**Current State (UnlockShop/Leaderboard):**
- Hard-coded content_margin values in .tscn files
- Hard-coded custom_minimum_size and spacing constants
- No central theme integration

**Migrated State:**

1. **Remove hard-coded values from .tscn** (optional but recommended):
   ```diff
   [sub_resource type="StyleBoxTexture" id="StyleBoxTexture_tab_unselected"]
   - content_margin_left = 12.0
   - content_margin_top = 6.0
   - content_margin_right = 12.0
   - content_margin_bottom = 6.0
   texture = ExtResource("raven_starter.png")
   ...
   ```

2. **Add theme application in component script:**
   ```gdscript
   # UnlockShop.gd
   func _ready() -> void:
   	_apply_tabbar_theme()
   	_load_notification_icon()
   	# ... rest of setup

   func _apply_tabbar_theme() -> void:
   	"""Apply MainTheme styling to TabBar"""
   	if ThemeManager and ThemeManager.main_theme:
   		var theme = ThemeManager.main_theme
   		theme.apply_tabbar_theme(tab_bar, "res://assets/ui/raven_starter.png")
   ```

## Best Practices

### 1. **Single Source of Truth**
Always reference `MainTheme` properties instead of hard-coding values:

```gdscript
# ✅ Good - theme-driven
tab_bar.custom_minimum_size = Vector2(0, theme.tab_min_height)

# ❌ Bad - hard-coded
tab_bar.custom_minimum_size = Vector2(0, 50)
```

### 2. **Consistent Content Margins**
All tabs should use the same content margins (12px/6px) unless there's a specific design reason:

```gdscript
# ✅ Good - consistent across states
style_unselected.content_margin_left = theme.tab_content_margin_horizontal
style_selected.content_margin_left = theme.tab_content_margin_horizontal
style_focus.content_margin_left = theme.tab_content_margin_horizontal

# ❌ Bad - inconsistent margins
style_unselected.content_margin_left = 12
style_selected.content_margin_left = 24  # Why different?
```

### 3. **Theme Validation**
Use `ThemeManager` to ensure theme is loaded:

```gdscript
func _ready() -> void:
	if not ThemeManager:
		push_warning("ThemeManager not available")
		return

	if not ThemeManager.main_theme:
		push_warning("MainTheme not loaded")
		return

	_apply_theme()
```

## Troubleshooting

### Issue: Tabs Don't Have Padding

**Problem:** Content margins not applied to StyleBoxTexture.

**Solution:** Ensure `content_margin_*` properties are set on the StyleBoxTexture resource, not just the TabBar node.

```gdscript
var style: StyleBoxTexture = tab_bar.get_theme_stylebox("tab_unselected")
style.content_margin_left = 12
style.content_margin_right = 12
```

### Issue: Tabs Have Different Heights

**Problem:** `custom_minimum_size` not consistently applied.

**Solution:** Set `custom_minimum_size.y` to `theme.tab_min_height` (50px) for all TabBar nodes.

### Issue: Tab Spacing Inconsistent

**Problem:** Missing `h_separation` or `icon_separation` overrides.

**Solution:** Apply theme constants using `add_theme_constant_override()`:

```gdscript
tab_bar.add_theme_constant_override("h_separation", theme.tab_separation)
tab_bar.add_theme_constant_override("icon_separation", theme.tab_icon_separation)
```

## Current Implementation Status

### ✅ Theme Integration Complete
- MainTheme.gd has `apply_tabbar_theme()` method
- Tab styling properties added to MainTheme
- StyleBoxFlat generation for programmatic tabs
- main_theme.tres updated with default values

### ✅ Using Theme Properties
- UnlockShop.tscn: Has standardized 12px/6px content margins
- Leaderboard.tscn: Has standardized 12px/6px content margins
- Both use custom_minimum_size = Vector2(0, 50)

### 🔄 Migration Opportunities
- UnlockShop.gd: Could call `theme.apply_tabbar_theme()` in `_ready()`
- Leaderboard.gd: Could call `theme.apply_tabbar_theme()` in `_ready()`
- Other TabBar scenes: Should use theme from the start

## Future Enhancements

### Global TabBar Theme Override

Create a project-wide Theme resource that applies to all TabBar nodes automatically:

**Project Settings → GUI → Theme:**
1. Create/assign a Theme resource
2. Add TabBar styles with MainTheme values
3. All TabBar nodes inherit styling by default

### Theme Variants

Support multiple tab styles in MainTheme:

```gdscript
# Future enhancement
theme.apply_tabbar_theme(tab_bar, "", "compact")  # Smaller padding
theme.apply_tabbar_theme(tab_bar, "", "large")    # Larger padding
```

## See Also

- [MainTheme.gd](../scripts/ui_framework/MainTheme.gd) - Full theme implementation
- [UnlockShop.tscn](../scenes/ui/components/UnlockShop.tscn) - Reference implementation
- [Leaderboard.tscn](../scenes/ui/components/Leaderboard.tscn) - Reference implementation
