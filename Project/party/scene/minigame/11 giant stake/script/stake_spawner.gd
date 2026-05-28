class_name StakeSpawner extends Node

### The nodes containing the stakes
@export var rows: Array[Node3D]
### How far apart horizontally should the stakes spawn
@export var stake_distance_horiz: float
### How far apart 'vertically' should the stakes spawn
@export var stake_distance_vert: float
@export var total_spawn_length: float = 40
### How long of a pause should there be between stakes in the same group
@export var time_between_stakes: float = 0.3


func _ready() -> void:
	initialize_stakes()
	set_physics_process(true)

	if !NetworkManager.is_hosting_game:
		return
	MinigameManager.instance.gameplay_started.connect(Callable(self , "start_spawning"))
	MinigameManager.instance.request_minigame_start()

### Spreads the stakes out evenly so we don't have to do it by hand
func initialize_stakes() -> void:
	var stake_original: GiantStake = rows[0].get_child(0)
	for i in range(rows.size()):
		for j in range(rows[i].get_children().size()):
			var stake = rows[i].get_child(j)
			stake.position = Vector3(stake_original.position.x + (stake_distance_horiz * j), stake_original.position.y, stake_original.position.z + (stake_distance_vert * i))

func start_spawning() -> void:
	set_physics_process(true)
	return

func start_new_spawn(new_stakes: Array[GiantStake]):
	for i in range(new_stakes.size()):
		new_stakes[i].set_bonus()
		new_stakes[i].spawn_stake()
		await get_tree().create_timer(time_between_stakes).timeout
	pass


## Minimum number of stakes to spawn
const MIN_STAKES: int = 1
## Maximum number of stakes to spawn
const MAX_STAKES: int = 4
## The chance an L-shaped stakes group will spawn
const SHAPE_CHANCE: int = 3

func request_spawn():
	print("requesting spawn")
	var rng = RandomNumberGenerator.new()
	var spawn_type = rng.randi_range(1, SHAPE_CHANCE) # If the stakes should spawn in an L shape
	var spawn_amt = rng.randi_range(MIN_STAKES, MAX_STAKES)
	var distance = rng.randi_range(1, 2)
	var spawn_direction: int

	var stakes: Array[GiantStake]

	# The initial starting stake
	var starting_row: int
	var starting_col: int

	while true: # Calculate the initial starting stake
		starting_col = rng.randi_range(1, rows.size())
		starting_row = rng.randi_range(1, rows[0].get_child_count())

		if is_valid_spawn(starting_row, starting_col): # If the stake is not valid, then repeat the rng
			stakes[0] = rows[starting_row].get_child(starting_col) as GiantStake
			break
	

	if spawn_amt > 1:
		var num_tries # If the spawn is not valid, then increment this counter and try again
		spawn_direction = rng.randi_range(1, 4)
				
		for i in range(1, spawn_amt):
			num_tries = 0
			while true:
				if num_tries > rows[0].get_child_count(): # If we have exceeded the number of children in a row, then try a new direction
					spawn_direction = rng.randi_range(1, 4)
					num_tries = 0
				if i == spawn_amt - 1 && spawn_type == 1: # If we are at the last stake in the sequence, spawn in a new direction to make an L-shape
					spawn_direction = rng.randi_range(1, 4)
					num_tries = 0
				match spawn_direction:
					1: # NORTH
						var new_row: int = starting_row - (distance + num_tries)
						if is_valid_spawn(new_row, starting_col):
							stakes[i] = rows[new_row].get_child(starting_col) as GiantStake
							break
						else:
							num_tries += 1
					2: # SOUTH
						var new_row: int = starting_row + (distance + num_tries)
						if is_valid_spawn(new_row, starting_col):
							stakes[i] = rows[new_row].get_child(starting_col) as GiantStake
							break
						else:
							num_tries += 1
					3: # EAST
						var new_col: int = starting_col + (distance + num_tries)
						if is_valid_spawn(starting_row, new_col):
							stakes[i] = rows[starting_row].get_child(new_col) as GiantStake
							break
						else:
							num_tries += 1
					4: # WEST
						var new_col: int = starting_col - (distance + num_tries)
						if is_valid_spawn(starting_row, new_col):
							stakes[i] = rows[starting_row].get_child(new_col) as GiantStake
						else:
							num_tries += 1
						pass
	rpc("start_new_spawn", stakes)
			

func is_valid_spawn(row: int, col: int) -> bool:
	if row > rows.size(): # Check if it's in a valid row
		return false
	
	if col > rows[row].get_child_count(): # Check if it's in a valid column
		return false
		
	var this_stake: GiantStake = rows[row].get_child(col)
	if this_stake.is_fallen == true:
		return false
	else:
		return true
