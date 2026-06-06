class_name Attraction extends Control

static var instance : Attraction

@export var interface_animator : AnimationPlayer
## Subviewport to separate attraction world from minigame worlds.
## Might need to apply transforms in blender to avoid broken orientations.
@export var sub_viewport : SubViewport
@export var minigame_book_animator : AnimationPlayer
@export var attraction_animator : AnimationPlayer
@export var description : DescriptionBox
@export var omochao : CharacterAnimator

## The index of the next queued minigame.
var _minigame_index : int

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

func update_viewport_size() -> void:
	sub_viewport.size = get_tree().root.get_viewport().get_visible_rect().size

func _ready() -> void:
	initialize_attraction()
	
	if !sub_viewport.own_world_3d:
		printerr("Subviewport isn't set to be a unique world! This will cause issues with minigames!")
	update_viewport_size()
	get_tree().root.get_viewport().size_changed.connect(Callable(self, "update_viewport_size"))
	
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
	if !NetworkManager.is_hosting_game:
		return
	rpc("start_attraction", NetworkManager.calculate_transition_tick())

@rpc("any_peer", "call_local", "reliable")
func start_attraction(tick : float) -> void:
	await get_tree().create_timer(NetworkTimeSynchronizer.get_time() - tick).timeout
	attraction_animator.play("start")
	on_attraction_started()

func on_attraction_started() -> void:
	pass

@export var omochao_minigame_position : Node3D
func start_omochao_minigame_throw() -> void:
	omochao.reparent(omochao_minigame_position)
	omochao.transform = Transform3D.IDENTITY
	omochao.position = Vector3.DOWN * 10
	omochao.visible = true
	var tween : Tween = create_tween()
	tween.tween_property(omochao, "position", Vector3.ZERO, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	omochao.play_animation("backflip")
	omochao.queue_minigame_animation("hover")
	minigame_book_animator.play("RESET")
	minigame_book_animator.advance(0.0)
	tween.tween_callback(Callable(minigame_book_animator, "play").bind("open"))

## Queues a random minigame.
func request_queue_minigame() -> void:
	if NetworkManager.is_hosting_game:
		# TODO use actual random index
		# Actual random game: randi_range(0, PartyManager.unlocked_minigame_list.size() - 1))
		rpc("queue_minigame", 7)

@rpc("any_peer", "call_local", "reliable")
func queue_minigame(index : int) -> void:
	_minigame_index = index
	on_minigame_queued()

## Overridable local function called after a minigame is queued.
## Typically you should update the UI here.
func on_minigame_queued() -> void:
	pass

## Loads a queued minigame.
func request_minigame_load() -> void:
	if !NetworkManager.is_hosting_game:
		return
	rpc("load_minigame", _minigame_index)

@rpc("any_peer", "call_local", "reliable")
func load_minigame(minigame_index : int) -> void:
	PartyManager.queued_minigame = PartyManager.unlocked_minigame_list[minigame_index]
	hide_attraction()
	RuleManager.show_menu()
	NetworkManager.attraction_loaded.connect(Callable(self, "show_attraction"), ConnectFlags.CONNECT_ONE_SHOT)

func hide_attraction() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func show_attraction() -> void:
	visible = true
	omochao.visible = false
	process_mode = Node.PROCESS_MODE_INHERIT
	minigame_book_animator.play("RESET")
	minigame_book_animator.advance(0.0)
	interface_animator.play("init")
	interface_animator.advance(0.0)
