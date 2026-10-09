extends Node3D
## 레벨 — KayKit 던전 조각으로 "화톳불 → 돌길 → 안개문 → 폐허 아리나"를 코드로 쌓는다.
## 좌표: 시작(화톳불)이 +Z, 안개문이 z=0, 아리나가 -Z 쪽. 타일 4×4, 벽 4(폭)×4(높이)×1(두께).

const DIR := "res://assets/dungeon/"
const ARENA_Z := -18.0 # 아리나 중심
const ARENA_HALF := 16.0

var _rng := RandomNumberGenerator.new()
var _cache := {}


func _ready() -> void:
	_rng.seed = 20261009
	_build_path()
	_build_gate_wall()
	_build_arena()
	_build_floor_collision()


# ── 조각 하나 놓기 (시각 + 선택적 박스 충돌)
func _piece(name: String, pos: Vector3, rot_y_deg := 0.0, collider: Vector3 = Vector3.ZERO, collider_offset := Vector3.ZERO, scale := 1.0) -> Node3D:
	var scene: PackedScene = _cache.get(name)
	if scene == null:
		scene = load(DIR + name + ".glb")
		_cache[name] = scene
	var node: Node3D = scene.instantiate()
	node.position = pos
	node.rotation_degrees.y = rot_y_deg
	if scale != 1.0:
		node.scale = Vector3.ONE * scale
	add_child(node)
	if collider != Vector3.ZERO:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = collider
		shape.shape = box
		shape.position = collider_offset
		body.add_child(shape)
		body.position = pos
		body.rotation_degrees.y = rot_y_deg
		add_child(body)
	return node


func _wall(kind: String, pos: Vector3, rot_y_deg := 0.0) -> void:
	_piece(kind, pos, rot_y_deg, Vector3(4, 4, 1), Vector3(0, 2, 0))


func _torch(pos: Vector3, rot_y_deg: float) -> void:
	_piece("torch_mounted", pos, rot_y_deg)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 2.2
	light.omni_range = 7.0
	light.shadow_enabled = false
	light.position = pos + Vector3(0, 0.8, 0)
	add_child(light)


func _wall_kind() -> String:
	var r := _rng.randf()
	return "wall" if r < 0.6 else ("wall_cracked" if r < 0.85 else "wall_broken")


# ── 시작 돌길: z 2 ~ 26, 양옆 벽
func _build_path() -> void:
	for z in [4, 8, 12, 16, 20, 24]:
		for x in [-2, 2]:
			_piece("floor_tile_large", Vector3(x, 0, z))
	for z in [2, 6, 10, 14, 18, 22, 26]:
		_wall(_wall_kind(), Vector3(-5, 0, z), 90)
		_wall(_wall_kind(), Vector3(5, 0, z), 90)
	for x in [-2, 2]:
		_wall("wall", Vector3(x, 0, 28), 0)
	for z in [6, 14, 22]:
		_torch(Vector3(-4.4, 2.2, z), 90)
		_torch(Vector3(4.4, 2.2, z), -90)
	# 길가 잔해
	_piece("rubble_half", Vector3(-4.6, 0, 9), 0)
	_piece("chest", Vector3(3.4, 0, 25), -120, Vector3(1.7, 1, 1.9), Vector3(0, 0.4, 0.3))


# ── 안개문이 박힌 벽 (z = 0)
func _build_gate_wall() -> void:
	for x in [-16, -12, -8, -4, 4, 8, 12, 16]:
		_wall(_wall_kind() if absf(x) > 4 else "wall", Vector3(x, 0, 0), 0)
	# 문틀: 문 자체는 FogGate 노드(투명 벽 포함)가 담당
	var doorway := _piece("wall_doorway", Vector3(0, 0, 0), 0)
	var door := doorway.find_child("wall_doorway_door", true, false) # 나무문은 떼고 안개만 남긴다
	if door:
		door.visible = false
	for sx in [-1.5, 1.5]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 4, 1)
		shape.shape = box
		shape.position = Vector3(sx, 2, 0)
		body.add_child(shape)
		add_child(body)
	var lintel := StaticBody3D.new()
	var ls := CollisionShape3D.new()
	var lb := BoxShape3D.new()
	lb.size = Vector3(4, 1, 1)
	ls.shape = lb
	ls.position = Vector3(0, 3.5, 0)
	lintel.add_child(ls)
	add_child(lintel)
	for x in [-2, 2]:
		_piece("floor_tile_large", Vector3(x, 0, 0))
	_piece("banner_white", Vector3(-3.2, 0, 0), 0)
	_piece("banner_white", Vector3(3.2, 0, 0), 0)
	_torch(Vector3(-6, 2.2, 0.5), 0)
	_torch(Vector3(6, 2.2, 0.5), 0)


# ── 아리나: 32×32 폐허 뜰, 기둥·잔해·횃불
func _build_arena() -> void:
	for x in range(-14, 15, 4):
		for z in range(-32, -3, 4):
			var r := _rng.randf()
			var kind := "floor_tile_large" if r < 0.78 else ("floor_tile_large_rocks" if r < 0.9 else "floor_dirt_large_rocky")
			_piece(kind, Vector3(x, 0, z), [0, 90, 180, 270][_rng.randi() % 4])
	for x in range(-14, 15, 4):
		_wall(_wall_kind(), Vector3(x, 0, -34), 0)
	for z in range(-32, -1, 4):
		_wall(_wall_kind(), Vector3(-16, 0, z), 90)
		_wall(_wall_kind(), Vector3(16, 0, z), 90)
	for p in [Vector3(-9, 0, -9), Vector3(9, 0, -9), Vector3(-9, 0, -27), Vector3(9, 0, -27)]:
		_piece("pillar", p, 0, Vector3(1.5, 4, 1.5), Vector3(0, 2, 0))
	_piece("rubble_large", Vector3(-10, 0, -32.5), 0, Vector3(8, 3, 3), Vector3(0, 1.5, 0))
	_piece("rubble_large", Vector3(12, 0, -31.5), 25, Vector3(8, 3, 3), Vector3(0, 1.5, 0))
	_piece("rubble_half", Vector3(-15.2, 0, -14), 90, Vector3(3, 3, 4), Vector3(0, 1.5, 2))
	_piece("column", Vector3(14.5, 0, -6), 0, Vector3(0.7, 1.4, 0.7), Vector3(0, 0.7, 0))
	_piece("column", Vector3(-14.5, 0, -24), 0, Vector3(0.7, 1.4, 0.7), Vector3(0, 0.7, 0))
	_piece("sword_shield_broken", Vector3(6, 1.2, -33.4), 0)
	_piece("banner_thin_white", Vector3(-6, 0, -34), 0)
	_piece("banner_thin_white", Vector3(6, 0, -34), 0)
	for z in [-10, -26]:
		_torch(Vector3(-15.4, 2.2, z), 90)
		_torch(Vector3(15.4, 2.2, z), -90)
	_torch(Vector3(-2, 2.2, -33.4), 0)
	_torch(Vector3(2, 2.2, -33.4), 0)


func _build_floor_collision() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 70)
	shape.shape = box
	shape.position = Vector3(0, -0.5, -4)
	body.add_child(shape)
	add_child(body)
