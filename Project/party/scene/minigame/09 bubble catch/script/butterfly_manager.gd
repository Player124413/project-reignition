extends Node3D

@export var butterflies : Array[Node3D]

func _ready() -> void:
	MinigameManager.instance.peers_loaded.connect(Callable(self, "initialize_butterflies"))

func initialize_butterflies() -> void:
	for i in butterflies.size():
		MinigameManager.instance.gameplay_started.connect(Callable(butterflies[i], "on_gameplay_started"))
		butterflies[i].request_spawn()
