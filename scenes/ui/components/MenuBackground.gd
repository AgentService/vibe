extends Node2D
## Animated menu background with parallax scrolling and particle effects
## Designed to run continuously across scene transitions when managed by MenuBackgroundManager

@onready var parallax_bg: ParallaxBackground = $ParallaxBackground
@onready var background_image: TextureRect = $ParallaxBackground/ParallaxLayer_Background/BackgroundImage
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

func reset_background() -> void:
	"""Reset background state when becoming visible after being hidden."""
	if parallax_bg:
		# Reset scroll offset to prevent accumulated drift
		parallax_bg.scroll_offset = Vector2.ZERO
		# Reset scroll base offset (camera-related positioning)
		parallax_bg.scroll_base_offset = Vector2.ZERO
		# Ensure camera zoom is ignored (set in scene file)
		parallax_bg.scroll_ignore_camera_zoom = true

	if background_image:
		# Ensure texture rect maintains proper size
		background_image.offset_right = 1920.0
		background_image.offset_bottom = 1080.0
		Logger.debug("Background reset to fullscreen with camera offsets cleared", "ui")

func _process(delta: float) -> void:
	"""Auto-scroll parallax for continuous motion effect."""
	if parallax_bg:
		parallax_bg.scroll_offset += SCROLL_SPEED * delta
