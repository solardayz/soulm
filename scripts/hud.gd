extends CanvasLayer
## HUD — 체력/스태미나 바, 에스트, 보스 체력바(이름), 상호작용 안내, 메시지, YOU DIED, 페이드

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


func _ready() -> void:
	boss_box.visible = false
	big_label.visible = false
	fade_rect.color.a = 0.0


func set_hp(hp: int, hp_max: int) -> void:
	hp_bar.max_value = hp_max
	hp_bar.value = hp


func set_stamina(st: float, st_max: float) -> void:
	st_bar.max_value = st_max
	st_bar.value = st


func set_estus(n: int) -> void:
	estus_label.text = "에스트 ×%d  [R]" % n


func show_boss(name: String) -> void:
	boss_name.text = name
	boss_box.visible = true


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
