# Content Database (ContentDB)

This directory contains all **game content definitions** - the things you add to the game.

## Philosophy: ContentDB vs BalanceDB

- **ContentDB** (`/data/content/`) - **Things you add**: Enemy types, abilities, items, heroes, maps
- **BalanceDB** (`/data/balance/`) - **Numbers you tweak**: Damage multipliers, spawn rates, cooldowns

## Directory Structure

### Implemented
- `enemies/` - Enemy type definitions using .tres resources (✅ migrated from JSON)

### Future Content Types
- `abilities/` - Skill and ability definitions (will use .tres)
- `items/` - Equipment and loot definitions (will use .tres)
- `heroes/` - Player class and hero definitions (will use .tres)
- `maps/` - Level and arena layout definitions (will use .tres)

## How ContentDB Works

1. **Hot-Reload**: Automatic resource reload when .tres files change
2. **Type Safety**: Godot's inspector validates property types and ranges
3. **Validation**: Runtime validation for business logic rules
4. **Fallbacks**: Invalid content falls back to safe defaults
5. **Visual Editing**: Edit content in Godot Inspector or text editor

## Adding New Content Types

When adding a new content type:
1. **Create Resource class** - Extend Resource with @export properties
2. **Create .tres files** - Save resources in appropriate content directory
3. **Add loading logic** - Update or create system to load .tres files
4. **Document schema** - Update README with property descriptions
5. **Add validation** - Implement business logic validation if needed

## Content Format: .tres Resources

ContentDB uses Godot's native Resource system (.tres files) providing:
- **Type safety** through @export annotations
- **Visual editing** in Godot Inspector  
- **Automatic hot-reload** when files change
- **Version control friendly** text format
- **Performance** optimized loading and memory usage

## Related Systems

- **EnemyRegistry**: Handles enemy .tres loading (✅ implemented)
- **BalanceDB Autoload**: Handles gameplay tunables (.json format)
- **Future Systems**: AbilitySystem, ItemSystem, etc. will load .tres content

---

**Status**: ✅ Enemy system fully migrated to .tres format
**Next**: Apply .tres pattern to abilities, items, and heroes when implemented