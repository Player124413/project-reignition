### Plays a sound effect but adjusts volume based on the number of other sfx in the group is playing.
class_name GroupSfxPlayer extends AudioStreamPlayer

@export var group : String
@export_range(0.0, 1.0, 0.1, "or_greater") var base_volume : float = 1.0
@export_range(0.0, 1.0, 0.1, "or_greater") var max_volume : float = 1.0
@export_range(0.0, 1.0, 0.1) var min_volume : float = 0.2
static var sfx_dictionary : Dictionary

func _ready() -> void:
	finished.connect(Callable(self, "stop_in_group"))
	tree_exiting.connect(Callable(self, "stop_in_group"))

func play_in_group() -> void:
	if !sfx_dictionary.has(group):
		sfx_dictionary.get_or_add(group, [self])
	else:
		sfx_dictionary[group].append(self)
		# Adjust volume of all in group
		var volume : float = 1.0 / sfx_dictionary[group].size()
		for sfx_player : GroupSfxPlayer in sfx_dictionary[group]:
			sfx_player.set_volume(volume)
	play()

func set_volume(volume : float) -> void:
	volume *= base_volume
	volume = clamp(volume, min_volume, max_volume)
	volume_linear = volume

func stop_in_group() -> void:
	stop()
	if !sfx_dictionary.has(group):
		return
	
	var index : int = sfx_dictionary[group].find(self)
	if index != -1:
		sfx_dictionary[group].remove_at(index)
		if sfx_dictionary[group].size() == 0:
			sfx_dictionary.erase(group)

func calculate_max_volume() -> float:
	return base_volume;
