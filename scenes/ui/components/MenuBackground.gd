extends Node2D
## Animated menu background with parallax scrolling and particle effects
## Designed to run continuously across scene transitions when managed by MenuBackgroundManager

@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var particles: GPUParticles2D = $FloatingParticles
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Parallax scrolling speed (pixels per second)
const SCROLL_SPEED: Vector2 = Vector2(-20, -5)

func _ready() -> void:
	# Start continuous animations
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

	# Start particle effects
	if particles:
		particles.emitting = true

	Logger.debug("MenuBackground initialized with parallax and particles", "ui")

func _process(delta: float) -> void:
	"""Auto-scroll parallax for continuous motion effect."""
	if parallax_bg:
		parallax_bg.scroll_offset += SCROLL_SPEED * delta
