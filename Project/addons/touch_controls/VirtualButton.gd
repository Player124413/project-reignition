extends Control
## Virtual button that simulates an Input action when touched.
##
## Rendered as a keyboard-style keycap (rounded square cap with border,
## bevel shadow and the bound key letter/label printed on it).
## Supports press, release, toggle mode and extra linked actions.

class_name VirtualButton

## The Input action name to trigger (e.g. "button_jump")
@export var action_name: String = ""
## Extra actions pressed/released together with the main one
## (e.g. "ui_accept" alongside "sys_pause" for the menu Enter key).
@export var extra_actions: Array[String] = []
## Label text shown on the button (usually the bound keyboard key)
@export var button_label: String = ""
## Small function caption drawn under the keycap (e.g. "Jump")
@export var caption: String = ""
## Whether this button uses toggle mode (press once to enable, again to disable)
@export var toggle_mode: bool = false
## Opacity when idle
@export var idle_alpha: float = 0.6
## Opacity when pressed
@export var pressed_alpha: float = 1.0
## Size multiplier for the button
@export var button_scale: float = 1.0

## Emitted when the button starts being pressed
signal pressed_started
## Emitted when the button is released
signal pressed_ended

var is_pressed: bool = false
var _touch_index: int = -1
var _is_toggled: bool = false

var _bg: Panel
var _label: Label
var _caption_lbl: Label

# ─── Keycap style ────────────────────────────────────────────────────

static func _make_style(bg: Color, border: Color, shadow_off: Vector2, shadow_size_: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 7
	s.corner_radius_top_right = 7
	s.corner_radius_bottom_left = 7
	s.corner_radius_bottom_right = 7
	s.set_border_width_all(2)
	s.border_color = border
	s.shadow_size = shadow_size_
	s.shadow_offset = shadow_off
	s.shadow_color = Color(0, 0, 0, 0.55)
	return s

const CAP_NORMAL := Color(0.15, 0.16, 0.19, 0.82)
const CAP_PRESSED := Color(0.22, 0.46, 0.75, 0.95)
const CAP_TOGGLE_ON := Color(0.16, 0.55, 0.32, 0.95)
const BORDER_NORMAL := Color(0.85, 0.88, 0.95, 0.55)
const BORDER_ACTIVE := Color(0.65, 0.85, 1.0, 0.95)

func _ready() -> void:
	# Never swallow GUI clicks of widgets (menus) that live under us.
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate.a = idle_alpha
	_build_children()
	_refresh_visual()

func _build_children() -> void:
	if _bg == null:
		_bg = Panel.new()
		_bg.name = "Background"
		_bg.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_bg)
	if _label == null:
		_label = Label.new()
		_label.name = "Label"
		_label.mouse_filter = MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 0.95))
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(_label)
	if _caption_lbl == null and not caption.is_empty():
		_caption_lbl = Label.new()
		_caption_lbl.name = "Caption"
		_caption_lbl.mouse_filter = MOUSE_FILTER_IGNORE
		_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		add_child(_caption_lbl)
	if button_label != "":
		_label.text = button_label
	_apply_size(size)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _bg != null:
		_apply_size(size)

## Layout the keycap children for a given button size.
func _apply_size(s: Vector2) -> void:
	if _bg:
		_bg.position = Vector2.ZERO
		_bg.size = s
	if _label:
		_label.position = Vector2.ZERO
		_label.size = s
		# Font size adapts to the label length so "Enter"/"Shift" still fit.
		var cap_h: float = s.y
		var fs: int = int(cap_h * 0.42)
		match button_label.length():
			2:
				fs = int(cap_h * 0.34)
			3:
				fs = int(cap_h * 0.28)
			4:
				fs = int(cap_h * 0.23)
			5:
				fs = int(cap_h * 0.2)
			6:
				fs = int(cap_h * 0.17)
			_:
				if button_label.length() > 6:
					fs = int(cap_h * 0.14)
		fs = maxi(fs, 9)
		_label.add_theme_font_size_override("font_size", fs)
	if _caption_lbl:
		_caption_lbl.text = caption
		_caption_lbl.position = Vector2(0, s.y + 2)
		_caption_lbl.size = Vector2(s.x, maxf(s.y * 0.28, 12))
		_caption_lbl.add_theme_font_size_override("font_size", maxi(int(s.y * 0.16), 9))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var editor_no_touch: bool = OS.has_feature("editor") and not OS.has_feature("android") and not OS.has_feature("ios") and not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available()
	if editor_no_touch:
		return
	
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_process_touch_event(event)

func _process_touch_event(event: InputEvent) -> void:
	var pos: Vector2
	var is_press: bool
	var touch_idx: int
	
	if event is InputEventScreenTouch:
		var te = event as InputEventScreenTouch
		pos = te.position
		is_press = te.pressed
		touch_idx = te.index
	elif event is InputEventScreenDrag:
		var de = event as InputEventScreenDrag
		pos = de.position
		touch_idx = de.index
		is_press = true
	else:
		return
	
	var is_inside: bool = _is_point_inside(pos)
	
	if is_press and is_inside and not is_pressed:
		# Start pressing this button
		_touch_index = touch_idx
		is_pressed = true
		_update_press_state(true)
		pressed_started.emit()
		get_viewport().set_input_as_handled()
		_refresh_visual()
		
	elif not is_press and touch_idx == _touch_index:
		# Release
		_touch_index = -1
		_update_press_state(false)
		pressed_ended.emit()
		get_viewport().set_input_as_handled()
		_refresh_visual()
		
	elif is_press and touch_idx == _touch_index and not is_inside:
		# Finger slid off the button — release
		_touch_index = -1
		_update_press_state(false)
		pressed_ended.emit()
		get_viewport().set_input_as_handled()
		_refresh_visual()

func _is_point_inside(point: Vector2) -> bool:
	var rect := Rect2(global_position, size)
	return rect.has_point(point)

func _all_actions() -> Array[String]:
	var out: Array[String] = []
	if not action_name.is_empty():
		out.append(action_name)
	for a in extra_actions:
		out.append(a)
	return out

func _press_actions() -> void:
	for a in _all_actions():
		if InputMap.has_action(a):
			Input.action_press(a)

func _release_actions() -> void:
	for a in _all_actions():
		if InputMap.has_action(a):
			Input.action_release(a)

func _update_press_state(pressing: bool) -> void:
	if pressing:
		if not toggle_mode:
			_press_actions()
			modulate.a = pressed_alpha
		else:
			_is_toggled = not _is_toggled
			if _is_toggled:
				_press_actions()
				modulate.a = pressed_alpha
			else:
				_release_actions()
				modulate.a = idle_alpha
	else:
		if not toggle_mode:
			_release_actions()
			modulate.a = idle_alpha
		# In toggle mode, release only happens when toggled off, so don't release here

func _refresh_visual() -> void:
	if _bg == null:
		return
	var active: bool = is_pressed or (_is_toggled and toggle_mode)
	if is_pressed and not _is_toggled:
		# Cap "pressed down": shift the face, shrink the bevel shadow
		_bg.add_theme_stylebox_override("panel", _make_style(CAP_PRESSED, BORDER_ACTIVE, Vector2(0, 1), 1))
		_bg.position = Vector2(0, 2)
		_label.position = Vector2(0, 2)
	elif active:
		_bg.add_theme_stylebox_override("panel", _make_style(CAP_TOGGLE_ON, BORDER_ACTIVE, Vector2(0, 3), 4))
		_bg.position = Vector2.ZERO
		_label.position = Vector2.ZERO
	else:
		_bg.add_theme_stylebox_override("panel", _make_style(CAP_NORMAL, BORDER_NORMAL, Vector2(0, 3), 4))
		_bg.position = Vector2.ZERO
		_label.position = Vector2.ZERO

## Set the printed key label (and re-fit the font).
func set_key_label(text: String) -> void:
	button_label = text
	if _label:
		_label.text = text
		_apply_size(size)

## Toggle the function caption under the cap.
func set_caption(text: String) -> void:
	caption = text
	if text.is_empty():
		if _caption_lbl:
			_caption_lbl.queue_free()
			_caption_lbl = null
	elif _caption_lbl:
		_caption_lbl.text = text
		_apply_size(size)
	else:
		_caption_lbl = Label.new()
		_caption_lbl.name = "Caption"
		_caption_lbl.mouse_filter = MOUSE_FILTER_IGNORE
		_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		add_child(_caption_lbl)
		_apply_size(size)

func force_release() -> void:
	if is_pressed:
		is_pressed = false
		_touch_index = -1
		if toggle_mode and _is_toggled:
			_refresh_visual()
			return  # Keep toggle state
		_release_actions()
		modulate.a = idle_alpha
		_refresh_visual()
