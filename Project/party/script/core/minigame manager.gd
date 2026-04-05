### Instance this node into every minigame.
class_name MinigameManager extends Node

static var instance : MinigameManager

## Emitted when all network peers are loaded and are ready to start the game.
signal peers_loaded
## Emitted when the players can actually start playing the game.
signal gameplay_started

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

@export_group("Manager Attributes")
@export var animator : AnimationPlayer

## Where to spawn players.
@export var subviewport_worlds : Array[SubViewport]

func _init() -> void:
	instance = self
	
	if !PartyManager.is_player_data_initialized():
		PartyManager.initialize_offline_player_data()
		initialize_debug_characters()

func _ready() -> void:
	# TODO Change splitscreen mode if in Tournament Palace (2 players)
	if screen_mode == SCREEN_MODE.SHARED || demo_transition_mode == DEMO_TRANSITION.FULLSCREEN:
		animator.play("demo-init") # NOTE: This animation is the same as a split-screen demo.
	
	# TODO Wait for peers to connect when online
	if !NetworkManager.is_online:
		peers_loaded.emit()

## Starts the "START!" animation that plays before each mini-game.
func start_minigame() -> void:
	if screen_mode == SCREEN_MODE.SPLITSCREEN && demo_transition_mode == DEMO_TRANSITION.FULLSCREEN:
		animator.play("demo-fade") # Transition to split-screen
	else:
		pass # TODO Play "START!" animation

## Emits the signal to actually enable gameplay objects.
func on_minigame_started() -> void:
	gameplay_started.emit()

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
func play_animation(anim : String) -> void:
	# TODO Sync across network
	animator.play(anim)

## Cleans up all nodes related to this particular mini-game.
func free_minigame() -> void:
	get_parent().queue_free() # NOTE: This function expects that the minigame manager is a direct child of the mini-game scene.
