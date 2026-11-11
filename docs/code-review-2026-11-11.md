# 결정사주 전체 코드 리뷰 — Antigravity CLI (2026-11-11)

- **모델: gemini-3.8-flash-high** (Opus 4.6·Sonnet 4.6 쿼터 소진 중이라 폴백 순서상 Gemini로 리뷰. 로그인 정상, 폴백 불필요.)
- 방식: 텍스트 전용 리뷰, 발췌본 3개, 코드 수정·푸시 없음. 모든 지적은 현재 코드와 대조해 검증함.
- 주의: 모델이 인용한 줄번호 중 상당수가 실제 파일과 불일치했다(예: 68줄짜리 follow_up_notify.dart를 299-317줄로 인용). 아래 줄번호는 내가 원본 코드에서 확인해 정정한 값이다.

## 수정 완료 (2026-11-11, 사용자 승인 — 커밋은 푸시 후 기재)

지적 20건 전부 수정했고 테스트 79개 통과, analyze 클린(saju.dart:192 info 1건만, 기존 것)이다.

- 1번 (10초 로딩): 앱 시작·리포트 진입에서 복원 대기를 없앴다. 로컬 해금 플래그만 보고, 복원은 백그라운드로 돌려 해금되면 상한을 6명으로 넓힌다. restorePass 대기도 10초 → 3초.
- 2번 (pending 유실): buyPass 리스너가 pending을 무시하고 완료를 기다린다.
- 3번 (전역 리스너 없음): PaymentService.initGlobalListener()를 앱 시작 시 등록한다. 결제 완료·복원 구매를 놓치지 않고 확인·해금한다.
- 4번 (복원 acknowledge 누락): 전역 리스너와 restorePass·buyPass 리스너에서 모두 completePurchase를 부른다 (중복 확인은 무해).
- 5번 (저장 연타): _saveRecord에 _saving 가드를 넣고 저장 중에는 버튼도 비활성화한다. 저장 실패 시 재시도 스낵바를 띄운다.
- 6번 (결제 다이얼로그 뒤로가기): 로딩 다이얼로그를 PopScope(canPop: false)로 감쌌다.
- 7번 (개인 길일 충 감점 누락): scoreDay에 일지 충 -20점을 넣었다. 가족 공통 길일의 중복 감점은 제거했다 (이중 감점 방지).
- 8번 (D+30 심야 푸시): followUpNotificationTime을 결정일 +30일 오전 8시로 고정했다.
- 9번 (희신 소실): 조후가 용신과 같으면 다음 후보(cands[1])를 희신으로 쓴다.
- 10번 (DST 일주 오차): saju.dart·decision.dart의 일주 계산을 UTC 날짜 차이로 바꿨다.
- 11번 (DST 날짜 루프 중복): 4개 루프를 _addDays(달력 날짜 직접 계산)로 바꿨다.
- 12번 (_cautionReason 순서): 충 검사를 상극 검사보다 먼저 한다.
- 13번 (가족 길일 사유 이분법): 65점 이상 좋은 날 / 50점 이상 무난한 날 / 그 아래 신중히 살펴볼 날, 3단계로 나눴다.
- 14번 (capturePng 검사 없음): debugNeedsPaint면 null을 돌려준다.
- 15번 (loadProduct 오류 구분 없음): 네트워크·스토어 오류면 예외를 던지고, buyPass는 error로 처리한다. 미등록(null)은 productNotFound 그대로다.
- 16번 (플래그 SharedPreferences만): 해금 플래그는 캐시로 두고, 전역 리스너 + 백그라운드 복원으로 스토어와 맞춘다 (1·3번 수정으로 해소).
- 17번 (Gal 예외 처리 없음): putImageBytes를 try/catch로 감싸 실패 시 false를 돌려준다.
- 18번 (상품 미등록 스낵바 개발자용 문구): "아직 결제 상품을 준비 중이에요. 잠시 뒤 다시 시도해 주세요."로 바꿨다.
- 19번 (예약 여부와 무관한 고정 스낵바): scheduleFollowUp이 bool을 돌려주게 하고, 예약 실패 시 스낵바 문구를 바꾼다.
- 20번 (결론 카드 Row 오버플로): 라벨 Text를 Expanded로 감쌌다.

새 테스트 4개 추가: 충 -20점(쌍둥이 사주 비교), 주의일 충 문구 우선, 가족 길일 사유 구간, 조후==용신 시 희신 유지. 기존 가족 공통 길일 테스트는 scoreDay 안에 감점이 들어간 만큼 기대값을 수정했다.

## 보낸 발췌본 (/tmp/agy-test/)

| 파일 | 크기 | 내용 |
|---|---|---|
| excerpt1-engine.md | 18,103B | saju.dart 전체(1-280), follow_up_notify.dart 전체(1-68), decision.dart 51-75(scoreDay), 170-290(luckyDays·branchesClash·worstDays·familyLuckyDays) |
| excerpt2-services.md | 16,162B | payment_service.dart 전체, notification_service.dart 전체, review_prompt.dart 전체, share_service.dart 전체 |
| excerpt3-screens.md | 17,026B | main.dart 전체, decision_report_screen.dart 100-240(티저·결제 흐름), 423-520(_saveRecord), home_screen.dart 372-470(_todayDecisionCard) |

발췌본에 안 들어간 것: compat.dart, decision.dart 나머지(dayScores·yearMonthScores·compareOptions·avoidLine·대운·evidenceLines), lucky_days/family/saju/new_year/glossary/policies/decision_log 화면, deep_link_service.dart(제거된 껍데기라 제외). daily_fortune.dart·decision_store.dart·family_store.dart는 발췌본 밖이지만 내가 직접 읽어 확인했다.

## 확인된 지적

### 높음 — 출시 전 수정 권장

1. **미구매자는 앱 시작·리포트 진입 때마다 최대 10초 로딩** — payment_service.dart:106-130 + main.dart:66-72 + decision_report_screen.dart:117-119. restorePass()가 매칭되는 구매 이벤트가 없으면 10초 타임아웃까지 기다리는데, 이걸 앱 시작(_loadMembers, _loading 해제 전)과 티저 진입(_showNotice)에서 await한다. 미구매자(출시 초기 사실상 전원)는 매번 최대 10초 스피너를 본다. 수정 방향: 시작 시에는 로컬 플래그만 보고 복원은 백그라운드로 돌리거나, 빈 구매 목록 이벤트가 오면 즉시 종료하게 할 것.
2. **결제 pending을 즉시 error로 처리해 결제 유실** — payment_service.dart:44-50 + 141-160. mapPurchaseStatus가 pending → error로 바꾸고, buyPass 리스너는 첫 이벤트로 completer를 완료한 뒤 구독을 해제한다. 보호자 승인·지연 결제 등으로 pending이 먼저 오면 error를 반환하고, 이후 purchased 이벤트를 아무도 받지 못해 해금·acknowledge가 누락된다.

### 중간

3. **전역 purchaseStream 리스너 없음** — payment_service.dart:106-180. buyPass/restorePass 때만 구독하고 finally에서 해제한다. 앱 실행 중 결제 완료·타임아웃 뒤 완료를 놓친다. (앱 시작·폼 진입 시 restorePass가 복구해주긴 해서 부분 완화됨.)
4. **restorePass에서 completePurchase 누락** — payment_service.dart:106-130. 복원으로 찾은 구매를 acknowledge하지 않는다. 미확인 구매가 이 경로로만 처리되면 Play가 3일 뒤 환불한다.
5. **저장 버튼 연타 시 중복 저장** — decision_report_screen.dart:423-460 + 757-768. _saveRecord 진입 가드가 없고, 버튼을 막는 _saved는 await 완료 뒤에야 true가 된다. 50-200ms 안에 두 번 누르면 결정이 2개 저장되고 알림도 2세트 예약된다.
6. **결제 로딩 다이얼로그 뒤로가기 미차단** — decision_report_screen.dart:205-221. barrierDismissible: false만 있고 PopScope가 없어, 결제 중 뒤로가기를 누르면 다이얼로그가 닫히고 결제 완료 뒤의 Navigator.pop()이 폼 화면을 닫아버린다.
7. **개인 길일에 일지 충 감점 누락** — decision.dart:51-72, 170-189. scoreDay·개인 luckyDays에 충 감점이 없어, 충인 날도 용신 등으로 고득점이면 최고 길일로 추천된다. familyLuckyDays(246-290)는 -20점을 깎는데 개인 길일은 안 깎는 모순이다. branchesClash 주석의 "충이면 피하는 날"이라는 설계 의도와도 어긋난다.
8. **D+30 알림이 결정 시각 그대로 (심야 푸시)** — follow_up_notify.dart:13-14. decidedAt + 30일이라 23시에 결정하면 30일 뒤 23시에 울린다. 오전 8시로 고정하는 게 맞다.
9. **조후가 용신과 겹치면 희신 소실** — saju.dart:217-240. johu가 yongsin과 같으면 `if (huishin == yongsin) huishin = null`에 걸려 cands[1] 대안이 있어도 희신이 사라진다. (희신은 표시용이라 영향은 작다.)

### 낮음

10. **DST 환경 일주 계산 오차** — saju.dart:164-166. 로컬 DateTime 차이로 일수를 구해 DST 적용 시간대에서는 하루가 어긋날 수 있다. 한국 전용이라 영향은 작다.
11. **DST 경계일 날짜 루프 중복** — decision.dart:179, 234, 263. `start.add(Duration(days: i))`라 가을 DST 종료일에 같은 날짜가 두 번 들어갈 수 있다. dayPillar가 날짜 부분만 써서 점수는 맞고, 같은 날짜가 길일 목록에 중복될 수 있는 정도다. 한국 전용이라 영향은 작다.
12. **_cautionReason 순서** — decision.dart:203-222. 상극 검사가 충 검사보다 먼저라 충인 날에도 상극 문구만 나간다.
13. **familyLuckyDays 사유 문구 이분법** — decision.dart:265-270. 30점대도 "무난한 날이에요"라고 나온다.
14. **capturePng debugNeedsPaint 검사 없음** — share_service.dart:19-27. 주석은 "렌더링이 끝나지 않았으면 null"이라 하지만 검사 코드가 없다. 버튼 탭 뒤 호출이라 실제로는 거의 안 맞는다.
15. **loadProduct 네트워크 오류와 미등록 구분 없음** — payment_service.dart:96-102. 둘 다 null → productNotFound 오안내.
16. **해금·리뷰 플래그 SharedPreferences만으로 관리** — payment_service.dart:74-83, review_prompt.dart:26-38. 재설치 시 소실되나 restorePass로 복구 가능. 설계상 감수.
17. **Gal.putImageBytes 예외 처리 없음** — share_service.dart:30-37. _saveImage에도 try-catch가 없어 저장 실패 시 무반응이다.
18. **상품 미등록 스낵바에 개발자용 문구** — decision_report_screen.dart:233-238. "Play Console에 decision_report_4900 상품을 등록한 뒤..."가 그대로 사용자에게 보인다.
19. **알림 예약 여부와 무관한 고정 스낵바** — decision_report_screen.dart:455-460. 길일이 오늘이고 8시가 지났거나 권한이 거부돼도 "길일 당일... 물어볼게요"라고 뜬다.
20. **결론 카드 Row 오버플로** — decision_report_screen.dart:503-525. Expanded가 없어 글자 크기 최대 + 좁은 화면에서 넘칠 수 있다. 기본 설정에서는 안 터진다.

## 오탐 (한 문장 이유)

- 리뷰1-3 (hashCode 불안정): 별도 Dart 프로세스 3회 실행에서 동일 recordId의 hashCode가 완전히 일치해 예약·취소가 같은 ID를 계산한다.
- 리뷰1-6 (과거 8시 알림): scheduleFollowUp이 `isAfter(now)`로 지난 시각은 예약하지 않도록 이미 방어하고 있다.
- 리뷰1-8 (stemElement RangeError): 모든 호출자가 내부에서 계산된 유효한 천간만 넘겨서 비정상 입력이 도달할 경로가 없다.
- 리뷰1-11 (take 음수): 모든 호출부가 기본값만 써서 음수 count가 들어갈 경로가 없다.
- 리뷰2-3 (타임존 9시간 지연): `TZDateTime.from`은 시각을 재해석하지 않고 같은 instant를 유지하므로 로컬 08시가 UTC 08시로 밀리지 않는다 (timezone 패키지 실측 확인).
- 리뷰2-8 (as 캐스트 크래시): _shareKey는 RepaintBoundary에만 붙어 있어 다른 RenderObject가 올 경로가 없다.
- 리뷰2-15 (문자열 비교): 답안 리터럴이 로그 화면·모델에 동일하게 고정돼 있어 지금은 일치한다.
- 리뷰3-6 (티저 빈 문구): 용신은 계산상 항상 값이 있고 부족 오행 목록도 최소 1개라 빈 문장이 나올 수 없다.
- 리뷰3-10 (mounted 누락): MainShell은 앱 루트라 저장 중에 언마운트될 경로가 없다.
- 리뷰3-11 (home members.first): `members.isNotEmpty` 가드가 있어 빈 목록에서는 호출되지 않는다.

## 해당 없음 (Android 전용 출시 기준)

- 리뷰2-4 (iOS Darwin 설정 누락), 리뷰2-7 (Play Store URL 하드코딩), 리뷰2-10 (iPad sharePositionOrigin), 리뷰3-3 (구매 복원 버튼 누락·Apple Guideline 3.1.1): 모두 iOS 전제라 당장 해당 없고, iOS 진출 시에 챙길 것.
- 리뷰3-1의 iOS Apple ID 팝업·심사 거절 주장도 같은 이유로 해당 없음. 단, 앱 시작 복원의 지연 부분은 위 확인된 지적 1번과 동일 건이다.

## 모델이 "확인 불가"라 한 항목 — 직접 확인해 해결

- 결제 복원·저장 견고성: 발췌본 2·직접 읽기로 확인 (위 목록 참조).
- 알림 ID 충돌: hashCode 실측상 프로세스 간 안정적, 31비트 마스킹도 기록 수십 개 규모에서는 충돌 가능성이 무시할 만하다.
- lib/engine 순수 Dart: 5개 파일 전부 Flutter import 없음 (grep 확인).
- decision_store·family_store: 손상 JSON은 try/catch + tryFromJson 필터로 건너뛰고 빈 목록을 반환한다. 스키마 마이그레이션은 v1 키만 있어 아직 해당 없음.

## 검증 못한 항목

- compat.dart(가족 궁합·띠), decision.dart의 dayScores·yearMonthScores·compareOptions·avoidLine·대운·evidenceLines, lucky_days·family·saju·new_year·glossary·policies·decision_log 화면: 발췌본 밖이라 이번 리뷰에서 검증 안 됨.
- 실기기 동작(실결제, 알림 실제 발송, 복원 실전)은 리뷰로 검증 불가 — 맥북 실기기 테스트에서 확인할 것.
