class_name TreasureBoxChestSpawner extends Node3D

static var instance : TreasureBoxChestSpawner
@export var chests : Array[TreasureBoxChest]

func _ready() -> void:
	instance = self

## Gets the index of a particular chest.
func get_chest_index(chest : TreasureBoxChest) -> int:
	return chests.find(chest)

## Returns the treasure chest associated with a particular index.
func get_chest(index : int) -> TreasureBoxChest:
	return chests[index]

func start_spawning() -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	var coin_array : Array[int] = [2, 4, 6, 8, 10, 12, 15, 17, 19]
	coin_array.resize(chests.size())
	coin_array.shuffle()
	rpc("sync_coin_values", coin_array)

@rpc("any_peer", "call_local", "reliable")
func sync_coin_values(coins : Array[int]) -> void:
	for i in chests.size():
		chests[i].num_coins = coins[i]
		chests[i].spawn()
