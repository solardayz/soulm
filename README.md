# NTB Souls — 안개문에서 첫 보스까지 (Godot 4.7)

다크소울3의 "재의 묘지 → 안개문 → 심판자 군다" 구간을 **무료(CC0) 에셋**으로 닮게 만든 데모.
화톳불에서 출발 → 돌길 → 하얀 안개문(E로 통과) → 폐허 뜰 한가운데 검에 꿰인 채 잠든 보스 → 검을 뽑으면(E) 보스전.

## 열기
Godot 4.7 프로젝트 매니저 → **가져오기** → 이 폴더의 `project.godot` → **가져오기 및 편집** → ▶ (⌘B).
처음 열 때 에셋 임포트에 10~20초 걸린다.

## 조작
| 키 | 동작 |
|---|---|
| WASD / 방향키 | 이동 (카메라 기준) |
| 마우스 | 시점 · Esc 로 마우스 풀기/잡기 |
| Space | 구르기 (앞 0.42초 무적). 입력 없으면 백스텝 |
| J / 마우스 왼쪽 | 공격 (2연타, 공격 중 한 번 더 누르면 이어짐) |
| Shift (누르고 있기) | 방패 막기 (피해 85% 감소, 스태미나 소모). 누른 직후 0.32초 안에 맞아도 패리 |
| **F / 마우스 오른쪽** | **패리** — 0.32초 성공 창, 그 뒤 0.13초는 빈틈. 성공하면 히트스톱 + 보스 스태거 → 공격이 리포스트(3배) |
| T | 터치 조작(가상 조이스틱·버튼) 켜고 끄기 — 터치 기기에선 자동으로 켜짐 |
| Tab / 마우스 가운데 | 락온 |
| R | 에스트 (체력 +55, 3개, 화톳불에서 충전) |
| E | 상호작용 — 안개문 통과 · 검 뽑기 · 화톳불 휴식 |

## 공격 범위 표시 / 패리 타이밍
보스가 공격 예비동작에 들어가면 바닥에 **붉은 부채꼴**(사거리·각도)이 뜨고 안쪽이 차오른다. 명중 **0.34초 전부터 노란색**으로 바뀌는데, 이때 패리(F)를 누르면 성공한다. 부채꼴 밖으로 나가거나 구르기 무적(앞 0.42초)으로 피할 수도 있다.

## 모바일
터치 기기에서는 왼쪽 가상 조이스틱, 오른쪽 공격·구르기·막기(홀드)·패리·에스트·락온 버튼이 자동으로 뜨고, 상호작용이 가능할 때 E 버튼이 나타난다. 화면 나머지 부분을 드래그하면 시점 회전. (`scripts/touch_controls.gd`, 코드로 그린 UI라 씬 수정 없이 버튼 위치·크기를 바꿀 수 있다)

## 보스 "심판자 IUDEX"
- 잠든 상태 → 검을 뽑으면 깨어남 → 추격(걷기/달리기) → 사거리 안에서 2H 예비동작 뒤 공격(찍기·베기·찌르기)
- 체력 50% 이하 → 2페이즈: 색이 어두워지고 25% 빨라지며 회전 베기 추가
- 예비동작을 보고 패리 → 스태거 2.6초 → 리포스트. 누적 피해 150마다 잠깐 휘청
- 사망 시 "YOU DIED" → 화톳불에서 부활, 보스·안개문 초기화. 승리 시 안개가 걷힌다

## 구조
| 경로 | 역할 |
|---|---|
| `scenes/Main.tscn` | 월드·플레이어·보스·안개문·화톳불·HUD |
| `scripts/level.gd` | KayKit 던전 조각으로 길·안개문 벽·아리나를 코드로 쌓음(충돌 포함) |
| `scripts/player.gd` | 상태기계(이동/구르기/공격/막기·패리/피격/에스트/연출 잠금) + Mixamo 클립 재생 |
| `scripts/mixamo_rig.gd` | Mixamo 클립 FBX 들을 모델의 AnimationPlayer 로 합침(루트 모션 제거, 반복 설정) |
| `scripts/boss.gd` | 보스 AI(잠듦/깨어남/추격/공격/스태거/2페이즈/사망) + 도끼 본 부착 |
| `scripts/fog_gate.gd` + `fog_gate.gdshader` | 안개(노이즈 셰이더) · 통과 연출 · 보이지 않는 벽 |
| `scripts/camera_rig.gd` | 3인칭 오빗 카메라 · 스프링암 · 락온 |
| `scripts/bonfire.gd`, `hud.gd`, `main.gd` | 화톳불 · HUD · 게임 흐름(사망/부활/승리) |

`Godot --path . -- --shot` 으로 실행하면 `_shots/`에 검증용 스크린샷을 찍고 전투 스모크 테스트 후 종료한다.

## 에셋
### Mixamo (Adobe, 게임 안에 포함해 쓰는 건 무료 · 원본 파일 재배포 금지)
- 플레이어: Paladin WProp J Nordstrom + Pro Sword and Shield Pack + Stand To Roll — `assets/mixamo/`(저장소에 올리지 않음, .gitignore). 받는 방법: mixamo.com 로그인 → Characters에서 Paladin → Download(FBX Binary, T-pose) → Animations에서 "Pro Sword and Shield Pack"과 "Stand To Roll"(In Place) → `assets/mixamo/{paladin,anim}/` 에 `scripts/player.gd` 의 CLIPS 이름으로 저장.

### KayKit (모두 CC0 — Kay Lousberg, kaylousberg.com)
- KayKit Dungeon Remastered 1.0 — 바닥·벽·기둥·잔해·횃불·배너
- KayKit Character Pack: Adventurers 1.0 — (이전 플레이어 Knight, 지금은 안 씀)
- KayKit Character Pack: Skeletons 1.0 — 보스(Skeleton_Warrior ×2.2, 애니메이션 95개) + 도끼
라이선스 원문은 `assets/characters/LICENSE_*.txt`, `assets/dungeon/LICENSE_dungeon.txt`. 원본 전체 팩은 `_downloads/`(지워도 됨).

## 한계 / 다음 할 일
- 사운드 없음(CC0 효과음 추가 예정), 보스 공격은 거리·각도 판정(무기 히트박스 아님)
- 다크소울3 고유 자산(모델·음악·대사)은 저작권이라 쓰지 않았다 — 연출과 조작감만 닮게 했다
