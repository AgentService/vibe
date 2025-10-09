# Visual Effects POC - Testing Playground

Interactive test scene for experimenting with different ability visual effect methods.

## 🎮 How to Use

1. **Open the scene**: `res://tests/visual_effects/EffectsPOC.tscn`
2. **Run the scene** (F6)
3. **Experiment with effects** using the keyboard controls below

## ⌨️ Keyboard Controls

### Effect Spawning
- **1** - Method A: Sprite+Shader (Projectile)
- **2** - Method A: Sprite+Shader (AOE)
- **3** - Method B: GPUParticles (Projectile)
- **4** - Method B: GPUParticles (AOE)
- **5** - Method C: Line2D (AOE)

### Parameters
- **+ / -** - Adjust effect scale (0.5x to 3.0x)
- **[ / ]** - Adjust AOE radius (50px to 500px)
- **R** - Randomize color

### Testing
- **A** - Toggle auto-fire (spawns current method every 1 second)
- **SPACE** - Stress test (spawn 100 random effects)
- **C** - Clear all active effects

### Debug Info
The window title shows real-time stats:
- FPS
- Active effect count
- Current scale
- Current AOE radius
- Auto-fire status

## 📁 File Structure

```
tests/visual_effects/
├── EffectsPOC.tscn          # Main test scene
├── EffectsPOC.gd            # Test harness script
├── README.md                # This file
├── effects/
│   ├── MethodA_SpriteShader.tscn          # Sprite + shader (projectile)
│   ├── MethodA_SpriteShader_AOE.tscn      # Sprite + shader (AOE)
│   ├── MethodA_SpriteShader.gd            # Shared script for Method A
│   ├── MethodB_GPUParticles.tscn          # GPU particles (projectile)
│   ├── MethodB_GPUParticles_AOE.tscn      # GPU particles (AOE)
│   ├── MethodB_GPUParticles.gd            # Shared script for Method B
│   ├── MethodC_Line2D.tscn                # Line2D circle (AOE only)
│   └── MethodC_Line2D.gd                  # Script for Method C
└── shaders/                  # Future: custom shaders for Method A
```

## 🎨 Visual Effect Methods

### Method A: Sprite2D + Shader
- **Pros**: Excellent visual quality with shaders, perfect scalability
- **Use case**: Projectiles with glow effects, AOE circles with custom shaders
- **Current state**: Basic sprite with tween fade (shader to be added)

### Method B: GPUParticles2D
- **Pros**: GPU-accelerated, great performance, smooth animations
- **Use case**: Particle trails, continuous auras, explosion effects
- **Current state**: Basic particle emission with color support

### Method C: Line2D
- **Pros**: Procedurally generated, perfect for geometric shapes
- **Use case**: AOE circles, geometric effects, range indicators
- **Current state**: Circle with configurable radius and line width

## 🔧 Customization

Each effect scene has a `configure(params: Dictionary)` method that accepts:
- `position` - Spawn position (Vector2)
- `scale` - Visual scale multiplier (float)
- `aoe_radius` - AOE radius in pixels (float)
- `color` - Effect color (Color)

## 🚀 Next Steps

1. **Add textures**: Assign proper textures to Sprite2D nodes (currently using icon.svg)
2. **Add shaders**: Create glow shaders for Method A in `shaders/` folder
3. **Test performance**: Use stress test to measure FPS with 100+ effects
4. **Document findings**: Record which method works best for each use case
5. **Refine visuals**: Tweak animations, colors, and effects based on testing

## 📝 Testing Workflow

1. **Visual Quality Test**:
   - Spawn each method (keys 1-5)
   - Compare visual appearance
   - Test color changes (R key)

2. **Scalability Test**:
   - Set AOE to 150px (base)
   - Spawn effects, note size
   - Set AOE to 300px (2x)
   - Verify effects are 2x larger

3. **Performance Test**:
   - Press SPACE for 100 effects
   - Check FPS in window title
   - Clear (C) and test each method individually

4. **Auto-fire Test**:
   - Select method (1-5)
   - Press A to enable auto-fire
   - Watch effects spawn every second
   - Useful for continuous visual feedback while adjusting parameters
