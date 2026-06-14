class_name TreasureBoxChestSpawner extends Node3D

static var instance : TreasureBoxChestSpawner

@export var chests : Array[TreasureBoxChest]
@export var coins : Array[Node3D]

## The number of coins in the best chest.
const HIGHEST_COIN_COUNT : int = 19

func _ready() -> void:
	instance = self
	MinigameManager.instance.minigame_finished.connect(Callable(self, "despawn_chests"))

func despawn_chests() -> void:
	for chest in chests:
		chest.despawn()

## Gets the index of a particular chest.
func get_chest_index(chest : TreasureBoxChest) -> int:
	return chests.find(chest)

## Returns the treasure chest associated with a particular index.
func get_chest(index : int) -> TreasureBoxChest:
	return chests[index]

func start_spawning() -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	var coin_array : Array[int] = [2, 4, 6, 8, 10, 12, 15, 17, HIGHEST_COIN_COUNT]
	coin_array.resize(chests.size())
	coin_array.shuffle()
	rpc("sync_coin_values", coin_array)

@rpc("any_peer", "call_local", "reliable")
func sync_coin_values(vals : Array[int]) -> void:
	for i in chests.size():
		chests[i].num_coins = vals[i]
		chests[i].spawn()

func get_coin() -> Node3D:
	var coin : Node3D = coins[0]
	coins.remove_at(0)
	return coin
