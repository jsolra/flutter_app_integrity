# Requirements Document

## Introduction

기존 app_integrity Flutter Plugin 패키지를 리팩토링하여 UI 로직을 완전히 제거하고, 위협 탐지 결과를 boolean 값으로 반환하는 순수 검증 패키지로 변환한다. 현재 패키지는 SecurityAlertDialog UI와 콜백(onThreatDetected, customDialogBuilder)을 포함하지만, 리팩토링 후에는 위협 탐지 시 true, 정상 시 false를 반환하는 단순한 API를 제공한다. UI 로직은 호스트 앱에서 개별적으로 구현하도록 책임을 분리한다.

## Glossary

- **App_Integrity_Plugin**: 앱 무결성 검증 기능을 제공하는 독립 Flutter Plugin 패키지. UI 로직을 포함하지 않으며 boolean 기반 검증 결과만 제공한다.
- **Integrity_Checker**: App_Integrity_Plugin의 Dart 진입점 클래스. Config를 주입받아 초기화하고 verify() 메서드를 통해 무결성 검증을 수행한다.
- **Integrity_Config**: Integrity_Checker 초기화 시 호스트 앱이 전달하는 설정 객체. 유효 서명 해시 목록, iOS 번들 ID 목록, 설치 출처 검증 활성화 여부, 디버그 모드 건너뛰기 옵션을 포함한다. onThreatDetected 콜백과 customDialogBuilder는 포함하지 않는다.
- **Security_Threat**: 무결성 검증 실패 시 생성되는 위협 정보 모델 객체. 위협 유형(ThreatType enum)과 상세 메시지(String)를 포함한다.
- **Host_App**: App_Integrity_Plugin을 pubspec.yaml 의존성으로 추가하여 사용하는 Flutter 앱 프로젝트. 검증 결과를 받아 UI 로직을 자체 구현한다.
- **SecurityAlertDialog**: 현재 패키지에 포함된 보안 경고 다이얼로그 위젯. 리팩토링 시 완전히 제거되는 대상이다.
- **ThreatCallback**: 현재 IntegrityConfig에 포함된 위협 탐지 콜백 타입(void Function(List<SecurityThreat>)). 리팩토링 시 제거되는 대상이다.
- **CustomDialogBuilder**: 현재 IntegrityConfig에 포함된 커스텀 다이얼로그 빌더 타입. 리팩토링 시 제거되는 대상이다.

## Requirements

### Requirement 1: UI 로직 완전 제거

**User Story:** As a 호스트 앱 개발자, I want to app_integrity 패키지에서 UI 관련 코드가 완전히 제거되기를, so that 패키지가 순수 검증 로직만 담당하고 UI는 호스트 앱에서 자유롭게 구현할 수 있다.

#### Acceptance Criteria

1. THE App_Integrity_Plugin SHALL SecurityAlertDialog 클래스와 관련 파일(lib/src/ui/ 디렉토리 전체)을 포함하지 않는다.
2. THE App_Integrity_Plugin SHALL showSecurityAlert 정적 메서드를 제공하지 않는다.
3. THE App_Integrity_Plugin SHALL Flutter의 material.dart, widgets.dart, cupertino.dart 등 UI 프레임워크 패키지에 대한 import를 lib/src/ 내 검증 로직 코드에서 포함하지 않는다(foundation.dart, services.dart는 허용).
4. THE App_Integrity_Plugin SHALL BuildContext를 매개변수로 받는 public 메서드를 제공하지 않는다.
5. THE App_Integrity_Plugin SHALL IntegrityConfig 모델에서 CustomDialogBuilder typedef 및 관련 Widget 반환 타입 정의를 포함하지 않는다.

### Requirement 2: Boolean 기반 verify() API 변환

**User Story:** As a 호스트 앱 개발자, I want to verify() 메서드가 boolean 값을 반환하기를, so that 위협 탐지 여부를 단순하게 확인하고 호스트 앱에서 후속 처리를 결정할 수 있다.

#### Acceptance Criteria

1. WHEN verify() 메서드가 호출되고 위협이 하나 이상 탐지된 경우, THE Integrity_Checker SHALL true를 반환한다.
2. WHEN verify() 메서드가 호출되고 위협이 탐지되지 않은 경우, THE Integrity_Checker SHALL false를 반환한다.
3. THE Integrity_Checker SHALL verify() 메서드의 반환 타입을 Future<bool>로 선언한다.
4. THE Integrity_Checker SHALL verify() 호출 시 내부적으로 기존의 Android 서명 검증, iOS 코드서명 검증, 설치 출처 검증 로직을 동일한 순서와 조건으로 수행한다.
5. IF verify() 수행 중 모든 검증 단계에서 PlatformException이 발생하여 어떤 위협도 명시적으로 탐지되지 않으면, THEN THE Integrity_Checker SHALL false를 반환한다.

### Requirement 3: IntegrityConfig에서 콜백 및 UI 관련 필드 제거

**User Story:** As a 호스트 앱 개발자, I want to IntegrityConfig에서 onThreatDetected 콜백과 customDialogBuilder 필드가 제거되기를, so that 설정 객체가 순수 검증 파라미터만 포함하여 역할이 명확해진다.

#### Acceptance Criteria

1. THE Integrity_Config SHALL onThreatDetected 콜백 필드를 포함하지 않으며, 생성자 파라미터로도 허용하지 않는다.
2. THE Integrity_Config SHALL customDialogBuilder 필드를 포함하지 않으며, 생성자 파라미터로도 허용하지 않는다.
3. THE Integrity_Config SHALL ThreatCallback typedef를 선언하지 않는다.
4. THE Integrity_Config SHALL CustomDialogBuilder typedef를 선언하지 않는다.
5. THE Integrity_Config SHALL validSigningHashes(List<String>), validBundleIds(List<String>), enableInstallSourceCheck(bool), skipInDebugMode(bool) 4개 필드만을 포함한다.
6. THE Integrity_Config SHALL 모든 필드에 기존과 동일한 기본값(validSigningHashes: const [], validBundleIds: const [], enableInstallSourceCheck: false, skipInDebugMode: true)을 제공한다.
7. WHEN Host_App이 Integrity_Config 생성자를 호출할 때 onThreatDetected 또는 customDialogBuilder 파라미터를 전달하면, THE Dart 컴파일러 SHALL 컴파일 오류를 발생시킨다.

### Requirement 4: 위협 상세 정보 접근 유지

**User Story:** As a 호스트 앱 개발자, I want to boolean 결과 외에도 상세 위협 정보에 접근할 수 있기를, so that 필요 시 위협 유형별 세부 대응 로직을 호스트 앱에서 구현할 수 있다.

#### Acceptance Criteria

1. WHEN verify()가 호출 완료되면, THE Integrity_Checker SHALL detectedThreats 속성을 통해 해당 호출에서 탐지된 Security_Threat의 불변(unmodifiable) 목록을 제공하며, 해당 목록에 대한 추가/삭제/수정 시도 시 UnsupportedError를 발생시킨다.
2. WHEN verify()가 호출 완료되면, THE Integrity_Checker SHALL hasThreat 속성을 통해 detectedThreats가 비어있지 않은 경우 true를, 비어있는 경우 false를 반환한다.
3. IF verify()가 아직 호출되지 않은 상태에서 detectedThreats에 접근하면, THEN THE Integrity_Checker SHALL 빈 불변 목록을 반환한다.
4. IF verify()가 아직 호출되지 않은 상태에서 hasThreat에 접근하면, THEN THE Integrity_Checker SHALL false를 반환한다.
5. WHEN verify()가 두 번 이상 호출되면, THE Integrity_Checker SHALL detectedThreats를 가장 최근 verify() 호출의 탐지 결과로 대체한다.
6. THE Security_Threat SHALL 위협 유형을 나타내는 ThreatType enum 필드(type)와 상세 설명을 나타내는 String 필드(message)를 불변 속성으로 포함한다.
7. THE ThreatType enum SHALL signatureMismatch, signatureUnavailable, bundleIdMismatch, codeSignatureDirectoryMissing, executableCorrupted, unofficialInstallSource 값을 포함한다.

### Requirement 5: 콜백 제거 후 verify() 동작 변경

**User Story:** As a 호스트 앱 개발자, I want to verify() 메서드가 콜백 호출 없이 결과만 반환하기를, so that 호스트 앱에서 반환값을 기반으로 직접 후속 로직을 제어할 수 있다.

#### Acceptance Criteria

1. WHEN verify()가 완료되면, THE Integrity_Checker SHALL 외부 콜백 함수를 호출하지 않고 boolean 값만 반환한다.
2. WHEN 위협이 탐지되면, THE Integrity_Checker SHALL 탐지된 위협 정보를 내부 상태(_detectedThreats)에 저장한 후 true를 반환한다.
3. WHEN verify()가 반복 호출되면, THE Integrity_Checker SHALL 이전 검증 결과(_detectedThreats)를 clear()한 후 새로운 검증을 수행한다.
4. IF verify() 수행 중 특정 검증 단계에서 PlatformException이 발생하면, THEN THE Integrity_Checker SHALL 해당 검증 단계를 건너뛰고 debugPrint로 오류 메시지를 출력한 후 나머지 검증을 계속 수행한다.
5. WHEN 위협이 탐지되지 않으면, THE Integrity_Checker SHALL 내부 상태(_detectedThreats)를 빈 목록으로 유지하고 false를 반환한다.

### Requirement 6: 디버그 모드 지원 유지

**User Story:** As a 호스트 앱 개발자, I want to 디버그 빌드에서 무결성 검증을 선택적으로 비활성화하기를, so that 개발 중에는 서명 검증 실패로 인한 불편 없이 앱을 실행할 수 있다.

#### Acceptance Criteria

1. WHERE Integrity_Config에서 skipInDebugMode가 true로 설정되고 kDebugMode가 true이면, THE Integrity_Checker SHALL 모든 검증을 건너뛰고 즉시 false를 반환한다.
2. WHEN 디버그 모드에서 검증이 건너뛰어지면, THE Integrity_Checker SHALL debugPrint를 통해 '디버그 모드: 무결성 검증 건너뜀' 메시지를 출력한다.
3. WHEN 디버그 모드에서 검증이 건너뛰어지면, THE Integrity_Checker SHALL _detectedThreats를 빈 상태로 유지하여 hasThreat이 false를, detectedThreats가 빈 목록을 반환하도록 한다.
4. WHERE Integrity_Config에서 skipInDebugMode가 false로 설정되면, THE Integrity_Checker SHALL kDebugMode 여부와 관계없이 검증을 정상 수행한다.

### Requirement 7: 패키지 public API 정리

**User Story:** As a 호스트 앱 개발자, I want to 패키지의 public export에서 UI 관련 심볼이 제거되기를, so that 패키지 import 시 불필요한 UI 클래스가 노출되지 않는다.

#### Acceptance Criteria

1. THE App_Integrity_Plugin SHALL 패키지 barrel 파일(lib/app_integrity.dart)에서 `export 'src/ui/security_alert_dialog.dart'` 구문을 제거하여 SecurityAlertDialog 클래스가 public API에 노출되지 않도록 한다.
2. THE App_Integrity_Plugin SHALL IntegrityConfig 모델에서 CustomDialogBuilder typedef 정의와 customDialogBuilder 필드를 제거하여 해당 타입이 public API에 노출되지 않도록 한다.
3. THE App_Integrity_Plugin SHALL IntegrityConfig 모델에서 ThreatCallback typedef 정의와 onThreatDetected 필드를 제거하여 해당 타입이 public API에 노출되지 않도록 한다.
4. THE App_Integrity_Plugin SHALL 패키지 barrel 파일(lib/app_integrity.dart)에서 IntegrityChecker, IntegrityConfig, SecurityThreat, ThreatType 4개 심볼만 public API로 export한다.
5. WHEN 호스트 앱이 `import 'package:app_integrity/app_integrity.dart'`를 사용하여 SecurityAlertDialog, CustomDialogBuilder, 또는 ThreatCallback을 참조하는 코드를 작성하면, THE Dart 정적 분석기 SHALL undefined class/typedef 오류를 발생시킨다.
