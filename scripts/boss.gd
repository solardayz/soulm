extends CharacterBody3D
## 심판자(IUDEX) — 아리나 한가운데 검에 꿰인 채 잠들어 있다. 검을 뽑으면 깨어나 추격·공격.
## 공격은 예비동작이 긴 2H 모션. 패리 성공 시 스태거(리포스트 기회). 체력 50% 이하에서 2페이즈.

signal hp_changed(hp: int, hp_max: int)
signal awakened
signal phase_changed(phase: int)
signal defeated
signal message(text: String)

enum S { DORMANT, AWAKENING, CHASE, ATTACK, STAGGER, FLINCH, DEAD }

const HP_MAX := 600
const WALK_SPEED := 2.6
const RUN_SPEED := 5.2
const TURN_SPEED := 4.0
const GRAVITY := 22.0
const STAGGER_TIME := 2.6
const POISE := 150 # 이만큼 맞으면 잠깐 휘청

const ATTACKS_P1 := [
	{"anim": "2H_Melee_Attack_Chop", "dmg": 32, "hit": 0.52, "range": 4.0, "arc": 70.0, "cd": 1.2, "lunge": 1.5},
	{"anim": "2H_Melee_Attack_Slice", "dmg": 26, "hit": 0.48, "range": 4.4, "arc": 120.0, "cd": 0.9, "lunge": 1.0},
	{"anim": "2H_Melee_Attack_Stab", "dmg": 36, "hit": 0.5, "range": 5.4, "arc": 40.0, "cd": 1.3, "lunge": 3.5}
]
const ATTACKS_P2 := [
	{"anim": "2H_Melee_Attack_Spin", "dmg": 48, "hit": 0.5, "range": 4.6, "arc": 360.0, "cd": 1.4, "lunge": 0.5}
]
const LOOPS := ["Idle_Combat", "Running_A", "Walking_D_Skeletons", "Skeleton_Inactive_Standing_Pose"]

var hp := HP_MAX
var state := S.DORMANT
var phase := 1
var staggered := false
var lockable := false
var body_radius := 1.2

var _player: CharacterBody3D
var _state_time := 0.0
var _cooldown := 0.0
var _attack: Dictionary = {}
var _hit_done := false
var _poise_damage := 0
var _speed_mult := 1.0

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var sword: Node3D = $CoiledSword
var _range_mesh: MeshInstance3D
var _range_mat: ShaderMaterial
const PARRY_CUE_SECONDS := 0.34 # 명중 직전 이 시간 동안 부채꼴이 노랗게 — 패리 타이밍


func _ready() -> void:
	add_to_group("boss")
	_player = get_tree().get_first_node_in_group("player")
	for a in LOOPS:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_attach_axe()
	_build_range_indicator()
	_play("Skeleton_Inactive_Standing_Pose")
	hp_changed.emit(hp, HP_MAX)


## 바닥 부채꼴 — 공격 사거리·각도를 보여주고 예비동작 동안 차오른다
func _build_range_indicator() -> void:
	_range_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	_range_mesh.mesh = plane
	_range_mat = ShaderMaterial.new()
	_range_mat.shader = load("res://scripts/range_indicator.gdshader")
	_range_mesh.material_override = _range_mat
	_range_mesh.position = Vector3(0, 0.1, 0) # 보스 원점은 발(바닥 y 0) → 타일 윗면(0.05) 바로 위
	_range_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_mesh.visible = false
	add_child(_range_mesh)


func _show_range(attack: Dictionary) -> void:
	_range_mat.set_shader_parameter("range_m", float(attack["range"]) + 0.6)
	_range_mat.set_shader_parameter("arc_deg", float(attack["arc"]))
	_range_mat.set_shader_parameter("progress", 0.0)
	_range_mat.set_shader_parameter("parry_cue", 0.0)
	_range_mat.set_shader_parameter("alpha_mul", 1.0)
	_range_mesh.visible = true


func _update_range(frac: float, len: float) -> void:
	if not _range_mesh.visible:
		return
	var hit: float = _attack["hit"]
	var p := clampf(frac / hit, 0.0, 1.0)
	_range_mat.set_shader_parameter("progress", p)
	var seconds_to_hit := (hit - frac) * len / maxf(anim.speed_scale, 0.01)
	_range_mat.set_shader_parameter("parry_cue", 1.0 if seconds_to_hit <= PARRY_CUE_SECONDS and frac < hit else 0.0)
	if frac >= hit:
		_range_mat.set_shader_parameter("alpha_mul", clampf(1.0 - (frac - hit) * 6.0, 0.0, 1.0))


func _hide_range() -> void:
	if _range_mesh:
		_range_mesh.visible = false


## 뼈 'handslot.r' 에 도끼를 붙인다 (KayKit 리그 규격)
func _attach_axe() -> void:
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel == null:
		return
	var bone := -1
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("handslot") and skel.get_bone_name(i).ends_with("r"):
			bone = i
	if bone < 0:
		return
	var axe_scene: PackedScene = load("res://assets/characters/weapons/Skeleton_Axe.gltf")
	if axe_scene == null:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = bone
	skel.add_child(att)
	var axe: Node3D = axe_scene.instantiate()
	att.add_child(axe)


## 플레이어가 검을 뽑으면 호출
func awaken() -> void:
	if state != S.DORMANT:
		return
	state = S.AWAKENING
	_state_time = 0.0
	if sword:
		var tw := create_tween()
		tw.tween_property(sword, "position:y", sword.position.y + 3.0, 0.8)
		tw.tween_callback(sword.queue_free)
	_play("Skeletons_Awaken_Standing")


func reset() -> void:
	hp = HP_MAX
	phase = 1
	staggered = false
	lockable = false
	_speed_mult = 1.0
	_poise_damage = 0
	_hide_range()
	state = S.DORMANT
	velocity = Vector3.ZERO
	global_position = get_meta("spawn", global_position)
	rotation.y = 0
	_tint(Color(1, 1, 1))
	_play("Skeleton_Inactive_Standing_Pose")
	hp_changed.emit(hp, HP_MAX)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_cooldown -= delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0
	match state:
		S.DORMANT, S.DEAD:
			velocity.x = 0
			velocity.z = 0
		S.AWAKENING:
			velocity.x = 0
			velocity.z = 0
			if not anim.is_playing() or _state_time > 2.8:
				state = S.CHASE
				lockable = true
				awakened.emit()
				message.emit("심판자가 깨어났다")
				_play("Idle_Combat")
		S.CHASE:
			_chase(delta)
		S.ATTACK:
			_attacking(delta)
		S.STAGGER:
			velocity.x = 0
			velocity.z = 0
			if _state_time >= STAGGER_TIME:
				staggered = false
				state = S.CHASE
				_cooldown = 0.6
		S.FLINCH:
			velocity.x = 0
			velocity.z = 0
			if _state_time >= 0.5:
				state = S.CHASE
	move_and_slide()


func _to_player() -> Vector3:
	var v := _player.global_position - global_position
	v.y = 0
	return v


func _chase(delta: float) -> void:
	if _player == null or _player.is_dead():
		velocity.x = 0
		velocity.z = 0
		_play("Idle_Combat")
		return
	var to := _to_player()
	var dist := to.length()
	_turn_toward(to, delta)
	var pool: Array = ATTACKS_P1 + (ATTACKS_P2 if phase == 2 else [])
	var candidates := pool.filter(func(a): return dist <= a["range"] + 0.4)
	if _cooldown <= 0 and not candidates.is_empty():
		_attack = candidates[randi() % candidates.size()]
		_hit_done = false
		state = S.ATTACK
		_state_time = 0.0
		velocity.x = 0
		velocity.z = 0
		_play(_attack["anim"], 1.05 * _speed_mult)
		_show_range(_attack)
		return
	if dist > 3.0:
		var run := dist > 7.0
		var spd := (RUN_SPEED if run else WALK_SPEED) * _speed_mult
		var dir := to.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		_play("Running_A" if run else "Walking_D_Skeletons", _speed_mult)
	else:
		# 사거리 안에서 쿨다운 대기 — 천천히 맴돈다
		var side := to.normalized().cross(Vector3.UP)
		velocity.x = side.x * 1.2
		velocity.z = side.z * 1.2
		_play("Idle_Combat")


func _attacking(delta: float) -> void:
	var len := maxf(anim.current_animation_length, 0.01)
	var frac := anim.current_animation_position / len
	if frac < 0.3:
		_turn_toward(_to_player(), delta * 1.5) # 초반엔 추적, 이후엔 커밋
	var lunge: float = _attack.get("lunge", 0.0)
	if frac > 0.2 and frac < 0.5 and lunge > 0:
		var f := -global_transform.basis.z
		velocity.x = f.x * lunge * 2.0
		velocity.z = f.z * lunge * 2.0
	else:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
	_update_range(frac, len)
	if not _hit_done and frac >= _attack["hit"]:
		_hit_done = true
		_strike()
	if not anim.is_playing() or frac >= 0.97:
		_hide_range()
		state = S.CHASE
		_cooldown = _attack["cd"] / _speed_mult
		_play("Idle_Combat")


func _strike() -> void:
	var to := _to_player()
	var forward := -global_transform.basis.z
	var in_range: bool = to.length() <= float(_attack["range"]) + 0.6
	var in_arc: bool = rad_to_deg(forward.angle_to(to.normalized())) <= float(_attack["arc"]) / 2.0
	if not (in_range and in_arc):
		return
	var result: String = _player.take_hit(int(_attack["dmg"] * (1.15 if phase == 2 else 1.0)), self)
	match result:
		"parry":
			_hide_range()
			staggered = true
			state = S.STAGGER
			_state_time = 0.0
			_play("Hit_B", 0.35)
			message.emit("패리 성공 — 리포스트!")
		"block":
			message.emit("막았다")
		"dodge":
			message.emit("회피")
		"hit":
			pass


func take_hit(damage: int, from: Node3D = null) -> void:
	if state in [S.DORMANT, S.AWAKENING, S.DEAD]:
		return
	hp = maxi(0, hp - damage)
	hp_changed.emit(hp, HP_MAX)
	if hp == 0:
		_hide_range()
		state = S.DEAD
		staggered = false
		lockable = false
		velocity = Vector3.ZERO
		_play("Death_A")
		defeated.emit()
		return
	if phase == 1 and hp <= HP_MAX / 2:
		_hide_range()
		phase = 2
		_speed_mult = 1.25
		_tint(Color(0.35, 0.2, 0.25))
		state = S.FLINCH
		_state_time = -1.2 # Taunt 동안 멈춤
		_play("Taunt_Longer", 1.3)
		phase_changed.emit(2)
		message.emit("심판자가 본성을 드러낸다")
		return
	if staggered:
		_hide_range()
		staggered = false
		state = S.FLINCH
		_state_time = 0.0
		_play("Hit_A")
		return
	_poise_damage += damage
	if _poise_damage >= POISE and state != S.ATTACK:
		_poise_damage = 0
		state = S.FLINCH
		_state_time = 0.0
		_play("Hit_A", 1.3)


func _turn_toward(dir: Vector3, delta: float) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, TURN_SPEED * delta))


func _tint(color: Color) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.get_surface_override_material_count():
			var mat := m.get_active_material(i)
			if mat is StandardMaterial3D:
				var dup := mat.duplicate() as StandardMaterial3D
				dup.albedo_color = color
				m.set_surface_override_material(i, dup)


func _play(name: String, speed := 1.0) -> void:
	if not anim.has_animation(name):
		push_warning("보스 애니메이션 없음: " + name)
		return
	if anim.current_animation == name and anim.is_playing() and name in LOOPS:
		return
	anim.play(name, 0.15, speed)
