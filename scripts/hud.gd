extends CanvasLayer
## HUD — 체력/스태미나 바, 에스트, 보스 체력바(이름), 상호작용 안내, 메시지, YOU DIED, 페이드,
## 조작법 카드(시작 때 표시 · H 키로 다시 열기) 와 하단 키 안내 줄. 안내 UI는 코드로 만든다.

const KEYS := [
	["W A S D", "이동  (화살표 키도 됨)"],
	["Space", "구르기  — 앞부분은 무적"],
	["Shift  길게", "방패 막기  (스태미나 소모)"],
	["J  ·  마우스 왼쪽", "공격  (연타하면 2연속)"],
	["F  ·  마우스 오른쪽", "패리  — 바닥 범위가 노랗게 될 때"],
	["R", "에스트  (체력 회복, 3개)"],
	["E", "상호작용  (검 뽑기 · 화톳불)"],
	["Tab  ·  휠 클릭", "락온  (보스를 계속 바라봄)"],
	["T", "터치 조작 켜기 / 끄기"],
	["H", "이 안내 열기 / 닫기"]
]
const HINT_TEXT := "WASD 이동  ·  Space 구르기  ·  Shift 막기  ·  J 공격  ·  F 패리  ·  R 에스트  ·  Tab 락온  ·  H 조작법"

@onready var hp_bar: ProgressBar = $Top/HP
@onready var st_bar: ProgressBar = $Top/Stamina
@onready var estus_label: Label = $Top/Estus
@onready var boss_box: Control = $BossBox
@onready var boss_name: Label = $BossBox/Name
@onready var boss_bar: ProgressBar = $BossBox/Bar
@onready var prompt_label: Label = $Prompt
@onready var msg_label: Label = $Message
@onready var big_label: Label = $Big
@onready var fade_rect: ColorRect = $Fade

var _msg_token := 0
var _guide: PanelContainer
var _hint: Label
var _guide_opened_at := 0.0
var _tips_shown := {}


func _ready() -> void:
	boss_box.visible = false
	big_label.visible = false
	fade_rect.color.a = 0.0
	_style_bar(hp_bar, Color(0.78, 0.12, 0.1))
	_style_bar(st_bar, Color(0.32, 0.72, 0.3))
	_style_bar(boss_bar, Color(0.62, 0.07, 0.07))
	for l in [boss_name, prompt_label, msg_label, big_label, estus_label]:
		_shadow(l)
	_build_hint()
	_build_guide()
	show_guide(true)


func _process(_delta: float) -> void:
	# 터치 조작이 켜져 있으면 버튼에 글자가 있으니 키 안내 줄은 숨긴다
	var touch := get_tree().get_first_node_in_group("touch_controls")
	_hint.visible = not (touch and touch.active) and not _guide.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		show_guide(not _guide.visible)
		return
	if not _guide.visible:
		return
	# 안내가 떠 있을 때 아무 조작이나 하면 닫힌다 (연 직후 0.4초는 무시 — 여는 키에 바로 닫히지 않게)
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventAction and event.pressed)
	if pressed and Time.get_ticks_msec() / 1000.0 - _guide_opened_at > 0.4:
		show_guide(false)


func show_guide(on: bool) -> void:
	_guide.visible = on
	if on:
		_guide_opened_at = Time.get_ticks_msec() / 1000.0


func set_hp(hp: int, hp_max: int) -> void:
	hp_bar.max_value = hp_max
	hp_bar.value = hp


func set_stamina(st: float, st_max: float) -> void:
	st_bar.max_value = st_max
	st_bar.value = st


func set_estus(n: int) -> void:
	estus_label.text = "에스트 ×%d   [R] 회복" % n


func show_boss(name: String) -> void:
	boss_name.text = name
	boss_box.visible = true
	show_guide(false)
	_tip("boss", "바닥 범위가 노랗게 변하는 순간 F 패리  ·  Space 구르기  ·  Shift 막기", 2.6, 5.0)


func set_boss_hp(hp: int, hp_max: int) -> void:
	boss_bar.max_value = hp_max
	boss_bar.value = hp


func hide_boss() -> void:
	boss_box.visible = false


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_message(text: String, seconds := 1.6) -> void:
	_msg_token += 1
	var mine := _msg_token
	msg_label.text = text
	await get_tree().create_timer(seconds).timeout
	if _msg_token == mine:
		msg_label.text = ""


func show_big(text: String, color: Color, seconds := 3.0) -> void:
	big_label.text = text
	big_label.add_theme_color_override("font_color", color)
	big_label.modulate.a = 0.0
	big_label.visible = true
	var tw := create_tween()
	tw.tween_property(big_label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(seconds)
	tw.tween_property(big_label, "modulate:a", 0.0, 0.8)
	await tw.finished
	big_label.visible = false


func fade(to_alpha: float, seconds := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to_alpha, seconds)
	await tw.finished


## 한 번만 보여주는 팁 (delay 뒤에 seconds 동안)
func _tip(key: String, text: String, delay: float, seconds: float) -> void:
	if _tips_shown.has(key):
		return
	_tips_shown[key] = true
	await get_tree().create_timer(delay).timeout
	show_message(text, seconds)


func _style_bar(bar: ProgressBar, fill: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(0.05, 0.05, 0.05, 0.9)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.show_percentage = false


func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 4)


## 화면 아래 한 줄 키 안내
func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = HINT_TEXT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.85))
	_shadow(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -34
	_hint.offset_bottom = -10
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


## 가운데 조작법 카드
func _build_guide() -> void:
	_guide = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.05, 0.05, 0.88)
	box.border_color = Color(0.75, 0.62, 0.35, 0.9)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(26)
	_guide.add_theme_stylebox_override("panel", box)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_guide.add_child(v)

	var title := Label.new()
	title.text = "조작법"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	v.add_child(title)

	var sub := Label.new()
	sub.text = "안개문을 지나 검을 뽑으면 보스가 깨어납니다"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	v.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for row in KEYS:
		grid.add_child(_keycap(row[0]))
		var d := Label.new()
		d.text = row[1]
		d.add_theme_font_size_override("font_size", 17)
		d.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(d)

	var foot := Label.new()
	foot.text = "아무 키나 누르면 닫힘  ·  H 로 다시 열기  ·  모바일은 화면의 조이스틱과 버튼"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	v.add_child(foot)

	# 화면 전체를 덮는 CenterContainer 안에 넣어야 크기와 상관없이 정확히 가운데에 온다
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(_guide)
	_guide.visible = false


func _keycap(text: String) -> Control:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.2, 0.18, 1.0)
	sb.border_color = Color(0.5, 0.45, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", sb)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_END
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	cap.add_child(l)
	return cap
