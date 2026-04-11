### Manages creating servers and adding clients.
extends Node

## Emitted when the host successfully connects.
signal host_connected
## Emitted when a client successfully connects.
signal client_connected

## Emitted when the current primary scene is changed. The other signals provide more detail on the type of scene change.
signal scene_changed()
signal attraction_loaded() # NOTE: This is also emitted when a mini-game finishes.
signal party_game_loaded()
## Emitted when the party game actually starts.
signal party_game_started()

## Emitted when a connection attempt either succeeds or fails.
signal connection_attempt_finished(err : String)

@export var log_parent : Node
@export var log_scene : PackedScene
var loggers : Array[Control]
const LOGGER_COUNT : int = 5
var current_log_index : int

## Determines whether this device is acting as a host or a client.
var is_hosting_game : bool
## The address to use for connections.
var address : String = "tomfol.io"
## The port to use for connections.
var port = 8890
## Represents the room id that players can give to each other.
var room_id : String
## Tracks whether the game is connected online or not.
var is_online : bool
## Determines whether to attempt NAT Punchthrough or not. Enable this when exporting the project.
var is_nat_enabled : bool = false

var load_states : Array[bool]
var loading_peers : int
## Tracks all the scenes instanced through the network manager. Includes party games and attractions.
var scene_dictionary : Dictionary = {}
enum TRANSITION_TYPE_ENUM {
	ATTRACTION,
	PARTY_GAME
}

func _ready() -> void:
	initialize_loggers()
	initialize_connection_logs()
	load_states.resize(PartyManager.MAX_PLAYER_COUNT)

func initialize_loggers() -> void:
	for i in LOGGER_COUNT:
		var new_log : Control = log_scene.instantiate()
		loggers.append(new_log)
		log_parent.add_child(new_log)

## Queues a scene change.
@rpc("any_peer", "call_local", "reliable")
func load_scene(scene_path : String, type : TRANSITION_TYPE_ENUM) -> void:
	rpc_id(1, "set_loading", multiplayer.get_unique_id(), true) # Let the host know we're loading
	
	# TODO Add Fade Transitions
	ResourceLoader.load_threaded_request(scene_path)
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
		await get_tree().create_timer(0.1).timeout
	
	var scene : PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	var scene_node : Node = scene.instantiate() as Node
	scene_dictionary[scene_path] = scene_node # Add to the dictionary
	add_child(scene_node)
	emit_scene_signals(type)
	
	rpc_id(1, "set_loading", multiplayer.get_unique_id(), false) # Let the host know we're done loading

func emit_scene_signals(type : TRANSITION_TYPE_ENUM) -> void:
	scene_changed.emit() # Base signal
	if type == TRANSITION_TYPE_ENUM.ATTRACTION:
		attraction_loaded.emit()
	elif type == TRANSITION_TYPE_ENUM.PARTY_GAME:
		party_game_loaded.emit()

@rpc("any_peer", "call_local", "reliable")
func unload_scene(scene_path : String) -> void:
	if !scene_dictionary.has(scene_path):
		print("WARN: Tried to unload scene that was never loaded.")
		return
	
	scene_dictionary[scene_path].queue_free() # Delete the node associated with the scene
	scene_dictionary.erase(scene_path) # Register the scene as unloaded

@rpc("any_peer", "call_local", "reliable")
func set_loading(peer_id : int, is_loading : bool) -> void:
	var index : int = multiplayer.get_peers().find(peer_id) if is_online else 0
	if index == -1:
		print("WARN: Invalid peer id %s passed to set_loading." % peer_id)
		return
	load_states[index] = is_loading
	loading_peers = loading_peer_count()
	if loading_peers == 0:
		rpc("finish_loading", calculate_transition_tick()) # RPC on a timer so we can sync unpauses

@rpc("any_peer", "call_local", "reliable")
func finish_loading(target_tick : float) -> void:
	await get_tree().create_timer(calculate_transition_delay(target_tick)).timeout
	get_tree().paused = false
	party_game_started.emit()
	print("Party Game Started.")

## How much extra time to delay during scene changes. A safe-guard in case the jitter spikes after loading.
const TRANSITION_SYNC_DELAY : float = 0.2
func calculate_transition_tick() -> float:
	return NetworkTimeSynchronizer.get_time() + (NetworkTimeSynchronizer.rtt_jitter * 2.0) + TRANSITION_SYNC_DELAY

## Returns the wait time to sync game to a particular tick.
func calculate_transition_delay(target_tick : float) -> float:
	return target_tick - NetworkTimeSynchronizer.get_time()

func loading_peer_count() -> int:
	var count : int = 0
	for i in load_states.size():
		if load_states[i]:
			count += 1
	return count

@rpc("any_peer", "call_local", "reliable")
func log_message(localization_key : StringName) -> void:
	loggers[current_log_index].log_message(localization_key)
	log_parent.move_child(loggers[current_log_index], LOGGER_COUNT - 1)
	current_log_index = (current_log_index + 1) % LOGGER_COUNT

@rpc("any_peer", "call_local", "reliable")
func log_player_connection(id : int) -> void:
	if multiplayer.get_unique_id() == id:
		log_message("network_server_connected")
		return
	log_message(tr("network_add_player").replace("0", str(id)))

@rpc("any_peer", "call_local", "reliable")
func log_player_disconnection(id : int) -> void:
	log_message(tr("network_remove_player").replace("0", str(id)))

func initialize_connection_logs() -> void:
	multiplayer.peer_disconnected.connect(Callable.create(self, "on_peer_disconnected"))
	multiplayer.connected_to_server.connect(Callable.create(self, "on_server_connected"))
	multiplayer.server_disconnected.connect(Callable.create(self, "on_server_disconnected"))

func on_peer_disconnected(id : int) -> void:
	if !is_hosting_game:
		return
	log_player_disconnection(id)

## Logs a client's connection to the server
func on_server_connected() -> void:
	# TODO Replace this with a nick-name
	rpc("log_player_connection", multiplayer.get_unique_id())

func on_server_disconnected() -> void:
	# TODO Display an error and reboot to main party menu
	log_message("network_server_disconnected")
	force_disconnect()

func start_network_signals():
	print("Noray network ready!")
	if is_hosting_game:
		setup_host_noray_connection_signals()
	else:
		setup_client_noray_connection_signals()

## Entry point for Host.
func create_server_peer():
	NetworkManager.log_message("network_connecting")
	await _register_with_noray()
	_start_noray_host()

## Entry point for Client.
func create_client_peer():
	NetworkManager.log_message("network_connecting")
	await _register_with_noray()
	setup_client_enet_connection_signals()
	Noray.connect_nat(room_id)

func _register_with_noray():
	print("Register with Noray hosted at: %s" % address)
	var err = OK
	
	# connect to Noray
	err = await Noray.connect_to_host(address, port)
	if err != OK:
		print("Failed to connect to Noray for registration at %s:%s" % [address, port, err])
		connection_attempt_finished.emit(err)
		return err
		
	# Register host
	Noray.register_host()
	await Noray.on_pid
	
	# Register remove address
	err = await Noray.register_remote()
	if err != OK:
		print("Failed to register remote %s" % err)
		connection_attempt_finished.emit(err)
		return err
	
	print("Finished Noray registration")

## Starts the Noray host.
func _start_noray_host():
	var noray_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err = noray_network_peer.create_server(Noray.local_port)
	multiplayer.multiplayer_peer = noray_network_peer
	if err != OK:
		print("Failed to listen on port %s with error: %s" % [Noray.local_port, err])
		connection_attempt_finished.emit(err)
		return
	
	# Capture room_id to display on host-peer for sharing with others
	print("Noray oid/gameId: %s" % Noray.oid)
	room_id = Noray.oid
	
	is_online = true
	host_connected.emit()
	connection_attempt_finished.emit(OK)
	NetworkManager.log_message("network_connected")

## Server method for handling client connections.
func _handle_noray_client_connect(_address: String, _port: int) -> Error:
	print("Noray host handle connect: %s:%s" % [_address, _port])
	print(multiplayer.multiplayer_peer)
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var err = await PacketHandshake.over_enet(peer.host, _address, _port)
	if err != OK:
		print("Noray packet handshake failed %s" % err)
		connection_attempt_finished.emit(err)
		return err
	
	return OK

## Client method for attempting a NAT Punchthrough.
func _handle_nat_connect(_address: String, _port: int) -> Error:
	if !is_nat_enabled: # NAT was disabled
		print("NAT is disabled. Using relay instead.")
		Noray.connect_relay(room_id)
		return OK
	print("Attempting to connect client via NAT: %s:%s" % [_address, _port])
	var err = await _handle_connect(_address, _port)
	if err != OK:
		print("NAT connection failed from client, trying Relay instead...")
		Noray.connect_relay(room_id)
		return OK
	else:
		print("NAT punchthrough successful!")
	return err

## Client method for attempting a relay connection.
func _handle_relay_connect(_address: String, _port: int) -> Error:
	print("Attempting to connect client via Relay: %s:%s" % [_address, _port])
	return await _handle_connect(_address, _port)

## Client method for handling a successful connection.
func _handle_connect(_address: String, _port: int) -> Error:
	print("Client handle connect to %s:%s, Noray.localport: %s" % [_address, _port, Noray.local_port])
	
	# Do a handshake
	var udp = PacketPeerUDP.new()
	udp.bind(Noray.local_port)
	udp.set_dest_address(_address, _port)
	
	var err = await PacketHandshake.over_packet_peer(udp, 8)
	udp.close()
	
	if err != OK:
		print("Client packet handshake failed %s" % err)
		connection_attempt_finished.emit(err)
		return err
		
	# Connect to host
	var peer = ENetMultiplayerPeer.new()
	err = peer.create_client(_address, _port, 0, 0, 0, Noray.local_port)
	
	if err != OK:
		print("Create client failed %s" % err)
		connection_attempt_finished.emit(err)
		return err
	
	multiplayer.multiplayer_peer = peer
	is_online = true
	client_connected.emit()
	connection_attempt_finished.emit(OK)
	return OK

## Noray host connections.
func setup_host_noray_connection_signals():
	if !Noray.on_connect_nat.is_connected(_handle_noray_client_connect):
		Noray.on_connect_nat.connect(_handle_noray_client_connect)
	if !Noray.on_connect_relay.is_connected(_handle_noray_client_connect):
		Noray.on_connect_relay.connect(_handle_noray_client_connect)

func clean_host_noray_connection_signals():
	if Noray.on_connect_nat.is_connected(_handle_noray_client_connect):
		Noray.on_connect_nat.disconnect(_handle_noray_client_connect)
	if Noray.on_connect_relay.is_connected(_handle_noray_client_connect):
		Noray.on_connect_relay.disconnect(_handle_noray_client_connect)

## Noray client connections.
func setup_client_noray_connection_signals():
	if !Noray.on_connect_nat.is_connected(_handle_nat_connect):
		Noray.on_connect_nat.connect(_handle_nat_connect)
	if !Noray.on_connect_relay.is_connected(_handle_relay_connect):
		Noray.on_connect_relay.connect(_handle_relay_connect)

func clean_client_noray_connection_signals():
	if Noray.on_connect_nat.is_connected(_handle_nat_connect):
		Noray.on_connect_nat.disconnect(_handle_nat_connect)
	if Noray.on_connect_relay.is_connected(_handle_relay_connect):
		Noray.on_connect_relay.disconnect(_handle_relay_connect)

## Client ENet signals 
func setup_client_enet_connection_signals():
	if !multiplayer.server_disconnected.is_connected(_noray_server_disconnected):
		multiplayer.server_disconnected.connect(_noray_server_disconnected)

func clean_client_enet_connection_signals():
	if multiplayer.server_disconnected.is_connected(_noray_server_disconnected):
		multiplayer.server_disconnected.disconnect(_noray_server_disconnected)

## Forcefully disconnects from the server
func force_disconnect() -> void:
	is_online = false
	NetworkManager.log_message("network_disconnected")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	# Clean up signal connections
	clean_host_noray_connection_signals()
	clean_client_enet_connection_signals()
	clean_client_noray_connection_signals()

## Called when the client disconnects from the server.
func _noray_server_disconnected():
	is_online = false
