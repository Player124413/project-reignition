### Interface for handling animations of a party character.
class_name CharacterAnimator extends Node3D

signal animation_event(info : int)

@export var skeleton : Skeleton3D
@export var animator : AnimationPlayer
@export var data : PartyCharacterResource

## Emitted after the select animation finishes. Emitted from aniamtion.
@warning_ignore("unused_signal")
signal select_finished

## The index of this character
var player_index : int

# TODO Add support for more complex character animations

func _ready() -> void:
	player_index = PartyManager.get_character_index(data)
	
	if player_index == -1:
		return
	
	if MinigameManager.instance != null && data != null:
		MinigameManager.instance.minigame_finished.connect(Callable.create(self, "on_minigame_finished"))
		MinigameManager.instance.results_started.connect(Callable.create(self, "on_results_started"))

## Emits a signal from an animation. Use this to send data to the generic minigame controller.
func emit_animation_event(info : int) -> void:
	emit_signal("animation_event", info)

## Plays a specific animation on the animator.
func play_animation(anim : StringName) -> void:
	if animator == null || !animator.has_animation(anim):
		return
	animator.play(anim)
	animator.seek(0.0, true)

## Plays a specific mini-game animation on the animator.
@rpc("any_peer", "call_local", "reliable")
func play_minigame_animation(anim : StringName, blend : float = 0.0, speed : float = 1.0, tick : float = 0.0) -> void:
	if animator == null || !animator.has_animation(anim):
		return
	
	var seek : float = 0.0
	if !is_zero_approx(tick):
		seek = NetworkTimeSynchronizer.get_time() - tick
	animator.seek(seek, true)
	animator.play("%s" % anim, blend, speed)

## Seeks an animation to the given network tick.
func network_seek(original_tick : float) -> void:
	if !NetworkManager.is_online:
		return
	animator.seek(NetworkTimeSynchronizer.get_time() - original_tick, true)

func queue_minigame_animation(anim : StringName, blend : float = 0.0) -> void:
	animator.set_blend_time(animator.assigned_animation, anim, blend)
	animator.queue(anim)

## Warps this animator to the correct results location.
func on_minigame_finished() -> void:
	if player_index == -1:
		return
	
	reparent(MinigameManager.instance.results_location[player_index])
	transform = Transform3D.IDENTITY
	play_animation("idle") # TODO Switch to boat anims if needed

## Play victory or loss animation
func on_results_started() -> void:
	if player_index == -1:
		return
	
	if PartyManager.get_player_data(player_index).minigame_placement == 0:
		play_animation("win")
	else:
		play_animation("lose")

## Loads a given animation library to the animator.
func load_animation_library(library_name : String, library : AnimationLibrary) -> void:
	animator.add_animation_library(library_name, library);
