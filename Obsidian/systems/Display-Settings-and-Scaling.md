# Display Settings and Scaling Guidelines

## Overview

This document provides comprehensive guidelines for display settings and scaling strategies for the Vibe 2D top-down pixel art game. The game uses mixed sprite sizes (16x16, 48x48, 64x64) and requires pixel-perfect rendering across different display resolutions.

## Project Settings Configuration

### Display Settings
```ini
[display]
window/size/viewport_width=1080
window/size/viewport_height=720
window/stretch/mode="viewport"
window/stretch/aspect="keep"
```

**Key Benefits:**
- **Viewport stretch mode**: Maintains game resolution while scaling to window
- **Keep aspect**: Prevents distortion, letterboxes if necessary
- **3:2 aspect ratio**: Optimal for modern displays (scales well to 1920x1280, 2160x1440)

### Rendering Settings
```ini
[rendering]
textures/canvas_textures/default_texture_filter=0
2d/snap_2d_transforms_to_pixel=true
2d/snap_2d_vertices_to_pixel=true
anti_aliasing/quality/msaa_2d=0
```

**Key Benefits:**
- **Nearest neighbor filtering**: Preserves sharp pixel boundaries
- **Pixel snapping**: Prevents sub-pixel positioning artifacts
- **No MSAA**: Maintains pure pixel art aesthetics

## Sprite Scaling Strategy

### Base Unit System
- **Primary Unit**: 16x16 pixels
- **Scaling Multipliers**:
  - 48x48 sprites = 3x scale (16×3)
  - 64x64 sprites = 4x scale (16×4)

### Pixel Density Guidelines
All sprites should maintain consistent pixel-per-unit ratios:
- **16x16 sprites**: 16 pixels per unit (1x)
- **48x48 sprites**: 16 pixels per unit (scaled 3x in engine)
- **64x64 sprites**: 16 pixels per unit (scaled 4x in engine)

## Import Settings Template

### Required Settings for All Sprites
1. **Filter**: OFF (unchecked)
2. **Mipmaps**: OFF (unchecked)
3. **Fix Alpha Border**: ON (checked)

### Import Workflow
1. Import sprite sheet
2. Open Import tab
3. Verify settings match template above
4. Click "Reimport" if changes needed

## Camera and Viewport Guidelines

### Camera2D Settings
- **Zoom**: Use integer values only (1.0, 2.0, 3.0, 4.0)
- **Position Smoothing**: Disable or set to very low values (≤0.1)
- **Drag Margins**: Align to pixel boundaries

### Viewport Considerations
- **Base Resolution**: 1080x720 provides good balance
- **Scaling Targets**:
  - 540x360 (0.5x) for performance mode
  - 2160x1440 (2x) for high-res displays
  - 3240x2160 (3x) for 4K displays

## Multi-Resolution Support

### Scaling Behavior
- **Viewport mode**: Game renders at fixed 1080x720, scales to window
- **Aspect preservation**: Letterboxing on different aspect ratios
- **Integer scaling**: When possible, use integer multiples for crisp pixels

### Testing Resolutions
Test on these common resolutions:
- 1920x1080 (16:9) - slight letterboxing
- 1920x1200 (16:10) - minimal letterboxing
- 2560x1440 (16:9) - good scaling
- 3840x2160 (16:9) - excellent scaling

## Performance Considerations

### Rendering Performance
- **MultiMeshInstance2D**: Use for high-count identical sprites
- **TextureArrays**: Consider for sprite animation frames
- **Batching**: Group similar sprites to reduce draw calls

### Memory Optimization
- **No Mipmaps**: Saves memory, maintains pixel clarity
- **Texture Compression**: Avoid for pixel art (causes artifacts)
- **Atlas Packing**: Use Godot's automatic atlas for smaller sprites

## Quality Assurance Checklist

### Visual Validation
- [ ] Sprites appear crisp at all zoom levels
- [ ] No sub-pixel positioning artifacts
- [ ] Consistent pixel density across sprite sizes
- [ ] Proper letterboxing on different aspect ratios

### Performance Validation
- [ ] Stable framerate across resolution scales
- [ ] Memory usage within acceptable bounds
- [ ] No texture filtering artifacts

### Compatibility Testing
- [ ] Different monitor DPI settings
- [ ] Windowed vs fullscreen modes
- [ ] Various graphics drivers

## Troubleshooting Common Issues

### Blurry Sprites
- Check texture filter is set to 0 (nearest neighbor)
- Verify import settings have Filter OFF
- Ensure pixel snapping is enabled

### Sub-pixel Artifacts
- Enable 2D transform and vertex snapping
- Check camera positioning uses integer coordinates
- Verify sprite positions are whole numbers

### Scaling Inconsistencies
- Confirm all sprites use base 16x16 pixel density
- Check that zoom levels are integer values
- Validate viewport stretch settings

## Migration Notes

If updating from different display settings:
1. Backup current project.godot
2. Apply new settings via Project > Project Settings
3. Reimport all sprite assets with new settings
4. Test scaling on multiple resolutions
5. Update camera configurations if needed

---

**Last Updated**: September 2024
**Version**: 1.0
**Related Files**:
- `project.godot` - Core display settings
- `data/README.md` - Sprite import guidelines