class_name ChestSpawner extends Node3D

@export var spawners: Array[Node3D]
@export var chests: Array[TreasureChest]

var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	if !NetworkManager.is_hosting_game:
		return
	print("starting minigame")

func start_spawning() -> void:
	set_physics_process(true)
	print("spawning chests")
	chests.shuffle()

	for i in range(spawners.size()):
		chests[i].global_position = spawners[i].global_position
