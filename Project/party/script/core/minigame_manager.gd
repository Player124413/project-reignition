### Instance this node into every minigame.
class_name MinigameManager extends Node

static var instance : MinigameManager

## Emitted when all network peers are ready to start the game. Start gameplay demos or call start_minigame() here.
signal peers_loaded
## Start reading player inputs and processing cpu players here. 
signal gameplay_started
## Stop processing players here.
signal gameplay_finished
## Teleport players to their results position here.
signal minigame_finished
## Character Animators will play their result animations when this signal emits.
signal results_started

@export_group("Minigame Settings")
## How should the screen be set up for this mini-game?
@export var screen_mode : SCREEN_MODE
enum SCREEN_MODE {
	SHARED, # A single screen for everybody. Use this for sequential or group mini-games.
	SPLITSCREEN # Each player gets a corner of the screen. Use this for simultaneous screens.
}

## Demo transition. Only used when splitscreen is active.
@export var demo_transition_mode : DEMO_TRANSITION
enum DEMO_TRANSITION {
	NONE, # Start with screen already split
	FULLSCREEN, # Show a fullscreen demo first (normally played by a majin)
}

## Library to attach to player animators when adding them to the scene
@export var anim_library : AnimationLibrary
const ANIMATION_LIBRARY_PREFIX : String = "MINIGAME"

## Option camera to use for the results screen.
@export var results_camera : Camera3D

@export_group("Manager Attributes")
@export var splitscreen_parent : Control
@export var animator : AnimationPlayer

## Where to spawn players.
@export var subviewport_worlds : Array[SubViewport]
## Where to spawn players during the results screen.
@export var results_location : Array[Node3D]
## Labels for the mini-game winners.
@export var winner_labels : Array[SyncedLabel]

## Number of players that have completed the current mini-game.
var completed_player_count : int
## Tracks the player's scores.
var player_scores : Array[int]

func _init() -> void:
	instance = self
	
	player_scores.resize(PartyManager.MAX_PLAYER_COUNT)
	if !PartyManager.is_player_data_initialized():
		PartyManager.initialize_offline_player_data()
		initialize_debug_characters()

func _ready() -> void:
	# TODO Change splitscreen mode if in Tournament Palace (2 players)
	animator.play("free-for-all")
	animator.advance(0.0)
	
	if screen_mode == SCREEN_MODE.SHARED || demo_transition_mode == DEMO_TRANSITION.FULLSCREEN:
		animator.play("demo-init") # NOTE: This animation is the same as a split-screen demo.
		animator.advance(0.0)
	NetworkManager.party_game_started.connect(Callable(self, "start_party_game"))

func _exit_tree() -> void:
	if NetworkManager.party_game_started.is_connected(Callable(self, "start_party_game")):
		NetworkManager.party_game_started.disconnect(Callable(self, "start_party_game"))

func start_party_game() -> void:
	peers_loaded.emit()

## Called when running a mini-game from the editor. Loads 4 default characters.
func initialize_debug_characters() -> void:
	print("Initializing default characters for debug mode.")
	for i in PartyManager.MAX_PLAYER_COUNT:
		# Simply add characters based on their index order
		var character_data : PartyCharacterResource = PartyManager._character_data.get(i)
		PartyManager.set_character_data(i, character_data.character_name)
		PartyManager.set_player_indexes(i, i, 1 if i == 0 else 0, 1) # Set everyone to a cpu except for p1
		if i > 0:
			PartyManager.set_difficulty(i, i)

func load_character_model(player_index : int) -> CharacterAnimator:
	var scene : PackedScene = load(PartyManager.get_player_data(player_index).character_data.model_file) as PackedScene
	var character : CharacterAnimator = scene.instantiate() as CharacterAnimator
	if anim_library != null:
		character.load_animation_library(ANIMATION_LIBRARY_PREFIX, anim_library)
	return character

## Plays an animation, synced across the network.
@rpc("any_peer", "call_local", "reliable")
func play_animation(anim : String) -> void:
	animator.play(anim)

func request_score_change(player_index : int, amount : int = 1) -> void:
	if player_index < 0 || player_index > PartyManager.MAX_PLAYER_COUNT:
		return
	rpc("_change_score", player_index, amount)

## Changes the score of a player.
@rpc("any_peer", "call_local", "reliable")
func _change_score(player_index : int, amount : int) -> void:
	player_scores[player_index] += amount
	print("Adding %s score to player %s. TOTAL: %s." % [amount, player_index, player_scores[player_index]])

## Adds one completed player and checks whether we should finish the mini-game.
func register_completed_player() -> void:
	completed_player_count += 1
	if completed_player_count == PartyManager.MAX_PLAYER_COUNT:
		finish_minigame()

func request_minigame_start() -> void:
	print("Starting Minigame!")
	if !NetworkManager.is_online || NetworkManager.is_hosting_game:
		rpc("start_minigame", NetworkManager.calculate_transition_tick())

## Plays the "START!" animation.
@rpc("any_peer", "call_local", "reliable")
func start_minigame(tick : float) -> void:
	var target_animation : String = "minigame-start"
	if screen_mode == SCREEN_MODE.SPLITSCREEN && demo_transition_mode == DEMO_TRANSITION.FULLSCREEN:
		target_animation = "demo-fade" # Transition to split-screen
	
	var callable : Callable = Callable(self, "play_animation").bind(target_animation)
	get_tree().create_timer(NetworkManager.calculate_transition_delay(tick)).timeout.connect(callable)

## Plays the "GAME SET!" animation, then starts the results screen.
func finish_minigame() -> void:
	gameplay_finished.emit()
	rpc("play_animation", "minigame-finish")

## Emits the signal to actually enable gameplay objects.
func on_gameplay_started() -> void:
	gameplay_started.emit()

## Emits the signal to teleport players to the results screen.
func on_minigame_finished() -> void:
	minigame_finished.emit()
	splitscreen_parent.visible = false # Hide splitscreen stuff
	if results_camera != null:
		results_camera.make_current()

# Calculate the minigame winners and plays the proper results screen.
func start_results() -> void:
	if NetworkManager.is_online && !NetworkManager.is_hosting_game:
		return
	
	var rankings : Array[int]
	rankings.resize(PartyManager.MAX_PLAYER_COUNT)
	
	var is_tie : bool = check_tie()
	print(is_tie)
	if is_tie: # Force everyone to lose if it's a tie.
		for i in rankings.size():
			rankings[i] = PartyManager.MAX_PLAYER_COUNT # This forces everybody to "lose."
	else: # Figure out the proper placement for each player
		for i in player_scores.size():
			var rank : int = 0
			for j in i:
				if player_scores[j] > player_scores[i]:
					rank += 1
				elif player_scores[j] < player_scores[i]:
					rankings[j] += 1
			rankings[i] = rank
	
	# Store rankings to PartyManager
	for i in PartyManager.MAX_PLAYER_COUNT:
		PartyManager.rpc("set_minigame_placement", i, rankings[i])
	
	if !is_tie:
		rpc("update_win_text")
	rpc("play_animation", "results-draw" if is_tie else "results-win") # Play the correct results animation

## Returns true if everybody has the same score.
func check_tie() -> bool:
	for i in range(1, player_scores.size()): # Check all scores against P1's score
		if player_scores[i] != player_scores[0]:
			return false
	return true

## Updates the names of the winners for the results screen.
@rpc("any_peer", "call_local", "reliable")
func update_win_text() -> void:
	var label_index : int = 0
	for i in PartyManager.MAX_PLAYER_COUNT:
		var data : PlayerData = PartyManager.get_player_data(i)
		print("Player %s placed %s with a score of %s." % [data.character_data.character_name, data.minigame_placement, player_scores[i]])
		if data.minigame_placement != 0:
			continue
		winner_labels[label_index].set_synced_text(data.character_data.character_name)
		label_index += 1
	
	for i in range(label_index, winner_labels.size()):
		winner_labels[i].modulate = Color.TRANSPARENT # Hide unused labels
	animator.play("results-solo-winner" if label_index <= 1 else "results-multi-winner")
	animator.advance(0.0)

func on_results_started() -> void:
	results_started.emit()

## Cleans up all nodes related to this particular mini-game.
func free_minigame() -> void:
	get_parent().queue_free() # NOTE: This function expects that the minigame manager is a direct child of the mini-game scene.
