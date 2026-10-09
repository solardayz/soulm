extends Node3D
## 안개문 — 다가가면 "안개를 헤치고 나아간다", E 로 통과 연출(조작 잠금 + 천천히 밀고 들어감).
## 보스전 중에는 되돌아갈 수 없고, 보스를 쓰러뜨리면 안개가 걷힌다.

signal prompt(text: String)
signal traversed

var traversed_once := false
var _player_near := false
var _busy := false

@onready var fog: MeshInstance3D = $Fog
@onready var wall: StaticBody3D = $Wall
@onready var trigger: Area3D = $Trigger


func _ready() -> void:
	trigger.body_entered.connect(func(b): if b.is_in_group("player"): _player_near = true; _refresh_prompt())
	trigger.body_exited.connect(func(b): if b.is_in_group("player"): _player_near = false; _refresh_prompt())


func _refresh_prompt() -> void:
	prompt.emit("안개를 헤치고 나아간다  [E]" if _player_near and not traversed_once and not _busy else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_near and not traversed_once and not _busy:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.global_position.z > global_position.z:
			_traverse(player)


func _traverse(player: Node3D) -> void:
	_busy = true
	_refresh_prompt()
	player.play_busy("Walking_A", 2.3)
	player.rotation.y = 0 # 문(-Z)을 향한다
	wall.collision_layer = 0
	var mat := fog.get_surface_override_material(0) as ShaderMaterial
	var tw := create_tween()
	tw.set_parallel(true)
	var start := player.global_position
	var end := Vector3(global_position.x, start.y, global_position.z - 2.2)
	tw.tween_property(player, "global_position", end, 2.2).set_trans(Tween.TRANS_SINE)
	if mat:
		tw.tween_property(mat, "shader_parameter/push", 1.0, 1.0)
		tw.chain().tween_property(mat, "shader_parameter/push", 0.0, 1.0)
	await tw.finished
	wall.collision_layer = 1
	traversed_once = true
	_busy = false
	_refresh_prompt()
	traversed.emit()


## 보스 처치 → 안개가 걷힌다
func dissolve() -> void:
	var mat := fog.get_surface_override_material(0) as ShaderMaterial
	if mat:
		create_tween().tween_property(mat, "shader_parameter/fade", 0.0, 2.5)
	wall.collision_layer = 0


func reset() -> void:
	traversed_once = false
	var mat := fog.get_surface_override_material(0) as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fade", 1.0)
		mat.set_shader_parameter("push", 0.0)
	wall.collision_layer = 1
	_refresh_prompt()
