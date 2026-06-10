extends Attraction

## Positions of players when choosing the rules.
@export var rule_positions : Array[Node3D]
@export var entry_positions : Array[Node3D]
@export var balcony_parents : Array[Node]
@export var player_labels : Array[SyncedLabel]
@export var round_label : SyncedLabel
@export var placement_label : SyncedLabel
@export var winner_label : SyncedLabel
@export var minigame_label : Label
@export var score_counter_p1 : TournamentPalaceWinCounter
@export var score_counter_p2 : TournamentPalaceWinCounter
@export var setting_menu : AttractionSettingMenu

@export var fall_shatter_sfx : AudioStreamPlayer
@export var fall_impact_sfx : AudioStreamPlayer
@export var daze_vfx : GPUParticles3D

## Tracks which balcony each player is at.
var balcony_indexes : Array[int]
var balcony_data : Array[BalconyData]

####################
##### Settings #####
####################
## Number of wins needed to progress through the bracket.
var win_count : int = 2
## Watch cpu players' games?
var view_cpu : bool = true

func initialize_setting_menu() -> void:
	setting_menu.options[0].set_selection(win_count - 1)
	setting_menu.options[1].set_selection(0 if view_cpu else 1)
	setting_menu.selection_changed.connect(Callable(self, "change_setting"))

func change_setting(selection : Vector2i) -> void:
	if selection.y == 0:
		win_count = selection.x + 1
	elif selection.y == 1:
		view_cpu = selection.x == 0

## Final results, from loser to winner.
var final_results : PackedInt32Array

func request_minigame_load() -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	# Comment this block out if you want to skip all minigames for debugging.
	if view_cpu || !PartyManager.get_player_data(p1).is_cpu_player() || !PartyManager.get_player_data(p2).is_cpu_player():
		super()
		return
	
	# Skip cpu games.
	var p1_placement : int = -PartyManager.get_player_data(p1).cpu_difficulty
	var p2_placement : int = -PartyManager.get_player_data(p2).cpu_difficulty
	if p1_placement == p2_placement:
		p1_placement += 1 if randf() > 0.5 else -1
	rpc("on_cpu_minigame_skipped", p1_placement, p2_placement)

@rpc("any_peer", "call_local", "reliable")
func on_cpu_minigame_skipped(p1_placement : int, p2_placement : int) -> void:
	PartyManager.set_minigame_placement(p1, p1_placement)
	PartyManager.set_minigame_placement(p2, p2_placement)
	await get_tree().create_timer(1, false, true).timeout
	show_attraction()

################
##### DATA #####
################
var p1 : int
var p2 : int
## Tracks which fight we're doing in the bracket.
var bracket_index : int
## Tracks which round we're on for the current index.
var round_index : int

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
			balcony_indexes.append(i)
		balcony_indexes.shuffle()
		rpc("send_balcony_indexes", balcony_indexes)

@rpc("any_peer", "call_remote", "reliable")
func send_balcony_indexes(indexes : Array[int]) -> void:
	balcony_indexes = indexes

func start_omochao_minigame_throw() -> void:
	if round_index != 1:
		_players[p1].character_animator.play_animation("fight", true)
		_players[p2].character_animator.play_animation("fight", true)
	super()

func enable_inputs() -> void:
	super()
	if !description._is_drawing:
		omochao.play_animation("select", false, 0.2)

func disable_inputs() -> void:
	super()
	if description._is_drawing:
		omochao.play_animation("talk", false, 0.2)

func on_attraction_started() -> void:
	initialize_setting_menu()
	for i in _players.size():
		_players[i].request_movement(rule_positions[i].global_position, false)

func start_omochao() -> void:
	if !NetworkManager.is_hosting_game:
		return
	description.rpc("show_description")
	description.rpc("set_text", "tp_intro_1")
	omochao.play_voice("attraction intro")
	disable_inputs()

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
				description.confirmed.connect(Callable(self, "advance_dialog"), CONNECT_ONE_SHOT)
				description.cancelled.connect(Callable(self, "skip_explanation"), CONNECT_ONE_SHOT)
			description.rpc("set_text", "tp_explain_%s" % dialog_index, show_dialog_box)
		else:
			if show_dialog_box:
				description.confirmed.connect(Callable(self, "request_show_settings"), CONNECT_ONE_SHOT)
				description.cancelled.connect(Callable(self, "request_start_gameplay"), CONNECT_ONE_SHOT)
			description.rpc("set_text", "tp_rule_%s" % dialog_index, show_dialog_box)

func request_show_settings() -> void:
	if NetworkManager.is_hosting_game:
		rpc("show_settings")

@rpc("any_peer", "call_local", "reliable")
func show_settings() -> void:
	setting_menu.menu_finished.connect(Callable(self, "request_start_gameplay"), CONNECT_ONE_SHOT)
	description.hide_description()
	description.disconnect_all_signals()
	setting_menu.show_menu()
	disable_inputs()

func skip_explanation() -> void:
	description.disconnect_all_signals()
	dialog_index += EXPLAIN_LENGTH
	advance_dialog()

func request_start_gameplay() -> void:
	description.disconnect_all_signals()
	if !NetworkManager.is_hosting_game:
		return
	rpc("start_gameplay", NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func start_gameplay(tick : float) -> void:
	current_state = STATE.GAME
	score_counter_p1.set_max_win(win_count)
	score_counter_p2.set_max_win(win_count)
	disable_inputs()
	attraction_animator.play("first-floor")
	attraction_animator.seek(NetworkTimeSynchronizer.get_time() - tick)
	description.hide_description()
	for i in _players.size():
		if i > 0:
			await get_tree().create_timer(0.3, false, true).timeout # Prevent players from crowding entry
		_players[i].request_movement(entry_positions[0].global_position, true, rule_positions[i].global_position)
		_players[i].request_movement(entry_positions[1].global_position, true, entry_positions[0].global_position)

const EXPLAIN_LENGTH : int = 4
const RULE_LENGTH : int = 3
func calculate_max_dialog_index() -> int:
	if current_state == STATE.EXPLAIN:
		return EXPLAIN_LENGTH
	if current_state == STATE.RULES:
		return RULE_LENGTH
	return 0

func exit_balcony(balcony_index : int) -> void:
	balcony_data[balcony_index].door_animator.play("open")
	if bracket_index == 0:
		# Prefight animations
		var pre_fight_callable : Callable = Callable(self, "first_floor_prefight").bind(balcony_indexes[balcony_index])
		_players[balcony_indexes[balcony_index]].movement_finished.connect(pre_fight_callable, CONNECT_ONE_SHOT)
	
	reset_player_animations(balcony_indexes[balcony_index])
	# Walk out
	var in_pos : Vector3 = balcony_data[balcony_index].get_inside_position()
	var out_pos : Vector3 = balcony_data[balcony_index].get_outside_position()
	_players[balcony_indexes[balcony_index]].queue_movement(in_pos, out_pos, false, NetworkTimeSynchronizer.get_time())
	_players[balcony_indexes[balcony_index]].request_rotation(0)

func first_floor_prefight(player_index : int) -> void:
	_players[player_index].character_animator.play_animation("fight", false, 0.1)
	_players[player_index].character_animator.play_voice("select")

## Called after a bracket round has completed.
func finalize_bracket_round() -> void:
	reset_camera()
	await get_tree().create_timer(2, false, true).timeout
	if final_results.size() != PartyManager.MAX_PLAYER_COUNT:
		start_bracket_round() # Start the next round
	else:
		start_results()

func start_special_prefight_animation(is_p1 : bool) -> void:
	var player_index : int = p1 if is_p1 else p2
	var balcony_index : int = balcony_indexes.find(player_index)
	attraction_animator.play("balcony%s" % balcony_index)
	_players[player_index].character_animator.play_animation("fight", true)
	_players[player_index].character_animator.play_voice("select")
	if NetworkManager.is_hosting_game:
		var target_rotation : float = PI * 0.5
		if !is_p1:
			target_rotation *= -1
		_players[player_index].request_rotation(target_rotation)

func reset_camera() -> void:
	attraction_animator.play_with_capture("default-view")

func start_round_camera() -> void:
	attraction_animator.play_with_capture("round%s" % bracket_index)

## Starts a bracket round between the two players.
func start_bracket_round() -> void:
	round_index = 0
	bracket_index += 1
	if bracket_index >= 3:
		interface_animator.play("start-consolation" if bracket_index == 3 else "start-championship")
		await get_tree().create_timer(1, false, true).timeout
	
	score_counter_p1.reset_wins()
	score_counter_p2.reset_wins()
	update_player_indexes()
	PartyManager.set_minigame_players([p1, p2])
	player_labels[0].set_synced_text(PartyManager.get_player_data(p1).character_data.character_name)
	player_labels[1].set_synced_text(PartyManager.get_player_data(p2).character_data.character_name)
	if bracket_index < 3:
		start_round_camera()
		await get_tree().create_timer(1, false, true).timeout
		var offset : Vector3 = _players[p1].global_position - _players[p2].global_position
		var angle : float = Vector3.FORWARD.signed_angle_to(offset, Vector3.UP)
		_players[p1].start_rotation(angle, NetworkTimeSynchronizer.get_time())
		_players[p1].character_animator.play_animation("fight", true)
		_players[p1].character_animator.play_voice("select")
		offset *= -1
		angle = Vector3.FORWARD.signed_angle_to(offset, Vector3.UP)
		_players[p2].start_rotation(angle, NetworkTimeSynchronizer.get_time())
		_players[p2].character_animator.play_animation("fight", true)
		_players[p2].character_animator.play_voice("select")
	advance_round()

func update_player_indexes() -> void:
	if bracket_index == 1:
		p1 = balcony_indexes[0]
		p2 = balcony_indexes[1]
	elif bracket_index == 2:
		p1 = balcony_indexes[2]
		p2 = balcony_indexes[3]
	elif bracket_index == 3:
		# Get who's fighing in the consolation match.
		p1 = -1
		p2 = -1
		var balcony_index : int = 0
		while p1 == -1 || p2 == -1:
			if balcony_indexes[balcony_index] == -1:
				balcony_index += 1
				continue
			if p1 == -1:
				p1 = balcony_indexes[balcony_index]
			else:
				p2 = balcony_indexes[balcony_index]
				break
			balcony_index += 1
	elif bracket_index == 4:
		# Championship match
		p1 = balcony_indexes[4]
		p2 = balcony_indexes[5]

func advance_round() -> void:
	request_queue_minigame()
	round_index += 1
	round_label.set_synced_text("%02d" % round_index)
	if round_index != 1:
		interface_animator.play("start-ingame")
	else:
		interface_animator.play("start-pregame-special" if bracket_index >= 3 else "start-pregame")

func on_minigame_queued() -> void:
	minigame_label.text = PartyManager.unlocked_minigame_list[_minigame_index].localization_key

	# Reset animations
func reset_player_animations(index : int) -> void:
	_players[index]._end_rotation = 0
	_players[index].global_rotation = Vector3.ZERO
	_players[index].character_animator.play_animation("%s/wait" % AttractionPartyCharacter.COMMON_LIBRARY_ANIMATION)
	_players[index].cancel_movement()

func show_attraction() -> void:
	super()
	for i in _players.size():
		reset_player_animations(i)
	
	interface_animator.play("start-result")
	var placement_p1 : int = PartyManager.get_player_data(p1).minigame_placement
	var placement_p2 : int = PartyManager.get_player_data(p2).minigame_placement
	_players[p1].character_animator.play_animation("draw" if placement_p1 >= placement_p2 else "select", true)
	_players[p2].character_animator.play_animation("draw" if placement_p2 >= placement_p1 else "select", true)
	_players[p1].character_animator.play_voice("draw" if placement_p1 >= placement_p2 else "celebrate1")
	_players[p2].character_animator.play_voice("draw" if placement_p2 >= placement_p1 else "celebrate1")
	if placement_p1 != placement_p2:
		if placement_p1 < placement_p2:
			score_counter_p1.set_win()
		else:
			score_counter_p2.set_win()
	
	await get_tree().create_timer(2, false, true).timeout
	if score_counter_p1.win_count != win_count && score_counter_p2.win_count != win_count:
		advance_round()
	else:
		if score_counter_p1.win_count > score_counter_p2.win_count:
			advance_player(p1, p2)
		else:
			advance_player(p2, p1)

## Starts all the animations needed to move a player to the next floor
## (or in the case of the consolation match, fall to the floor)
func advance_player(winner : int, loser : int) -> void:
	winner_label.set_synced_text(_players[winner].character_animator.data.character_name)
	var winner_balcony : int = balcony_indexes.find(winner)
	var loser_balcony : int = balcony_indexes.find(loser)
	_players[winner].character_animator.play_animation("win", true)
	_players[winner].character_animator.play_voice("celebrate2")
	_players[loser].character_animator.play_animation("lose", true)
	interface_animator.play("start-win")
	attraction_animator.play("balcony%s"%winner_balcony)
	await get_tree().create_timer(5, false, true).timeout
	
	if bracket_index == 3: # Consolation result
		# Register results of consolation match
		final_results.append(loser)
		final_results.append(winner)
		
		attraction_animator.play("balcony%s"%loser_balcony)
		await get_tree().create_timer(1, false, true).timeout
		balcony_data[loser_balcony].balcony_animator.play("shatter")
		fall_shatter_sfx.play()
		_players[loser].character_animator.play_animation("%s/fall-start" % AttractionPartyCharacter.PARTY_LIBRARY_ANIMATION)
		_players[loser].character_animator.play_voice("balance")
		_players[loser].character_animator.queue_minigame_animation("%s/fall" % AttractionPartyCharacter.PARTY_LIBRARY_ANIMATION, 0.2)
		await get_tree().create_timer(0.8, false, true).timeout
		var tween : Tween = create_tween()
		var end_pos : Vector3 = _players[loser].global_position
		end_pos.y = 0
		tween.tween_property(_players[loser], "global_position", end_pos, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(0.6, false, true).timeout
		_players[loser].character_animator.play_animation("%s/crash-land" % AttractionPartyCharacter.PARTY_LIBRARY_ANIMATION)
		_players[loser].character_animator.play_voice("hurt1")
		fall_impact_sfx.play()
		await get_tree().create_timer(0.5, false, true).timeout
		attraction_animator.play_with_capture("fallen%s" % loser_balcony)
		daze_vfx.global_position = _players[loser].global_position + Vector3.UP * 5
		daze_vfx.emitting = true
		await get_tree().create_timer(2, false, true).timeout
		daze_vfx.emitting = false
		finalize_bracket_round()
		return
	
	# Walk inside
	var in_pos : Vector3 = balcony_data[winner_balcony].get_inside_position()
	var out_pos : Vector3 = balcony_data[winner_balcony].get_outside_position()
	_players[winner].queue_movement(out_pos, in_pos, false, NetworkTimeSynchronizer.get_time())
	await get_tree().create_timer(1, false, true).timeout
	balcony_data[winner_balcony].door_animator.play("close")
	balcony_indexes[winner_balcony] = -1
	balcony_indexes.append(winner)
	winner_balcony = balcony_indexes.size() - 1
	reset_camera()
	await get_tree().create_timer(1, false, true).timeout
	if bracket_index == 4:
		final_results.append(loser)
		final_results.append(winner)
		attraction_animator.play_with_capture("balcony-top")
	elif bracket_index == 1:
		attraction_animator.play_with_capture("balcony-l")
	elif bracket_index == 2:
		attraction_animator.play_with_capture("balcony-r")
	exit_balcony(winner_balcony)

func start_results() -> void:
	disable_inputs()
	for i in _players.size():
		reset_player_animations(i)
	
	attraction_animator.speed_scale = 1.5
	for i in final_results.size():
		var balcony_index : int = balcony_indexes.find(final_results[i])
		placement_label.set_synced_text("party_placement%s" % (final_results.size() - i))
		winner_label.set_synced_text(_players[final_results[i]].character_animator.data.character_name)
		attraction_animator.play_with_capture(("fallen%s" if i == 0 else "balcony%s") % balcony_index)
		await get_tree().create_timer(0.5, false, true).timeout
		if i == final_results.size() - 1:
			interface_animator.play("result-win")
			bgm.stop()
			_players[final_results[i]].character_animator.play_animation("win", true)
			_players[final_results[i]].character_animator.play_voice("win2")
		else:
			interface_animator.play("result-lose")
			_players[final_results[i]].character_animator.play_animation("lose" if i == 0 else "draw", true)
			_players[final_results[i]].character_animator.play_voice("fail" if i == 0 else "draw")
		await get_tree().create_timer(3, false, true).timeout
	current_state = STATE.REPLAY
	attraction_animator.speed_scale = 1.0

class BalconyData:
	var balcony_animator : AnimationPlayer
	var door_animator : AnimationPlayer
	var player_position : Node3D
	const BALCONY_INSIDE_OFFSET : float = 30.0
	func get_outside_position() -> Vector3:
		return player_position.global_position
	func get_inside_position() -> Vector3:
		return get_outside_position() + Vector3.FORWARD * BALCONY_INSIDE_OFFSET
