# Ghost Enemy Sprite Generation Prompt

## Image Generation Prompt (Copy this exactly)

```
Create a pixel art ghost enemy sprite for a top-down 2D game with the following specifications:

TECHNICAL REQUIREMENTS:
- Format: PNG with transparent background (alpha channel)
- Size: 32x32 pixels square canvas
- Style: Pixel art, retro/indie game aesthetic
- Perspective: Top-down view (viewed from above)
- Color depth: 8-bit or 16-bit color palette
- No background - pure transparency around the ghost

VISUAL DESIGN:
- Ghost appearance: Ethereal, floating specter
- Body shape: Wispy, translucent form with flowing edges
- Color scheme: Pale white/cyan ghost with subtle blue highlights
- Features: Simple dark eyes or eye sockets, no mouth
- Movement suggestion: Slightly elongated bottom suggesting upward float
- Particle effects: Optional wispy trails or energy particles

STYLE REFERENCE:
- Match pixel art games like: Enter the Gungeon, Nuclear Throne, Vampire Survivors
- Clean pixel edges, no anti-aliasing blur
- Readable at small scale (32x32)
- Distinct silhouette for gameplay visibility

CRITICAL:
- The background MUST be completely transparent (alpha = 0)
- The ghost itself can have semi-transparent areas (alpha 50-100%)
- Save as PNG with alpha channel preserved
- No white background, no colored background, pure transparency
```

## Alternative Simpler Prompt

```
Pixel art ghost sprite, 32x32 pixels, top-down view, transparent PNG background, ethereal white-cyan wispy ghost with dark eyes, retro indie game style, clean pixel edges, no anti-aliasing
```

## Post-Generation Checklist

After generating the image:
1. ✅ Verify PNG format with transparency
2. ✅ Check dimensions are exactly 32x32 pixels
3. ✅ Confirm background is transparent (checkered pattern in image editors)
4. ✅ Test import in Godot: Drag to `assets/sprites/` folder
5. ✅ Verify sprite displays correctly in game (no white box around ghost)

## Godot Import Settings

After importing to Godot, configure:
- **Import tab** → Compress: `VRAM Compressed`
- **Flags** → Filter: `Nearest` (keeps pixel crisp)
- **Flags** → Mipmaps: `Disabled`
- **SVG** → Scale: `1.0`

## Alternative Tools (If AI generation fails)

1. **Aseprite** (pixel art editor): Draw manually with transparency
2. **Piskel** (free web tool): https://www.piskelapp.com/
3. **OpenGameArt**: Search for "ghost sprite transparent PNG"
4. **Itch.io asset packs**: Filter for "top-down ghost sprite"

## File Naming Convention

Save generated sprite as:
- `ghost_enemy_32.png` - Main sprite
- `ghost_enemy_64.png` - HD variant (optional)
- `ghost_enemy_sheet.png` - If animation frames needed

## Testing in Godot

```gdscript
# Quick test script to verify transparency
extends Sprite2D

func _ready():
    texture = load("res://assets/sprites/ghost_enemy_32.png")
    # Should see checkered background behind sprite in editor
    # Should see game background through transparent areas in-game
```
