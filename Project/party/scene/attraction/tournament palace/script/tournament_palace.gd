extends Attraction

## Positions of players when choosing the rules.
@export var rule_positions : Array[Node3D]
@export var entry_positions : Array[Node3D]
@export var balcony_parents : Array[Node]
@export var player_labels : Array[SyncedLabel]

var bracket_order : Array[int]
var balcony_data : Array[BalconyData]

var current_state : STATE
var dialog_index : int
enum STATE {
	INTRO,
	EXPLAIN,
	RULES,
	GAME,
	REPLAY
}

func initialize_attraction() -> void:
	# For editor start
	PartyManager.current_mode = PartyManager.CURRENT_MODE_ENUM.TOURNAMENT_PALACE
	
	# Load balconies
	for i in balcony_parents.size():
		# All balconies have the same node structure.
		var new_data : BalconyData = BalconyData.new()
		if balcony_parents[i].has_node("Balcony"):
			new_data.balcony_animator = balcony_parents[i].get_node("Balcony/AnimationPlayer")
		new_data.door_animator = balcony_parents[i].get_node("Door/AnimationPlayer")
		new_data.player_position = balcony_parents[i].get_node("PlayerPosition")
		balcony_data.append(new_data)
	
	if NetworkManager.is_hosting_game:
		# Determine bracket order
		for i in _players.size():
			bracket_order.append(i)
		bracket_order.shuffle()

func enable_inputs() -> void:
	super()
	if !description._is_drawing:
		omochao.play_animation("select", false, 0.2)

func disable_inputs() -> void:
	super()
	if description._is_drawing:
		omochao.play_animation("talk", false, 0.2)

func on_attraction_started() -> void:
	for i in _players.size():
		_players[i].request_movement(rule_positions[i].global_position, false)


func start_omochao() -> void:
	if !NetworkManager.is_hosting_game:
		return
	description.rpc("show_description")
	description.rpc("set_text", "tp_intro_1")
	enable_inputs()

func advance_dialog() -> void:
	dialog_index += 1
	description.disconnect_all_signals()
	var max_index : int = calculate_max_dialog_index()
	if dialog_index > max_index:
		current_state = (current_state + 1) as STATE
		dialog_index = 1
	
	if current_state == STATE.EXPLAIN || current_state == STATE.RULES:
		var show_dialog_box : bool = dialog_index == 1
		if current_state == STATE.EXPLAIN:
			if show_dialog_box:
				description.connect("confirmed", Callable(self, "advance_dialog"), CONNECT_ONE_SHOT)
				description.connect("cancelled", Callable(self, "skip_explanation"), CONNECT_ONE_SHOT)
			description.rpc("set_text", "tp_explain_%s" % dialog_index, show_dialog_box)
		else:
			if show_dialog_box:
				description.connect("confirmed", Callable(self, "show_rules"), CONNECT_ONE_SHOT)
				description.connect("cancelled", Callable(self, "start_gameplay"), CONNECT_ONE_SHOT)
			description.rpc("set_text", "tp_rule_%s" % dialog_index, show_dialog_box)
	
func skip_explanation() -> void:
	dialog_index += EXPLAIN_LENGTH
	advance_dialog()

func start_gameplay() -> void:
	current_state = STATE.GAME
	disable_inputs()
	rpc("start_first_floor_preview", NetworkTimeSynchronizer.get_time())
	for i in _players.size():
		if i > 0:
			await get_tree().create_timer(0.3, false, true).timeout # Prevent players from crowding entry
		_players[i].request_movement(entry_positions[0].global_position, true, rule_positions[i].global_position)
		_players[i].request_movement(entry_positions[1].global_position, true, entry_positions[0].global_position)

@rpc("any_peer", "call_local", "reliable")
func start_first_floor_preview(tick : float) -> void:
	attraction_animator.play("first-floor")
	attraction_animator.seek(NetworkTimeSynchronizer.get_time() - tick)
	description.hide_description()

const EXPLAIN_LENGTH : int = 4
const RULE_LENGTH : int = 3
func calculate_max_dialog_index() -> int:
	if current_state == STATE.EXPLAIN:
		return EXPLAIN_LENGTH
	if current_state == STATE.RULES:
		return RULE_LENGTH
	return 0

func show_first_floor_player(balcony_index : int) -> void:
	balcony_data[balcony_index].door_animator.play("open")
	var end_pos : Vector3 = balcony_data[balcony_index].player_position.global_position
	var start_pos : Vector3 = end_pos + Vector3.FORWARD * 30
	var pre_fight_callable : Callable = Callable(self, "first_floor_prefight").bind(bracket_order[balcony_index])
	_players[bracket_order[balcony_index]].movement_finished.connect(pre_fight_callable)
	_players[bracket_order[balcony_index]]._end_rotation = 0
	_players[bracket_order[balcony_index]].global_rotation = Vector3.ZERO
	_players[bracket_order[balcony_index]].cancel_movement()
	if NetworkManager.is_hosting_game:
		_players[bracket_order[balcony_index]].request_movement(end_pos, false, start_pos)
		_players[bracket_order[balcony_index]].request_rotation(0)

func first_floor_prefight(player_index : int) -> void:
	_players[player_index].character_animator.play_animation("fight", false, 0.1)
	_players[player_index].character_animator.play_voice("select")

## Starts a round between the two players
func start_round(round_index : int) -> void:
	var p1 : int = 0
	var p2 : int = 0
	if round_index == 1:
		p1 = bracket_order[0]
		p2 = bracket_order[1]
	
	PartyManager.set_minigame_players([p1, p2])
	player_labels[0].set_synced_text(PartyManager.get_player_data(p1).character_data.character_name)
	player_labels[1].set_synced_text(PartyManager.get_player_data(p2).character_data.character_name)
	var offset : Vector3 = _players[p1].global_position - _players[p2].global_position
	var angle : float = Vector3.FORWARD.signed_angle_to(offset, Vector3.UP)
	_players[p1].start_rotation(angle, NetworkTimeSynchronizer.get_time())
	_players[p1].character_animator.play_animation("fight", true)
	offset *= -1
	angle = Vector3.FORWARD.signed_angle_to(offset, Vector3.UP)
	_players[p2].start_rotation(angle, NetworkTimeSynchronizer.get_time())
	_players[p2].character_animator.play_animation("fight", true)
	minigame_start_animator.play("start")

class BalconyData:
	var balcony_animator : AnimationPlayer
	var door_animator : AnimationPlayer
	var player_position : Node3D
