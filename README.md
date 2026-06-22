# app_integrity

앱 무결성 검증 Flutter Plugin 패키지입니다.

Android에서는 APK 서명 인증서 SHA-256 해시 비교 및 설치 출처 검증을, iOS에서는 코드서명 무결성, 번들 ID 검증, 설치 출처 검증을 수행하여 위변조된 앱 실행을 탐지합니다.

## 주요 기능

- **Android APK 서명 검증** — 서명 인증서 SHA-256 해시를 비교하여 재서명된 앱을 탐지
- **iOS 코드서명 무결성 검증** — _CodeSignature 디렉토리 존재, 실행파일 존재, Mach-O 바이너리 암호화 상태 검사
- **iOS 번들 ID 검증** — 현재 앱의 번들 ID가 유효 목록에 포함되는지 확인
- **설치 출처 검증** — 공식 스토어(Google Play, App Store 등)에서 설치되었는지 확인
- **위협 탐지 콜백** — 탐지된 위협을 콜백으로 전달하여 앱별 대응 가능
- **기본 보안 경고 UI** — 내장 AlertDialog 제공, 커스텀 다이얼로그 빌더 지원
- **디버그 모드 지원** — 개발 중에는 검증을 자동으로 건너뛰어 개발 편의성 제공

## 설치

`pubspec.yaml`에 의존성을 추가합니다:

```yaml
dependencies:
  app_integrity:
    path: ../app_integrity  # 로컬 경로 또는 git URL
```

## 빠른 시작

```dart
import 'package:app_integrity/app_integrity.dart';

// 1. 설정 생성
final config = IntegrityConfig(
  validSigningHashes: ['YOUR_SIGNING_HASH_BASE64'],
  validBundleIds: ['com.example.yourapp'],
);

// 2. IntegrityChecker 생성
final checker = IntegrityChecker(config: config);

// 3. 검증 수행
final threats = await checker.verify();

// 4. 결과 확인
if (checker.hasThreat) {
  print('위협 탐지: ${checker.detectedThreats}');
}
```

## API 문서

### IntegrityConfig

무결성 검증 설정을 담는 모델 클래스입니다.

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `validSigningHashes` | `List<String>` | `[]` | Android APK 서명 SHA-256 해시 목록 (Base64 인코딩) |
| `validBundleIds` | `List<String>` | `[]` | iOS 유효 번들 ID 목록 |
| `enableInstallSourceCheck` | `bool` | `false` | 설치 출처 검증 활성화 여부 |
| `skipInDebugMode` | `bool` | `true` | 디버그 모드에서 검증 건너뛰기 |
| `onThreatDetected` | `ThreatCallback?` | `null` | 위협 탐지 시 호출되는 콜백 |
| `customDialogBuilder` | `CustomDialogBuilder?` | `null` | 커스텀 보안 경고 다이얼로그 빌더 |

### ThreatType

탐지 가능한 위협 유형을 정의하는 열거형입니다.

| 값 | 설명 | 플랫폼 |
|----|------|--------|
| `signatureMismatch` | Android 서명 해시 불일치 | Android |
| `signatureUnavailable` | 서명 정보를 가져올 수 없음 | Android |
| `bundleIdMismatch` | iOS 번들 ID 불일치 | iOS |
| `codeSignatureDirectoryMissing` | iOS _CodeSignature 디렉토리 누락 | iOS |
| `executableCorrupted` | iOS 실행파일 손상/누락 | iOS |
| `unofficialInstallSource` | 비공식 설치 출처 | Android / iOS |

### SecurityThreat

탐지된 보안 위협을 나타내는 모델 클래스입니다.

```dart
class SecurityThreat {
  final ThreatType type;    // 위협 유형
  final String message;     // 상세 설명 메시지
}
```

### IntegrityChecker

무결성 검증을 수행하는 핵심 클래스입니다.

```dart
final checker = IntegrityChecker(config: config);

// 검증 수행 — 탐지된 SecurityThreat 목록 반환
List<SecurityThreat> threats = await checker.verify();

// 위협 탐지 여부 (bool)
bool hasIssue = checker.hasThreat;

// 탐지된 위협의 불변 목록
List<SecurityThreat> detected = checker.detectedThreats;
```

### SecurityAlertDialog

보안 경고 다이얼로그를 표시하는 유틸리티 클래스입니다.

```dart
// 기본 보안 경고 다이얼로그 표시
await SecurityAlertDialog.showSecurityAlert(context, threats);

// 커스텀 다이얼로그 빌더 사용
await SecurityAlertDialog.showSecurityAlert(
  context,
  threats,
  customDialogBuilder: (context, threats) {
    return YourCustomWidget(threats: threats);
  },
);
```

## 고급 사용법

### 커스텀 콜백 등록

위협 탐지 시 앱별 대응 로직을 실행할 수 있습니다:

```dart
final config = IntegrityConfig(
  validSigningHashes: ['YOUR_HASH'],
  validBundleIds: ['com.example.yourapp'],
  onThreatDetected: (threats) {
    // 서버에 위협 정보 전송
    reportToServer(threats);
    // 또는 앱 종료
    SystemNavigator.pop();
  },
);
```

### 커스텀 다이얼로그

기본 AlertDialog 대신 커스텀 UI를 사용할 수 있습니다:

```dart
final config = IntegrityConfig(
  validSigningHashes: ['YOUR_HASH'],
  customDialogBuilder: (context, threats) {
    return AlertDialog(
      title: const Text('앱 위변조 감지'),
      content: Text('${threats.length}건의 보안 위협이 발견되었습니다.'),
      actions: [
        TextButton(
          onPressed: () => exit(0),
          child: const Text('앱 종료'),
        ),
      ],
    );
  },
);
```

### 설치 출처 검증 활성화

기본적으로 비활성화되어 있으며, 필요 시 활성화합니다:

```dart
final config = IntegrityConfig(
  validSigningHashes: ['YOUR_HASH'],
  enableInstallSourceCheck: true, // 설치 출처 검증 활성화
);
```

Android에서는 Google Play Store, Huawei AppGallery, Samsung Galaxy Store를 공식 스토어로 인식합니다. iOS에서는 App Store 영수증 파일 기반으로 판정합니다.

## Android 설정

### 서명 해시 생성

`keytool`을 사용하여 서명 인증서의 SHA-256 해시를 Base64로 변환합니다:

```bash
# keystore에서 SHA-256 해시 확인
keytool -list -v -keystore your-keystore.jks -alias your-alias

# 출력에서 SHA-256 fingerprint를 찾아 Base64로 변환
# 예시: SHA-256: AB:CD:EF:12:34:...
# 콜론을 제거하고 hex → bytes → Base64 변환

# 원라인 명령어 (Linux/Mac)
keytool -list -v -keystore your-keystore.jks -alias your-alias \
  | grep "SHA-256" \
  | cut -d: -f2- \
  | tr -d ': ' \
  | xxd -r -p \
  | base64
```

생성된 Base64 문자열을 `validSigningHashes`에 추가합니다.

### 참고 사항

- API 28 이상: `GET_SIGNING_CERTIFICATES` 사용
- API 28 미만: `GET_SIGNATURES` 사용 (자동 처리됨)

## iOS 설정

### 번들 ID 설정

Xcode에서 확인한 번들 ID를 `validBundleIds`에 추가합니다:

```dart
final config = IntegrityConfig(
  validBundleIds: ['com.yourcompany.yourapp'],
);
```

### 검증 항목

iOS에서는 다음 항목을 자동으로 검증합니다:

1. `_CodeSignature` 디렉토리 존재 여부
2. 실행파일 존재 여부
3. Mach-O 바이너리 암호화 상태 (LC_ENCRYPTION_INFO 검사)
4. 번들 ID 일치 여부 (validBundleIds 설정 시)
5. 설치 출처 (enableInstallSourceCheck 활성화 시)

## 디버그 모드 동작

기본적으로 `skipInDebugMode: true`가 설정되어 있어 디버그 빌드에서는 모든 무결성 검증을 건너뜁니다. 콘솔에 "디버그 모드: 무결성 검증 건너뜀" 로그가 출력됩니다.

개발 중 검증 로직을 테스트하려면 명시적으로 비활성화하세요:

```dart
final config = IntegrityConfig(
  validSigningHashes: ['YOUR_HASH'],
  skipInDebugMode: false, // 디버그 모드에서도 검증 수행
);
```

## 플랫폼 지원

| 플랫폼 | 지원 여부 | 검증 항목 |
|--------|-----------|-----------|
| Android | ✅ | APK 서명 해시, 설치 출처 |
| iOS | ✅ | 코드서명, 번들 ID, 바이너리 암호화, 설치 출처 |
