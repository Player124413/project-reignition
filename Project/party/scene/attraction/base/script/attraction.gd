class_name Attraction extends Node

static var instance : Attraction
@export var attraction_animator : AnimationPlayer

var _players : Array[AttractionPartyCharacter]

func register_player(player : AttractionPartyCharacter) -> void:
	_players.append(player)

func _init() -> void:
	instance = self
	if !PartyManager.is_player_data_initialized():
		PartyManager.initialize_offline_player_data()
		PartyManager.initialize_debug_characters()
	
	initialize_attraction()

func initialize_attraction() -> void:
	pass

func _ready() -> void:
	if NetworkManager.is_online:
		NetworkManager.peers_loaded.connect(Callable(self, "request_game_start"))
	else:
		request_game_start()

func request_game_start() -> void:
	if !NetworkManager.is_hosting_game:
		return
	rpc("start_game", NetworkManager.calculate_transition_tick())

@rpc("any_peer", "call_local", "reliable")
func start_game(tick : float) -> void:
	await get_tree().create_timer(NetworkTimeSynchronizer.get_time() - tick).timeout
	attraction_animator.play("start")
	on_game_started()

func on_game_started() -> void:
	pass

## Loads a random minigame.
func request_minigame_load() -> void:
	rpc("load_minigame", PartyManager.get_random_minigame())

@rpc("any_peer", "call_local", "reliable")
func load_minigame(minigame_index : int) -> void:
	#PartyManager.queued_minigame = minigame_list[minigame_index]
	#hide_menu()
	#disable_processing()
	RuleManager.cancelled.connect(Callable(self, "show_menu"), ConnectFlags.CONNECT_ONE_SHOT)
	RuleManager.show_menu()
	NetworkManager.attraction_loaded.connect(Callable(self, "show_menu"), ConnectFlags.CONNECT_ONE_SHOT)
