# Layered Equipment Animation Guide - Godot AnimatedSprite2D Setup

**Status:** 📋 Reference Guide  
**Priority:** Medium  
**Category:** Character System Implementation  

## Overview
This guide explains how to set up layered equipment animations using multiple AnimatedSprite2D nodes in Godot, based on the Raven Fantasy character system implementation.

## Scene Structure

### **Node Hierarchy**
```
PlayerRanger (CharacterBody2D)
├── BaseLayer (AnimatedSprite2D) - Z Index: 0
├── PantsLayer (AnimatedSprite2D) - Z Index: 1  
├── ClothingLayer (AnimatedSprite2D) - Z Index: 2
├── AccessoriesLayer (AnimatedSprite2D) - Z Index: 3
├── WeaponsLayer (AnimatedSprite2D) - Z Index: 4
├── HairLayer (AnimatedSprite2D) - Z Index: 5
├── CollisionShape2D
└── PointLight2D
```

### **Z-Index Layer Order** (Bottom to Top)
Based on Raven Fantasy documentation:
1. **Shield Back** (Z: -1) - Shield behind character
2. **Skin/Base** (Z: 0) - Naked character base
3. **Pants** (Z: 1) - Bottom clothing
4. **Clothing** (Z: 2) - Shirts, armor, torso items
5. **Accessories** (Z: 3) - Belts, pouches, decorative items
6. **Magic/Tools/Weapons** (Z: 4) - Held items, swords, bows
7. **Hair** (Z: 5) - Hair styles, head accessories
8. **Shield Above** (Z: 6) - Shield parts above character

## SpriteFrames Resource Requirements

### **Animation Name Consistency**
All layers MUST have the same animation names:
```
Required Animations:
- idle_down, idle_left, idle_right, idle_up
- walk_down, walk_left, walk_right, walk_up  
- run_down, run_left, run_right, run_up
- attack_down, attack_left, attack_right, attack_up
- bow_down, bow_left, bow_right, bow_up (for rangers)
```

### **Frame Count Matching**
Each animation across all layers must have:
- **Same number of frames** (usually 4 frames per animation)
- **Same frame timing/speed** (e.g., 8.0 fps for walk, 5.0 fps for idle)
- **Same loop settings** (typically true for movement animations)

### **Handling Missing Equipment**
For animations where equipment doesn't change appearance:
- **Option 1:** Create transparent 48x48 frames
- **Option 2:** Use fallback system (implemented in Player script)
- **Option 3:** Duplicate frames from similar animations

## Asset Extraction Workflow

### **Step 1: Base Character Setup**
1. **Extract base character** from `Full.png` (Raven Fantasy)
2. **Use 48x48 grid** for precise frame extraction
3. **Create SpriteFrames resource** with all required animations
4. **Test base character** independently before adding layers

### **Step 2: Equipment Layer Creation**
For each equipment piece (e.g., Brown Pants from Adventurer Set):

#### **Method A: Manual Extraction (Recommended)**
1. **Open equipment PNG** in image editor (GIMP, Photoshop)
2. **Set grid to 48x48 pixels**
3. **Extract each frame** matching base character animation layout
4. **Save as individual PNG files**:
   ```
   pants_walk_down_1.png
   pants_walk_down_2.png
   pants_walk_down_3.png
   pants_walk_down_4.png
   ```
5. **Import into Godot SpriteFrames** resource
6. **Match animation names** exactly with base character

#### **Method B: Script-Based Extraction**
Use the `extract_raven_precise.gd` script with custom coordinates for each equipment piece.

### **Step 3: Layer Synchronization**
1. **Make each layer's SpriteFrames unique** (Inspector > "Make Unique")
2. **Verify animation names match** across all layers
3. **Test in-game** - all layers should animate together

## Player Script Integration

### **Current Implementation**
The Player script automatically detects and synchronizes equipment layers:

```gdscript
# Equipment layers detected automatically in _ready()
@onready var equipment_layers: Array[AnimatedSprite2D] = []

# All layers synchronized in _play_animation()
func _play_animation(anim_name: String):
    animated_sprite.play(anim_name)  # Base layer
    for layer in equipment_layers:
        if layer.sprite_frames.has_animation(anim_name):
            layer.play(anim_name)
        else:
            # Fallback to similar animation
            var fallback = _find_fallback_animation(layer.sprite_frames, anim_name)
            layer.play(fallback)
```

### **Requirements for New Equipment**
- **AnimatedSprite2D nodes** as children of Player/PlayerRanger
- **Unique SpriteFrames resources** (not shared references)
- **Consistent animation naming** with base character

## Common Issues and Solutions

### **Issue 1: Border Artifacts in Frame Extraction**
**Problem:** SpriteFrames grid extraction includes neighboring pixels
**Solutions:**
- Use manual frame extraction with precise selection
- Add 1-2 pixel padding between atlas frames
- Use script-based extraction with exact coordinates

### **Issue 2: Layers Not Synchronizing**
**Problem:** Equipment layer not animating with base character
**Debugging:**
1. Check if layer has matching animation names
2. Verify SpriteFrames resource is unique (not shared)
3. Ensure Player script detects the layer (check logs)
4. Confirm animation has frames and proper settings

### **Issue 3: Animation Timing Mismatch**
**Problem:** Layers animate at different speeds
**Solution:** Ensure all layers have identical:
- Frame per second (fps) settings
- Loop settings
- Frame counts per animation

### **Issue 4: Z-Index Display Order**
**Problem:** Equipment renders in wrong order (e.g., pants over shirt)
**Solution:** Set proper Z-Index values in Inspector:
```
Base: 0, Pants: 1, Clothing: 2, etc.
```

## Performance Considerations

### **Optimization Tips**
- **Limit layer count** - Only add layers actually used
- **Share common animations** - Use same SpriteFrames for similar equipment
- **Pool equipment changes** - Don't create new resources at runtime
- **Use MultiMeshInstance2D** for enemies with equipment (future)

### **Memory Usage**
Each equipment layer adds:
- ~1MB per SpriteFrames resource (depends on animation count)
- Minimal runtime overhead per AnimatedSprite2D node
- CPU cost scales with number of active layers

## Testing Checklist

### **Visual Testing**
- [ ] All layers render in correct Z-order
- [ ] No visual artifacts or misalignment between layers
- [ ] Smooth animation transitions across all layers
- [ ] Equipment appears/disappears correctly when changed

### **Performance Testing**
- [ ] Frame rate stable with multiple equipment layers
- [ ] Memory usage reasonable during equipment changes
- [ ] No animation stuttering or lag

### **Integration Testing**
- [ ] Character selection spawns correct character with equipment
- [ ] Equipment persists across scene transitions
- [ ] Save/load preserves equipment state
- [ ] Hot-reload (F5) works with equipment changes

## Equipment Database Structure

### **Future Implementation**
```gdscript
# EquipmentItem.gd
extends Resource
class_name EquipmentItem

@export var id: StringName
@export var display_name: String
@export var slot_type: String  # "pants", "clothing", "weapons", etc.
@export var sprite_frames: SpriteFrames
@export var layer_index: int  # Z-order for rendering
```

### **Equipment Slot Management**
```gdscript
# Character equipment state
var equipped_items: Dictionary = {
    "pants": null,
    "clothing": null, 
    "weapons": null,
    "accessories": null
}

func equip_item(item: EquipmentItem):
    equipped_items[item.slot_type] = item
    _update_layer_sprite_frames(item.slot_type, item.sprite_frames)
```

## Example Equipment Items

### **From Raven Fantasy Adventurer Set**
- **Pants Layer**: Brown Pants, Jeans Pants
- **Clothing Layer**: Blue Shirt, Green Shirt  
- **Accessories Layer**: Adventurer Cape, Adventurer Cape 2
- **Hands Layer**: Leather Gloves, Leather Gloves 2
- **Feet Layer**: Leather Boots, Leather Boots 2
- **Hair Layer**: Hero Hair, Hero Hair 2

Each item should have matching animation sets with the base character.

## Troubleshooting

### **Animation Not Playing on Equipment Layer**
1. **Check animation names** - must match base character exactly
2. **Verify SpriteFrames resource** - ensure it's unique, not shared
3. **Confirm layer detection** - check Player script logs for layer count
4. **Test individual layer** - play animation manually in Inspector

### **Equipment Appears in Wrong Position**
1. **Check Z-Index ordering** - higher numbers render on top
2. **Verify frame alignment** - equipment frames must align with base character
3. **Confirm 48x48 grid** - all frames must use same pixel dimensions
4. **Test AnimatedSprite2D scale** - should match base character scaling

## Future Enhancements

### **Advanced Features**
- **Equipment preview system** - Character select screen equipment display
- **Real-time equipment swapping** - Hot-swap equipment without scene reload  
- **Equipment stats integration** - Visual changes affect gameplay stats
- **Multiple character class support** - Equipment works across Knight/Ranger/Mage
- **Procedural equipment** - Randomized equipment combinations
- **Equipment colors/variants** - Shader-based equipment recoloring

This guide provides the foundation for implementing a robust layered equipment system that scales with your character system growth.