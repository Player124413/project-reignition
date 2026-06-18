### Score Counter for Party Games. 
class_name RaceTracker extends TextureRect

@export_group("Settings")
@export var enable_reorder : bool
@export var display_mode : DISPLAY_MODES
enum DISPLAY_MODES {
	LAP,
	PERCENT,
}
@export_group("Components")
@export var progress_label : SyncedLabel
@export var position_label : SyncedLabel
@export var character_texture_rect : TextureRect
@export var animator : AnimationPlayer

## Static arrays that stores the local progress of each player.
## Used to get player's approximate progress without sending positions over the network every frame.
static var player_laps : PackedInt64Array
static var player_percentages : PackedFloat64Array
static var player_progresses : PackedFloat64Array

var _player_index : int = -1

func _ready() -> void:
	get_parent().child_order_changed.connect(Callable(self, "update_animation"))
	visible = false
	if player_laps.size() != PartyManager.MAX_PLAYER_COUNT:
		player_laps.resize(PartyManager.MAX_PLAYER_COUNT)
	if player_percentages.size() != PartyManager.MAX_PLAYER_COUNT:
		player_percentages.resize(PartyManager.MAX_PLAYER_COUNT)
	if player_progresses.size() != PartyManager.MAX_PLAYER_COUNT:
		player_progresses.resize(PartyManager.MAX_PLAYER_COUNT)

## Sets the player index and links the on_score_updated signal.
func initialize_race_tracker(player_index : int) -> void:
	_player_index = player_index
	var character_data : PartyCharacterResource = PartyManager.get_player_data(_player_index).character_data
	character_texture_rect.texture = character_data.score_portrait
	player_laps[_player_index] = 0
	player_percentages[_player_index] = 0
	player_progresses[_player_index] = 0
	if PartyManager.minigame_players.has(_player_index):
		MinigameManager.instance.gameplay_started.connect(Callable.create(self, "on_gameplay_started"))
		MinigameManager.instance.results_started.connect(Callable.create(self, "on_results_started"))
	MinigameManager.instance.on_score_updated.connect(Callable(self, "on_score_updated"))

## Updates the percentage of this tracker.
func set_progress_percent(percent : float) -> void:
	player_percentages[_player_index] = percent
	if display_mode == DISPLAY_MODES.PERCENT:
		progress_label.text = "%02d%" % floori(percent * 100.0)

## Updates the lap of this tracker.
func set_progress_lap(curr_lap : int, total_lap : int) -> void:
	player_laps[_player_index] = curr_lap
	curr_lap = max(curr_lap, 1) # Don't display less than lap 1
	if display_mode == DISPLAY_MODES.LAP:
		progress_label.set_synced_text(tr("party_lap").replace("[C]", str(curr_lap)).replace("[T]", str(total_lap)))

## Updates the raw progress of this tracker.
func set_progress_raw(progress : float) -> void:
	player_progresses[_player_index] = progress
	if enable_reorder:
		var index : int = 0
		for i in player_progresses.size():
			if i == _player_index || player_progresses[i] < player_progresses[_player_index]:
				continue
			index += 1
		if index != get_index():
			get_parent().move_child(self, index)
			update_animation()

func update_animation() -> void:
	var index : int = get_index()
	animator.play("winning" if index == 0 else "losing")
	position_label.set_synced_text("party_placement%s" % (index + 1))

func on_gameplay_started() -> void:
	visible = true
	update_animation()

func on_results_started() -> void:
	visible = false
