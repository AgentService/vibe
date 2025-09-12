# Implement Raven Fantasy Layered Equipment System

**Status:** 🔴 Blocked (Requires base character implementation)  
**Priority:** High  
**Estimated Time:** 4-6 hours  
**Dependencies:** `implement-raven-base-character.md` must be completed first  

## Objective
Implement the complete layered character customization system using Raven Fantasy Adventurer Set, enabling visual equipment representation for PoE-style buildcraft mechanics.

## Asset Location
```
C:\App\GodotGame\assets\sprites\Raven Fantasy - Pixelart Top Down Character - Adventurer Set\
└── Raven Fantasy - Pixelart Top Down Character - Adventurer Set\
    └── Extras\
        ├── Adventurer Cape.png / Adventurer Cape 2.png
        ├── Blue Shirt.png / Green Shirt.png
        ├── Brown Pants.png / Jeans Pants.png
        ├── Leather Boots.png / Leather Boots 2.png
        ├── Leather Gloves.png / Leather Gloves 2.png
        └── Hero Hair.png / Hero Hair 2.png
```

## Technical Specifications (from Official Instructions)
- **Grid System:** 48x48 pixels (80px for spear weapons)
- **Layer Order (Top to Bottom):**
  1. Above Shield
  2. Hair
  3. Weapons
  4. Magic and Tools
  5. Accessories (Capes, Gloves, Boots)
  6. Clothing (Shirts, Armor)
  7. Pants
  8. Skin (Base character)
  9. Shield Back

## Implementation Strategy

### Phase 1: Layer System Architecture
- [ ] Design multi-node character structure:
  ```gdscript
  Player (CharacterBody2D)
  ├── LayeredCharacter (Node2D)
  │   ├── ShieldBack (AnimatedSprite2D)      # Layer 9
  │   ├── SkinBase (AnimatedSprite2D)        # Layer 8
  │   ├── Pants (AnimatedSprite2D)           # Layer 7
  │   ├── Clothing (AnimatedSprite2D)        # Layer 6
  │   ├── Accessories (AnimatedSprite2D)     # Layer 5
  │   ├── MagicTools (AnimatedSprite2D)      # Layer 4
  │   ├── Weapons (AnimatedSprite2D)         # Layer 3
  │   ├── Hair (AnimatedSprite2D)            # Layer 2
  │   └── ShieldAbove (AnimatedSprite2D)     # Layer 1
  └── CollisionShape2D
  ```

### Phase 2: Asset Processing
- [ ] Extract clothing layers from 48x48 grid:
  - Hair variants (Hero Hair, Hero Hair 2)
  - Clothing (Blue Shirt, Green Shirt)
  - Pants (Brown Pants, Jeans Pants)
  - Accessories (Leather Gloves, Boots, Capes)
- [ ] Create SpriteFrames resources for each clothing piece
- [ ] Ensure all clothing animations match base character frame count
- [ ] Handle transparent regions properly for layering

### Phase 3: Animation Synchronization System
- [ ] Create `LayeredCharacterController` script:
  ```gdscript
  class_name LayeredCharacterController
  extends Node2D
  
  # Synchronize all layer animations
  func play_animation(anim_name: String, direction: String)
  func set_equipment_layer(layer_type: EquipmentLayer, sprite_frames: SpriteFrames)
  func clear_equipment_layer(layer_type: EquipmentLayer)
  ```
- [ ] Implement frame synchronization across all layers
- [ ] Handle animation speed and loop consistency
- [ ] Optimize performance with selective layer updates

### Phase 4: Equipment Integration System
- [ ] Create equipment type enum:
  ```gdscript
  enum EquipmentLayer {
      HAIR,
      SHIRT,
      PANTS, 
      GLOVES,
      BOOTS,
      CAPE,
      WEAPON,
      SHIELD
  }
  ```
- [ ] Design equipment data resources in `/data/content/equipment/`
- [ ] Connect equipment system to item/affix mechanics
- [ ] Implement equipment change notifications via EventBus

### Phase 5: Character Customization API
- [ ] Create character appearance configuration:
  ```gdscript
  class_name CharacterAppearance
  extends Resource
  
  @export var skin_type: int = 1
  @export var hair_style: int = 0
  @export var equipment_layers: Dictionary = {}
  ```
- [ ] Implement appearance save/load system
- [ ] Create character customization interface (future UI task)
- [ ] Hot-reload support for appearance changes

### Phase 6: Game Integration
- [ ] Update Player.gd to use LayeredCharacterController
- [ ] Connect to existing combat system for weapon animations
- [ ] Integrate with inventory system for visual updates
- [ ] Test with ability system for magic effect layering

## Testing Requirements

### Visual Testing
- [ ] All clothing combinations render correctly
- [ ] Layer ordering maintains proper depth
- [ ] Animation synchronization across all layers
- [ ] Transparent regions handle properly

### Performance Testing
- [ ] Frame rate impact with full clothing layers
- [ ] Memory usage with multiple SpriteFrames loaded
- [ ] Combat system maintains 30Hz with layered rendering

### System Integration Testing
- [ ] Equipment changes update visual layers
- [ ] Save/load preserves character appearance
- [ ] Hot-reload works with layered system

## Success Criteria
- [ ] Complete visual customization system functional
- [ ] Equipment visually represented on character
- [ ] No performance regression from base character
- [ ] Proper integration with existing item/equipment systems
- [ ] Foundation for future equipment expansion

## Architecture Impact
- **Equipment System:** Visual representation of all equipped items
- **Character Progression:** Visual feedback for gear upgrades
- **Buildcraft Support:** Different equipment combinations create distinct visual looks
- **Performance:** Efficient layered rendering system

## Files to Create/Modify
- `/scripts/systems/character/LayeredCharacterController.gd`
- `/data/content/equipment/` resource definitions
- `/scenes/arena/Player.tscn` (update to layered system)
- SpriteFrames resources for each equipment piece

## Future Extensions
- Additional clothing sets from other Raven Fantasy packs
- Procedural color variations for equipment
- Animation blending for complex equipment interactions
- Equipment particle effects integration

## Notes
- Start with basic clothing layers (shirt, pants, hair)
- Defer complex weapon/shield interactions until layer system stable
- Consider memory optimization for large numbers of equipment variations
- Document layer system for future equipment additions