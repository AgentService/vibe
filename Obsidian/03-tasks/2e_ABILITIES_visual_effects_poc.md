# [SUBTASK] Ability System - Visual Effects POC (Proof of Concept)

**Parent Task:** `2_ABILITIES_system_implementation.md`
**Phase:** Between Phase 4 and Phase 6
**Status:** 📋 Not Started
**Estimated Time:** 3-4 hours
**Depends On:** Phase 3 (Ranger Arrow) complete
**Branch:** `visual-effects-poc` (separate from main ability development)

---

## 🎯 POC Goal

**Test 3 visual effect methods** for projectiles and AOE/aura attacks to determine which approaches meet scalability and performance requirements **BEFORE** implementing Phase 6 (Ability Library expansion).

**Critical Questions to Answer:**
1. Which method handles **AOE scaling** (items increase radius 50-200%)?
2. Which method handles **100+ simultaneous effects** at 60 FPS?
3. Which method supports **color/size customization** (Option 3 hybrid system)?

---

## 🔄 Why Separate Branch?

**Branch Strategy:**
```bash
# Create POC branch from current ability_system branch
git checkout ability_system
git checkout -b visual-effects-poc

# After testing, merge findings back (documentation only)
# Delete branch after decision made
```

**Rationale:**
- ✅ POC code is throwaway (test harness, not production)
- ✅ Findings documented in migration guide
- ✅ Keeps ability_system branch clean
- ✅ Easy to delete POC code after decision

---

## 📊 Methods to Test

Focus on **projectiles** and **AOE/aura** attacks only (no lightning, no ground trails yet).

### Method A: Sprite2D + Shader
- **Visual quality:** Excellent (glow, color shifting)
- **Scalability hypothesis:** Perfect (sprite.scale + shader parameters)
- **Performance hypothesis:** Very good (GPU shader execution)

### Method B: GPUParticles2D
- **Visual quality:** Excellent (smooth particle animation)
- **Scalability hypothesis:** Good (if emission shape scales)
- **Performance hypothesis:** Excellent (GPU-accelerated)

### Method C: Line2D (AOE only)
- **Visual quality:** Good (clean geometric look)
- **Scalability hypothesis:** Perfect (procedural generation)
- **Performance hypothesis:** Excellent (single draw call)

---

## ✅ Tasks

### Task 2e.1: Create POC Scene (~1 hour)

**Branch:**
```bash
git checkout ability_system
git checkout -b visual-effects-poc
```

**File:** `tests/visual_effects/EffectsPOC.tscn`

**Scene Structure:**
```
EffectsPOC.tscn
├─ Node2D (root)
├─ ColorRect (dark background, 1920×1080, color: #1a1a1a)
├─ Camera2D (centered, zoom: 1.0)
├─ TestPlayer (Sprite2D - white square 32×32)
├─ TestEnemyGrid (Node2D)
│  └─ 20× EnemySquare (positioned in 4×5 grid)
├─ ControlPanel (CanvasLayer)
│  └─ VBoxContainer
│     ├─ Label ("Effects POC - Press 1-3 for methods")
│     ├─ HSlider ("Scale: 0.5 - 3.0", value: 1.0)
│     ├─ HSlider ("AOE Radius: 50 - 500", value: 150)
│     ├─ ColorPickerButton ("Effect Color", color: WHITE)
│     ├─ Label ("FPS: 60", name: "FPSLabel")
│     ├─ Label ("Active Effects: 0", name: "EffectCountLabel")
│     └─ Button ("Spawn 100 Effects (Stress Test)")
└─ PerformanceMonitor (Script attached)
```

**Success Criteria:**
- [ ] Scene opens without errors
- [ ] Control panel visible
- [ ] TestPlayer and enemies visible
- [ ] Can adjust sliders

---

### Task 2e.2: Create Test Harness Script (~30 min)

**File:** `tests/visual_effects/EffectsPOC.gd`

**Requirements:**
- [ ] Attach script to EffectsPOC.tscn root node
- [ ] Implement keyboard controls:
  - `1` - Spawn Method A (Sprite2D + Shader) at mouse
  - `2` - Spawn Method B (GPUParticles2D) at mouse
  - `3` - Spawn Method C (Line2D) at mouse
  - `SPACE` - Spawn 100 random effects (stress test)
  - `C` - Clear all active effects
- [ ] Connect sliders to test parameters
- [ ] Track active effects in array
- [ ] Update FPS counter every 0.5s
- [ ] Color-code FPS (Green: >55, Yellow: 45-55, Red: <45)

**Code Template:**
```gdscript
extends Node2D

const MethodA = preload("res://tests/visual_effects/effects/MethodA_SpriteShader.tscn")
const MethodB = preload("res://tests/visual_effects/effects/MethodB_GPUParticles.tscn")
const MethodC = preload("res://tests/visual_effects/effects/MethodC_Line2D.tscn")

@onready var scale_slider: HSlider = $ControlPanel/VBoxContainer/ScaleSlider
@onready var aoe_slider: HSlider = $ControlPanel/VBoxContainer/AOESlider
@onready var color_picker: ColorPickerButton = $ControlPanel/VBoxContainer/ColorPicker
@onready var fps_label: Label = $ControlPanel/VBoxContainer/FPSLabel
@onready var effect_count_label: Label = $ControlPanel/VBoxContainer/EffectCountLabel

var active_effects: Array[Node] = []
var test_scale: float = 1.0
var test_aoe: float = 150.0
var test_color: Color = Color.WHITE

func _ready():
	print("=== Visual Effects POC ===")
	print("Press 1-3 to spawn effects at mouse position")
	print("Press SPACE for stress test (100 effects)")
	print("Press C to clear all effects")

	scale_slider.value_changed.connect(func(v): test_scale = v)
	aoe_slider.value_changed.connect(func(v): test_aoe = v)
	color_picker.color_changed.connect(func(c): test_color = c)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _spawn_effect(MethodA, "Sprite+Shader")
			KEY_2: _spawn_effect(MethodB, "GPUParticles")
			KEY_3: _spawn_effect(MethodC, "Line2D")
			KEY_SPACE: _stress_test()
			KEY_C: _clear_effects()

func _spawn_effect(scene: PackedScene, method_name: String):
	var effect = scene.instantiate()

	if effect.has_method("configure"):
		effect.configure({
			"position": get_global_mouse_position(),
			"scale": test_scale,
			"aoe_radius": test_aoe,
			"color": test_color,
		})
	else:
		effect.global_position = get_global_mouse_position()
		effect.scale = Vector2.ONE * test_scale
		effect.modulate = test_color

	add_child(effect)
	active_effects.append(effect)
	print("[%s] Spawned (scale: %.2f, AOE: %.0f)" % [method_name, test_scale, test_aoe])

func _stress_test():
	print("=== STRESS TEST: 100 effects ===")
	for i in 100:
		var method = [MethodA, MethodB, MethodC].pick_random()
		var method_name = ["Sprite+Shader", "GPUParticles", "Line2D"].pick_random()
		_spawn_effect(method, method_name)

func _clear_effects():
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()

func _process(_delta):
	# Clean up dead effects
	active_effects = active_effects.filter(func(e): return is_instance_valid(e))
	effect_count_label.text = "Active Effects: %d" % active_effects.size()

	# Update FPS
	var fps = Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	if fps >= 55:
		fps_label.modulate = Color.GREEN
	elif fps >= 45:
		fps_label.modulate = Color.YELLOW
	else:
		fps_label.modulate = Color.RED
```

**Success Criteria:**
- [ ] Press 1/2/3 spawns effects at mouse
- [ ] Effects use slider values (scale/AOE/color)
- [ ] FPS counter updates
- [ ] Stress test spawns 100 effects
- [ ] Clear removes all effects

---

### Task 2e.3: Implement Method A - Sprite2D + Shader (~45 min)

**File:** `tests/visual_effects/effects/MethodA_SpriteShader.tscn`

**Projectile Version:**
```
MethodA_SpriteShader.tscn (Projectile)
├─ Node2D (root, script: MethodA_SpriteShader.gd)
├─ Sprite2D
│  ├─ Texture: white_circle.png (64×64)
│  └─ Material: ShaderMaterial
│     └─ Shader: glow_shader.gdshader
└─ AnimationPlayer
   └─ Animation: "fade" (0.5s, auto-plays)
```

**AOE/Aura Version:**
```
MethodA_SpriteShader_AOE.tscn
├─ Node2D (root, script: MethodA_SpriteShader.gd)
├─ Sprite2D
│  ├─ Texture: white_ring.png (150×150)
│  └─ Material: ShaderMaterial
│     └─ Shader: glow_shader.gdshader
└─ AnimationPlayer
   └─ Animation: "pulse" (0.8s, loops)
```

**Shader:** `tests/visual_effects/shaders/glow_shader.gdshader`
```glsl
shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = tex;
	COLOR.rgb += glow_color.rgb * glow_intensity;
	COLOR.a *= fade_amount;
}
```

**Script:** `tests/visual_effects/effects/MethodA_SpriteShader.gd`
```gdscript
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

func configure(params: Dictionary):
	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Scale (visual + AOE)
	var scale_val = params.get("scale", 1.0)
	var aoe_radius = params.get("aoe_radius", 150.0)
	var aoe_scale = aoe_radius / 150.0  # Base radius: 150px
	sprite.scale = Vector2.ONE * scale_val * aoe_scale

	# Color
	var color = params.get("color", Color.WHITE)
	sprite.material.set_shader_parameter("glow_color", color)

	# Play animation
	anim.play("fade")
	anim.animation_finished.connect(queue_free)
```

**Success Criteria:**
- [ ] Spawns at mouse position
- [ ] Scales correctly (slider test: 0.5x, 1x, 2x, 3x)
- [ ] AOE scales correctly (slider test: 50px, 150px, 300px, 500px)
- [ ] Color changes work (test: white, red, blue, cyan)
- [ ] Animation plays and despawns

---

### Task 2e.4: Implement Method B - GPUParticles2D (~45 min)

**File:** `tests/visual_effects/effects/MethodB_GPUParticles.tscn`

**Projectile Trail Version:**
```
MethodB_GPUParticles.tscn (Projectile Trail)
├─ GPUParticles2D (root, script: MethodB_GPUParticles.gd)
   ├─ Texture: particle_circle.png (16×16)
   └─ Process Material: ParticleProcessMaterial
```

**AOE/Aura Version:**
```
MethodB_GPUParticles_AOE.tscn (Continuous Aura)
├─ GPUParticles2D (root, script: MethodB_GPUParticles.gd)
   ├─ Texture: particle_circle.png (16×16)
   └─ Process Material: ParticleProcessMaterial
```

**Script:** `tests/visual_effects/effects/MethodB_GPUParticles.gd`
```gdscript
extends GPUParticles2D

const BASE_AOE := 150.0

func configure(params: Dictionary):
	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Scale
	var scale_val = params.get("scale", 1.0)
	var aoe_radius = params.get("aoe_radius", BASE_AOE)
	var aoe_scale = aoe_radius / BASE_AOE

	scale = Vector2.ONE * scale_val * aoe_scale

	# Configure emission shape
	var mat: ParticleProcessMaterial = process_material.duplicate()
	process_material = mat

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 50.0 * aoe_scale  # ✅ KEY: Scale emission!

	# Color
	mat.color = params.get("color", Color.WHITE)

	# Start emission
	emitting = true

	# Auto-cleanup
	await get_tree().create_timer(lifetime).timeout
	queue_free()
```

**Inspector Setup (MethodB_GPUParticles_AOE.tscn):**
```
GPUParticles2D:
  Amount: 50
  Lifetime: 0.8
  Explosiveness: 0.0  # Continuous
  One Shot: false
  Preprocess: 0.5
  Local Coords: true

ParticleProcessMaterial:
  Emission Shape: Sphere
  Sphere Radius: 50.0

  Direction: (0, 0, 0)
  Spread: 180.0

  Initial Velocity: 50-100
  Gravity: (0, 0)

  Scale: 1.0
  Scale Curve: [Linear 1.0 → 0.5]

  Color: White
  Color Ramp: [White → Transparent]
```

**Success Criteria:**
- [ ] Spawns at mouse position
- [ ] Particles distribute evenly in circle (not clustered at center)
- [ ] AOE scaling works (compare 150px vs 300px emission radius)
- [ ] Color changes work
- [ ] Aura version loops continuously
- [ ] Projectile version despawns after lifetime

---

### Task 2e.5: Implement Method C - Line2D (~30 min)

**File:** `tests/visual_effects/effects/MethodC_Line2D.tscn`

**AOE Circle Version:**
```
MethodC_Line2D.tscn (AOE Circle)
├─ Node2D (root, script: MethodC_Line2D.gd)
└─ Line2D
   ├─ Width: 5.0
   ├─ Default Color: White
   └─ Gradient: [White → Transparent]
```

**Script:** `tests/visual_effects/effects/MethodC_Line2D.gd`
```gdscript
extends Node2D

@onready var line: Line2D = $Line2D

func configure(params: Dictionary):
	# Position
	global_position = params.get("position", Vector2.ZERO)

	# Generate circle arc
	var aoe_radius = params.get("aoe_radius", 150.0)
	var segments = 32

	line.clear_points()
	for i in segments + 1:  # +1 to close circle
		var angle = float(i) / segments * TAU
		var point = Vector2(cos(angle), sin(angle)) * aoe_radius
		line.add_point(point)

	# Color
	line.default_color = params.get("color", Color.WHITE)

	# Scale (line width)
	var scale_val = params.get("scale", 1.0)
	line.width = 5.0 * scale_val

	# Fade out
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
```

**Success Criteria:**
- [ ] Spawns circle at mouse position
- [ ] Circle radius matches AOE slider
- [ ] Line width scales with scale slider
- [ ] Color changes work
- [ ] Fades out smoothly

---

### Task 2e.6: Testing & Documentation (~1 hour)

**Test Cases:**

**Scalability Test:**
1. Set AOE to 150px (base) → Spawn all 3 methods → Note visual size
2. Set AOE to 300px (2x) → Spawn all 3 methods → Verify 2x larger
3. Set AOE to 500px (3.3x) → Spawn all 3 methods → Verify proportional

**Expected Results:**
- ✅ Method A (Sprite+Shader): Scales perfectly (sprite.scale)
- ✅/⚠️ Method B (GPUParticles): Scales IF emission_sphere_radius updated
- ✅ Method C (Line2D): Scales perfectly (procedural arc)

**Performance Test:**
1. Press SPACE for 100 effects stress test
2. Note FPS for each method
3. Repeat 3 times, average results

**Expected Results:**
- Method A: 50-60 FPS (shader overhead)
- Method B: 55-60 FPS (GPU-accelerated)
- Method C: 58-60 FPS (minimal overhead)

**Document Findings:**

**File:** `tests/visual_effects/POC_FINDINGS.md`

```markdown
# Visual Effects POC - Findings

**Date:** [Date]
**Branch:** visual-effects-poc

## Scalability Test Results

| Method | 150px AOE | 300px AOE | 500px AOE | Scales Correctly? |
|--------|-----------|-----------|-----------|-------------------|
| A: Sprite+Shader | ✅ | ✅ | ✅ | YES |
| B: GPUParticles | ✅/❌ | ✅/❌ | ✅/❌ | YES/NO |
| C: Line2D | ✅ | ✅ | ✅ | YES |

## Performance Test Results (100 effects)

| Method | Average FPS | Frame Drops? | Notes |
|--------|-------------|--------------|-------|
| A: Sprite+Shader | XX FPS | Yes/No | ... |
| B: GPUParticles | XX FPS | Yes/No | ... |
| C: Line2D | XX FPS | Yes/No | ... |

## Recommendations

**For Projectiles:**
- [ ] Method A (Sprite+Shader) - Best balance of visuals + scalability
- [ ] Method B (GPUParticles) - Best for trails only
- [ ] Method C (Line2D) - Not suitable for projectiles

**For AOE/Aura:**
- [ ] Method A (Sprite+Shader) - ...
- [ ] Method B (GPUParticles) - ...
- [ ] Method C (Line2D) - ...

## Next Steps

1. Update `2_ABILITIES_system_implementation.md` Phase 6 with chosen method
2. Update `ability-system-melee-migration-guide.md` visual section
3. Delete visual-effects-poc branch
4. Merge findings documentation to ability_system branch
```

**Success Criteria:**
- [ ] All test cases executed
- [ ] Results documented in POC_FINDINGS.md
- [ ] Screenshots/video captured (optional)
- [ ] Recommendation made for Phase 6

---

## 📋 POC Completion Checklist

**Setup:**
- [ ] Created visual-effects-poc branch
- [ ] Created tests/visual_effects/ folder structure
- [ ] Created POC scene with control panel

**Implementation:**
- [ ] Method A (Sprite+Shader) - Projectile version
- [ ] Method A (Sprite+Shader) - AOE version
- [ ] Method B (GPUParticles2D) - Projectile version
- [ ] Method B (GPUParticles2D) - AOE version
- [ ] Method C (Line2D) - AOE version
- [ ] Test harness script with keyboard controls

**Testing:**
- [ ] Scalability test (3 AOE sizes per method)
- [ ] Performance test (100 effects stress test)
- [ ] Color customization test
- [ ] Visual comparison screenshots

**Documentation:**
- [ ] POC_FINDINGS.md created with results
- [ ] Recommendation documented
- [ ] Updated parent task (2_ABILITIES_system_implementation.md)
- [ ] Updated migration guide visual section

**Cleanup:**
- [ ] Merged POC_FINDINGS.md to ability_system branch
- [ ] Deleted visual-effects-poc branch
- [ ] POC scene archived (optional: keep for future reference)

---

## 🔄 Integration with Phase 6

**After POC completion:**

1. **Update Phase 6 tasks** with chosen method(s)
2. **Update migration guide** Step 2.3 (visual effects)
3. **Create base effect scenes** using proven approach
4. **Implement visual customization** (color, scale) in MeleeAbility.gd

**Branch workflow:**
```bash
# Complete POC on visual-effects-poc branch
git checkout visual-effects-poc
# ... implement POC tasks ...
git add tests/visual_effects/POC_FINDINGS.md
git commit -m "docs(abilities): visual effects POC findings"

# Merge findings back to ability_system
git checkout ability_system
git merge visual-effects-poc --no-ff
# ... resolve any conflicts ...

# Delete POC branch
git branch -d visual-effects-poc
```

---

## ⏭️ Next Phase After POC

**After POC complete → Return to main ability system flow:**
- Phase 4: Tome Validation (2d_ABILITIES_phase4_tome_validation.md)
- **Phase 5 (NEW):** Visual Effects POC (THIS TASK) ✅ Complete
- Phase 6: Expand Ability Library + Visual Foundation (using POC findings)

---

**Status:** Ready to begin when Phase 3 (Ranger Arrow) complete
