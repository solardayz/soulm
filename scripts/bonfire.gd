extends Node3D
## 화톳불 — 쉬면 체력·에스트가 차고 보스(살아 있다면)가 원위치. 사망 시 여기서 부활.

signal prompt(text: String)
signal rested

var _near := false

@onready var light: OmniLight3D = $Light


func _ready() -> void:
	$Area.body_entered.connect(func(b): if b.is_in_group("player"): _near = true; prompt.emit("화톳불에서 쉰다  [E]"))
	$Area.body_exited.connect(func(b): if b.is_in_group("player"): _near = false; prompt.emit(""))


func _process(_delta: float) -> void:
	light.light_energy = 2.4 + sin(Time.get_ticks_msec() * 0.011) * 0.35 + sin(Time.get_ticks_msec() * 0.023) * 0.2


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _near:
		var player := get_tree().get_first_node_in_group("player")
		if player and not player.is_dead():
			player.play_busy("Sit_Floor_Down", 1.6)
			rested.emit()


func respawn_point() -> Vector3:
	return global_position + Vector3(0, 0.2, 2.5)
