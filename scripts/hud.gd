extends CanvasLayer
## HUD — 체력/스태미나 바, 에스트, 보스 체력바(이름), 상호작용 안내, 메시지, YOU DIED, 페이드,
## 오른쪽 위 반투명 조작법 카드(항상 표시 · H 로 숨기기/보이기 · 터치 조작 땐 숨김). 안내 UI는 코드로 만든다.

const KEYS := [
	["W A S D", "이동"],
	["Space", "구르기 (앞부분 무적)"],
	["Shift 길게", "방패 막기"],
	["J · 왼클릭", "공격 (연타 2연속)"],
	["F · 오른클릭", "패리 (범위가 노랄 때)"],
	["R", "에스트 회복"],
	["E", "상호작용 (검 · 화톳불)"],
	["Tab · 휠클릭", "락온"],
	["T", "터치 조작"],
	["H", "이 카드 숨기기"]
]

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
var _guide_on := true
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
	_build_guide()


func _process(_delta: float) -> void:
	# 터치 조작이 켜져 있으면 버튼에 글자가 있으니 카드는 숨긴다
	var touch := get_tree().get_first_node_in_group("touch_controls")
	_guide.visible = _guide_on and not (touch and touch.active)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_guide_on = not _guide_on


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


## 오른쪽 위 구석의 반투명 조작법 카드
func _build_guide() -> void:
	_guide = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.04, 0.04, 0.45)
	box.border_color = Color(0.75, 0.62, 0.35, 0.5)
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	_guide.add_theme_stylebox_override("panel", box)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.size_flags_horizontal = Control.SIZE_SHRINK_END
	_guide.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_guide.add_child(v)

	var title := Label.new()
	title.text = "조작법   (H 숨기기)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 0.95))
	v.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	for row in KEYS:
		grid.add_child(_keycap(row[0]))
		var d := Label.new()
		d.text = row[1]
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88, 0.95))
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(d)

	# 화면 전체 MarginContainer 안에서 오른쪽 위로 붙인다 (크기와 상관없이 구석 정렬)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(_guide)


func _keycap(text: String) -> Control:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.23, 0.2, 0.75)
	sb.border_color = Color(0.6, 0.55, 0.42, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", sb)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_END
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	cap.add_child(l)
	return cap
