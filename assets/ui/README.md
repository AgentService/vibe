# UI Assets - Asset Organization Guide

This directory contains UI-specific assets used in menus, character selection, HUD, and other interface elements.

## Asset Organization

```
assets/ui/
├── characters/
│   └── portraits/          # Character selection portraits
│       ├── knight_portrait.png
│       ├── ranger_portrait.png
│       └── ...
├── abilities/
│   └── icons/              # Ability icons (64x64 recommended)
│       ├── sword.png
│       ├── bow.png
│       └── ...
└── passives/
    └── icons/              # Passive skill icons (64x64 recommended)
        ├── shield.png
        ├── dodge.png
        └── ...
```

## Filename-Based Asset Loading

**Convention:** Character data files (`.tres`) reference assets by **filename only**, not full paths.

### Example:

**In character-types.tres:**
```gdscript
main_ability_icon = "sword"         # NOT "res://assets/ui/abilities/icons/sword.png"
main_passive_icon = "shield"        # NOT "res://assets/ui/passives/icons/shield.png"
portrait_icon = "knight_portrait"   # NOT "res://assets/ui/characters/portraits/knight_portrait.png"
```

**Why this approach?**
- ✅ Data files stay clean and readable
- ✅ Artists can reorganize assets without breaking data files
- ✅ Supports multiple file formats (.png, .svg) automatically
- ✅ Easy to implement fallback textures
- ✅ Follows content-driven game development best practices

### Asset Resolution

The `CharacterSelect.gd` script resolves filenames to full paths using these conventions:

| Asset Type | Base Path | Example Filename | Resolved Path |
|------------|-----------|------------------|---------------|
| Character Portrait | `res://assets/ui/characters/portraits/` | `"knight_portrait"` | `res://assets/ui/characters/portraits/knight_portrait.png` |
| Ability Icon | `res://assets/ui/abilities/icons/` | `"sword"` | `res://assets/ui/abilities/icons/sword.png` |
| Passive Icon | `res://assets/ui/passives/icons/` | `"shield"` | `res://assets/ui/passives/icons/shield.png` |

**Supported formats:** `.png`, `.svg` (tried in that order)

**Fallback:** If asset not found, falls back to `res://icon.svg` with a warning in logs

## Adding New Character Assets

1. **Create character portrait:**
   - Place in `assets/ui/characters/portraits/`
   - Name: `{character_id}_portrait.png` (e.g., `knight_portrait.png`)
   - Recommended size: 128x128 or higher

2. **Create ability icon:**
   - Place in `assets/ui/abilities/icons/`
   - Name: `{ability_name}.png` (e.g., `sword.png`)
   - Recommended size: 64x64

3. **Create passive icon:**
   - Place in `assets/ui/passives/icons/`
   - Name: `{passive_name}.png` (e.g., `shield.png`)
   - Recommended size: 64x64

4. **Update character-types.tres:**
   ```gdscript
   portrait_icon = "knight_portrait"  # Just the filename
   main_ability_icon = "sword"
   main_passive_icon = "shield"
   ```

## Asset Guidelines

### Character Portraits
- **Format:** PNG (with transparency) or SVG
- **Size:** 128x128 minimum, 256x256 recommended
- **Style:** Should match game's art style
- **Background:** Transparent or with vignette

### Ability/Passive Icons
- **Format:** PNG (with transparency) or SVG
- **Size:** 64x64 recommended
- **Style:** Clear, recognizable at small sizes
- **Background:** Transparent

### Naming Conventions
- Use lowercase with underscores: `knight_portrait.png`, `fire_bolt.png`
- Be descriptive: `sword_slash.png` better than `ability_1.png`
- Match the filename in `.tres` files exactly (case-sensitive on some platforms)

## Extending the System

To add a new asset type (e.g., character backgrounds):

1. **Create directory:**
   ```bash
   mkdir -p assets/ui/characters/backgrounds
   ```

2. **Add constant in CharacterSelect.gd:**
   ```gdscript
   const BACKGROUND_PATH = "res://assets/ui/characters/backgrounds/"
   ```

3. **Use existing helper:**
   ```gdscript
   background.texture = _load_texture_from_filename(
       char_type.background_icon,
       BACKGROUND_PATH,
       FALLBACK_BACKGROUND
   )
   ```

## Asset Validation

Missing assets will:
1. Log a warning: `[WARN:UI] Asset not found: sword (tried res://assets/ui/abilities/icons/)`
2. Fall back to `res://icon.svg` (default Godot icon)
3. Continue running without crashing

**Tip:** Check logs after adding new characters to ensure all assets loaded correctly.

---

**See Also:**
- [Character Data Schema](../../data/core/README.md)
- [CharacterType.gd](../../scripts/domain/CharacterType.gd)
- [CharacterSelect.gd](../../scenes/ui/CharacterSelect.gd)
