extends Node
## 효과음·BGM 관리 (자동 로드 "Audio"). 어디서든 Audio.sfx("swing") · Audio.bgm("boss").
## 파일은 assets/audio/ (출처·라이선스는 LICENSE_audio.txt). 웹에서는 첫 클릭/키 입력 뒤에 소리가 나기 시작한다.

const SFX_DIR := "res://assets/audio/sfx/"
const BGM_DIR := "res://assets/audio/bgm/"
# 이름 → 후보 파일들 (여러 개면 무작위로 골라 반복감을 줄인다)
const SFX := {
	"swing": ["swing_1", "swing_2", "swing_3"],
	"clash": ["clash_1", "clash_2", "clash_3"],
	"hit": ["hit_0", "hit_1", "hit_2"],
	"hurt": ["hurt_0", "hurt_1", "hurt_2"],
	"step": ["step_0", "step_1", "step_2", "step_3", "step_4"],
	"parry": ["parry"],
	"gong": ["gong"],
	"roll": ["roll"],
	"estus": ["estus"],
	"ui": ["ui"]
}
const BGM := {"ambient": "ambient.ogg", "boss": "boss.mp3"}
const BGM_DB := -11.0
const POOL := 10

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_name := ""


func _ready() -> void:
	for name in SFX:
		_streams[name] = []
		for f in SFX[name]:
			var s: AudioStream = load(SFX_DIR + f + ".ogg")
			if s:
				_streams[name].append(s)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	add_child(_bgm_a)
	add_child(_bgm_b)
	bgm("ambient")


## 효과음 하나. vol_db 로 크기, pitch 로 높낮이(괴물은 낮게), jitter 로 매번 조금씩 다르게
func sfx(name: String, vol_db := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	var list: Array = _streams.get(name, [])
	if list.is_empty():
		return
	var p: AudioStreamPlayer = null
	for cand in _pool:
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = _pool[0]
	p.stream = list[randi() % list.size()]
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.play()


## 배경음 교체 — 1.2초 크로스페이드. 같은 곡이면 그대로
func bgm(name: String) -> void:
	if name == _bgm_name:
		return
	var path: String = BGM_DIR + BGM.get(name, "")
	var s: AudioStream = load(path) if BGM.has(name) else null
	if s == null:
		push_warning("BGM 없음: " + name)
		return
	if "loop" in s:
		s.loop = true
	_bgm_name = name
	var out := _bgm_a if _bgm_a.playing else _bgm_b
	var into := _bgm_b if out == _bgm_a else _bgm_a
	into.stream = s
	into.volume_db = -40.0
	into.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(into, "volume_db", BGM_DB, 1.2)
	if out.playing:
		tw.tween_property(out, "volume_db", -40.0, 1.2)
		tw.chain().tween_callback(out.stop)
