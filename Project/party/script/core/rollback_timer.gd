### Essentially a timer that checks for multiplayer authority.
### Instance this as a direct child of any object that needs rollback.
class_name RollbackTimer extends Node

## Emitted whenever a rollback is locally applied. Connect
signal rollback_applied(rb_params : Array)

## If True, will attempt to re-simulate frames when rolling back.
@export var enable_lag_compensation : bool = true
## How should authority be determined?
@export var authority_mode : AUTHORITY_MODE
## How many parameters should we allocate?
@export var param_count : int = 2
var target : Node

enum AUTHORITY_MODE {
	AUTHORITY,
	HOST
}

## How often to rollback
@export var rollback_interval : float = 0.2
## Stores the latest time we've updated on the network
var latest_network_time : float
var rollback_interval_timer : float

## Parameters to sync
var _params : Array

## Creates a RollbackTimer and connects signals
## Call this and pass in the object to sync.
func _ready() -> void:
	_params.resize(param_count)

func register_target(tar : Node) -> void:
	target = tar
	rollback_applied.connect(Callable(target, "on_rollback_applied"))

## Optional function if you want a different authority mode.
func set_authority_mode(mode : AUTHORITY_MODE) -> void:
	authority_mode = mode

## Sets a param.
func set_param(index : int, value) -> void:
	_params[index] = value

## Optional function if you want to change lag compensation.
func set_lag_compensation(value : bool) -> void:
	enable_lag_compensation = value

## Returns whether this rollback timer is the authority.
func is_authority() -> bool:
	if authority_mode == AUTHORITY_MODE.HOST && !NetworkManager.is_hosting_game:
		return false
	if authority_mode == AUTHORITY_MODE.AUTHORITY && !is_multiplayer_authority():
		return false
	return true

## Call this to process this rollback timer.
## Typcially you should do this right after setting up the params.
func process_rollback() -> void:
	if !is_instance_valid(target) || !target.is_physics_processing():
		return
	
	if !is_authority():
		return
	
	rollback_interval_timer = move_toward(rollback_interval_timer, 0, get_physics_process_delta_time())
	if is_zero_approx(rollback_interval_timer):
		rollback_interval_timer = rollback_interval
		## Send an rpc request to resync across the network
		rpc("apply_rollback", NetworkTimeSynchronizer.get_time(), _params)

## Resyncs this majin across the network.
@rpc("any_peer", "call_remote", "unreliable")
func apply_rollback(network_time : float, rollback_params : Array) -> void:
	if network_time <= latest_network_time: # Already recieved an earlier tick
		return
	
	if is_authority():
		return
	
	# Rollback to sync state
	latest_network_time = network_time
	rollback_applied.emit(rollback_params) # Notify observers
	if enable_lag_compensation: # Lag compensation
		for i in range(floor((NetworkTimeSynchronizer.get_time() - network_time) / get_physics_process_delta_time())):
			target.process_movement_tick()
