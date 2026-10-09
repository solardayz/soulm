extends Node3D
## 3인칭 카메라 — 마우스 오빗, 스프링암 충돌, Tab 락온(플레이어와 보스 사이를 바라봄)

const SENS := 0.0028
const PITCH_MIN := -0.9
const PITCH_MAX := 0.5
const LOCK_RANGE := 28.0

var yaw := 0.0
var pitch := -0.25
var lock_target: Node3D = null

@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var player: CharacterBody3D = get_parent()


func _touch_mode() -> bool:
	var t := get_tree().get_first_node_in_group("touch_controls")
	return t != null and t.active


func _ready() -> void:
	if not (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	arm.add_excluded_object(player.get_rid())
	top_level = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and _touch_mode() and lock_target == null:
		# 조이스틱이 먹은 드래그는 여기 오지 않는다 — 나머지 화면 드래그가 시점
		yaw -= event.relative.x * SENS * 1.6
		pitch = clampf(pitch - event.relative.y * SENS * 1.6, PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and lock_target == null and not _touch_mode():
		yaw -= event.relative.x * SENS
		pitch = clampf(pitch - event.relative.y * SENS, PITCH_MIN, PITCH_MAX)
	elif event.is_action_pressed("lock_on"):
		_toggle_lock()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _touch_mode():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _toggle_lock() -> void:
	if lock_target:
		lock_target = null
	else:
		var best: Node3D = null
		var best_d := LOCK_RANGE
		for b in get_tree().get_nodes_in_group("boss"):
			if b.get("lockable") == false:
				continue
			var d: float = b.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = b
		lock_target = best
	player.lock_target = lock_target


func _physics_process(delta: float) -> void:
	if lock_target and (not is_instance_valid(lock_target) or lock_target.get("lockable") == false):
		lock_target = null
		player.lock_target = null
	var anchor: Vector3 = player.global_position + Vector3(0, 1.6, 0)
	if lock_target:
		var to: Vector3 = lock_target.global_position + Vector3(0, 2.0, 0) - anchor
		var target_yaw := atan2(-to.x, -to.z)
		yaw = lerp_angle(yaw, target_yaw, minf(1.0, 8.0 * delta))
		pitch = lerpf(pitch, -0.2, minf(1.0, 4.0 * delta))
	global_position = global_position.lerp(anchor, minf(1.0, 14.0 * delta))
	rotation = Vector3(pitch, yaw, 0)


## 플레이어 이동이 쓰는 "카메라 기준" 수평 기저
func camera_basis() -> Basis:
	return Basis(Vector3.UP, yaw)
