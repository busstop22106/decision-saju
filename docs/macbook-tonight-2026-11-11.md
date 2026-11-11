# 오늘 밤 10시 맥북 작업 순서 — 결정사주 (2026-11-11)

예상 1시간. 필수: 1 → 2 → 3 → 7. 시간 모자라면 4·5·6은 내일로 미뤄도 됨.
맥북 프로젝트 폴더: `~/jino/decision-saju`

## 1. 최신 코드 받기

```bash
cd ~/jino/decision-saju
git pull
git log --oneline -3
```

- 최신 커밋이 `1fe1ced8`이면 OK (딥링크 제거 + 코드 리뷰 지적 20건 수정까지 반영된 상태, 테스트 79개).
- `c9d8c261`이 보이면 pull이 덜 된 것이다. `1fe1ced8`이 나올 때까지 다시 `git pull`할 것.
- pull이 안 되면 `git status` 결과를 채팅에 알려줄 것.

## 2. Actions 워크플로우 복사 + 딥링크 파일 삭제 (한 번에 커밋·푸시)

```bash
mkdir -p .github/workflows
cp docs/android-apk-workflow.yml .github/workflows/android-apk.yml
git rm lib/services/deep_link_service.dart
git add .github/workflows/android-apk.yml
git commit -m "Actions: APK 빌드 워크플로우 추가 + 딥링크 파일 삭제"
git push
```

- 푸시하면 GitHub Actions가 자동으로 APK를 빌드한다 (GitHub 저장소 → Actions 탭에서 확인).
- 22:13에 오는 리마인더가 바로 이 단계다.

## 3. Play Console 상품 등록 — 가장 중요, 반드시 비소모성

Play Console → 결정사주 앱 → 수익 창출 → 인앱 상품 → 상품 만들기

- **상품 ID: `decision_report_4900`** (정확히 이 문자열, 앱 코드와 같아야 함)
- 이름: 결정 패스
- **유형: 비소모성 (Non-consumable) — 반드시 이것.** 소모성으로 등록하면 복원이 안 돼서 평생 패스 의미가 없어짐.
- 가격: 4,900원
- 설명: 한 번 결제하면 모든 결정 리포트 무제한 + 가족 보관함 6명
- 저장 후 활성화까지 할 것.

반영까지 몇 시간 걸릴 수 있다. 오늘 밤 결제 테스트에서 "상품을 찾을 수 없어요"가 뜨면 정상이니 내일 다시 확인하면 된다.

## 4. 세리프 폰트 (Noto Serif KR)

1. fonts.google.com/noto/specimen/Noto+Serif+KR → Get font → zip 다운로드 → 압축 풀기
2. zip 안의 `NotoSerifKR[wght].ttf` 파일을 `assets/fonts/`에 두 개 복사해서 이름 바꾸기:
   - `NotoSerifKR-Regular.ttf`
   - `NotoSerifKR-Bold.ttf`
   (같은 가변 폰트 파일 두 개여도 됨. pubspec에서 굵기를 나눠 쓰기 때문)
3. `pubspec.yaml`의 `flutter:` 섹션에 추가:

```yaml
  fonts:
    - family: Noto Serif KR
      fonts:
        - asset: assets/fonts/NotoSerifKR-Regular.ttf
        - asset: assets/fonts/NotoSerifKR-Bold.ttf
          weight: 700
```

4. 저장 후 실행:

```bash
flutter pub get
git add assets/fonts pubspec.yaml
git commit -m "폰트: Noto Serif KR 적용"
git push
```

## 5. 앱 아이콘 복원 (빌드용)

`flutter create .`는 없는 아이콘을 다시 만들어준다. 다만 AndroidManifest를 건드릴 수 있으니 먼저 백업한다.

```bash
cp android/app/src/main/AndroidManifest.xml /tmp/AndroidManifest-backup.xml
flutter create .
grep -c POST_NOTIFICATIONS android/app/src/main/AndroidManifest.xml
git status --short
```

- grep 결과가 0이면 백업에서 복원: `cp /tmp/AndroidManifest-backup.xml android/app/src/main/AndroidManifest.xml`
- `git status`에서 AndroidManifest나 build.gradle.kts가 예상과 다르게 바뀌었으면 알려줄 것.
- 아이콘은 기본 Flutter 아이콘으로 복원된다 (결 도장 커스텀 아이콘은 나중에 따로). 커밋·푸시:

```bash
git add android/app/src/main/res
git commit -m "앱 아이콘 복원"
git push
```

## 6. 업로드 키스토어 만들기 (스토어 AAB용)

작명별 키스토어는 재사용 금지. 새로 만든다.

```bash
keytool -genkeypair -v -keystore ~/decision-saju-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias decision-saju-upload
```

- 물어보는 것들: 키스토어 비밀번호, 이름(실명 말고 '결정사주'로 적으면 됨), 조직·도시·국가(KR). 키 비밀번호는 Enter(키스토어 비밀번호와 동일).
- **비밀번호 2개는 메모장에 적어둘 것. 잃어버리면 스토어 업데이트 불가.**
- `android/key.properties` 파일 만들기 (내용은 본인 비밀번호로 채울 것):

```
storePassword=<키스토어 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=decision-saju-upload
storeFile=/Users/<맥북 계정명>/decision-saju-upload.jks
```

- `android/app/build.gradle.kts`에 서명 설정 추가. 파일 맨 위 `android {` 앞에 아래를 넣는다:

```kotlin
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}
```

그리고 `buildTypes { release { ... } }` 부분을 아래처럼 바꾼다:

```kotlin
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
```

- `key.properties`는 절대 커밋하지 말 것. 확인: `git check-ignore android/key.properties` — 아무것도 안 나오면 `.gitignore`에 `android/key.properties` 한 줄 추가.
- `.jks` 파일은 홈 폴더에 있어서 저장소에 안 들어간다. 안전한 곳(iCloud·외장 등)에 복사해서 백업해둘 것.
- 참고: Play Console에 AAB를 처음 올리면 Google이 앱 서명 키를 관리하게 되고, 지금 만드는 키는 업로드용 키다.

## 7. 실기기 빌드·확인

폰을 USB로 연결한 뒤:

```bash
flutter run
```

확인할 것:

1. 앱이 켜지고 홈이 한옥 클래식(한지 크림 + 주홍)으로 보이는지, 제목이 명조체(세리프)로 보이는지 (4번을 했다면).
2. 결정 리포트 만들기 → 결제 화면. 상품이 아직 반영 안 됐으면 "상품을 찾을 수 없어요"가 뜰 수 있음 (정상, 내일 재확인).
3. 가족 보관함: 3명까지만 추가되고, 4번째에서 "결정 패스를 사면 6명까지" 안내가 뜨는지.
4. 결정 하나 저장한 뒤 알림 예약 확인:

```bash
adb shell dumpsys notification | grep -i decision
```

5. 스크린샷 몇 장(홈, 결정 리포트, 가족 보관함) 찍어서 채팅에 올리기.

## 8. (시간 남으면) AAB 빌드

```bash
flutter build appbundle --release
```

- `build/app/outputs/bundle/release/app-release.aab` 생성 확인.
- 스토어 업로드는 상품 반영 확인 후에.
