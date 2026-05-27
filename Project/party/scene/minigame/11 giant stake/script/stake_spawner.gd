extends Node

### The nodes containing the stakes
@export var rows: Array[Node3D]
### How far apart horizontally should the stakes spawn
@export var stake_distance_horiz: float
### How far apart 'vertically' should the stakes spawn
@export var stake_distance_vert: float
@export var total_spawn_length: float = 40


func _ready() -> void:
	initialize_stakes()
	set_physics_process(true)

	if !NetworkManager.is_hosting_game:
		return
	MinigameManager.instance.gameplay_started.connect(Callable(self , "start_spawning"))
	MinigameManager.instance.request_minigame_start()

### Spreads the stakes out evenly so we don't have to do it by hand
func initialize_stakes() -> void:
	var stake_original = rows[0].get_child(0)
	for i in range(rows.size()):
		for j in range(rows[i].get_children().size()):
			var stake = rows[i].get_child(j)
			stake.position = Vector3(stake_original.position.x + (stake_distance_horiz * j), stake_original.position.y, stake_original.position.z + (stake_distance_vert * i))

func start_spawning() -> void:
	set_physics_process(true)
	return

## Minimum number of stakes to spawn
const MIN_STAKES: int = 1
## Maximum number of stakes to spawn
const MAX_STAKES: int = 4
## The chance an L-shaped stakes group will spawn
const SHAPE_CHANCE: int = 3

@rpc("any_peer", "call_local", "reliable")
func request_spawn() -> void:
	var rng = RandomNumberGenerator.new()
	var spawn_type = rng.randf_range(1, SHAPE_CHANCE)
	var spawn_amt = rng.randf_range(MIN_STAKES, MAX_STAKES)
	var spawn_direction = rng.randf_range(1, 4)

	while true:
		var starting_col = rng.randf_range(1, rows.size())
		var starting_row = rng.randf_range(1, rows[0].get_child_count())

	
	return

func check_valid_spawn(row: int, col: int) -> bool:
	var this_stake: GiantStake = rows[row].get_child(col)
	if this_stake.is_fallen == true:
		return true
	else:
		return false
