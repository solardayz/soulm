extends Node3D
## 게임 흐름 — 신호를 묶는다: 안개문 통과 → 검 뽑기 → 보스전 → 승리/사망·부활

const BOSS_NAME := "심판자 (돌연변이 괴물)"

@onready var player: CharacterBody3D = $Player
@onready var boss: CharacterBody3D = $Boss
@onready var fog_gate: Node3D = $FogGate
@onready var bonfire: Node3D = $Bonfire
@onready var hud: CanvasLayer = $HUD
@onready var sword_prompt: Area3D = $Boss/SwordPrompt
@onready var touch: CanvasLayer = $TouchControls

var _sword_near := false


func _ready() -> void:
	boss.set_meta("spawn", boss.global_position)
	player.hp_changed.connect(hud.set_hp)
	player.stamina_changed.connect(hud.set_stamina)
	player.estus_changed.connect(hud.set_estus)
	player.died.connect(_on_player_died)
	boss.hp_changed.connect(hud.set_boss_hp)
	boss.awakened.connect(func(): hud.show_boss(BOSS_NAME))
	boss.message.connect(hud.show_message)
	boss.defeated.connect(_on_boss_defeated)
	fog_gate.prompt.connect(_prompt)
	fog_gate.traversed.connect(func(): hud.show_message("심판자의 뜰", 2.0))
	bonfire.prompt.connect(_prompt)
	bonfire.rested.connect(_on_rested)
	sword_prompt.body_entered.connect(func(b): if b.is_in_group("player"): _sword_near = true; _sword_prompt())
	sword_prompt.body_exited.connect(func(b): if b.is_in_group("player"): _sword_near = false; _sword_prompt())
	hud.set_estus(player.estus)
	_debug_screenshots()


func _prompt(text: String) -> void:
	hud.set_prompt(text)
	touch.set_interact_available(text != "")


func _sword_prompt() -> void:
	_prompt("검을 뽑는다 (심판자 각성)  [E]" if _sword_near and boss.state == boss.S.DORMANT else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _sword_near and boss.state == boss.S.DORMANT and not player.is_dead():
		_prompt("")
		player.play_busy("Interact", 1.4)
		await get_tree().create_timer(0.9).timeout
		boss.awaken()


func _on_boss_defeated() -> void:
	hud.hide_boss()
	hud.show_big("심판자를 쓰러뜨렸다", Color(1.0, 0.85, 0.45), 3.5)
	fog_gate.dissolve()


func _on_player_died() -> void:
	hud.show_big("YOU DIED", Color(0.75, 0.1, 0.1), 2.6)
	await get_tree().create_timer(3.2).timeout
	await hud.fade(1.0, 0.8)
	_respawn()
	await get_tree().create_timer(0.4).timeout
	await hud.fade(0.0, 1.0)


func _on_rested() -> void:
	player.hp = player.HP_MAX
	player.estus = player.ESTUS_MAX
	player.hp_changed.emit(player.hp, player.HP_MAX)
	player.estus_changed.emit(player.estus)
	if boss.state != boss.S.DEAD:
		boss.reset()
		fog_gate.reset()
		hud.hide_boss()
	hud.show_message("휴식 — 체력과 에스트가 회복되었다", 2.0)


func _respawn() -> void:
	player.respawn(bonfire.respawn_point())
	player.rotation.y = 0
	$Player/CameraRig.lock_target = null
	if boss.state != boss.S.DEAD:
		boss.reset()
		fog_gate.reset()
	hud.hide_boss()
	_prompt("")


## 검증용: `--shot` 인자로 실행하면 몇 프레임 뒤 스크린샷을 저장하고 종료한다
func _debug_screenshots() -> void:
	if not "--shot" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	for i in 45:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://_shots/start.png")
	# 안개문 앞으로 순간이동해서 한 장 더
	player.global_position = Vector3(0, 0.2, 4)
	player.rotation.y = 0
	$Player/CameraRig.yaw = 0
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://_shots/gate.png")
	player.global_position = Vector3(0, 0.2, -12)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://_shots/arena.png")
	# 전투 스모크 테스트: 검을 뽑고 보스가 깨어나 공격하는지, 플레이어 공격이 들어가는지
	boss.awaken()
	for i in 200:
		await get_tree().process_frame
	player.global_position = boss.global_position + Vector3(0, 0, 3.0)
	player.rotation.y = PI
	# 보스가 공격 예비동작에 들어가 범위 부채꼴이 보일 때를 잡는다 (위에서 내려다보는 각도)
	$Player/CameraRig.pitch = -0.8
	$Player/CameraRig/SpringArm3D.spring_length = 10.0
	for i in 400:
		await get_tree().process_frame
		if boss.state == boss.S.ATTACK and boss._range_mesh.visible:
			for k in 12:
				await get_tree().process_frame
			break
	get_viewport().get_texture().get_image().save_png("res://_shots/fight.png")
	# 범위 표시 강제 — 렌더링 자체를 확인
	boss._show_range(boss.ATTACKS_P1[1])
	boss._range_mat.set_shader_parameter("progress", 0.6)
	boss._range_mat.set_shader_parameter("parry_cue", 1.0)
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://_shots/range.png")
	print("[shot] range visible=", boss._range_mesh.visible, " gpos=", boss._range_mesh.global_position, " aabb=", boss._range_mesh.get_aabb(), " mat=", boss._range_mesh.material_override, " params r=", boss._range_mat.get_shader_parameter("range_m"), " a=", boss._range_mat.get_shader_parameter("alpha_mul"))
	print("[shot] boss state=", boss.state, " boss hp=", boss.hp, " player hp=", player.hp, " player state=", player.state)
	boss.take_hit(100, player)
	await get_tree().process_frame
	print("[shot] after hit boss hp=", boss.hp)
	# 공격 판정: 보스 앞 2m 에서 마주보면 맞고, 등을 돌리면 안 맞아야 한다
	var hp0: int = boss.hp
	var fwd: Vector3 = -boss.global_transform.basis.z
	player.global_position = boss.global_position + fwd * (boss.body_radius + 1.5)
	player.rotation.y = atan2(fwd.x, fwd.z) # 보스를 마주봄 (-Z 전방)
	player._deal_damage()
	var facing_hit: bool = boss.hp < hp0
	hp0 = boss.hp
	player.rotation.y += PI # 등을 돌림
	player._deal_damage()
	var back_hit: bool = boss.hp < hp0
	print("[shot] attack arc: facing hit=", facing_hit, " back hit=", back_hit)
	get_tree().quit()
