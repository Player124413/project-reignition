### Represents a player in the Weight Puzzle minigame.
extends PartyGameCharacterSpawner

@export var coin_box: Node3D
@export var weight_platform2: Node3D
@export var weight_animator: AnimationPlayer
@export var debug_label: Label3D

##The current number of coins in the bucket
var num_coins: int

##The amount of coins needed to win the minigame
const COINS_TO_REACH: int = 50

func on_spawn_finished() -> void:
	super()

	character_animator.play_animation("%s/19-lift-wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)

func _process(delta: float) -> void:
	debug_label.text = str(num_coins)
