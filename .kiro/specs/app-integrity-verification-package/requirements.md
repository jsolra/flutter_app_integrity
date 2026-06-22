# Requirements Document

## Introduction

mealcare_package와 독립된 별도 Flutter Plugin 패키지(app_integrity)를 신규 생성한다. 이 패키지는 android/, ios/ 네이티브 코드를 자체 포함하는 Plugin 형태로, 호스트 앱에서 별도 네이티브 등록 없이 자동으로 플러그인이 등록된다. Android에서는 APK 서명 인증서 SHA-256 해시 비교를, iOS에서는 코드서명 무결성 및 번들 ID 검증을 수행하여 위변조된 앱 실행을 탐지한다. 앱 번들명, 서명 HASH 등 앱별 고유값은 호스트 앱에서 Config 객체로 주입한다.

## Glossary

- **App_Integrity_Plugin**: 앱 무결성 검증 기능을 제공하는 독립 Flutter Plugin 패키지. android/ 및 ios/ 폴더에 네이티브 코드를 자체 포함하며 Flutter Plugin 자동 등록 메커니즘을 따른다.
- **Integrity_Checker**: App_Integrity_Plugin에서 제공하는 Dart 진입점 클래스. 호스트 앱이 Config를 전달하여 초기화하고 verify()를 호출하여 검증을 수행한다.
- **Integrity_Config**: Integrity_Checker 초기화 시 호스트 앱이 전달하는 설정 객체. 유효 서명 해시 목록, iOS 번들 ID 목록, 설치 출처 검증 활성화 여부, 콜백 등을 포함한다.
- **Signing_Hash**: Android 앱의 서명 인증서를 SHA-256으로 해싱한 후 Base64(NO_WRAP)로 인코딩한 문자열.
- **Security_Threat**: 무결성 검증 실패 시 생성되는 위협 정보 모델 객체. 위협 유형과 상세 메시지를 포함한다.
- **Threat_Callback**: 위협 탐지 시 호스트 앱에서 제공하는 콜백 함수. Security_Threat 목록을 인자로 받는다.
- **Code_Signing_Result**: iOS 네이티브 코드가 반환하는 코드서명 검증 결과 딕셔너리. 번들 ID, CodeSignature 디렉토리 존재, 실행파일 존재, 바이너리 암호화 상태 등을 포함한다.
- **Host_App**: App_Integrity_Plugin을 pubspec.yaml 의존성으로 추가하여 사용하는 Flutter 앱 프로젝트.
- **Method_Channel**: Flutter Plugin 내부에서 Dart와 네이티브(Android/iOS) 코드 간 통신에 사용되는 MethodChannel. Plugin 자동 등록 시 내부적으로 생성된다.

## Requirements

### Requirement 1: 독립 Flutter Plugin 패키지 구조

**User Story:** As a 호스트 앱 개발자, I want to app_integrity를 독립된 Flutter Plugin 패키지로 사용하기를, so that pubspec.yaml에 의존성만 추가하면 네이티브 코드 등록 없이 즉시 사용할 수 있다.

#### Acceptance Criteria

1. THE App_Integrity_Plugin SHALL Flutter Plugin 표준 디렉토리 구조(lib/, android/, ios/, test/, example/)를 따른다.
2. THE App_Integrity_Plugin SHALL pubspec.yaml에 flutter.plugin 섹션을 정의하여 Android는 Kotlin pluginClass를, iOS는 Swift pluginClass를 선언한다.
3. WHEN Host_App이 pubspec.yaml에 app_integrity 의존성을 추가하고 빌드하면, THE Flutter 빌드 시스템 SHALL 네이티브 플러그인 코드를 자동으로 등록한다.
4. THE App_Integrity_Plugin SHALL mealcare_package에 대한 의존성을 갖지 않는 독립 패키지로 존재한다.
5. THE App_Integrity_Plugin SHALL 최소 Flutter SDK 3.0.0 이상, Dart SDK 3.0.0 이상을 지원한다.

### Requirement 2: 외부 파라미터 주입을 통한 초기화

**User Story:** As a 호스트 앱 개발자, I want to 앱별 고유 값(서명 해시, 번들 ID)을 Config 객체로 주입하여 초기화하기를, so that 하나의 Plugin 패키지를 여러 호스트 앱에서 재사용할 수 있다.

#### Acceptance Criteria

1. WHEN Host_App이 Integrity_Config 객체와 함께 Integrity_Checker를 생성하면, THE Integrity_Checker SHALL 해당 Config에 포함된 유효 서명 해시 목록, iOS 번들 ID 목록, 콜백 설정을 내부에 저장한다.
2. IF Integrity_Config에 유효 서명 해시 목록이 빈 리스트로 전달되면, THEN THE Integrity_Checker SHALL 경고 로그를 출력하고 Android 서명 검증을 건너뛴다.
3. IF Integrity_Config에 iOS 번들 ID 목록이 빈 리스트로 전달되면, THEN THE Integrity_Checker SHALL 경고 로그를 출력하고 번들 ID 검증을 건너뛴다.
4. THE Integrity_Config SHALL 모든 설정 필드에 합리적인 기본값을 제공하여, 최소 설정만으로 초기화가 가능하도록 한다.
5. THE Integrity_Config SHALL validSigningHashes, validBundleIds, enableInstallSourceCheck, skipInDebugMode, onThreatDetected, customDialogBuilder 필드를 포함한다.

### Requirement 3: Android APK 서명 인증서 검증

**User Story:** As a 호스트 앱 개발자, I want to Android 환경에서 런타임에 APK 서명 인증서가 위변조되었는지 자동 검증하기를, so that 디컴파일 후 재서명된 앱 실행을 탐지할 수 있다.

#### Acceptance Criteria

1. WHEN Android 플랫폼에서 verify()가 호출되면, THE Integrity_Checker SHALL Method_Channel을 통해 네이티브 Kotlin 코드로부터 현재 앱의 Signing_Hash를 요청한다.
2. WHEN 네이티브 Kotlin 코드가 Signing_Hash를 반환하면, THE Integrity_Checker SHALL 해당 값을 Integrity_Config의 유효 서명 해시 목록과 비교한다.
3. IF 현재 Signing_Hash가 유효 서명 해시 목록에 포함되지 않으면, THEN THE Integrity_Checker SHALL signatureMismatch 유형의 Security_Threat 객체를 생성한다.
4. IF 네이티브 Kotlin 코드가 null을 반환하면, THEN THE Integrity_Checker SHALL signatureUnavailable 유형의 Security_Threat를 생성한다.
5. THE Android 네이티브 Kotlin 코드 SHALL PackageManager API를 사용하여 현재 앱의 서명 인증서를 SHA-256으로 해싱하고 Base64(NO_WRAP)로 인코딩하여 반환한다.
6. THE Android 네이티브 Kotlin 코드 SHALL Android API 28 이상에서는 GET_SIGNING_CERTIFICATES를, 미만 버전에서는 GET_SIGNATURES를 사용한다.
7. THE Android 네이티브 Kotlin 코드 SHALL FlutterPlugin 인터페이스를 구현하여 Flutter Plugin 자동 등록 메커니즘을 따른다.

### Requirement 4: iOS 코드서명 무결성 검증

**User Story:** As a 호스트 앱 개발자, I want to iOS 환경에서 코드서명 무결성과 번들 ID를 검증하기를, so that 탈옥 환경에서 위변조된 앱 실행을 탐지할 수 있다.

#### Acceptance Criteria

1. WHEN iOS 플랫폼에서 verify()가 호출되면, THE Integrity_Checker SHALL Method_Channel을 통해 네이티브 Swift 코드로부터 Code_Signing_Result를 요청한다.
2. WHEN Code_Signing_Result가 반환되면, THE Integrity_Checker SHALL 번들 ID가 Integrity_Config의 유효 번들 ID 목록에 포함되는지 확인한다.
3. IF 번들 ID가 유효 번들 ID 목록에 포함되지 않으면, THEN THE Integrity_Checker SHALL bundleIdMismatch 유형의 Security_Threat를 생성한다.
4. IF Code_Signing_Result에서 _CodeSignature 디렉토리가 존재하지 않으면, THEN THE Integrity_Checker SHALL codeSignatureDirectoryMissing 유형의 Security_Threat를 생성한다.
5. IF Code_Signing_Result에서 실행파일이 존재하지 않으면, THEN THE Integrity_Checker SHALL executableCorrupted 유형의 Security_Threat를 생성한다.
6. THE iOS 네이티브 Swift 코드 SHALL _CodeSignature 디렉토리 존재, 실행파일 존재, 번들 ID, 바이너리 암호화 상태, 디버그/시뮬레이터 여부를 포함하는 Code_Signing_Result 딕셔너리를 반환한다.
7. THE iOS 네이티브 Swift 코드 SHALL Mach-O 헤더의 LC_ENCRYPTION_INFO 또는 LC_ENCRYPTION_INFO_64 로드 커맨드에서 cryptid 값을 확인하여 바이너리 암호화 상태를 판정한다.
8. WHILE DEBUG 빌드 또는 시뮬레이터 환경이면, THE iOS 네이티브 Swift 코드 SHALL 바이너리 암호화 검사를 통과로 처리한다.
9. THE iOS 네이티브 Swift 코드 SHALL FlutterPlugin 프로토콜을 구현하여 Flutter Plugin 자동 등록 메커니즘을 따른다.

### Requirement 5: 설치 출처 검증

**User Story:** As a 호스트 앱 개발자, I want to 앱이 공식 스토어에서 설치되었는지 확인하기를, so that 사이드로딩된 앱을 탐지할 수 있다.

#### Acceptance Criteria

1. WHEN Android에서 설치 출처 검증이 활성화된 상태로 verify()가 호출되면, THE Integrity_Checker SHALL Method_Channel을 통해 네이티브 Kotlin 코드로부터 설치 출처 패키지명을 요청한다.
2. THE Android 네이티브 Kotlin 코드 SHALL API 30 이상에서는 getInstallSourceInfo를, 미만 버전에서는 getInstallerPackageName을 사용하여 설치 출처를 반환한다.
3. IF Android 설치 출처가 공식 스토어 패키지명(com.android.vending, com.huawei.appmarket, com.samsung.android.vending) 목록에 포함되지 않으면, THEN THE Integrity_Checker SHALL unofficialInstallSource 유형의 Security_Threat를 생성한다.
4. WHEN iOS에서 설치 출처 검증이 활성화된 상태로 verify()가 호출되면, THE iOS 네이티브 Swift 코드 SHALL App Store 영수증 파일 존재 여부와 경로를 확인하여 "appstore", "testflight", "sideloaded" 중 하나를 반환한다.
5. IF iOS 설치 출처가 "sideloaded"이면, THEN THE Integrity_Checker SHALL unofficialInstallSource 유형의 Security_Threat를 생성한다.
6. THE Integrity_Config SHALL enableInstallSourceCheck 필드의 기본값을 false로 하여 설치 출처 검증을 선택적으로 활성화할 수 있도록 한다.

### Requirement 6: 위협 탐지 결과 콜백

**User Story:** As a 호스트 앱 개발자, I want to 위협 탐지 결과를 콜백으로 받아 앱별로 다른 대응을 할 수 있기를, so that 패키지 사용측에서 종료, 경고, 로깅 등 대응 로직을 자유롭게 커스터마이징할 수 있다.

#### Acceptance Criteria

1. WHEN verify()가 완료되면, THE Integrity_Checker SHALL 탐지된 Security_Threat 목록을 반환값으로 제공한다.
2. WHEN Security_Threat가 하나 이상 탐지되면, THE Integrity_Checker SHALL Integrity_Config에 등록된 Threat_Callback을 호출한다.
3. IF Threat_Callback이 등록되지 않았으면, THEN THE Integrity_Checker SHALL 기본 동작으로 디버그 로그에 위협 정보를 출력한다.
4. THE Security_Threat SHALL 위협 유형(enum)과 상세 메시지(String)를 포함한다.
5. THE Integrity_Checker SHALL hasThreat 속성을 통해 위협 탐지 여부를 boolean 값으로 제공한다.
6. THE Integrity_Checker SHALL detectedThreats 속성을 통해 불변(unmodifiable) Security_Threat 목록을 제공한다.

### Requirement 7: 기본 보안 경고 UI 제공

**User Story:** As a 호스트 앱 개발자, I want to 패키지에서 기본 보안 경고 다이얼로그를 제공받되 커스터마이징도 가능하기를, so that 별도 UI 구현 없이도 빠르게 적용할 수 있다.

#### Acceptance Criteria

1. THE App_Integrity_Plugin SHALL 기본 보안 경고 다이얼로그를 표시하는 정적 메서드(showSecurityAlert)를 제공한다.
2. WHEN showSecurityAlert가 호출되면, THE App_Integrity_Plugin SHALL 경고 아이콘, 제목, 위협 메시지 요약, 종료 버튼을 포함한 AlertDialog를 표시한다.
3. THE 기본 보안 경고 다이얼로그 SHALL 뒤로가기 버튼과 외부 영역 탭으로 닫을 수 없도록 barrierDismissible을 false로 설정한다.
4. WHERE Host_App이 커스텀 다이얼로그 빌더를 Integrity_Config에 제공하면, THE showSecurityAlert SHALL 기본 다이얼로그 대신 커스텀 빌더를 사용하여 다이얼로그를 표시한다.

### Requirement 8: 디버그 모드 지원

**User Story:** As a 호스트 앱 개발자, I want to 디버그 빌드에서 무결성 검증을 선택적으로 비활성화하기를, so that 개발 중에는 서명 검증 실패로 인한 불편 없이 앱을 실행할 수 있다.

#### Acceptance Criteria

1. WHERE Integrity_Config에서 skipInDebugMode가 true로 설정되면, THE Integrity_Checker SHALL kDebugMode일 때 모든 검증을 건너뛰고 즉시 빈 Security_Threat 목록을 반환한다.
2. WHEN 디버그 모드에서 검증이 건너뛰어지면, THE Integrity_Checker SHALL "디버그 모드: 무결성 검증 건너뜀" 로그를 출력한다.
3. THE Integrity_Config SHALL skipInDebugMode 필드의 기본값을 true로 한다.
