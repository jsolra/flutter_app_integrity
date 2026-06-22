# Implementation Plan: App Integrity Verification Package

## Overview

기존 보일러플레이트 Flutter Plugin 구조 위에 앱 무결성 검증 기능을 단계적으로 구현한다. Core 데이터 모델 → Platform Interface → Native 구현 (Android/iOS) → Dart 검증 로직 → UI 컴포넌트 순서로 빌드하여, 각 단계가 이전 단계 위에 점진적으로 통합된다.

## Tasks

- [x] 1. Core 데이터 모델 및 설정 클래스 구현
  - [x] 1.1 ThreatType enum 생성
    - `lib/src/models/threat_type.dart` 생성
    - signatureMismatch, signatureUnavailable, bundleIdMismatch, codeSignatureDirectoryMissing, executableCorrupted, unofficialInstallSource 값 정의
    - _Requirements: 6.4_
  - [x] 1.2 SecurityThreat 모델 생성
    - `lib/src/models/security_threat.dart` 생성
    - type(ThreatType), message(String) 필드 포함
    - == operator, hashCode, toString 오버라이드 구현
    - _Requirements: 6.4_
  - [x] 1.3 IntegrityConfig 모델 생성
    - `lib/src/models/integrity_config.dart` 생성
    - validSigningHashes, validBundleIds, enableInstallSourceCheck, skipInDebugMode, onThreatDetected, customDialogBuilder 필드 포함
    - 기본값: enableInstallSourceCheck=false, skipInDebugMode=true
    - ThreatCallback, CustomDialogBuilder typedef 정의
    - _Requirements: 2.4, 2.5, 5.6, 8.3_
  - [ ]* 1.4 데이터 모델 단위 테스트 작성
    - SecurityThreat equality 테스트
    - IntegrityConfig 기본값 검증
    - _Requirements: 2.4, 6.4_

- [x] 2. Platform Interface 확장
  - [x] 2.1 AppIntegrityPlatform 추상 클래스 업데이트
    - `lib/app_integrity_platform_interface.dart` 수정
    - getPlatformVersion() 제거
    - getSigningHash() → Future<String?> 추가
    - checkCodeSigning() → Future<Map<String, dynamic>?> 추가
    - getInstallSource() → Future<String?> 추가
    - _Requirements: 3.1, 4.1, 5.1_
  - [x] 2.2 MethodChannelAppIntegrity 업데이트
    - `lib/app_integrity_method_channel.dart` 수정
    - 3개 메서드 각각 MethodChannel.invokeMethod 호출 구현
    - _Requirements: 3.1, 4.1, 5.1_

- [x] 3. Android 네이티브 구현 (Kotlin)
  - [x] 3.1 AppIntegrityPlugin 서명 해시 구현
    - `android/src/main/kotlin/.../AppIntegrityPlugin.kt` 수정
    - getPlatformVersion 제거
    - getSigningHash 메서드 구현: PackageManager API로 서명 인증서 조회
    - API 28 이상: GET_SIGNING_CERTIFICATES 사용
    - API 28 미만: GET_SIGNATURES 사용 (deprecated but needed)
    - SHA-256 해싱 후 Base64(NO_WRAP) 인코딩
    - _Requirements: 3.5, 3.6, 3.7_
  - [x] 3.2 AppIntegrityPlugin 설치 출처 구현
    - getInstallSource 메서드 구현
    - API 30 이상: getInstallSourceInfo().installingPackageName 사용
    - API 30 미만: getInstallerPackageName() 사용 (deprecated but needed)
    - _Requirements: 5.1, 5.2_
  - [ ]* 3.3 Android 네이티브 단위 테스트 작성
    - Mocked PackageManager로 getSigningHash 테스트
    - API 레벨별 분기 테스트
    - _Requirements: 3.5, 3.6, 5.2_

- [x] 4. iOS 네이티브 구현 (Swift)
  - [x] 4.1 AppIntegrityPlugin 코드서명 검증 구현
    - `ios/Classes/AppIntegrityPlugin.swift` 수정
    - getPlatformVersion 제거
    - checkCodeSigning 메서드 구현:
      - Bundle.main에서 _CodeSignature 디렉토리 존재 확인
      - 실행파일 존재 확인
      - Bundle.main.bundleIdentifier로 번들 ID 획득
      - Mach-O LC_ENCRYPTION_INFO/LC_ENCRYPTION_INFO_64 cryptid 확인
      - 디버그/시뮬레이터 환경 판별
    - Map<String, Any> 딕셔너리 반환
    - _Requirements: 4.6, 4.7, 4.8, 4.9_
  - [x] 4.2 AppIntegrityPlugin 설치 출처 구현
    - getInstallSource 메서드 구현
    - App Store 영수증 파일(StoreKit/receipt) 경로 확인
    - sandbox receipt → "testflight"
    - 정상 receipt → "appstore"
    - receipt 없음 → "sideloaded"
    - _Requirements: 5.4_
  - [ ]* 4.3 iOS 네이티브 단위 테스트 작성
    - checkCodeSigning 반환 딕셔너리 구조 검증
    - getInstallSource 반환값 검증
    - _Requirements: 4.6, 5.4_

- [x] 5. Checkpoint - 네이티브 빌드 검증
  - Ensure all tests pass, ask the user if questions arise.
  - Android/iOS 각각 빌드가 성공하는지 확인

- [x] 6. IntegrityChecker 검증 로직 구현
  - [x] 6.1 IntegrityChecker 클래스 생성
    - `lib/src/integrity_checker.dart` 생성
    - config 필드, _detectedThreats 내부 상태
    - hasThreat getter: _detectedThreats.isNotEmpty
    - detectedThreats getter: List.unmodifiable(_detectedThreats) 반환
    - _Requirements: 2.1, 6.5, 6.6_
  - [x] 6.2 verify() 메서드 구현 - 디버그 모드 체크
    - kDebugMode && config.skipInDebugMode일 때 빈 리스트 즉시 반환
    - 로그 출력: "디버그 모드: 무결성 검증 건너뜀"
    - _Requirements: 8.1, 8.2_
  - [x] 6.3 verify() 메서드 구현 - Android 서명 검증
    - Platform.isAndroid일 때 getSigningHash() 호출
    - validSigningHashes가 비어있으면 경고 로그 출력 후 건너뜀
    - 결과가 null이면 signatureUnavailable 위협 생성
    - 결과가 validSigningHashes에 없으면 signatureMismatch 위협 생성
    - PlatformException catch 시 로그 출력, 건너뜀
    - _Requirements: 2.2, 3.1, 3.2, 3.3, 3.4_
  - [x] 6.4 verify() 메서드 구현 - iOS 코드서명 검증
    - Platform.isIOS일 때 checkCodeSigning() 호출
    - codeSignatureExists가 false면 codeSignatureDirectoryMissing 위협 생성
    - executableExists가 false면 executableCorrupted 위협 생성
    - validBundleIds가 비어있으면 경고 로그 출력 후 번들 ID 검증 건너뜀
    - bundleId가 validBundleIds에 없으면 bundleIdMismatch 위협 생성
    - _Requirements: 2.3, 4.1, 4.2, 4.3, 4.4, 4.5_
  - [x] 6.5 verify() 메서드 구현 - 설치 출처 검증
    - enableInstallSourceCheck가 true일 때만 실행
    - Android: getInstallSource() 호출, 공식 스토어 목록과 비교
    - iOS: getInstallSource() 호출, "sideloaded"이면 위협 생성
    - _Requirements: 5.1, 5.3, 5.4, 5.5, 5.6_
  - [x] 6.6 verify() 메서드 구현 - 콜백 및 결과 반환
    - _detectedThreats 업데이트
    - 위협이 있고 onThreatDetected가 설정되어 있으면 콜백 호출
    - 콜백이 없으면 debugPrint로 위협 정보 출력
    - 위협 목록 반환
    - _Requirements: 6.1, 6.2, 6.3_
  - [ ]* 6.7 Property test: 검증 결과 정확성
    - **Property 1: 검증 결과 정확성 (Verification Result Correctness)**
    - Mock platform interface로 다양한 native 응답 조합 생성
    - verify() 결과가 각 조건에 맞는 위협만 정확히 포함하는지 검증
    - 최소 100회 반복
    - **Validates: Requirements 3.2, 3.3, 4.2, 4.3, 4.4, 4.5, 5.3, 5.5, 6.1**
  - [ ]* 6.8 Property test: 콜백 호출 일관성
    - **Property 2: 콜백 호출 일관성 (Callback Invocation Consistency)**
    - 위협이 있는 시나리오에서 콜백이 verify() 반환값과 동일한 리스트로 호출되는지 검증
    - 최소 100회 반복
    - **Validates: Requirements 6.2**
  - [ ]* 6.9 Property test: 상태 일관성
    - **Property 3: 상태 일관성 (State Consistency)**
    - verify() 후 hasThreat == detectedThreats.isNotEmpty 검증
    - detectedThreats 불변성 검증 (외부 수정 시도 시 에러 확인)
    - 최소 100회 반복
    - **Validates: Requirements 6.5, 6.6**
  - [ ]* 6.10 Property test: 디버그 모드 바이패스
    - **Property 4: 디버그 모드 바이패스 (Debug Mode Bypass)**
    - skipInDebugMode=true + kDebugMode=true 시 항상 빈 리스트 반환
    - 최소 100회 반복
    - **Validates: Requirements 8.1**

- [x] 7. 패키지 export 및 public API 정리
  - [x] 7.1 lib/app_integrity.dart 업데이트
    - 기존 보일러플레이트 제거
    - 모든 public 클래스 export 정리
    - _Requirements: 1.1, 1.2_

- [x] 8. 보안 경고 UI 컴포넌트 구현
  - [x] 8.1 SecurityAlertDialog 구현
    - `lib/src/ui/security_alert_dialog.dart` 생성
    - showSecurityAlert 정적 메서드 구현
    - 기본 AlertDialog: 경고 아이콘, 제목("보안 경고"), 위협 메시지 요약, 종료 버튼
    - barrierDismissible: false, WillPopScope로 뒤로가기 방지
    - customDialogBuilder가 있으면 기본 다이얼로그 대신 사용
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - [ ]* 8.2 SecurityAlertDialog 위젯 테스트 작성
    - 기본 다이얼로그 요소 존재 확인 (아이콘, 제목, 버튼)
    - barrierDismissible false 확인
    - 커스텀 빌더 사용 시 기본 다이얼로그 미표시 확인
    - **Property 5: 커스텀 다이얼로그 라우팅 (Custom Dialog Routing)**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4**

- [x] 9. Checkpoint - 전체 통합 검증
  - Ensure all tests pass, ask the user if questions arise.
  - example 앱에서 import 및 기본 사용 가능 확인

- [x] 10. Example 앱 및 README 업데이트
  - [x] 10.1 Example 앱 업데이트
    - `example/lib/main.dart`에서 IntegrityChecker 기본 사용 예시 구현
    - IntegrityConfig 생성 → IntegrityChecker 생성 → verify() 호출 → 결과 표시
    - _Requirements: 1.3, 2.1_
  - [x] 10.2 README.md 업데이트
    - 패키지 설명, 설치 방법, 기본 사용법, API 문서 작성
    - _Requirements: 1.1_

- [x] 11. Final Checkpoint - 최종 검증
  - Ensure all tests pass, ask the user if questions arise.
  - `flutter analyze` 경고 없음 확인
  - pubspec.yaml 의존성 정리 확인

## Task Dependency Graph

```json
{
  "waves": [
    {
      "wave": 1,
      "tasks": ["1"],
      "description": "Core 데이터 모델 및 설정 클래스 구현"
    },
    {
      "wave": 2,
      "tasks": ["2"],
      "description": "Platform Interface 확장"
    },
    {
      "wave": 3,
      "tasks": ["3", "4"],
      "description": "Android 및 iOS 네이티브 구현 (병렬 가능)"
    },
    {
      "wave": 4,
      "tasks": ["5"],
      "description": "네이티브 빌드 검증 Checkpoint"
    },
    {
      "wave": 5,
      "tasks": ["6"],
      "description": "IntegrityChecker 검증 로직 구현"
    },
    {
      "wave": 6,
      "tasks": ["7", "8"],
      "description": "Public API 정리 및 UI 컴포넌트 (병렬 가능)"
    },
    {
      "wave": 7,
      "tasks": ["9"],
      "description": "전체 통합 검증 Checkpoint"
    },
    {
      "wave": 8,
      "tasks": ["10"],
      "description": "Example 앱 및 README 업데이트"
    },
    {
      "wave": 9,
      "tasks": ["11"],
      "description": "최종 검증 Checkpoint"
    }
  ]
}
```

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- 각 태스크는 특정 requirements를 참조하여 추적 가능성 유지
- Checkpoints에서 빌드/테스트 실패 시 이전 단계로 돌아가 수정
- Property tests는 Method Channel을 mock하여 다양한 native 응답 조합 생성
- Android/iOS 네이티브 코드는 각 플랫폼 빌드 환경에서만 실행 가능
