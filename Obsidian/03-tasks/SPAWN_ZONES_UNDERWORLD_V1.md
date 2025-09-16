# SPAWN_ZONES_UNDERWORLD_V1: Restricted Auto-Spawn Implementation

Status: Phase 0 Ready → Implementation Started
Owner: Solo (Indie)
Priority: Medium
Type: Arena Enhancement
Dependencies: UnderworldArena, MapConfig, WaveDirector, MCP Integration
Risk: Low (builds on existing data-driven system)
Complexity: MVP=2/10, Full=5/10

---

## Background

The underworld arena currently has spawn zones defined in `underworld_config.tres` but the auto-spawn debug system ignores these zones and spawns enemies randomly around the arena. This task implements zone-restricted spawning so that when auto-spawn is enabled in the debug editor, bosses and enemies only spawn in the predefined spawn zones.

**Current State:**
- ✅ MapConfig.gd has spawn_zones Array[Dictionary] schema
- ✅ underworld_config.tres has 5 spawn zones defined (north_cavern, south_cavern, etc.)
- ✅ UnderworldArena.gd has get_spawn_zones() and get_weighted_spawn_zone() methods
- ❌ WaveDirector ignores spawn zones and uses simple radius spawning
- ❌ Debug auto-spawn doesn't respect zone restrictions

**Goal:** Make debug auto-spawn respect zone boundaries for immediate visual validation

---

## Goals & Acceptance Criteria

### Phase 0: Simple Zone-Restricted Auto-Spawn (Target: 2-3 hours)
- [ ] **Visual Zone Markers**: Add Area2D nodes to UnderworldArena.tscn using MCP for each spawn zone
- [ ] **Zone-Based Spawning**: Modify debug auto-spawn to only spawn within defined zones
- [ ] **Visual Validation**: See bosses spawning only in designated areas when using debug controls
- [ ] **Fallback Safety**: If no zones defined, fall back to current radius-based spawning

**Success Criteria:**
- Debug B key boss spawning only occurs within predefined spawn zones
- Visual Area2D markers show spawn zone boundaries in editor
- Zone selection uses weighted random selection from underworld_config.tres
- No enemies spawn outside designated areas during debug testing

### Phase 1: Enhanced Zone System (Future)
- [ ] Zone visualization during gameplay (debug mode)
- [ ] Zone-specific enemy types
- [ ] Time-based zone activation
- [ ] Zone exclusion areas (around player, hazards)

---

## Implementation Plan

### Step 1: Create Visual Zone Markers (30 minutes)
**Using MCP to add nodes directly in editor:**

1. **Open UnderworldArena scene via MCP**
   ```gdscript
   # MCP command to open scene
   open_scene("res://scenes/arena/UnderworldArena.tscn")
   ```

2. **Add SpawnZone parent node**
   ```gdscript
   # Add Node2D container for spawn zones
   add_node("Node2D", "SpawnZones", "UnderworldArena")
   ```

3. **Create Area2D nodes for each zone** (based on underworld_config.tres zones):
   ```gdscript
   # For each zone in underworld_config.tres:
   # - north_cavern: position Vector2(0, -400), radius 80
   # - south_cavern: position Vector2(0, 400), radius 80
   # - east_tunnel: position Vector2(400, 0), radius 60
   # - west_tunnel: position Vector2(-400, 0), radius 60
   # - center_pit: position Vector2(0, 0), radius 40

   add_node("Area2D", "SpawnZone_NorthCavern", "SpawnZones")
   add_node("CollisionShape2D", "CollisionShape2D", "SpawnZone_NorthCavern")
   # Set CircleShape2D with radius 80, position (0, -400)

   # Repeat for all 5 zones
   ```

4. **Configure collision shapes**
   - Use CircleShape2D for circular spawn areas
   - Set radius from config data
   - Position nodes at zone centers

**Files Modified:**
- `scenes/arena/UnderworldArena.tscn` (via MCP node creation)

### Step 2: Implement Zone-Based Spawning Logic (45 minutes)
**Create spawn zone manager system:**

1. **Add SpawnZoneManager to UnderworldArena.gd**
   ```gdscript
   # Add to UnderworldArena.gd
   @onready var spawn_zones_container: Node2D = $SpawnZones
   var _spawn_zone_areas: Array[Area2D] = []

   func _ready():
       super._ready()
       _initialize_spawn_zones()

   func _initialize_spawn_zones():
       # Cache Area2D nodes for efficient access
       for child in spawn_zones_container.get_children():
           if child is Area2D:
               _spawn_zone_areas.append(child)
   ```

2. **Override get_random_spawn_position in UnderworldArena.gd**
   ```gdscript
   ## Override to use spawn zones instead of simple radius
   func get_random_spawn_position() -> Vector2:
       if _spawn_zone_areas.is_empty():
           # Fallback to parent radius-based spawning
           return super.get_random_spawn_position()

       # Use weighted zone selection from MapConfig
       var selected_zone_data = get_weighted_spawn_zone()
       if selected_zone_data.is_empty():
           return super.get_random_spawn_position()

       # Generate random position within selected zone
       var zone_pos = selected_zone_data.get("position", Vector2.ZERO)
       var zone_radius = selected_zone_data.get("radius", 50.0)

       var angle = randf() * TAU
       var distance = randf() * zone_radius
       return zone_pos + Vector2(cos(angle), sin(angle)) * distance
   ```

**Files Modified:**
- `scripts/arena/UnderworldArena.gd`

### Step 3: Enhance MapConfig Zone Selection (30 minutes)
**Improve weighted zone selection:**

1. **Add get_weighted_spawn_zone implementation to MapConfig.gd**
   ```gdscript
   ## Get random spawn zone using weighted selection
   func get_weighted_spawn_zone() -> Dictionary:
       if spawn_zones.is_empty():
           return {}

       # Calculate total weight
       var total_weight = 0.0
       for zone in spawn_zones:
           total_weight += zone.get("weight", 1.0)

       # Select random zone by weight
       var random_value = randf() * total_weight
       var current_weight = 0.0

       for zone in spawn_zones:
           current_weight += zone.get("weight", 1.0)
           if random_value <= current_weight:
               return zone

       # Fallback to first zone
       return spawn_zones[0]
   ```

2. **Add zone validation methods**
   ```gdscript
   ## Validate that spawn zones are within arena bounds
   func validate_spawn_zones() -> bool:
       for zone in spawn_zones:
           var pos = zone.get("position", Vector2.ZERO)
           var radius = zone.get("radius", 0.0)

           # Check if zone is completely within arena bounds
           if pos.length() + radius > arena_bounds_radius:
               Logger.warn("Spawn zone %s extends beyond arena bounds" % zone.get("name", "unnamed"))
               return false
       return true
   ```

**Files Modified:**
- `scripts/resources/MapConfig.gd`

### Step 4: Debug Visualization (30 minutes)
**Add debug drawing for spawn zones:**

1. **Add debug visualization to UnderworldArena.gd**
   ```gdscript
   var _debug_draw_zones: bool = false

   func _ready():
       super._ready()
       # Enable debug drawing if debug config enabled
       if DebugConfig and DebugConfig.debug_panels_enabled:
           _debug_draw_zones = true

   func _draw():
       if not _debug_draw_zones:
           return

       # Draw spawn zone circles
       for zone_data in get_spawn_zones():
           var pos = zone_data.get("position", Vector2.ZERO)
           var radius = zone_data.get("radius", 50.0)
           var weight = zone_data.get("weight", 1.0)

           # Color intensity based on weight
           var color = Color.YELLOW
           color.a = 0.3 + (weight * 0.4)  # Higher weight = more opaque

           draw_circle(pos, radius, color)
           draw_arc(pos, radius, 0, TAU, 32, Color.WHITE, 2.0)
   ```

**Files Modified:**
- `scripts/arena/UnderworldArena.gd`

### Step 5: Integration Testing (15 minutes)
**Validate the system works:**

1. **Test zone-based spawning**
   - Open UnderworldArena in editor
   - Enable debug auto-spawn (B key)
   - Verify bosses only spawn within visible Area2D zones
   - Test weighted selection (center_pit should spawn less frequently)

2. **Test fallback behavior**
   - Temporarily remove spawn_zones from config
   - Verify system falls back to radius-based spawning
   - Restore spawn_zones configuration

**Validation Steps:**
- [ ] Visual zone markers visible in editor
- [ ] Debug spawning respects zone boundaries
- [ ] Weighted selection working (different spawn frequencies)
- [ ] Fallback works when no zones defined
- [ ] No enemies spawn outside designated areas

---

## Commit Strategy (Small Loops)

### Commit 1: Visual Zone Setup
```bash
git add scenes/arena/UnderworldArena.tscn
git commit -m "feat(spawn): add visual Area2D markers for spawn zones in UnderworldArena

- Added SpawnZones container with 5 Area2D nodes
- Each zone matches underworld_config.tres positions/radii
- Visual markers for: north_cavern, south_cavern, east_tunnel, west_tunnel, center_pit
- Provides editor visualization of spawn boundaries

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Commit 2: Zone-Based Spawning Logic
```bash
git add scripts/arena/UnderworldArena.gd
git commit -m "feat(spawn): implement zone-based spawning in UnderworldArena

- Override get_random_spawn_position() to use MapConfig spawn zones
- Add _initialize_spawn_zones() to cache Area2D references
- Weighted zone selection from underworld_config.tres
- Fallback to radius spawning if no zones defined
- Debug auto-spawn now respects zone boundaries

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Commit 3: Enhanced MapConfig Zone Selection
```bash
git add scripts/resources/MapConfig.gd
git commit -m "feat(spawn): add weighted zone selection to MapConfig

- Implement get_weighted_spawn_zone() with proper weight distribution
- Add validate_spawn_zones() for arena bounds checking
- Deterministic zone selection using weight probabilities
- Support for fallback when spawn_zones empty

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Commit 4: Debug Visualization
```bash
git add scripts/arena/UnderworldArena.gd
git commit -m "feat(spawn): add debug visualization for spawn zones

- Draw spawn zone circles with weight-based opacity
- Visual feedback for zone boundaries during development
- Conditional rendering based on DebugConfig.debug_panels_enabled
- Color-coded zones (higher weight = more opaque)

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## MCP Workflow Commands

### Scene Setup Commands
```gdscript
# Open the underworld arena scene
open_scene("res://scenes/arena/UnderworldArena.tscn")

# Add container for spawn zones
add_node("Node2D", "SpawnZones", "UnderworldArena")

# Add spawn zone areas (repeat for each zone)
add_node("Area2D", "SpawnZone_NorthCavern", "SpawnZones")
add_node("CollisionShape2D", "CollisionShape2D", "SpawnZone_NorthCavern")

# Set properties via MCP
update_property("SpawnZone_NorthCavern", "position", "Vector2(0, -400)")
update_property("SpawnZone_NorthCavern/CollisionShape2D", "shape", "CircleShape2D")
# Set CircleShape2D radius to 80
```

### Testing Commands
```gdscript
# Play scene to test spawning
play_scene("res://scenes/arena/UnderworldArena.tscn")

# Get visual feedback on running scene
get_running_scene_screenshot()

# Stop testing
stop_running_scene()
```

---

## File Touch List

### New Files
- None (using existing architecture)

### Modified Files
**Scene Files:**
- `scenes/arena/UnderworldArena.tscn` - Add visual spawn zone markers

**Script Files:**
- `scripts/arena/UnderworldArena.gd` - Zone-based spawning logic + debug visualization
- `scripts/resources/MapConfig.gd` - Enhanced zone selection methods

**Data Files:**
- `data/content/maps/underworld_config.tres` - Already configured, no changes needed

### Documentation
- Update `CHANGELOG.md` with spawn zone implementation summary
- Note Obsidian documentation update if architecture changes significantly

---

## Success Metrics

### Functionality
- [ ] Debug B key spawning only occurs within defined zones
- [ ] Visual zone markers show boundaries in editor
- [ ] Weighted selection works (center_pit spawns less than caverns)
- [ ] Fallback to radius spawning when no zones defined

### Performance
- [ ] No noticeable performance impact during spawning
- [ ] Zone caching eliminates repeated node lookups
- [ ] Debug visualization can be toggled off for release builds

### Integration
- [ ] Compatible with existing debug controls
- [ ] Works with current MapConfig data structure
- [ ] No breaking changes to existing spawning system
- [ ] Visual markers don't interfere with gameplay

---

## Timeline & Effort

**Total Effort:** ~2.5 hours

- **Step 1 (Visual Setup):** 30 minutes via MCP
- **Step 2 (Spawning Logic):** 45 minutes
- **Step 3 (Zone Selection):** 30 minutes
- **Step 4 (Debug Viz):** 30 minutes
- **Step 5 (Testing):** 15 minutes

**Immediate Value:**
- Visual validation of spawn zones in editor
- Restricted spawning during debug testing
- Foundation for advanced spawn system features

**Future Expansion:**
- Phase 1: Zone-specific enemy types
- Phase 2: Time-based zone activation
- Phase 3: Integration with full SpawnDirector system