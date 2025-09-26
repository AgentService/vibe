# Themed Decoration System Guide

## Overview
The forest plugin now uses a sophisticated themed decoration system that groups decorations by color/theme and provides fine-tuned control over spawn rates, clustering behavior, and environmental preferences.

## Theme Configuration

### 🌿 **Green Vegetation Theme**
- **Tiles:** Vector2i(9,0), Vector2i(12,0), Vector2i(15,0)
- **Weight:** 3.0 (most common)
- **Rarity:** 1.2x (20% bonus)
- **Clustering:** High (80% chance, radius 4, max 5 per cluster)
- **Behavior:** Spreads throughout arena, avoids boundaries

### 🌲 **Tall Trees Theme**
- **Tiles:** Vector2i(18,0), Vector2i(21,0)
- **Weight:** 1.5 (moderate)
- **Rarity:** 0.8x (20% reduction)
- **Clustering:** Moderate (60% chance, radius 6, max 3 per cluster)
- **Behavior:** Prefers center areas, needs more spacing

### 🪨 **Grey Rocks Theme**
- **Tiles:** Vector2i(24,0), Vector2i(27,0)
- **Weight:** 2.0 (common)
- **Rarity:** 1.0x (normal)
- **Clustering:** High (90% chance, radius 5, max 4 per cluster)
- **Behavior:** Prefers edges, forms rock formations

### 🟠 **Orange Resources Theme**
- **Tiles:** Vector2i(30,0)
- **Weight:** 0.5 (rare)
- **Rarity:** 0.3x (70% reduction - very rare!)
- **Clustering:** Low (30% chance, radius 3, max 2 per cluster)
- **Behavior:** Scattered individually, high spacing requirements

## Spawn Probability Calculation

**Final spawn chance for each theme:**
- Green Vegetation: 3.0 × 1.2 = **3.6 weight** (~50% of decorations)
- Grey Rocks: 2.0 × 1.0 = **2.0 weight** (~28% of decorations)
- Tall Trees: 1.5 × 0.8 = **1.2 weight** (~17% of decorations)
- Orange Resources: 0.5 × 0.3 = **0.15 weight** (~2% of decorations)

## Clustering Behavior

### **High Clustering Themes** (Rocks, Vegetation)
- Form natural groups of 3-5 decorations
- 80-90% chance to spawn near same theme
- Creates realistic resource patches

### **Moderate Clustering Themes** (Tall Trees)
- Form small groves of 2-3 trees
- 60% chance to cluster together
- Requires more spacing between clusters

### **Low Clustering Themes** (Orange Resources)
- Mostly spawn individually
- 30% chance to form pairs
- Rare and scattered distribution

## Environmental Preferences

- **Edge Preference:** Grey Rocks (prefer arena edges)
- **Center Preference:** Tall Trees (prefer central areas)
- **Neutral:** Green Vegetation, Orange Resources (spawn anywhere)
- **Boundary Avoidance:** All themes avoid tree boundaries (2-5 tile buffer)

## Configuration Files

### Theme Definitions
- `GreenVegetationTheme.tres` - Common vegetation clusters
- `TallTreesTheme.tres` - Large tree decorations
- `GreyRocksTheme.tres` - Stone formations
- `OrangeResourcesTheme.tres` - Rare resources

### Integration
- `ForestBiome.tres` - Links all themes together
- `ProceduralArenaGenerator.gd` - Uses themed system for generation
- `BiomeConfig.gd` - Provides weighted selection and clustering logic

## Tuning Guide

### **Make Theme More Common:**
- Increase `spawn_weight` (1.0 → 2.0)
- Increase `rarity_modifier` (1.0 → 1.5)

### **Make Theme Cluster More:**
- Increase `cluster_chance` (0.7 → 0.9)
- Increase `max_cluster_size` (3 → 5)
- Decrease `cluster_decay` (0.6 → 0.4)

### **Change Distribution:**
- Set `prefer_edges = true` for edge spawning
- Set `prefer_center = true` for center spawning
- Adjust `boundary_buffer` for spacing from trees

### **Spacing Control:**
- Increase `min_spacing` / `max_spacing` for more spread
- Decrease for denser placement

The system automatically handles weighted selection, clustering logic, environmental preferences, and ensures decorations don't conflict with tree boundaries!