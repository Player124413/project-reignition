### Basic behavior for spawning players. Extend this class as necessary.
class_name PartyGameCharacterSpawner extends Node3D

@export var player_index : int
@export var character_animator : CharacterAnimator
@export var score_counter : ScoreCounter
@export var spawn_position : Node3D = self

func _ready() -> void:
	if NetworkManager.is_online && player_index != -1:
		# Set up authority
		var data : PlayerData = PartyManager.get_player_data(player_index)
		if !data.is_cpu_player():
			set_multiplayer_authority(data.device)
	
	if player_index != -1:
		# Instance Player Model
		character_animator = MinigameManager.instance.load_character_model(player_index)
		spawn_position.add_child(character_animator)
		character_animator.play_animation(get_anim_prefix() + "wait")
		
		# TODO Check if this player index is actually being used in duel minigames
		set_physics_process(false)
		MinigameManager.instance.gameplay_started.connect(Callable.create(self, "activate"))
		MinigameManager.instance.gameplay_finished.connect(Callable.create(self, "deactivate"))
		MinigameManager.instance.minigame_finished.connect(Callable.create(self, "on_minigame_finished"))
		
		if player_index == 0 && NetworkManager.is_hosting_game: # Only generate queue on player 1
			MinigameManager.instance.peers_loaded.connect(Callable(self, "generate_pitch_queue"))
		
		if is_instance_valid(score_counter):
			# Initialize the score counter
			score_counter.set_player_index(player_index)
	else:
		# This is a demo character
		on_demo_spawned()
	
	character_animator.connect("animation_event", Callable.create(self, "process_animation_event"))
	on_spawn_finished()

## Called after spawn logic has finished.
func on_spawn_finished() -> void:
	pass

## Called after a demo object has spawned. Default behavior: hide the demo object.
func on_demo_spawned() -> void:
	# Hide demo batting station after gameplay starts
	MinigameManager.instance.gameplay_started.connect(Callable.create(self, "set_visible").bind(false))

## Gets the animation prefix for minigame animations.
func get_anim_prefix() -> String:
	if player_index == -1:
		return "%02d-" % MinigameManager.instance.minigame_resource.minigame_index
	
	return "%s/" % MinigameManager.ANIMATION_LIBRARY_PREFIX

## Called when recieving an animation event. Override in subclass.
func animation_event() -> void:
	print("Received unhandled animation event.")
