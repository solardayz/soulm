class_name MixamoRig
## Mixamo FBX 애니메이션을 한 AnimationPlayer 로 모은다.
## Mixamo 는 클립마다 FBX 하나(같은 뼈대, 애니메이션 이름은 항상 "mixamo_com")라서
## 모델의 AnimationPlayer 에 클립 파일들을 읽어 이름을 붙여 넣는다. 트랙 경로가 "Skeleton3D:mixamorig_*" 로 같아 그대로 맞는다.

const ANIM_DIR := "res://assets/mixamo/anim/"
const HIPS_POS_PATH := "Skeleton3D:mixamorig_Hips"


## clips: { "Idle": "idle", ... } (이름 → 파일 이름, .fbx 제외) · loops: 반복 재생할 이름들
static func build(player: AnimationPlayer, clips: Dictionary, loops: Array) -> void:
	var lib := AnimationLibrary.new()
	for name in clips:
		var path: String = ANIM_DIR + clips[name] + ".fbx"
		var ps: PackedScene = load(path)
		if ps == null:
			push_warning("Mixamo 클립 없음: " + path)
			continue
		var inst: Node = ps.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		var src: Animation = ap.get_animation("mixamo_com") if ap and ap.has_animation("mixamo_com") else null
		if src == null:
			push_warning("Mixamo 클립에 애니메이션이 없음: " + path)
			inst.free()
			continue
		var a: Animation = src.duplicate(true)
		_strip_root_motion(a)
		a.loop_mode = Animation.LOOP_LINEAR if name in loops else Animation.LOOP_NONE
		lib.add_animation(name, a)
		inst.free()
	if player.has_animation_library(""):
		player.remove_animation_library("")
	player.add_animation_library("", lib)


## 이동은 코드가 하므로 골반의 수평 이동(루트 모션)은 첫 키 위치에 고정한다 (위아래 흔들림은 남긴다)
static func _strip_root_motion(a: Animation) -> void:
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D or String(a.track_get_path(i)) != HIPS_POS_PATH:
			continue
		var n := a.track_get_key_count(i)
		if n == 0:
			continue
		var first: Vector3 = a.track_get_key_value(i, 0)
		for k in n:
			var v: Vector3 = a.track_get_key_value(i, k)
			a.track_set_key_value(i, k, Vector3(first.x, v.y, first.z))
