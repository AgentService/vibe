# Event Scenes

This directory contains scene-based event visuals that can be edited in the Godot editor.

## BreachIndicator.tscn

**Scene Structure:**
```
BreachIndicator (Node2D) [script: BreachIndicator.gd]
├── Particles (optional - add CPUParticles2D or GPUParticles2D)
└── AudioPlayer (optional - add AudioStreamPlayer2D)
```

**Setup Instructions:**
1. Create a new Scene in Godot
2. Add Node2D as root, rename to "BreachIndicator"
3. Attach script: `res://scripts/ui/BreachIndicator.gd`
4. Save as: `res://scenes/events/BreachIndicator.tscn`
5. Optionally add particle effects and sound for activation

**Editor Settings to Tweak:**
- **Visual Settings**: Adjust colors for waiting/expanding/shrinking phases
- **Animation Settings**: Modify pulse speed and expansion curves
- **Effects**: Enable/disable particles and sounds
- **Performance**: Adjust update frequency and draw complexity

The BreachIndicator script is designed to be editor-friendly with @export properties for easy tweaking without code changes.