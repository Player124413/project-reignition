extends Control
## Virtual button that simulates an Input action when touched.
##
## Supports press, release, and strength (for analog-like behaviour on long-hold).

class_name VirtualButton

## The Input action name to trigger (e.g. "button_jump")
@export var action_name: String = ""
## Label text shown on the button
@export var button_label: String = ""
## Whether this button uses toggle mode (press once to enable, again to disable)
@export var toggle_mode: bool = false
## Opacity when idle
@export var idle_alpha: float = 0.35
## Opacity when pressed
@export var pressed_alpha: float = 0.8
## Size multiplier for the button
@export var button_scale: float = 1.0

var is_pressed: bool = false
var _touch_index: int = -1
var _is_toggled: bool = false

@onready var _bg: NinePatchRect = $Background
@onready var _label: Label = $Label
@onready var _touch_area: Area2D = $TouchArea

func _ready() -> void:
	modulate.a = idle_alpha
	if _label and not button_label.is_empty():
		_label.text = button_label
	if button_scale != 1.0:
		scale = Vector2(button_scale, button_scale)

func _input(event: InputEvent) -> void:
	if OS.has_feature("editor") and not OS.has_feature("android") and not OS.has_feature("ios") and not OS.has_feature("mobile"):
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
		get_viewport().set_input_as_handled()
		
	elif not is_press and touch_idx == _touch_index:
		# Release
		_touch_index = -1
		_update_press_state(false)
		get_viewport().set_input_as_handled()
		
	elif is_press and touch_idx == _touch_index and not is_inside:
		# Finger slid off the button — release
		_touch_index = -1
		_update_press_state(false)
		get_viewport().set_input_as_handled()

func _is_point_inside(point: Vector2) -> bool:
	var rect := Rect2(global_position, size)
	return rect.has_point(point)

func _update_press_state(pressing: bool) -> void:
	if pressing:
		if not toggle_mode:
			Input.action_press(action_name)
			modulate.a = pressed_alpha
		else:
			_is_toggled = not _is_toggled
			if _is_toggled:
				Input.action_press(action_name)
				modulate.a = pressed_alpha
			else:
				Input.action_release(action_name)
				modulate.a = idle_alpha
	else:
		if not toggle_mode:
			Input.action_release(action_name)
			modulate.a = idle_alpha
		# In toggle mode, release only happens when toggled off, so don't release here

func force_release() -> void:
	if is_pressed:
		is_pressed = false
		_touch_index = -1
		if toggle_mode and _is_toggled:
			return  # Keep toggle state
		Input.action_release(action_name)
		modulate.a = idle_alpha