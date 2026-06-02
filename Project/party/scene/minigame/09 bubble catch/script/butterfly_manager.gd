class_name ButterflyManager extends Node3D

static var instance : ButterflyManager

@export var butterflies : Array[Node3D]
var camera : Camera3D

func _ready() -> void:
	instance = self
	camera = get_tree().root.get_camera_3d()
	initialize_butterflies()
	MinigameManager.instance.results_started.connect(Callable(self, "disable"))

func disable() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func initialize_butterflies() -> void:
	for i in butterflies.size():
		butterflies[i].collected.connect(Callable(self, "request_collect_butterfly"))
		butterflies[i].request_spawn()

## Processes a collection attempt.
func request_collect_butterfly(butterfly : Node3D, bubble : Node3D) -> void:
	if butterfly.is_bonus && bubble.bubble_size <= 1: # Bubble isn't big enough
		return
	var popup_position : Vector2 = camera.unproject_position(bubble.global_position + Vector3.UP * 3)
	bubble.rpc("collect_butterfly", butterflies.find(butterfly), NetworkTimeSynchronizer.get_time(), popup_position)
