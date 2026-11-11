# 이 저장소에서 작업할 때 지킬 것

유민혁(minhyuk94)의 개인 프로젝트 "파이트 고!". 사용자는 한국어로 대화합니다. 게임 글자도 한국어.

## 무엇인가

옥상에서 여럿이 싸우는 3D 난투 액션 (지금은 컴퓨터 3명과). Godot 4.6(GDScript, GL Compatibility), 웹으로 내보내 GitHub Pages(`https://mhyoo-games.github.io/fight-go/`, 조직 mhyoo-games).
사용자가 유형·장신구·무대를 **조금씩 늘려 갈** 계획이다.

## 지킬 것

- 옛 온라인 난투 게임에서 영감을 받았지만 **새로 만든 게임**이다. 다른 게임·만화의 이름·캐릭터·기술 이름·그림을 쓰지 않고, 다른 회사·게임 이름을 README·화면·이력서에 넣지 않는다. 유형 이름도 우리 것(주먹꾼·요원·염력사·장사).
- 키(사용자가 정한 것, 바꾸지 않는다): 방향키 걷기, 같은 방향 두 번 = 달리기 / Z 조준 / X 약 / C 강 / V 점프 / Z+X·Z+C 장신구 기술 / Z+X+C 필살기 / 달리며 X·C 대시 공격, 달리며 X+C 대시 필살기 / 공중 X+C 점프 필살기 / 무기 옆 X·C 줍기 / 문 앞 ↑ / X+C 같이 = 막기.
- **밸런스가 가장 중요**(사용자 요청): 누운 상대는 못 때린다(`_can_hit`), 일어날 때 무적, 띄운 상대는 `JUG_MAX`번까지 이어 때릴 수 있고 갈수록 약해진다(`JUG_SCALE`). 숫자를 바꾸면 `_juggle`·`_ai_match`(유형별 승리 수) 테스트를 같이 본다. 컴퓨터끼리는 장사가 조금 유리하게 나오는 편.
- **캐릭터는 사용자가 준 Kenney Animated Characters Protagonists(CC0, `assets/hero/`, 모델 하나 + 옷 4장)**, 나머지(동작·장신구·무기·무대)는 코드로. 팩에는 run·idle·jump 동작뿐이라 쓰지 않고, `scripts/fighter.gd`가 뼈를 직접 움직인다: 자세 `POSES`(내 관절 각도, 팔을 내린 것이 기준, `<이름>_w`는 준비 자세) → `_apply`가 모델 뼈(`BONES`, T자세라 팔은 `OFF_L/R`로 맞춤, 좌표 변환 `CB`)에 넣는다. 걷기·달리기는 `_loco`가 계산, `sync`가 규칙 상태 → 준비/치기/돌아오기 자세와 섞는 빠르기를 고른다. 장신구 모양 `equip`·줍는 무기 `weapon_mesh`/`hold`는 `_socket`(뼈에 붙는 자리, 내 좌표·크기 그대로)에 붙인다. 유형별 차이는 `LOOKS`(옷·크기·서 있는 자세), 컴퓨터는 색을 살짝 입힌다. 사용자가 "동작이 뚝뚝 끊긴다"고 했던 것 → 자세는 늘 부드럽게 이어지게.
- 막기(사용자 요청): X+C를 같이 누르고 있기. 앞에서 온 공격만 막고(`BLOCK_CHIP`만큼만 아픔), 막기 힘(`guard`, DEF에 따라)이 다하면 깨져 멍해진다. X 바로 뒤에 C가 눌리면 `GUARD_CANCEL` 안에서 공격을 접고 막는다. 달리는 중 X+C는 대시 필살기, Z+X+C는 필살기, 공중 X+C는 점프 필살기.
- 무대는 `Rules.city()` 하나가 기준: `plats`(kind roof·step·hut·box·plank·room·wall), `doors`(짝끼리 오감), `items`(무기 자리), `ramps`(컴퓨터가 오르는 길). `scripts/stage.gd`는 이것을 읽어 그리고 꾸밈만 더한다. 창고(실내)는 x>50에 멀리 떨어뜨려 둔 곳(`Rules.zone`).
- 규칙은 `scripts/rules.gd`: 유형 `STYLES`(능력치 `p` = STR·TEC·SPD·JMP·DEF 1~10 → `derive`가 실제 값으로), 장신구 `ACCS`(값 price·`mod` 능력치 덤·zx·zc 기술), 줍는 무기 `WEAPONS`(uses 횟수), 기술 표 `moves()`(st 준비·act 맞는 시간·rec 빈틈·dmg·kb·up·reach·wide·lunge, rehit 연타, shot 날아가는 것(boom 터짐), dash 통과, hop 뛰어오름, use 무기 횟수), `move_for`가 유형별 차이를 얹는다. `step`(선수 한 명) → `resolve`(맞는 판정·몸 밀기·탄). 돈·상점·저장 `reward/buy/parse_save`(`user://fightgo_save.json`). 새 유형·장신구·기술에는 `tests/run_tests.gd` 테스트(자료 검사는 저절로 돎).
- 장신구를 더할 때: `ACCS`에 값·mod·zx·zc, `moves()`에 기술, `Fighter.equip`에 모양, 필요하면 `POSES`에 자세, `move_for`에 유형별 차이. 이름은 우리 것으로 새로 짓는다.
- 화면 쪽 `scripts/match.gd`: 두 번 누르기 달리기(`TAP`), 타격 멈춤(`hitstop`), 효과, 무기 생기기, 나를 따라가는 카메라. `scripts/main.gd`: 대기실(능력치 막대)·상점.
- 라이선스 화면(`scripts/licenses.gd`)은 Godot 배포 조건이라 지우지 않는다. 새 에셋을 쓰면 credits에 적는다.
- Godot 4.6은 Variant에서 `:=` 추론이 오류 → 타입을 적는다.
- 소리는 board_racing의 생성기로 만든 것을 가져왔다(`tools/sound/gen.py`, 새로 지은 곡).
- 게임을 크게 바꾸면 조직 첫 화면(mhyoo-games.github.io `games.json`)과 이력서(minhyuk94.github.io `games`)도 ko/ja/en으로 맞춘다. 소스·저장소 링크는 이력서에 넣지 않는다.

## 돌려 보기

- 테스트: `godot --headless --import` 후 `godot --headless -s tests/run_tests.gd`
- 화면: `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --shot=title|shop|lineup|poses|fight8|room6|result --out=/tmp/x.png` (fightN = 컴퓨터끼리 N초 싸운 장면, roomN = 창고 안, lineup·poses = 캐릭터 모아 보기). 소프트웨어 렌더라 느리다(40초짜리는 몇 분).
