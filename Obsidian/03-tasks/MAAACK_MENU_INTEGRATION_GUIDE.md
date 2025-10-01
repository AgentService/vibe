# Maaack Menu Plugin - Integration Guide

**Status:** 📋 Planning → Implementation
**Goal:** Replace scattered UI with professional menu system
**Time Estimate:** 4-6 hours

---

## 🎯 What You Get

### Complete Menu System:
- ✅ **Main Menu** - Play, Options, Credits, Quit
- ✅ **Options Menus** - Video, Audio, Controls, Accessibility
- ✅ **Pause Menu** - Resume, Settings, Quit to Menu
- ✅ **Loading Screen** - Async scene loading with progress
- ✅ **Credits** - Auto-scrolling credits with music
- ✅ **Settings Persistence** - Save/load via Config autoload
- ✅ **Input Remapping** - Full keyboard + gamepad support
- ✅ **UI Sounds** - Button clicks, hover sounds
- ✅ **Background Music** - Crossfading between tracks

---

## 📁 Plugin Structure

```
addons/maaacks_menus_template/
├── base/                          # DON'T EDIT - Core templates
│   ├── scenes/
│   │   ├── menus/
│   │   │   ├── main_menu/         # MainMenu.tscn (base template)
│   │   │   ├── options_menu/      # OptionsMenu.tscn + sub-menus
│   │   │   └── pause_menu/        # PauseMenu.tscn
│   │   ├── loading_screen/        # LoadingScreen.tscn
│   │   ├── credits/               # Credits.tscn
│   │   └── autoloads/             # SceneLoader, Config, etc.
│   └── scripts/
│       ├── app_settings.gd        # Settings manager
│       ├── player_config.gd       # Config file I/O
│       ├── ui_sound_controller.gd # UI audio
│       └── music_controller.gd    # Background music
│
├── examples/                      # Reference implementations
│   ├── scenes/
│   │   ├── main_menu/            # MainMenuAnimated.tscn (inherits base)
│   │   ├── loading_screen/       # LoadingScreenShader.tscn
│   │   └── opening/              # OpeningGodotLogo.tscn
│   └── resources/
│       └── themes/               # Example theme files
│
└── docs/                         # Full documentation
    ├── ExistingProject.md        # For integrating into existing projects
    ├── MainMenuSetup.md
    ├── GameSceneSetup.md
    └── LoadingScenes.md
```

---

## 🔧 How It Works: Base + Inheritance Pattern

### Concept:
1. **Base scenes** = Generic templates (don't touch these)
2. **Your scenes** = Inherit from base, customize
3. **Plugin updates** = Base scenes update, your customizations stay safe

### Example:
```
addons/.../base/scenes/menus/main_menu/MainMenu.tscn  ← Base (generic)
                        ↓ inherit (right-click > "New Inherited Scene")
scenes/ui/menus/MyMainMenu.tscn  ← Your customized version
```

---

## 📋 Step-by-Step Integration

### Phase 1: Enable Plugin & Configure Autoloads

#### 1.1 Enable Plugin in Godot
1. Open your project in Godot
2. Go to **Project > Project Settings > Plugins**
3. Find "Maaack's Menus Template"
4. Click checkbox to enable
5. **First-time setup dialog will appear**:
   - Click **"Copy Examples"** - This copies example scenes to your project root
   - Click **"Update Main Scene"** - Sets main scene to the plugin's entry point

#### 1.2 Verify Autoloads Added
The plugin automatically adds these autoloads to your project:

**Project > Project Settings > Autoloads:**
```
AppSettings        - res://addons/maaacks_menus_template/base/scripts/app_settings.gd
Config             - res://addons/maaacks_menus_template/base/scripts/player_config.gd
SceneLoader        - res://addons/maaacks_menus_template/base/scenes/autoloads/scene_loader.tscn
UISoundController  - res://addons/maaacks_menus_template/base/scripts/ui_sound_controller.gd
MusicController    - res://addons/maaacks_menus_template/base/scripts/music_controller.gd
```

**⚠️ IMPORTANT:** If these conflict with your existing autoloads (RunManager, EventBus, etc.), don't worry - they coexist. You'll integrate them later.

---

### Phase 2: Create Your Menu Scenes (Inheritance)

Instead of editing base scenes, you inherit from them. Here's how:

#### 2.1 Create Main Menu

**In Godot Editor:**
1. Right-click in FileSystem: `addons/maaacks_menus_template/base/scenes/menus/main_menu/MainMenu.tscn`
2. Select **"New Inherited Scene"**
3. Save as: `scenes/ui/menus/MainMenu.tscn` (your project)

**Now customize it:**
```gdscript
# Your MainMenu.tscn is now an inherited scene
# Changes you make here won't affect the base template

# Scene tree looks like:
MainMenu (inherited from base/MainMenu.tscn)
  ├── Background (can override)
  ├── MenuButtons (can override)
  │   ├── PlayButton
  │   ├── OptionsButton
  │   ├── CreditsButton
  │   └── QuitButton
  └── VersionLabel (can override)
```

**To customize:**
- **Change button text**: Click button in scene tree, edit Text property
- **Add your logo**: Add TextureRect as child, position it
- **Change background**: Override Background node's texture/color
- **Add animations**: Attach AnimationPlayer, create animations

#### 2.2 Create Options Menu (Already Done - Just Inherit)

```
Right-click: base/scenes/menus/options_menu/OptionsMenu.tscn
> New Inherited Scene
> Save as: scenes/ui/menus/OptionsMenu.tscn
```

**Options menu includes:**
- Video settings (resolution, fullscreen, VSync)
- Audio settings (Master, Music, SFX sliders)
- Controls (input remapping)
- Accessibility (subtitles, colorblind modes)

**No need to customize initially** - it works out of the box!

#### 2.3 Create Pause Menu

```
Right-click: base/scenes/menus/pause_menu/PauseMenu.tscn
> New Inherited Scene
> Save as: scenes/ui/menus/PauseMenu.tscn
```

#### 2.4 Create Loading Screen

```
Right-click: base/scenes/loading_screen/LoadingScreen.tscn
> New Inherited Scene
> Save as: scenes/ui/LoadingScreen.tscn
```

**Customization tip:** Look at `examples/scenes/loading_screen/LoadingScreenShader.tscn` for shader pre-caching example.

---

### Phase 3: Connect Menu Buttons to Your Game

#### 3.1 Main Menu → Start Game Flow

Edit your inherited `scenes/ui/menus/MainMenu.tscn` script:

```gdscript
# Attach script to your MainMenu scene
extends "res://addons/maaacks_menus_template/base/scenes/menus/main_menu/main_menu.gd"

func _ready():
    super._ready()  # Call base _ready()

    # Override the Play button behavior
    var play_button = $MenuButtons/PlayButton
    play_button.pressed.disconnect(_on_play_pressed)  # Disconnect base
    play_button.pressed.connect(_on_custom_play_pressed)  # Connect yours

func _on_custom_play_pressed():
    # Your custom flow: Character Select → Map Select → Arena
    SceneLoader.load_scene("res://scenes/ui/CharacterSelect.tscn")
    # OR transition to your existing StateManager flow:
    # StateManager.transition_to_state(StateManager.State.CHARACTER_SELECT)
```

#### 3.2 Integrate with Your StateManager

You have a custom `StateManager` autoload. Here's how to integrate:

**Option A: Make SceneLoader work with StateManager**
```gdscript
# In your StateManager.gd, add:
func go_to_scene(scene_path: String):
    SceneLoader.load_scene(scene_path)  # Uses Maaack's loader
    # Shows loading screen automatically
```

**Option B: Use Maaack's SceneLoader directly**
```gdscript
# Anywhere in your code:
SceneLoader.load_scene("res://scenes/arena/Arena.tscn")
# Loading screen appears automatically
# Async loading with progress bar
# Switches when ready
```

---

### Phase 4: Migrate Your Existing UI Content

#### 4.1 Character Select Screen

**Current:** `scenes/ui/MainMenu.tscn` has CharacterSelectContainer

**New Approach:** Create dedicated scene inheriting from base

```gdscript
# Create: scenes/ui/CharacterSelect.tscn
# This can be a simple Control scene with your existing logic

extends Control

func _ready():
    # Your existing character selection code
    # When character selected:
    SessionState.set_character(selected_character)
    SceneLoader.load_scene("res://scenes/ui/MapSelect.tscn")
```

#### 4.2 Map/Tier Select Screen

```gdscript
# Create: scenes/ui/MapSelect.tscn

extends Control

func _ready():
    # Your existing map/tier selection code
    # When map + tier selected:
    SessionState.set_map(selected_map)
    SessionState.set_tier(selected_tier)
    SceneLoader.load_scene("res://scenes/arena/Arena.tscn")
```

#### 4.3 Unlocks Shop Screen

**Keep your current shop!** It's already well-designed. Just integrate it:

```gdscript
# In MainMenu, add "Shop" button:
func _on_shop_pressed():
    SceneLoader.load_scene("res://scenes/ui/UnlocksShop.tscn")

# In UnlocksShop.tscn, add "Back" button:
func _on_back_pressed():
    SceneLoader.load_scene("res://scenes/ui/menus/MainMenu.tscn")
```

---

### Phase 5: Configure Settings & Audio

#### 5.1 Add Background Music

```gdscript
# In your MainMenu scene:
func _ready():
    super._ready()
    MusicController.play_music("res://assets/audio/music/main_menu_theme.ogg")

# In Arena scene:
func _ready():
    MusicController.play_music("res://assets/audio/music/battle_theme.ogg")
    # Automatically crossfades from previous track!
```

#### 5.2 Add UI Sounds

```gdscript
# UISoundController automatically hooks into ALL buttons
# Just provide the sound files:

# In Project Settings > Autoloads > UISoundController:
# Set these properties in the Inspector:
@export var hover_sound: AudioStream  # res://assets/audio/ui/hover.ogg
@export var click_sound: AudioStream  # res://assets/audio/ui/click.ogg
@export var back_sound: AudioStream   # res://assets/audio/ui/back.ogg
```

**All buttons in your project now have sounds automatically!**

#### 5.3 Configure Settings Persistence

Settings are saved automatically to `user://config.cfg`:

```gdscript
# Anywhere in your code, read/write settings:

# Save custom setting
Config.set_value("gameplay", "difficulty", "hard")

# Read custom setting
var difficulty = Config.get_value("gameplay", "difficulty", "normal")

# Already handled by plugin:
# - Video settings (resolution, fullscreen, VSync)
# - Audio settings (volume sliders)
# - Input remapping (all InputMap actions)
```

---

### Phase 6: Add Pause Menu to Arena

```gdscript
# In Arena.tscn, add PauseMenu as CanvasLayer child

# scenes/arena/Arena.tscn structure:
Arena (Node2D)
  ├── Player
  ├── Enemies
  ├── ... your game nodes ...
  └── PauseMenuLayer (CanvasLayer)  ← ADD THIS
      └── PauseMenu (inherited scene)

# The pause menu will:
# - Show when ESC pressed
# - Pause the game tree
# - Show Resume/Options/Quit buttons
# - Handle everything automatically
```

**No scripting needed** - the base PauseMenu handles it!

---

### Phase 7: Add Credits Scene

```gdscript
# Inherit from base:
Right-click: base/scenes/credits/Credits.tscn
> New Inherited Scene
> Save as: scenes/ui/Credits.tscn

# Customize credits text:
# Edit the RichTextLabel in Credits.tscn
# Or provide a credits.txt file:
```

**Create:** `res://ATTRIBUTION.md` or `res://CREDITS.txt`

```markdown
# Game Credits

## Development
- Game Design: Your Name
- Programming: Your Name
- Art: Artist Name

## Music & Sound
- Main Theme: Composer Name
- SFX: SFX Artist

## Special Thanks
- Maaack's Menus Template
- Godot Engine Community

...
```

**The Credits scene auto-scrolls this file with background music!**

---

## 🎨 Customization Examples

### Example 1: Add Your Logo to Main Menu

```gdscript
# In scenes/ui/menus/MainMenu.tscn (your inherited scene):
# Add as child of MainMenu root:

1. Add TextureRect node
2. Set texture to your logo
3. Position at top center
4. Set expand_mode = "Keep Aspect Centered"
```

### Example 2: Change Button Appearance

```gdscript
# Create a custom theme:
# Resources > New > Theme
# Save as: res://resources/themes/my_game_theme.tres

# In your MainMenu.tscn:
# Select MenuButtons/PlayButton
# Inspector > Theme Overrides > Styles
# Set "Normal", "Hover", "Pressed" StyleBoxFlat

# OR: Apply theme globally
# Project Settings > GUI > Theme > Custom = my_game_theme.tres
```

### Example 3: Add Animated Background

```gdscript
# Look at examples/scenes/main_menu/MainMenuAnimated.tscn
# It shows how to add:
# - Particle effects
# - Animated backgrounds
# - Shader effects
# - Smooth transitions

# Copy its AnimationPlayer to your scene
```

---

## 🔗 Integration with Your Existing Systems

### With MetaProgression:

```gdscript
# In MainMenu:
func _ready():
    super._ready()
    # Display Rift Fragments from MetaProgression
    var fragments_label = Label.new()
    fragments_label.text = "💎 %d" % MetaProgression.get_rift_fragments()
    $UI.add_child(fragments_label)
```

### With SessionState:

```gdscript
# SessionState already tracks current run
# Just save selected options before starting:

func _on_start_game():
    # Character, Map, Tier already in SessionState
    SceneLoader.load_scene("res://scenes/arena/Arena.tscn")
```

### With LocalLeaderboard:

```gdscript
# In end-of-run screen:
func show_results(run_data: Dictionary):
    LocalLeaderboard.submit_score(run_data)
    # Show leaderboard panel
    SceneLoader.load_scene("res://scenes/ui/menus/MainMenu.tscn")
```

### With EventBus:

```gdscript
# Your EventBus still works!
# Just emit events as normal:

EventBus.game_started.emit()
EventBus.player_died.emit(death_reason)

# In MainMenu:
func _ready():
    super._ready()
    EventBus.game_started.connect(_on_game_started)
```

---

## 🎯 Recommended Menu Flow

```
Main Menu (Maaack's MainMenu)
  ├─> Play → Character Select (your scene)
  │             └─> Map Select (your scene)
  │                   └─> Arena (your game)
  │                         └─> Death → Results (your scene)
  │                                       └─> Main Menu
  ├─> Shop → Unlocks Shop (your existing scene)
  │            └─> Back → Main Menu
  ├─> Options → Options Menu (Maaack's)
  │               └─> Video/Audio/Controls/Accessibility
  ├─> Credits → Credits (Maaack's)
  └─> Quit → Exit Game

In-Game:
  ESC → Pause Menu (Maaack's)
          ├─> Resume
          ├─> Options
          └─> Quit to Main Menu
```

---

## 📝 Migration Checklist

### Phase 1: Setup
- [x] Copy plugin to `addons/`
- [ ] Enable plugin in Project Settings
- [ ] Verify autoloads added
- [ ] Read plugin documentation (`addons/maaacks_menus_template/docs/`)

### Phase 2: Create Inherited Scenes
- [ ] Inherit MainMenu → `scenes/ui/menus/MainMenu.tscn`
- [ ] Inherit OptionsMenu → `scenes/ui/menus/OptionsMenu.tscn`
- [ ] Inherit PauseMenu → `scenes/ui/menus/PauseMenu.tscn`
- [ ] Inherit LoadingScreen → `scenes/ui/LoadingScreen.tscn`
- [ ] Inherit Credits → `scenes/ui/Credits.tscn`

### Phase 3: Connect Your Content
- [ ] Create CharacterSelect.tscn (or migrate existing)
- [ ] Create MapSelect.tscn (or migrate existing)
- [ ] Connect Play button → CharacterSelect
- [ ] Connect CharacterSelect → MapSelect
- [ ] Connect MapSelect → Arena
- [ ] Connect Arena death → Results screen
- [ ] Connect Results → Main Menu

### Phase 4: Configure Audio
- [ ] Add main menu background music
- [ ] Add battle music
- [ ] Add UI sound effects (hover, click, back)
- [ ] Configure audio buses in Options Menu

### Phase 5: Add Pause to Game
- [ ] Add PauseMenu CanvasLayer to Arena.tscn
- [ ] Test ESC pausing/resuming
- [ ] Test "Quit to Menu" from pause

### Phase 6: Polish
- [ ] Add game logo to MainMenu
- [ ] Customize button styles
- [ ] Add credits content
- [ ] Add version label
- [ ] Test full menu flow

### Phase 7: Cleanup
- [ ] Archive old MainMenu.tscn (scenes/ui/MainMenu.OLD.tscn)
- [ ] Remove duplicate UI code
- [ ] Update documentation
- [ ] Commit changes

---

## 🚨 Common Issues & Solutions

### Issue: "Autoload already exists"
**Solution:** The plugin's autoloads (Config, SceneLoader) won't conflict with yours (RunManager, EventBus). They coexist. Just make sure names don't clash.

### Issue: "Buttons don't work after inheriting"
**Solution:** You likely disconnected signals. In inherited scenes, the base signals are preserved. Only override if you need custom behavior.

### Issue: "Settings not saving"
**Solution:** Check `user://config.cfg` exists. The Config autoload creates it automatically. Make sure you're using `Config.set_value()` not just changing variables.

### Issue: "Loading screen doesn't appear"
**Solution:** You must use `SceneLoader.load_scene()` not `get_tree().change_scene_to_file()`. The loader shows the loading screen automatically.

### Issue: "Can't find base scene to inherit"
**Solution:** Make sure plugin is enabled first. Base scenes are in `addons/maaacks_menus_template/base/scenes/`.

---

## 📚 Further Reading

**Plugin Docs:** `addons/maaacks_menus_template/docs/`
- `ExistingProject.md` - Integration guide
- `MainMenuSetup.md` - Main menu customization
- `GameSceneSetup.md` - Game scene integration
- `LoadingScenes.md` - Async loading
- `AddingCustomOptions.md` - Extend settings
- `HowPartsWork.md` - Architecture overview

**Example Scenes:** `addons/maaacks_menus_template/examples/`
- MainMenuAnimated.tscn - Advanced main menu
- LoadingScreenShader.tscn - Shader pre-caching
- OpeningGodotLogo.tscn - Splash screen

---

## 🎯 Next Steps

1. **Enable the plugin** in Godot (Project > Project Settings > Plugins)
2. **Explore base scenes** to understand structure
3. **Inherit MainMenu** as your first test
4. **Connect Play button** to your CharacterSelect
5. **Test the flow** from menu → game → menu

**Estimated Time:**
- Initial setup: 30 minutes
- Create inherited scenes: 1 hour
- Connect your content: 2 hours
- Configure audio: 30 minutes
- Polish & test: 1 hour
- **Total: ~5 hours**

---

Ready to start? Let's enable the plugin and create your first inherited scene!
