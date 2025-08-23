# Content Database (ContentDB)

This directory contains all **game content definitions** - the things you add to the game.

## Philosophy: ContentDB vs BalanceDB

- **ContentDB** (`/data/content/`) - **Things you add**: Enemy types, abilities, items, heroes, maps
- **BalanceDB** (`/data/balance/`) - **Numbers you tweak**: Damage multipliers, spawn rates, cooldowns

## Directory Structure

### Implemented
- `enemies/` - Enemy type definitions (moved from `/data/enemies/`)

### Future Content Types
- `abilities/` - Skill and ability definitions
- `items/` - Equipment and loot definitions  
- `heroes/` - Player class and hero definitions
- `maps/` - Level and arena layout definitions

## How ContentDB Works

1. **Hot-Reload**: Press F5 to reload content changes
2. **Validation**: Schema validation prevents broken JSON
3. **Fallbacks**: Invalid content falls back to safe defaults
4. **Unified Loading**: Same patterns for all content types

## Adding New Content Types

When adding a new content type:
1. Create schema in `/data/schemas/`
2. Add loading logic to ContentDB autoload
3. Document in this README
4. Add validation and fallback rules

## Related Systems

- **ContentDB Autoload**: Loads and manages all content
- **BalanceDB Autoload**: Handles gameplay tunables
- **EnemyRegistry**: Currently handles enemy loading (will move to ContentDB)

---

**Status**: Directory structure established, ContentDB implementation pending