class_name Attraction extends Node

static var instance : Attraction
@export var minigame_start_animator : AnimationPlayer
@export var minigame_book_animator : AnimationPlayer
@export var attraction_animator : AnimationPlayer
@export var description : DescriptionBox
@export var omochao : CharacterAnimator

var _is_processing_inputs : bool
func enable_inputs() -> void:
	# Only allow inputs if we're not in a popup (otherwise popup menu takes priority)
	_is_processing_inputs = !description._is_menu_processing && !description._is_menu_queued

func disable_inputs() -> void:
	_is_processing_inputs = false

var _players : Array[AttractionPartyCharacter]
func register_player(player : AttractionPartyCharacter) -> void:
	_players.append(player)

func _init() -> void:
	instance = self
	if !PartyManager.is_player_data_initialized():
		PartyManager.initialize_offline_player_data()
		PartyManager.initialize_debug_characters()

func initialize_attraction() -> void:
	pass

func _ready() -> void:
	initialize_attraction()
	description.draw_started.connect(Callable(self, "disable_inputs"))
	description.draw_finished.connect(Callable(self, "enable_inputs"))
	printt("READ Attraction.", NetworkManager.is_online)
	if NetworkManager.is_online:
		NetworkManager.peers_loaded.connect(Callable(self, "request_attraction_start"))
	else:
		request_attraction_start()

func _physics_process(_delta : float) -> void:
	if !NetworkManager.is_hosting_game || !_is_processing_inputs:
		return
	
	if Input.is_action_just_pressed("button_primary1"):
		advance_dialog()

func advance_dialog() -> void:
	pass

func request_attraction_start() -> void:
	print("Starting Attraction.")
	if !NetworkManager.is_hosting_game:
		return
	rpc("start_attraction", NetworkManager.calculate_transition_tick())

@rpc("any_peer", "call_local", "reliable")
func start_attraction(tick : float) -> void:
	await get_tree().create_timer(NetworkTimeSynchronizer.get_time() - tick).timeout
	print("Starting animation.")
	attraction_animator.play("start")
	on_attraction_started()

func on_attraction_started() -> void:
	pass

@export var omochao_minigame_position : Node3D
func start_omochao_minigame_throw() -> void:
	omochao.reparent(omochao_minigame_position)
	omochao.position = Vector3.DOWN * 10
	omochao.visible = true
	var tween : Tween = create_tween()
	tween.tween_property(omochao, "position", Vector3.ZERO, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	omochao.play_animation("backflip")
	omochao.queue_minigame_animation("hover")
	minigame_book_animator.play("RESET")
	minigame_book_animator.advance(0.0)
	tween.tween_callback(Callable(minigame_book_animator, "play").bind("open"))

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
