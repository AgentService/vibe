# Underworld Arena Setup Guide

This guide walks you through setting up your new Raven Fantasy underworld tileset and creating the UnderworldArena scene.

## Phase 1: Import Underworld Tileset (5-10 mins)

### 1.1 Import Tileset Assets
1. **Import your Raven Fantasy underworld tileset** into `res://assets/tilesets/underworld/`
2. **Set import settings** for each texture:
   - Filter: `Off` (for pixel-perfect look)
   - Mipmaps: `Off` 
3. **Click "Reimport"** to apply settings

### 1.2 Create TileSet Resource
1. **Create new TileSet resource**: Right-click in FileSystem → New Resource → TileSet
2. **Save as**: `res://data/content/maps/tilesets/underworld_tileset.tres`
3. **Open TileSet in bottom panel** and configure:

### 1.3 Configure Tile Physics
Follow the existing map convention from `/data/content/maps/README.md`:

**Physics Layers:**
- **Layer 0**: Walls/Solid Collision
- **Layer 1**: Hazards/Special Areas (optional)

**Tile Setup:**
- **Floor tiles**: No collision (visual only)
- **Wall tiles**: Add collision shapes on Layer 0
- **Lava/Hazard tiles**: Add collision on Layer 1 (future environmental damage)

## Phase 2: Create UnderworldArena Scene (15-20 mins)

### 2.1 Create Scene Structure
1. **New Scene** → 2D Scene
2. **Rename root node** to `UnderworldArena`
3. **Attach script**: `res://scripts/arena/UnderworldArena.gd` (already created)
4. **Save as**: `res://scenes/arena/UnderworldArena.tscn`

### 2.2 Add Required Child Nodes
Add these children to UnderworldArena (follow existing Arena.tscn structure):

```
UnderworldArena (Node2D) - UnderworldArena.gd script
├── MM_Projectiles (MultiMeshInstance2D)
├── MM_Enemies_Swarm (MultiMeshInstance2D) 
├── MM_Enemies_Regular (MultiMeshInstance2D)
├── MM_Enemies_Elite (MultiMeshInstance2D)
├── MM_Enemies_Boss (MultiMeshInstance2D)
├── MeleeEffects (Node2D)
│   └── MeleeCone (Polygon2D) - visible = false
├── Ground (TileMapLayer) - z_index = 0
├── GroundDetails (TileMapLayer) - z_index = 0  
├── GroundObjects (TileMapLayer) - z_index = 1
├── PlayerSpawnPoint (Marker2D)
├── ArenaRoot (Node2D)
├── LightOccluder2D (LightOccluder2D)
├── CanvasModulate (CanvasModulate) - color = (0.8, 0.3, 0.2, 1)
├── FireParticles (GPUParticles2D) - optional underworld effects
└── DebugSystemControls (Node) - script: res://scripts/systems/debug/DebugSystemControls.gd
```

### 2.3 Configure TileMapLayers
1. **Ground layer**: Set TileSet to your `underworld_tileset.tres`
2. **Paint floor tiles** - create arena layout (circular/rectangular as preferred)
3. **GroundDetails layer**: Add decorative details, cracks, glow effects
4. **GroundObjects layer**: Add wall tiles with collision for arena boundaries

### 2.4 Setup Lighting for Underworld Theme
1. **CanvasModulate**: Set color to `(0.8, 0.3, 0.2, 1)` for reddish ambient
2. **Add PointLight2D nodes** around the arena:
   - Color: `(1.0, 0.4, 0.2, 1)` (orange-red fire glow)
   - Energy: `1.5-2.0`
   - Position: Near lava/fire areas

### 2.5 Position PlayerSpawnPoint
- Place **PlayerSpawnPoint** at arena center or preferred starting location
- This determines where the player spawns

### 2.6 Configure Arena Properties
In the Inspector for UnderworldArena root node:
1. **Map Config**: Assign `res://data/content/maps/underworld_config.tres`
2. **Arena ID**: `"underworld_arena"`
3. **Arena Name**: `"Underworld Arena"`
4. **Spawn Radius**: `500.0`
5. **Arena Bounds**: `600.0`

## Phase 3: Optional Visual Enhancements (5-10 mins)

### 3.1 Fire Particle Effects
1. **FireParticles (GPUParticles2D)**:
   - Process Material: New ParticleProcessMaterial
   - Texture: Fire/ember texture from your tileset
   - Configure emission for ambient fire particles

### 3.2 Additional Atmospheric Elements
- **Add more PointLight2D** for lava glow effects
- **LightOccluder2D**: Configure for dramatic shadows
- **AudioStreamPlayer2D**: Add ambient underworld sounds (future)

## Phase 4: Testing (5 mins)

### 4.1 Test Scene
1. **Run scene directly** (F6) to test basic functionality
2. **Check console** for any script errors
3. **Verify lighting** and visual appearance

### 4.2 Integration Test
1. **Modify** `res://scenes/arena/Arena.tscn` temporarily to test spawn
2. **Or add scene switching logic** in your main game flow

## File Structure Created

After following this guide, you'll have:

```
├── scripts/resources/MapConfig.gd                    ✅ (created)
├── scripts/arena/UnderworldArena.gd                  ✅ (created)  
├── data/content/maps/underworld_config.tres          ✅ (created)
├── data/content/maps/tilesets/underworld_tileset.tres    (manual)
└── scenes/arena/UnderworldArena.tscn                     (manual)
```

## Next Steps

Once your UnderworldArena is working:

1. **Create variations**: Copy scene and modify for different underworld layouts
2. **Add to progression**: Integrate with existing arena selection system
3. **Expand features**: Add environmental hazards, special spawn zones
4. **Future integration**: Ready for full Map/Arena Foundation when implemented

## Tips

- **Follow existing patterns**: Check `scenes/arena/Arena.tscn` for reference
- **Test frequently**: Run scene after each major step
- **Use debug tools**: Enable DebugSystemControls for testing
- **Performance**: Keep tile count reasonable for smooth gameplay

This foundation will serve you well for current needs and future expansion!