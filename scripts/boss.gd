extends CharacterBody3D
## 심판자(IUDEX) — 아리나 한가운데 검에 꿰인 채 잠들어 있다. 검을 뽑으면 깨어나 추격·공격.
## 모델은 Mixamo Mutant(근육 괴물) + Creature Pack 클립. 공격은 할퀴기·펀치·점프 내려찍기.
## 패리 성공 시 스태거(리포스트 기회). 체력 50% 이하에서 2페이즈(포효 후 빨라지고 점프 공격이 넓어진다).

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

# hit: 클립 진행률 중 명중 시점 · speed: 클립 재생 속도 (Mixamo 클립 길이가 제각각이라 공격마다 정한다)
const ATTACKS_P1 := [
	{"anim": "Swipe", "dmg": 28, "hit": 0.45, "range": 3.8, "arc": 110.0, "cd": 1.0, "lunge": 1.0, "speed": 1.1},
	{"anim": "Punch", "dmg": 34, "hit": 0.5, "range": 3.6, "arc": 60.0, "cd": 1.1, "lunge": 1.5, "speed": 0.9},
	{"anim": "Jump_Attack", "dmg": 40, "hit": 0.62, "range": 6.0, "arc": 50.0, "cd": 1.5, "lunge": 3.5, "speed": 1.25}
]
const ATTACKS_P2 := [
	{"anim": "Jump_Attack", "dmg": 50, "hit": 0.62, "range": 7.0, "arc": 100.0, "cd": 1.3, "lunge": 4.5, "speed": 1.35}
]
# 이름 → assets/mixamo/mutant_anim/<파일>.fbx
const CLIPS := {
	"Dormant": "breathing_idle",
	"Awaken": "roar",
	"Idle": "idle",
	"Walk": "walk",
	"Run": "run",
	"Swipe": "swipe",
	"Punch": "punch",
	"Jump_Attack": "jump_attack",
	"Stagger": "breathing_idle",
	"Flinch": "flex",
	"Roar": "roar",
	"Death": "dying"
}
const LOOPS := ["Idle", "Run", "Walk", "Dormant", "Stagger"]

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
	MixamoRig.build(anim, CLIPS, LOOPS, "res://assets/mixamo/mutant_anim/")
	_attach_equipment()
	_build_range_indicator()
	_play("Dormant")
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


## 뼈 'handslot.r'에 무기, 'handslot.l'에 대형 해골 방패를 장착하고 머리에 붉은 안광을 붙인다
func _attach_equipment() -> void:
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel == null:
		return
	
	var bone_r := -1
	var bone_l := -1
	var bone_head := skel.find_bone("mixamorig_Head") # Mixamo 리그는 이름이 고정
	for i in skel.get_bone_count():
		var bname := skel.get_bone_name(i).to_lower()
		if bname.begins_with("handslot") and bname.ends_with("r"):
			bone_r = i
		elif bname.begins_with("handslot") and bname.ends_with("l"):
			bone_l = i
		elif bone_head < 0 and "head" in bname:
			bone_head = i

	# 1. 오른손 무기: 해골 대검/도끼
	if bone_r >= 0:
		var wp_scene: PackedScene = load("res://assets/characters/weapons/Skeleton_Blade.gltf")
		if wp_scene == null:
			wp_scene = load("res://assets/characters/weapons/Skeleton_Axe.gltf")
		if wp_scene:
			var att_r := BoneAttachment3D.new()
			att_r.bone_idx = bone_r
			skel.add_child(att_r)
			var wp: Node3D = wp_scene.instantiate()
			wp.scale = Vector3(1.3, 1.3, 1.3)
			att_r.add_child(wp)

	# 2. 왼손 무기: 대형 해골 방패
	if bone_l >= 0:
		var shield_scene: PackedScene = load("res://assets/characters/weapons/Skeleton_Shield_Large_A.gltf")
		if shield_scene:
			var att_l := BoneAttachment3D.new()
			att_l.bone_idx = bone_l
			skel.add_child(att_l)
			var shield: Node3D = shield_scene.instantiate()
			shield.scale = Vector3(1.4, 1.4, 1.4)
			att_l.add_child(shield)

	# 3. 해골 눈빛: 붉은 안광 효과 (Dark Souls 보스 감성)
	if bone_head >= 0:
		var att_head := BoneAttachment3D.new()
		att_head.bone_idx = bone_head
		skel.add_child(att_head)
		var eye_light := OmniLight3D.new()
		eye_light.light_color = Color(1.0, 0.25, 0.1)
		eye_light.light_energy = 3.0
		eye_light.omni_range = 3.5
		eye_light.position = Vector3(0, 0.35, 0.35)
		att_head.add_child(eye_light)


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
	_play("Awaken", 1.2)


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
	_play("Dormant")
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
				_play("Idle")
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
		_play("Idle")
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
		_play(_attack["anim"], float(_attack.get("speed", 1.0)) * _speed_mult)
		_show_range(_attack)
		return
	if dist > 3.0:
		var run := dist > 7.0
		var spd := (RUN_SPEED if run else WALK_SPEED) * _speed_mult
		var dir := to.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		_play("Run" if run else "Walk", _speed_mult)
	else:
		# 사거리 안에서 쿨다운 대기 — 천천히 맴돈다
		var side := to.normalized().cross(Vector3.UP)
		velocity.x = side.x * 1.2
		velocity.z = side.z * 1.2
		_play("Idle")


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
		_play("Idle")


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
			_play("Stagger", 0.6)
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
		_play("Death")
		defeated.emit()
		return
	if phase == 1 and hp <= HP_MAX / 2:
		_hide_range()
		phase = 2
		_speed_mult = 1.25
		_tint(Color(0.85, 0.25, 0.2))
		state = S.FLINCH
		_state_time = -1.2 # Taunt 동안 멈춤
		_play("Roar", 1.3)
		phase_changed.emit(2)
		message.emit("괴물이 붉은 분노를 내뿜는다!")
		return
	if staggered:
		_hide_range()
		staggered = false
		state = S.FLINCH
		_state_time = 0.0
		_play("Flinch", 2.5)
		return
	_poise_damage += damage
	if _poise_damage >= POISE and state != S.ATTACK:
		_poise_damage = 0
		state = S.FLINCH
		_state_time = 0.0
		_play("Flinch", 3.0)


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
