class_name ChestSpawner extends Node3D

@export var spawners: Array[Node3D]
@export var chests: Array[Chest]

var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	if !NetworkManager.is_hosting_game:
		return
	print("starting minigame")
	MinigameManager.instance.gameplay_started.connect(Callable(self , "start_spawning"))

func start_spawning() -> void:
	set_physics_process(true)
	print("spawning chests")
	chests.shuffle()

	for i in range(spawners.size()):
		chests[i].global_position = spawners[i].global_position
