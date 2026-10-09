extends CharacterBody3D
## 플레이어(기사) — 소울류 조작: 카메라 기준 이동, 구르기(무적 프레임), 공격 2연타, 방패 막기 + 타이밍 패리, 에스트, 상호작용.
## 애니메이션은 KayKit Knight.glb 의 AnimationPlayer 를 그대로 쓴다.

signal hp_changed(hp: int, hp_max: int)
signal stamina_changed(stamina: float, stamina_max: float)
signal estus_changed(count: int)
signal died
signal hit_landed(target: Node3D, damage: int, riposte: bool)

enum S { FREE, ROLL, ATTACK, BLOCK, PARRY, HIT, HEAL, BUSY, DEAD }

const WALK_SPEED := 3.2
const RUN_SPEED := 5.6
const ROLL_SPEED := 7.5
const TURN_SPEED := 12.0
const GRAVITY := 22.0

const HP_MAX := 100
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 30.0
const ROLL_COST := 22.0
const ATTACK_COST := 18.0
const BLOCK_HIT_COST := 28.0
const BLOCK_DAMAGE_RATIO := 0.15

const ROLL_TIME := 0.62
const ROLL_IFRAMES := 0.42
const PARRY_WINDOW := 0.32
const PARRY_COST := 12.0
const PARRY_STANCE := 0.45 # 전용 패리: 앞 0.32초가 성공 창, 나머지는 빈틈
const ATTACK_RANGE := 2.4
const ATTACK_ARC_DEG := 80.0
const ATTACK_DAMAGE := 45
const RIPOSTE_MULT := 3
const ESTUS_MAX := 3
const ESTUS_HEAL := 55

const ATTACK_ANIMS := ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"]
const HIDE_PARTS := ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"]
const LOOPS := ["Idle", "Running_A", "Walking_A", "Blocking", "Running_Strafe_Left", "Running_Strafe_Right"]

var hp := HP_MAX
var stamina := STAMINA_MAX
var estus := ESTUS_MAX
var state := S.FREE
var lock_target: Node3D = null

var _state_time := 0.0
var _combo := 0
var _attack_queued := false
var _attack_hit_done := false
var _block_pressed_at := -10.0
var _heal_done := false
var _roll_dir := Vector3.FORWARD
var _face_dir := Vector3.FORWARD
var _busy_timer := 0.0

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var rig: Node3D = $CameraRig


func _ready() -> void:
	add_to_group("player")
	for part in HIDE_PARTS:
		var n := model.find_child(part, true, false)
		if n:
			n.visible = false
	for a in LOOPS:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	hp_changed.emit(hp, HP_MAX)
	stamina_changed.emit(stamina, STAMINA_MAX)
	estus_changed.emit(estus)


func _physics_process(delta: float) -> void:
	_state_time += delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	match state:
		S.FREE:
			_do_move(delta, true)
			if not Input.is_action_pressed("block"):
				stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
		S.BLOCK:
			_do_move(delta, false)
			if not Input.is_action_pressed("block"):
				_set_state(S.FREE)
		S.ROLL:
			velocity.x = _roll_dir.x * ROLL_SPEED * (1.0 - _state_time / ROLL_TIME * 0.6)
			velocity.z = _roll_dir.z * ROLL_SPEED * (1.0 - _state_time / ROLL_TIME * 0.6)
			if _state_time >= ROLL_TIME:
				_set_state(S.FREE)
		S.ATTACK:
			velocity.x = move_toward(velocity.x, 0, 20 * delta)
			velocity.z = move_toward(velocity.z, 0, 20 * delta)
			var len := maxf(anim.current_animation_length, 0.01)
			var frac := anim.current_animation_position / len
			if frac < 0.35:
				_face_target_or_dir(delta)
			if not _attack_hit_done and frac >= 0.42:
				_attack_hit_done = true
				_deal_damage()
			if frac >= 0.62 and _attack_queued and _combo < ATTACK_ANIMS.size() - 1 and stamina >= ATTACK_COST:
				_combo += 1
				_attack_queued = false
				_start_attack()
			elif not anim.is_playing() or frac >= 0.98:
				_set_state(S.FREE)
		S.PARRY:
			velocity.x = move_toward(velocity.x, 0, 25 * delta)
			velocity.z = move_toward(velocity.z, 0, 25 * delta)
			if lock_target:
				_turn_toward(lock_target.global_position - global_position, delta)
			if _state_time >= PARRY_STANCE:
				_set_state(S.FREE)
		S.HIT, S.HEAL, S.BUSY:
			velocity.x = move_toward(velocity.x, 0, 20 * delta)
			velocity.z = move_toward(velocity.z, 0, 20 * delta)
			if state == S.HEAL and not _heal_done and _state_time >= 0.7:
				_heal_done = true
				hp = mini(HP_MAX, hp + ESTUS_HEAL)
				hp_changed.emit(hp, HP_MAX)
			_busy_timer -= delta
			if _busy_timer <= 0:
				_set_state(S.FREE)
		S.DEAD:
			velocity.x = 0
			velocity.z = 0
	stamina_changed.emit(stamina, STAMINA_MAX)
	move_and_slide()


func _move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch := get_tree().get_first_node_in_group("touch_controls")
	if touch and touch.active and touch.move_vector.length() > 0.05:
		v = touch.move_vector
	return v


func _do_move(delta: float, can_run: bool) -> void:
	var input := _move_input()
	var cam_basis: Basis = rig.camera_basis()
	var dir := (cam_basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized() * input.length()
	var speed := RUN_SPEED if can_run else WALK_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length() > 0.1:
		_face_dir = dir.normalized()
	if lock_target:
		_turn_toward(lock_target.global_position - global_position, delta)
	elif dir.length() > 0.1:
		_turn_toward(dir, delta)
	if state == S.BLOCK:
		_play("Blocking")
	elif dir.length() > 0.1:
		_play("Running_A")
	else:
		_play("Idle")


func _face_target_or_dir(delta: float) -> void:
	if lock_target:
		_turn_toward(lock_target.global_position - global_position, delta * 2)
	else:
		_turn_toward(_face_dir, delta * 2)


func _turn_toward(dir: Vector3, delta: float) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))


func _unhandled_input(event: InputEvent) -> void:
	if state == S.DEAD:
		return
	if event.is_action_pressed("dodge") and state in [S.FREE, S.BLOCK] and stamina >= ROLL_COST:
		_start_roll()
	elif event.is_action_pressed("attack") and stamina >= ATTACK_COST:
		if state in [S.FREE, S.BLOCK]:
			_combo = 0
			_start_attack()
		elif state == S.ATTACK:
			_attack_queued = true
	elif event.is_action_pressed("block") and state == S.FREE:
		_block_pressed_at = _now()
		_set_state(S.BLOCK)
		_play("Block")
	elif event.is_action_pressed("parry") and state in [S.FREE, S.BLOCK] and stamina >= PARRY_COST:
		stamina -= PARRY_COST
		_set_state(S.PARRY)
		_play("Block", 1.6)
	elif event.is_action_pressed("heal") and state == S.FREE and estus > 0 and hp < HP_MAX:
		estus -= 1
		estus_changed.emit(estus)
		_heal_done = false
		_set_state(S.HEAL)
		_busy_timer = 1.3
		_play("Use_Item")


func _start_roll() -> void:
	stamina -= ROLL_COST
	var input := _move_input()
	if input.length() > 0.1:
		var d: Vector3 = rig.camera_basis() * Vector3(input.x, 0, input.y)
		d.y = 0
		_roll_dir = d.normalized()
		_face_dir = _roll_dir
		rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)
		_set_state(S.ROLL)
		_play("Dodge_Forward", 1.0 / ROLL_TIME * 0.9)
	else:
		_roll_dir = -(-global_transform.basis.z) # 입력이 없으면 백스텝
		_set_state(S.ROLL)
		_play("Dodge_Backward", 1.0 / ROLL_TIME * 0.9)


func _start_attack() -> void:
	stamina -= ATTACK_COST
	_attack_hit_done = false
	_attack_queued = false
	_set_state(S.ATTACK)
	_play(ATTACK_ANIMS[_combo], 1.25)


func _deal_damage() -> void:
	var forward := -global_transform.basis.z
	for boss in get_tree().get_nodes_in_group("boss"):
		if not boss.has_method("take_hit"):
			continue
		var to: Vector3 = boss.global_position - global_position
		to.y = 0
		var reach: float = ATTACK_RANGE + boss.get("body_radius") if boss.get("body_radius") != null else ATTACK_RANGE
		if to.length() <= reach and rad_to_deg(forward.angle_to(to.normalized())) <= ATTACK_ARC_DEG:
			var riposte: bool = boss.get("staggered") == true
			var dmg := ATTACK_DAMAGE * (RIPOSTE_MULT if riposte else 1)
			boss.take_hit(dmg, self)
			hit_landed.emit(boss, dmg, riposte)


## 보스가 호출. 반환: "parry" | "block" | "dodge" | "hit" | "dead"
func take_hit(damage: int, from: Node3D = null) -> String:
	if state == S.DEAD:
		return "dead"
	if state == S.ROLL and _state_time <= ROLL_IFRAMES:
		return "dodge"
	if state == S.PARRY and _state_time <= PARRY_WINDOW:
		_set_state(S.BUSY)
		_busy_timer = 0.5
		_play("Block_Attack", 1.3)
		_hit_stop()
		return "parry"
	if state == S.BLOCK:
		if _now() - _block_pressed_at <= PARRY_WINDOW:
			_set_state(S.BUSY)
			_busy_timer = 0.5
			_play("Block_Attack", 1.3)
			_hit_stop()
			return "parry"
		stamina -= BLOCK_HIT_COST
		if stamina >= 0:
			_apply_damage(int(damage * BLOCK_DAMAGE_RATIO))
			_set_state(S.BUSY)
			_busy_timer = 0.45
			_play("Block_Hit")
			return "block"
		stamina = 0 # 가드 브레이크
	_apply_damage(damage)
	if state != S.DEAD:
		_set_state(S.HIT)
		_busy_timer = 0.55
		_play("Hit_A", 1.2)
	return "hit"


## 패리 성공의 손맛 — 아주 짧게 시간을 멈춘다 (실시간 타이머로 복구)
func _hit_stop(scale := 0.12, seconds := 0.22) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _apply_damage(damage: int) -> void:
	hp = maxi(0, hp - damage)
	hp_changed.emit(hp, HP_MAX)
	if hp == 0:
		_set_state(S.DEAD)
		_play("Death_A")
		died.emit()


## 외부 연출(안개문 통과·검 뽑기)이 조작을 잠근다
func play_busy(animation: String, seconds: float) -> void:
	_set_state(S.BUSY)
	_busy_timer = seconds
	_play(animation)


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	hp = HP_MAX
	stamina = STAMINA_MAX
	estus = ESTUS_MAX
	lock_target = null
	hp_changed.emit(hp, HP_MAX)
	estus_changed.emit(estus)
	_set_state(S.FREE)
	_play("Idle")


func is_dead() -> bool:
	return state == S.DEAD


func _set_state(s: int) -> void:
	state = s
	_state_time = 0.0


func _play(name: String, speed := 1.0) -> void:
	if not anim.has_animation(name):
		push_warning("애니메이션 없음: " + name)
		return
	if anim.current_animation == name and anim.is_playing() and name in LOOPS:
		return
	anim.play(name, 0.12, speed)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
