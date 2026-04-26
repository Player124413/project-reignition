extends Control

## The amount of time this minigame should take.
@export var max_game_time : int = 60
@export var time_label : SyncedLabel
@export var animation_player : AnimationPlayer

## The current time left.
var current_time : float
## The amount of time displayed on the label.
var display_time : int

func _ready() -> void:
	visible = false
	current_time = max_game_time
	set_display_time(ceil(current_time))
	
	MinigameManager.instance.gameplay_started.connect(Callable.create(self, "on_gameplay_started"))
	MinigameManager.instance.minigame_finished.connect(Callable.create(self, "on_minigame_finished"))

func _physics_process(_delta: float) -> void:
	if !visible:
		return
	
	current_time -= get_physics_process_delta_time()
	set_display_time(ceil(current_time))
	if current_time < 0:
		set_physics_process(false)
		if is_multiplayer_authority():
			MinigameManager.instance.finish_minigame()

func set_display_time(value : int) -> void:
	if display_time == value:
		return
	
	display_time = value
	time_label.set_synced_text("%02d" % display_time)
	if display_time < 10:
		animation_player.play("countdown")
		animation_player.seek(0.0, true)

func on_gameplay_started() -> void:
	visible = true

func on_minigame_finished() -> void:
	visible = false
