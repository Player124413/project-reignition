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
### Minimum amount of time till the next group
@export var min_time_between_groups: float = 1
### Maximum amount of time till the next group
@export var max_time_between_groups: float = 5
### How long until the first group spawns
@export var time_before_first_spawn: float = 5
var can_spawn: bool = false

### Chance of stake becoming metal (eg: 5 = 1/5 chance)
const CHANCE_FOR_BONUS: int = 5
var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	initialize_stakes()
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
	await get_tree().create_timer(time_before_first_spawn).timeout
	request_spawn() # Requests the first group
	can_spawn = true
	process_spawns()
	return

func start_new_spawn(new_stakes: Array[Vector2i]):
	print("-----------------------")
	for i in range(new_stakes.size()):
		print("Launching Stake: " + str(i))
		print("Row: " + str(new_stakes[i].x))
		print("Col: " + str(new_stakes[i].y))
		
		var this_stake: GiantStake = get_stake(new_stakes[i].x, new_stakes[i].y) as GiantStake
		if this_stake.is_fallen: # Stake is already spawned
			continue
		this_stake.rpc("spawn_stake", rng.randi_range(1, CHANCE_FOR_BONUS) == 1)
		await get_tree().create_timer(time_between_stakes).timeout
	
	print("-----------------------")

func process_spawns() -> void:
	if !NetworkManager.is_hosting_game:
		return
	if !can_spawn:
		return
	await get_tree().create_timer(rng.randf_range(min_time_between_groups, max_time_between_groups)).timeout
	request_spawn()
	process_spawns()
	
	
## Minimum number of stakes to spawn
const MIN_STAKES: int = 1
## Maximum number of stakes to spawn
const MAX_STAKES: int = 4
## The chance an L-shaped stakes group will spawn
const SHAPE_CHANCE: int = 3
## How many rows
const MAX_ROWS: int = 10
## How many columns
const MAX_COLS: int = 11
## How many times should next_valid_spawn be called until giving up?
const FAILSAFE: int = 50

enum DIRECTION {
	NORTH,
	SOUTH,
	EAST,
	WEST,
}

## The type of shape stakes should spawn in
enum SHAPE {
	SINGLE,
	DOUBLE,
	DOUBLE_SPACE, # This shape has a space between two stakes
	TRIPLE,
	TRIPLE_SPACE,
	#QUAD,
	#QUAD_L, # This shape has 3 consecutive stakes and one in another direction
	COUNT
}

func request_spawn():
	if !NetworkManager.is_hosting_game:
		return
	
	print("requesting spawn")
	var spawn_direction: DIRECTION
	var shape: SHAPE = rng.randi_range(0, SHAPE.COUNT - 1) as SHAPE

	var stakes: Array[Vector2i]

	# The initial starting stake
	var starting_row: int
	var starting_col: int
	
	while true: # Calculate the initial starting stakes
		print("Getting first stake")
		print("Shape: " + str(shape))
		starting_col = rng.randi_range(1, rows.size())
		starting_row = rng.randi_range(1, rows[0].get_child_count())
		stakes.resize(1)

		if is_valid_spawn(starting_row, starting_col): # If the stake is not valid, then repeat the rng
			stakes[0] = Vector2i(starting_row, starting_col)
			break

		
	while true: # Calculate all possible shapes
		spawn_direction = rng.randi_range(0, 3) as DIRECTION
		
		if shape == SHAPE.SINGLE:
			break
		
		if shape == SHAPE.DOUBLE:
			stakes.resize(2)
			match spawn_direction:
				DIRECTION.NORTH:
					if is_valid_spawn(starting_row - 1, starting_col):
						stakes[1] = Vector2i(starting_row - 1, starting_col)
						break
				DIRECTION.SOUTH:
					if is_valid_spawn(starting_row + 1, starting_col):
						stakes[1] = Vector2i(starting_row + 1, starting_col)
						break
				DIRECTION.EAST:
					if is_valid_spawn(starting_row, starting_col + 1):
						stakes[1] = Vector2i(starting_row, starting_col + 1)
						break
				DIRECTION.WEST:
					if is_valid_spawn(starting_row, starting_col - 1):
						stakes[1] = Vector2i(starting_row, starting_col - 1)
						break
		
		if shape == SHAPE.DOUBLE_SPACE:
			stakes.resize(2)
			match spawn_direction:
				DIRECTION.NORTH:
					if is_valid_spawn(starting_row - 2, starting_col):
						stakes[1] = Vector2i(starting_row - 2, starting_col)
						break
				DIRECTION.SOUTH:
					if is_valid_spawn(starting_row + 2, starting_col):
						stakes[1] = Vector2i(starting_row + 2, starting_col)
						break
				DIRECTION.EAST:
					if is_valid_spawn(starting_row, starting_col + 2):
						stakes[1] = Vector2i(starting_row, starting_col + 2)
						break
				DIRECTION.WEST:
					if is_valid_spawn(starting_row, starting_col - 2):
						stakes[1] = Vector2i(starting_row, starting_col - 2)
						break
		if shape == SHAPE.TRIPLE:
			stakes.resize(3)
			match spawn_direction:
				DIRECTION.NORTH:
					if is_valid_spawn(starting_row - 1, starting_col):
						stakes[1] = Vector2i(starting_row - 1, starting_col)
						if is_valid_spawn(starting_row - 2, starting_col):
							stakes[2] = Vector2i(starting_row - 2, starting_col)
							break
				DIRECTION.SOUTH:
					if is_valid_spawn(starting_row + 1, starting_col):
						stakes[1] = Vector2i(starting_row + 1, starting_col)
						if is_valid_spawn(starting_row + 2, starting_col):
							stakes[2] = Vector2i(starting_row + 2, starting_col)
							break
				DIRECTION.EAST:
					if is_valid_spawn(starting_row, starting_col + 1):
						stakes[1] = Vector2i(starting_row, starting_col + 1)
						if is_valid_spawn(starting_row, starting_col + 2):
							stakes[2] = Vector2i(starting_row, starting_col + 2)
							break
				DIRECTION.WEST:
					if is_valid_spawn(starting_row, starting_col - 1):
						stakes[1] = Vector2i(starting_row, starting_col - 1)
						if is_valid_spawn(starting_row, starting_col - 2):
							stakes[2] = Vector2i(starting_row, starting_col - 2)
							break
		if shape == SHAPE.TRIPLE_SPACE:
			stakes.resize(3)
			match spawn_direction:
				DIRECTION.NORTH:
					if is_valid_direction(starting_row - 2, starting_col):
						stakes[1] = Vector2i(starting_row - 2, starting_col)
						if is_valid_direction(starting_row - 4, starting_col):
							stakes[2] = Vector2i(starting_row - 4, starting_col)
							break
				DIRECTION.SOUTH:
					if is_valid_direction(starting_row + 2, starting_col):
						stakes[1] = Vector2i(starting_row + 2, starting_col)
						if is_valid_direction(starting_row + 4, starting_col):
							stakes[2] = Vector2i(starting_row + 4, starting_col)
							break
				DIRECTION.EAST:
					if is_valid_direction(starting_row, starting_col + 2):
						stakes[1] = Vector2i(starting_row, starting_col + 2)
						if is_valid_direction(starting_row, starting_col + 4):
							stakes[2] = Vector2i(starting_row, starting_col + 4)
							break
				DIRECTION.WEST:
					if is_valid_direction(starting_row, starting_col - 2):
						stakes[1] = Vector2i(starting_row, starting_col - 2)
						if is_valid_direction(starting_row, starting_col - 4):
							stakes[2] = Vector2i(starting_row, starting_col - 4)
							break
	
	start_new_spawn(start_corrections(stakes, spawn_direction))

func is_valid_spawn(row: int, col: int) -> bool:
	if row > rows.size() - 1: # Check if it's in a valid row
		return false
	
	if col > rows[row].get_child_count() - 1: # Check if it's in a valid column
		return false
	
	if row < 0:
		return false

	if col < 0:
		return false
	
	var this_stake: GiantStake = rows[row].get_child(col) as GiantStake
	if this_stake.starting_stake == true:
		return false
	if this_stake.is_fallen == true:
		return false

	return true

func is_valid_direction(row: int, col: int):
	if row > rows.size() - 1:
		return false

	if row < 0:
		return false

	if col < 0:
		return false
	
	if col > rows[row].get_child_count() - 1:
		return false
	var this_stake: GiantStake = rows[row].get_child(col) as GiantStake
	if this_stake.starting_stake == true:
		return false
	return true

var num_checks: int = 0
func get_next_valid_spawn(row: int, col: int, direction: DIRECTION) -> Vector2i:
	num_checks += 1
	if num_checks >= FAILSAFE:
		return Vector2i(0, 0)
	
	var rng = RandomNumberGenerator.new()
	match direction:
		DIRECTION.NORTH:
			for i in range(MAX_ROWS, 0):
				if i < row: # Start checking rows past our current row
					if is_valid_spawn(i, col):
						num_checks = 0 # Resets the check counter upon a successful spawn
						return Vector2i(i, col)
					if i == 0: # Call this method again if we reached the end of our search, and choose another direction
						return get_next_valid_spawn(0, col, rng.randi_range(3, 4) as DIRECTION) # Chooses EAST or WEST randomly

		DIRECTION.SOUTH:
			for i in range(0, MAX_ROWS):
				if i > row:
					if is_valid_spawn(i, col):
						num_checks = 0
						return Vector2i(i, col)
					if i == MAX_ROWS:
						return get_next_valid_spawn(MAX_ROWS, col, rng.randi_range(3, 4) as DIRECTION)
		DIRECTION.EAST:
			for i in range(0, MAX_COLS):
				if i > col:
					if is_valid_spawn(row, i):
						num_checks = 0
						return Vector2i(row, i)
					if i == MAX_COLS:
						return get_next_valid_spawn(row, MAX_COLS, rng.randi_range(1, 2) as DIRECTION)
		DIRECTION.WEST:
			for i in range(MAX_COLS, 0):
				if i < col:
					if is_valid_spawn(row, i):
						num_checks = 0
						return Vector2i(row, i)
					if i == 0:
						return get_next_valid_spawn(row, 0, rng.randi_range(1, 2))
	return Vector2i.ZERO

func start_corrections(stakes: Array[Vector2i], direction: DIRECTION) -> Array[Vector2i]:
	var new_stakes: Array[Vector2i] = stakes

	for i in range(0, stakes.size()):
		if !is_valid_spawn(new_stakes[i].x, new_stakes[i].y):
			new_stakes[i] = get_next_valid_spawn(new_stakes[i].x, new_stakes[i].y, direction)
	
	return new_stakes


func get_stake(row: int, col: int) -> GiantStake:
	return rows[row].get_child(col) as GiantStake
