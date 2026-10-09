extends CanvasLayer
## 모바일 터치 조작 — 왼쪽 가상 조이스틱, 오른쪽 버튼(공격·구르기·막기·패리·에스트·락온), 안내가 뜨면 상호작용 버튼.
## 터치 기기면 자동으로 켜지고, PC에서는 T 키 또는 `--touch` 인자로 켠다. 버튼은 InputEventAction 을 쏴서
## 키보드와 같은 경로(_unhandled_input)로 들어간다.

var active := false
var move_vector := Vector2.ZERO

var _joy_base: Control
var _joy_knob: Control
var _joy_touch := -1
var _joy_center := Vector2.ZERO
const JOY_RADIUS := 70.0
var _interact_btn: Button
var _buttons: Control


func _ready() -> void:
	layer = 20
	active = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
	_build()
	visible = active
	add_to_group("touch_controls")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		active = not active
		visible = active
		if not active:
			move_vector = Vector2.ZERO


# ── UI 만들기 (코드로 — 씬 파일을 크게 만들지 않기 위해)
func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_joy_base = _circle(Color(1, 1, 1, 0.12), 170)
	_joy_base.name = "JoyBase"
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.position = Vector2(60, -250)
	_joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_base.gui_input.connect(_joy_input)
	root.add_child(_joy_base)
	_joy_knob = _circle(Color(1, 1, 1, 0.35), 76)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.position = Vector2(47, 47)
	_joy_base.add_child(_joy_knob)

	_buttons = Control.new()
	_buttons.name = "Buttons"
	_buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_buttons.position = Vector2(-330, -300)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_buttons)
	_btn("공격", "attack", Vector2(200, 120), 104, Color(0.75, 0.15, 0.12, 0.8))
	_btn("구르기", "dodge", Vector2(96, 190), 84, Color(0.2, 0.45, 0.8, 0.8))
	_btn("막기", "block", Vector2(96, 60), 84, Color(0.35, 0.35, 0.4, 0.8), true)
	_btn("패리", "parry", Vector2(0, 125), 78, Color(0.85, 0.7, 0.2, 0.85))
	_btn("에스트", "heal", Vector2(230, 0), 68, Color(0.9, 0.5, 0.15, 0.8))
	_btn("락온", "lock_on", Vector2(230, 240), 68, Color(0.3, 0.6, 0.35, 0.8))
	_interact_btn = _btn("E", "interact", Vector2(-120, 125), 72, Color(0.9, 0.9, 0.9, 0.85))
	_interact_btn.visible = false


func _circle(color: Color, size: float) -> Control:
	var c := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size / 2))
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.35)
	c.add_theme_stylebox_override("panel", sb)
	c.custom_minimum_size = Vector2(size, size)
	c.size = Vector2(size, size)
	return c


func _btn(label: String, action: String, pos: Vector2, size: float, color: Color, hold := false) -> Button:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18 if size < 90 else 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color if state != "pressed" else color.lightened(0.3)
		sb.set_corner_radius_all(int(size / 2))
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(1, 1, 1, 0.5)
		b.add_theme_stylebox_override(state, sb)
	b.button_down.connect(func(): _send(action, true))
	b.button_up.connect(func(): if hold: _send(action, false))
	_buttons.add_child(b)
	return b


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
	if not pressed:
		return
	# 누르기만 하는 버튼은 바로 떼 준다 (키를 눌렀다 뗀 것과 같게)
	if action != "block":
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event.call_deferred(up)


# ── 조이스틱
func _joy_input(event: InputEvent) -> void:
	var size := _joy_base.size
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var idx: int = event.index if event is InputEventScreenTouch else -2
		if pressed and _joy_touch == -1:
			_joy_touch = idx
			_joy_center = size / 2
			_joy_update(event.position)
			_joy_base.accept_event()
		elif not pressed and idx == _joy_touch:
			_joy_touch = -1
			move_vector = Vector2.ZERO
			_joy_knob.position = size / 2 - _joy_knob.size / 2
			_joy_base.accept_event()
	elif event is InputEventScreenDrag and event.index == _joy_touch:
		_joy_update(event.position)
		_joy_base.accept_event()
	elif event is InputEventMouseMotion and _joy_touch == -2:
		_joy_update(event.position)
		_joy_base.accept_event()


func _joy_update(local_pos: Vector2) -> void:
	var v := (local_pos - _joy_center) / JOY_RADIUS
	if v.length() > 1.0:
		v = v.normalized()
	move_vector = v
	_joy_knob.position = _joy_center + v * JOY_RADIUS - _joy_knob.size / 2


## HUD 안내문이 있을 때만 상호작용 버튼을 보여준다
func set_interact_available(on: bool) -> void:
	if _interact_btn:
		_interact_btn.visible = on
