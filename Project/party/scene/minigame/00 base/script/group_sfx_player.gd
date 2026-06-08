### Plays a sound effect but adjusts volume based on the number of other sfx in the group is playing.
class_name GroupSfxPlayer extends AudioStreamPlayer

@export var group : String
@export_range(0.0, 1.0, 0.1, "or_greater") var base_volume : float = 1.0
@export_range(0.0, 1.0, 0.1, "or_greater") var max_volume : float = 1.0
@export_range(0.0, 1.0, 0.1) var min_volume : float = 0.2
## How long to prevent playing other sound effects from this same group.
@export_range(0.0, 1.0, 0.1) var lockout_time : float = 0.0

func _ready() -> void:
	finished.connect(Callable(self, "stop_in_group"))

func play_in_group() -> void:
	if playing && max_polyphony == 1:
		return
	
	if !is_zero_approx(lockout_time) && GroupSfxManager.instance.is_group_locked(group, lockout_time):
		return
	
	print("Playing audio!")
	GroupSfxManager.instance.register_player(self, group)
	play()

func set_volume(volume : float) -> void:
	volume *= base_volume
	volume = clamp(volume, min_volume, max_volume)
	volume_linear = volume

func stop_in_group() -> void:
	GroupSfxManager.instance.unregister_player(self, group)
	stop()
