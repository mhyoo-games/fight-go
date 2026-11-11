# 이 저장소에서 작업할 때 지킬 것

유민혁(minhyuk94)의 개인 프로젝트 "파이트 고!". 사용자는 한국어로 대화합니다. 게임 글자도 한국어.

## 무엇인가

옥상에서 여럿이 싸우는 3D 난투 액션 (지금은 컴퓨터 3명과). Godot 4.6(GDScript, GL Compatibility), 웹으로 내보내 GitHub Pages(`https://mhyoo-games.github.io/fight-go/`, 조직 mhyoo-games).
사용자가 유형·장신구·무대를 **조금씩 늘려 갈** 계획이다.

## 지킬 것

- 옛 온라인 난투 게임에서 영감을 받았지만 **새로 만든 게임**이다. 다른 게임·만화의 이름·캐릭터·기술 이름·그림을 쓰지 않고, 다른 회사·게임 이름을 README·화면·이력서에 넣지 않는다. 유형 이름도 우리 것(주먹꾼·요원·염력사·장사).
- 키: 방향키 / Z 조준 / X 약 / C 강 / V 점프 / Z+X·Z+C 장신구 기술 / Z+X+C 필살기 / 공중 X+C 점프 필살기 (사용자가 정한 것, 바꾸지 않는다).
- **그림은 에셋 없이 코드로.** 캐릭터 `scripts/fighter.gd`(관절 Node3D + `POSES` 각도, `look` 사전으로 머리·옷, `equip`으로 장신구, 외곽선은 next_pass), 무대 `scripts/stage.gd`. 무대 그림과 규칙의 발판(`Rules.rooftop().plats`)은 손으로 맞춘 것이라 한쪽을 바꾸면 다른 쪽도.
- 규칙은 `scripts/rules.gd`: 유형 `STYLES`(능력치·필살기), 장신구 `ACCS`(zx·zc 기술), 기술 표 `moves()`(st 준비·act 맞는 시간·rec 빈틈·dmg·kb·up·reach·wide·lunge, rehit 연타, shot 날아가는 것, dash 통과), `move_for`가 유형별 차이를 얹는다. `step`(선수 한 명) → `resolve`(맞는 판정·몸 밀기·탄). 새 유형·장신구·기술에는 `tests/run_tests.gd` 테스트(데이터 검사는 저절로 돎).
- 장신구를 더할 때: `ACCS`에 zx·zc, `moves()`에 기술, `Fighter.equip`에 모양, 필요하면 `POSES`에 자세, `move_for`에 유형별 차이.
- 라이선스 화면(`scripts/licenses.gd`)은 Godot 배포 조건이라 지우지 않는다. 새 에셋을 쓰면 credits에 적는다.
- Godot 4.6은 Variant에서 `:=` 추론이 오류 → 타입을 적는다.
- 소리는 board_racing의 생성기로 만든 것을 가져왔다(`tools/sound/gen.py`, 새로 지은 곡).
- 게임을 크게 바꾸면 조직 첫 화면(mhyoo-games.github.io `games.json`)과 이력서(minhyuk94.github.io `games`)도 ko/ja/en으로 맞춘다. 소스·저장소 링크는 이력서에 넣지 않는다.

## 돌려 보기

- 테스트: `godot --headless --import` 후 `godot --headless -s tests/run_tests.gd`
- 화면: `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy -- --shot=title|title2|fight8|result --out=/tmp/x.png` (fightN = 컴퓨터끼리 N초 싸운 장면)
