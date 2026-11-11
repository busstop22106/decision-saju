# 결정사주 2차 코드 리뷰 — 지적 수정 기록 (2026-11-11)

- **모델: gemini-3.8-flash-high** (Opus 4.6·Sonnet 4.6 쿼터 소진 중이라 폴백 순서상 Gemini로 리뷰)
- 방식: 텍스트 전용 리뷰, 발췌본 7개(`/tmp/agy-test/excerpt2-1~7.md`, 답변 `answer2-1~7.txt`), 코드 수정·푸시 없음. 모든 지적은 현재 코드와 대조해 검증함.
- 범위: 오탐 17건은 제외하고 확인된 것만 수정했다. 제외된 대표 사례: `sajuOfBirth` 성별 하드코딩(`computeSaju`가 성별을 안 써서 영향 없음), `AddMemberSheet` 시트 미닫힘(시트가 `pop()`을 직접 함), `FamilyScreen` 시간 모름 시주(`timeUnknown`이면 `birthHour`가 null이라 시주 없음), `LuckyDaysScreen` 빈 목록·UTC 비교·`didUpdateWidget`(30일 고정이라 빈 목록 불가·로컬 자정 비교·화면이 매번 새로 뜸), `NewYearScreen` 프로그레스 clamp·빈 목록·UTC 라벨(점수 0~100 고정·12개월 고정·로컬 날짜), `decision_log` 날짜 UTC 라벨(로컬 저장), `decision` 동점 비교·오행구족 빈 문구·fallback 조언·`DateTime.now` 정규화(용신이 null이 안 되는 구조·fallback은 의도된 문구·날짜 단위 계산이라 영향 없음), `saju_screen` 피커 mounted 가드·기둥 라벨·부족 오행 빈 문자열·점 색상 폴백(방어 수준이라 이번에 안 함), `glossary` 다이얼로그 스크롤(짧은 한 줄 해설이라 안 넘침), `family` 버튼 라벨(`maxMembers` 기본값이 3이라 비교가 맞음).

## 수정 완료 (2026-11-11, 사용자 승인)

테스트 93개 통과(기존 79개 + 신규 14개), analyze 클린(saju.dart:192 info 1건만, 기존 것).

### 높음
- 1번 (첫 대운이 월주 그대로): `currentDaewoon` 이동 칸수를 `steps + 1`로 바꿨다. 첫 10년은 월주에서 1칸 이동한 간지가 첫 대운이다.
- 2번 (역행 대운수): `daewoonStartAge(birth, {forward})`에 순행/역행 분기를 넣었다. 역행(남성 음간·여성 양간)은 이전 절기까지 일수로 계산한다. 1987-05-20 기준 순행 6세·역행 5세로 테스트에 박았다.

### 중간
- 3번 (되물음 연타): `_answer`에 `_isSubmitting` 가드를 넣고 처리 중에는 답변 버튼을 비활성화한다.
- 4번 (되물음 카드 삭제·선택안 없음): `_dueCard`에 삭제 버튼과 '선택: A안…' 표시를 넣었다. 선택안 문구는 `_chosenText`로 뽑아 `_recordCard`와 공유한다.
- 5번 (길일 선택 테두리 안 보임): 길일(주홍 배경)을 고르면 흰색 테두리로 바꿨다. 주홍 테두리가 배경에 묻히던 문제.
- 6번 (신년 칩 목록 이동): 진입 연도를 `_baseYear`로 고정해 칩 목록을 `[_baseYear-1, _baseYear, _baseYear+1]`로 고정했다.
- 7번 (출생 시간 Row 넘침): Row를 Wrap으로 바꿔 좁은 화면·큰 글씨에서 2줄로 넘어가게 했다.
- 8번 (삼합 판정): 두 띠 결합은 '반합(半合)'으로 나눴다. **배점 15점** — 육합 17점과 같은 띠 13점 사이로 정했다. `ZodiacRelation.banhap` 추가, 점수·라벨 스위치에 반영. 삼합 20점은 3명이 모이는 경우의 개념으로 enum에만 남겼다.

### 낮음 (묶음)
- compat `_harmonyOf`: 희신 0.8 → **0.9**로 올려 상생 0.85보다 높게 했다.
- compat `_memberCompat` 부족 오행: 가장 적은 오행 전부를 집합으로 모아 이름이 그중 하나라도 채우면 '채워줘요'로 본다.
- compat `_memberCompat` 상생·상극 공존: else-if를 풀어 상생과 상극이 함께 있으면 둘 다 적는다 (용신 직접 포함 + 상극이면 두 줄).
- compat 빈 picks/members: 이름 글자 없으면 오행·용신 점수 0.0 (0으로 나누면 NaN), 구성원 없으면 합계 0.0·최고 궁합 null. `computeFamilyCompat`의 assert는 계약 표시로 유지한다.
- 길일 화면: 큰 글씨 타일 오버플로 — 타일 내용을 `FittedBox(scaleDown)`으로 감싸 넘칠 때만 축소. 탭마다 90번 재계산 — `initState`에서 1회 계산해 캐시. InkWell 리플 — 불투명 Container 대신 `Ink`에 decoration을 둬 리플이 보이게. 30일 창 월 표시 — 매월 1일에 '월/1' 형태로 적는다.
- 가족 화면: `_confirmRemove`에 try-catch + 실패 스낵바. `_compatCard` Row 정렬 — 첫 줄 기준 정렬 + 이름 2줄·말줄임. 사주 반복 계산 — 년지를 루프 전에 1회만 계산. 용신 폴백 — 매핑 실패 시 내부 문자열 대신 '—'.
- 용어 화면: 단일 Card 일괄 렌더링은 용어 17개라 영향 없어 그대로 뒀다.
- 정책 화면: 마지막 항목 뒤 간격 제거 — 하단 패딩 24와 합쳐 36이던 여백을 24로 정리.
- 만세력 화면: `_detailRow` — Spacer 대신 간격 + Flexible 우측 정렬로 큰 글씨 오버플로 방지. 윤년 2/29 — 피커 초기 날짜를 기존 입력값 우선, 없으면 30년 전(29일이면 28일로 보정). 구성원 칩 — `onSelected` 파라미터를 쓰고, 칩을 골라도 직접 입력값을 지우지 않는다 (화면은 배타 모드 유지: 구성원 선택 시 직접 입력 섹션 숨김, 해제하면 입력값 그대로 돌아옴).
- 신년 화면: build마다 365일 재계산 — 연도가 바뀔 때만 `_recompute()`. 칩 Row·점수 Row — Wrap·Flexible로 큰 글씨 경계. 52 고정 너비 — 최소 너비 제약으로 변경. `m.month < 12` — 위치 기준(마지막 항목)으로 변경.
- 결정 일지 화면: `_load` try-catch-finally로 로딩이 영원히 안 끝나지 않게. `_recordCard` 하단 Row — 결과 텍스트를 Flexible + 말줄임. chosen B안 fallback — 'B'를 명시 분기하고 그 외는 '선택 없음'. `_remove` — 삭제 try-catch + 실패 스낵바 + `_load` 전 mounted 확인. Key 부재 — 무상태 카드라 영향 없어 안 넣었다.
- 문구: `avoidLine` "기운이 받쳐요" → "기운이 부딪쳐요" (극에 맞는 표현). 같은 문구가 `_cautionReason`에도 있어 함께 고쳤다. `evidenceLines` 조사 하드코딩 — 마지막 한글 음절의 받침으로 '이'/'가'를 고르는 `_particleGa` 헬퍼를 넣었다 ('화(火)가'·'목(木)이'). 한자가 붙은 이름은 마지막 한글 음절로 판정한다.

### 설계 결정 2건 (전통적으로 맞는 쪽으로 구현)
- **가족 오행 분포에 아기 사주 포함**: `computeFamilyCompat`의 `before` 분포에 `babySaju.elementCounts`를 합산한다. 전에는 구성원만 합산하고 아기 8자가 빠져 있었다.
- **대운 계산을 세는나이 기준으로 전환**: `currentDaewoon`의 나이를 만 나이가 아니라 세는나이(`now.year - birth.year + 1`)로 판정한다. 대운수(절기 일수 ÷ 3)는 전통적으로 세는나이 체계다.

### 참고
- `computeFamilyCompat` 이름 궁합 경로는 현재 앱에서 호출하는 곳이 없다. `family_screen`은 띠 라벨만 쓴다. compat 수정은 잠재 문제 정리 수준이고, 실제 동작 중인 코드는 `zodiacRelation`·`zodiacScore`·`zodiacLabel`·`sajuOfBirth`다.
