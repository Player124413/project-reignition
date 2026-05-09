### Spawns objects for the parasol diving minigame.
### Coins are spawned in an alternating left-right pattern (Actually just reuses the same coins repeatedly).
### Clouds are spawned randomly.
extends Node3D

@export var scroll_parent : Node3D
@export var coin_pool : Array[Node3D]
@export var spawn_positions : Array[Node3D]
## How often coins should be spawned.
@export var coin_spawn_interval : float
@export var scroll_speed : float = 10.0
var coin_spawn_timer : float

## Tracks which side to spawn coins on.
var _is_spawning_right : bool
const BONUS_CHANCE : float = 0.3

func _ready() -> void:
	if !NetworkManager.is_hosting_game:
		return
	MinigameManager.instance.gameplay_started.connect(Callable(self, "activate"))
	MinigameManager.instance.gameplay_finished.connect(Callable(self, "deactivate"))
	deactivate()

func _physics_process(delta: float) -> void:
	var current_tick : float = NetworkTimeSynchronizer.get_time() - MinigameManager.instance.gameplay_start_tick
	scroll_parent.position = Vector3.UP * current_tick * scroll_speed
	if !NetworkManager.is_hosting_game:
		return
	coin_spawn_timer -= delta
	if coin_spawn_timer <= 0:
		request_coin_spawn()

func activate() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

func deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func request_coin_spawn() -> void:
	rpc("spawn_coin", NetworkTimeSynchronizer.get_time(), _is_spawning_right, randf() < BONUS_CHANCE)
	_is_spawning_right = !_is_spawning_right
	coin_spawn_timer = coin_spawn_interval

@rpc("authority", "call_local", "reliable")
func spawn_coin(time : float, is_right_side : bool, is_bonus : bool) -> void:
	# Take the last coin, spawn it, the repool it to the back
	var coin : Node3D = coin_pool[0]
	coin_pool.remove_at(0)
	coin_pool.append(coin)
	
	var spawn_position : Vector3 = spawn_positions[1 if is_right_side else 0].global_position
	spawn_position += Vector3.UP * (NetworkTimeSynchronizer.get_time() - time) * scroll_speed
	coin.spawn(spawn_position, is_bonus)
