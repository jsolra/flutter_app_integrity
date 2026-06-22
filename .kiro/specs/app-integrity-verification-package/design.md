# Design Document: App Integrity Verification Package

## Overview

app_integrity는 Flutter Plugin 표준 패턴(Platform Interface → Method Channel → Native)을 따르는 독립 패키지로, 호스트 앱의 무결성을 런타임에 검증한다. Android에서는 APK 서명 인증서 SHA-256 해시 비교와 설치 출처 검증을, iOS에서는 코드서명 디렉토리 존재 확인, 실행파일 존재 확인, Mach-O 바이너리 암호화 상태 검사, 번들 ID 비교, App Store 영수증 기반 설치 출처 검증을 수행한다.

Dart 측에서는 `IntegrityChecker` 클래스가 진입점 역할을 하며, `IntegrityConfig`를 통해 앱별 설정을 주입받는다. 검증 결과는 `SecurityThreat` 목록으로 반환되고, 콜백과 기본 UI를 통해 호스트 앱에 전달된다.

## Architecture

### 계층 구조

```
┌─────────────────────────────────────────────────────┐
│                   Host App (Dart)                     │
│  IntegrityConfig → IntegrityChecker.verify()         │
└───────────────────────┬─────────────────────────────┘
                        │
┌───────────────────────┼─────────────────────────────┐
│           App Integrity Plugin (Dart)                 │
│                       │                              │
│  ┌────────────────────┴───────────────────────┐     │
│  │         IntegrityChecker                    │     │
│  │  - config: IntegrityConfig                  │     │
│  │  - verify() → List<SecurityThreat>          │     │
│  │  - hasThreat: bool                          │     │
│  │  - detectedThreats: List<SecurityThreat>    │     │
│  └────────────────────┬───────────────────────┘     │
│                       │                              │
│  ┌────────────────────┴───────────────────────┐     │
│  │     AppIntegrityPlatform (Abstract)         │     │
│  │  - getSigningHash() → String?               │     │
│  │  - getCodeSigningResult() → Map?            │     │
│  │  - getInstallSource() → String?             │     │
│  └────────────────────┬───────────────────────┘     │
│                       │                              │
│  ┌────────────────────┴───────────────────────┐     │
│  │    MethodChannelAppIntegrity                 │     │
│  │    (implements AppIntegrityPlatform)         │     │
│  └────────────────────┬───────────────────────┘     │
└───────────────────────┼─────────────────────────────┘
                        │ MethodChannel('app_integrity')
            ┌───────────┴───────────┐
            │                       │
┌───────────┴──────────┐ ┌─────────┴────────────┐
│  Android (Kotlin)     │ │    iOS (Swift)        │
│  AppIntegrityPlugin   │ │  AppIntegrityPlugin   │
│  - getSigningHash     │ │  - checkCodeSigning   │
│  - getInstallSource   │ │  - getInstallSource   │
└──────────────────────┘ └──────────────────────┘
```

### Method Channel 통신 프로토콜

채널명: `app_integrity`

| Method Name | Direction | Arguments | Return Type |
|---|---|---|---|
| `getSigningHash` | Dart → Android | 없음 | `String?` (Base64 SHA-256) |
| `checkCodeSigning` | Dart → iOS | 없음 | `Map<String, dynamic>` |
| `getInstallSource` | Dart → Android/iOS | 없음 | `String?` |

#### checkCodeSigning 반환 Map 구조

```dart
{
  "bundleId": String,              // 현재 앱 번들 ID
  "codeSignatureExists": bool,     // _CodeSignature 디렉토리 존재 여부
  "executableExists": bool,        // 실행파일 존재 여부
  "isEncrypted": bool,             // Mach-O 바이너리 암호화 여부
  "isDebugBuild": bool,            // 디버그 빌드 여부
  "isSimulator": bool,             // 시뮬레이터 여부
}
```

## Components and Interfaces

### Dart Public API

```dart
// lib/app_integrity.dart - 패키지 진입점
export 'src/integrity_checker.dart';
export 'src/models/integrity_config.dart';
export 'src/models/security_threat.dart';
export 'src/models/threat_type.dart';
export 'src/ui/security_alert_dialog.dart';
```

### IntegrityChecker

```dart
class IntegrityChecker {
  final IntegrityConfig config;
  List<SecurityThreat> _detectedThreats = [];

  IntegrityChecker({required this.config});

  /// 무결성 검증 수행. 탐지된 위협 목록 반환.
  Future<List<SecurityThreat>> verify();

  /// 위협 탐지 여부
  bool get hasThreat;

  /// 탐지된 위협의 불변 목록
  List<SecurityThreat> get detectedThreats;
}
```

### AppIntegrityPlatform (Platform Interface)

```dart
abstract class AppIntegrityPlatform extends PlatformInterface {
  Future<String?> getSigningHash();
  Future<Map<String, dynamic>?> checkCodeSigning();
  Future<String?> getInstallSource();
}
```

### MethodChannelAppIntegrity

```dart
class MethodChannelAppIntegrity extends AppIntegrityPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('app_integrity');

  @override
  Future<String?> getSigningHash() async {
    return await methodChannel.invokeMethod<String>('getSigningHash');
  }

  @override
  Future<Map<String, dynamic>?> checkCodeSigning() async {
    final result = await methodChannel.invokeMethod<Map>('checkCodeSigning');
    return result?.cast<String, dynamic>();
  }

  @override
  Future<String?> getInstallSource() async {
    return await methodChannel.invokeMethod<String>('getInstallSource');
  }
}
```

### Android Native (Kotlin)

```kotlin
class AppIntegrityPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app_integrity")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getSigningHash" -> result.success(getSigningHash())
            "getInstallSource" -> result.success(getInstallSource())
            else -> result.notImplemented()
        }
    }

    private fun getSigningHash(): String? { /* PackageManager API */ }
    private fun getInstallSource(): String? { /* InstallSourceInfo API */ }
}
```

### iOS Native (Swift)

```swift
public class AppIntegrityPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) { /* ... */ }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkCodeSigning":
            result(checkCodeSigning())
        case "getInstallSource":
            result(getInstallSource())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkCodeSigning() -> [String: Any] { /* ... */ }
    private func getInstallSource() -> String { /* ... */ }
}
```

## Data Models

### IntegrityConfig

```dart
typedef ThreatCallback = void Function(List<SecurityThreat> threats);
typedef CustomDialogBuilder = Widget Function(
  BuildContext context,
  List<SecurityThreat> threats,
);

class IntegrityConfig {
  /// Android APK 서명에 사용된 유효한 SHA-256 해시 목록 (Base64 인코딩)
  final List<String> validSigningHashes;

  /// iOS 유효 번들 ID 목록
  final List<String> validBundleIds;

  /// 설치 출처 검증 활성화 여부 (기본값: false)
  final bool enableInstallSourceCheck;

  /// 디버그 모드에서 검증 건너뛰기 (기본값: true)
  final bool skipInDebugMode;

  /// 위협 탐지 시 호출되는 콜백
  final ThreatCallback? onThreatDetected;

  /// 커스텀 보안 경고 다이얼로그 빌더
  final CustomDialogBuilder? customDialogBuilder;

  const IntegrityConfig({
    this.validSigningHashes = const [],
    this.validBundleIds = const [],
    this.enableInstallSourceCheck = false,
    this.skipInDebugMode = true,
    this.onThreatDetected,
    this.customDialogBuilder,
  });
}
```

### ThreatType Enum

```dart
enum ThreatType {
  /// Android 서명 해시 불일치
  signatureMismatch,

  /// 서명 정보를 가져올 수 없음
  signatureUnavailable,

  /// iOS 번들 ID 불일치
  bundleIdMismatch,

  /// iOS _CodeSignature 디렉토리 누락
  codeSignatureDirectoryMissing,

  /// iOS 실행파일 손상/누락
  executableCorrupted,

  /// 비공식 설치 출처
  unofficialInstallSource,
}
```

### SecurityThreat

```dart
class SecurityThreat {
  final ThreatType type;
  final String message;

  const SecurityThreat({
    required this.type,
    required this.message,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityThreat &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          message == other.message;

  @override
  int get hashCode => type.hashCode ^ message.hashCode;

  @override
  String toString() => 'SecurityThreat(type: $type, message: $message)';
}
```

### Android 설치 출처 상수

```dart
// Dart side - 공식 스토어 패키지명 목록
const List<String> officialAndroidStores = [
  'com.android.vending',        // Google Play Store
  'com.huawei.appmarket',       // Huawei AppGallery
  'com.samsung.android.vending', // Samsung Galaxy Store
];
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: 검증 결과 정확성 (Verification Result Correctness)

*For any* combination of native platform responses (signing hash, code signing result, install source) and IntegrityConfig settings, the `verify()` method SHALL produce exactly the set of SecurityThreat objects that correspond to detected violations — a signatureMismatch when the hash is not in validSigningHashes, a bundleIdMismatch when bundleId is not in validBundleIds, a codeSignatureDirectoryMissing when codeSignatureExists is false, an executableCorrupted when executableExists is false, and an unofficialInstallSource when install source is not in the official list.

**Validates: Requirements 3.2, 3.3, 4.2, 4.3, 4.4, 4.5, 5.3, 5.5, 6.1**

### Property 2: 콜백 호출 일관성 (Callback Invocation Consistency)

*For any* IntegrityConfig with a registered ThreatCallback, whenever verify() returns a non-empty threat list, the callback SHALL be invoked with exactly the same threat list that verify() returns.

**Validates: Requirements 6.2**

### Property 3: 상태 일관성 (State Consistency)

*For any* state of IntegrityChecker after verify() completes, `hasThreat` SHALL equal `detectedThreats.isNotEmpty`, and `detectedThreats` SHALL be an unmodifiable list whose contents cannot be altered externally.

**Validates: Requirements 6.5, 6.6**

### Property 4: 디버그 모드 바이패스 (Debug Mode Bypass)

*For any* IntegrityConfig with skipInDebugMode=true, when running in debug mode (kDebugMode=true), verify() SHALL always return an empty SecurityThreat list regardless of any other config values or platform responses.

**Validates: Requirements 8.1**

### Property 5: 커스텀 다이얼로그 라우팅 (Custom Dialog Routing)

*For any* IntegrityConfig with a non-null customDialogBuilder, when showSecurityAlert is invoked, the system SHALL call the customDialogBuilder instead of displaying the default AlertDialog.

**Validates: Requirements 7.4**

### Property 6: Config 저장 라운드트립 (Config Storage Round-Trip)

*For any* valid IntegrityConfig, creating an IntegrityChecker with that config and reading back the config field SHALL return an equivalent IntegrityConfig object.

**Validates: Requirements 2.1**

## Error Handling

### Dart 측 에러 처리

| 상황 | 처리 방식 |
|---|---|
| Method Channel 호출 실패 (PlatformException) | 해당 검증 항목을 건너뛰고, 로그 출력. 위협 목록에는 추가하지 않음 |
| 네이티브가 null 반환 (Android signing hash) | `signatureUnavailable` 위협 생성 |
| iOS Code Signing Result가 null | 해당 검증을 건너뛰고 로그 출력 |
| 빈 validSigningHashes 목록 | Android 서명 검증 건너뜀, 경고 로그 출력 |
| 빈 validBundleIds 목록 | iOS 번들 ID 검증 건너뜀, 경고 로그 출력 |

### Android 네이티브 에러 처리

| 상황 | 처리 방식 |
|---|---|
| PackageManager에서 서명 정보 조회 실패 | null 반환 |
| InstallSourceInfo 조회 실패 | null 반환 |

### iOS 네이티브 에러 처리

| 상황 | 처리 방식 |
|---|---|
| Bundle path 접근 실패 | codeSignatureExists=false, executableExists=false로 설정 |
| Mach-O 헤더 파싱 실패 | isEncrypted=false로 설정 (안전 측) |

## Testing Strategy

### 단위 테스트 (Unit Tests)

**Dart 측:**
- `IntegrityConfig` 기본값 검증
- `SecurityThreat` equality 및 toString
- `IntegrityChecker` 디버그 모드 건너뛰기 로그 출력 확인
- `showSecurityAlert` 위젯 테스트 (AlertDialog 요소 확인)

**Android (Kotlin):**
- `getSigningHash()` - Mocked PackageManager로 SHA-256 + Base64 인코딩 검증
- API 28 이상/미만 분기 처리 검증
- `getInstallSource()` - API 30 이상/미만 분기 처리 검증

**iOS (Swift):**
- `checkCodeSigning()` - 반환 딕셔너리 구조 검증
- `getInstallSource()` - 영수증 파일 경로 기반 판정 검증

### 속성 기반 테스트 (Property-Based Tests)

라이브러리: `dart_check` (또는 `glados` — Dart PBT 라이브러리)

각 속성 테스트는 최소 100회 반복 실행하며, Method Channel을 mock하여 다양한 네이티브 응답 조합을 생성한다.

- **Property 1**: 랜덤 signing hash, code signing result map, install source 조합 생성 → verify() 결과 검증
- **Property 2**: 위협이 있는 시나리오에서 콜백 호출 여부 및 인자 검증
- **Property 3**: verify() 후 hasThreat와 detectedThreats 일관성 검증
- **Property 4**: skipInDebugMode=true + kDebugMode=true 시 항상 빈 목록 반환
- **Property 5**: customDialogBuilder 제공 시 기본 다이얼로그 대신 커스텀 빌더 호출 검증
- **Property 6**: IntegrityConfig 생성 → IntegrityChecker 생성 → config 필드 읽기 동등성 검증

**태그 형식**: `Feature: app-integrity-verification-package, Property {N}: {title}`
