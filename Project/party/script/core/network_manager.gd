### Manages creating servers and adding clients.
extends Node

## Emitted when the host successfully connects.
signal host_connected
## Emitted when a client successfully connects.
signal client_connected

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

func _ready() -> void:
	initialize_loggers()

func initialize_loggers() -> void:
	for i in LOGGER_COUNT:
		var new_log : Control = log_scene.instantiate()
		loggers.append(new_log)
		log_parent.add_child(new_log)

func log_message(localization_key : StringName) -> void:
	loggers[current_log_index].log_message(localization_key)
	log_parent.move_child(loggers[current_log_index], 0)
	current_log_index = current_log_index + 1 % LOGGER_COUNT

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
	print("create Noray client peer")
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
		return err
		
	# Register host
	Noray.register_host()
	await Noray.on_pid
	
	# Register remove address
	err = await Noray.register_remote()
	if err != OK:
		print("Failed to register remote %s" % err)
		return err
	
	print("Finished Noray registration")

## Starts the Noray host.
func _start_noray_host():
	print("Starting Noray host")
	var noray_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err = noray_network_peer.create_server(Noray.local_port)
	multiplayer.multiplayer_peer = noray_network_peer
	if err != OK:
		print("Failed to listen on port %s with error: %s" % [Noray.local_port, err])
		return
	
	# Capture room_id to display on host-peer for sharing with others
	print("Noray oid/gameId: %s" % Noray.oid)
	room_id = Noray.oid
	
	is_online = true
	host_connected.emit()
	NetworkManager.log_message("network_connected")

## Server method for handling client connections.
func _handle_noray_client_connect(_address: String, _port: int) -> Error:
	print("Noray host handle connect: %s:%s" % [_address, _port])
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var err = await PacketHandshake.over_enet(peer.host, _address, _port)
	if err != OK:
		print("Noray packet handshake failed %s" % err)
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
		return err
		
	# Connect to host
	var peer = ENetMultiplayerPeer.new()
	err = peer.create_client(_address, _port, 0, 0, 0, Noray.local_port)
	
	if err != OK:
		print("Create client failed %s" % err)
		return err
	
	multiplayer.multiplayer_peer = peer
	is_online = true
	client_connected.emit()
	return OK

## Noray host connections.
func setup_host_noray_connection_signals():
	Noray.on_connect_nat.connect(_handle_noray_client_connect)
	Noray.on_connect_relay.connect(_handle_noray_client_connect)

## Noray client connections.
func setup_client_noray_connection_signals():
	Noray.on_connect_nat.connect(_handle_nat_connect)
	Noray.on_connect_relay.connect(_handle_relay_connect)

## Client ENet signals 
func setup_client_enet_connection_signals():
	multiplayer.server_disconnected.connect(_noray_server_disconnected)

## Called when the client disconnects from the server.
func _noray_server_disconnected():
	is_online = false
	NetworkManager.log_message("network_disconnected")
