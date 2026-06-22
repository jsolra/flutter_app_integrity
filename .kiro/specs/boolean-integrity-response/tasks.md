# Implementation Plan: Boolean Integrity Response

## Overview

기존 `app_integrity` 패키지에서 UI 로직(SecurityAlertDialog, 콜백, CustomDialogBuilder)을 완전히 제거하고, `verify()` 반환 타입을 `Future<bool>`로 변환하는 리팩토링을 순차적으로 수행한다. 네이티브 코드(android/, ios/)는 변경하지 않는다.

## Tasks

- [ ] 1. IntegrityConfig에서 콜백 및 UI 관련 코드 제거
  - [ ] 1.1 IntegrityConfig 모델 수정
    - `lib/src/models/integrity_config.dart`에서 `ThreatCallback` typedef 제거
    - `CustomDialogBuilder` typedef 제거
    - `onThreatDetected` 필드 및 생성자 파라미터 제거
    - `customDialogBuilder` 필드 및 생성자 파라미터 제거
    - `import 'package:flutter/widgets.dart'` 제거
    - `import 'package:app_integrity/src/models/security_threat.dart'` 제거 (typedef에서만 사용되었으므로)
    - 최종 필드: `validSigningHashes`, `validBundleIds`, `enableInstallSourceCheck`, `skipInDebugMode` 4개만 유지
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 1.5_

- [ ] 2. IntegrityChecker의 verify() 반환 타입 변경 및 콜백 로직 제거
  - [ ] 2.1 verify() 메서드 리팩토링
    - `lib/src/integrity_checker.dart`에서 `verify()` 반환 타입을 `Future<List<SecurityThreat>>`에서 `Future<bool>`로 변경
    - 메서드 시작 부분에서 `_detectedThreats.clear()` 호출 (디버그 모드 건너뛰기 분기 이후에도 빈 상태 유지)
    - 디버그 모드 건너뛰기 시 `return false` 반환
    - 기존 검증 로직(Android 서명, iOS 코드서명, 설치 출처) 동일하게 유지하되 로컬 `threats` 리스트 대신 `_detectedThreats`에 직접 추가
    - 콜백 호출 로직(`config.onThreatDetected` 관련 코드) 전체 제거
    - 최종 반환값을 `_detectedThreats.isNotEmpty`로 변경
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.3, 6.4_

- [ ] 3. SecurityAlertDialog 파일 삭제 및 barrel 파일 정리
  - [ ] 3.1 SecurityAlertDialog 파일 삭제
    - `lib/src/ui/security_alert_dialog.dart` 파일 삭제
    - `lib/src/ui/` 디렉토리 삭제
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ] 3.2 barrel 파일 업데이트
    - `lib/app_integrity.dart`에서 `export 'src/ui/security_alert_dialog.dart';` 구문 제거
    - 최종 export: IntegrityChecker, IntegrityConfig, SecurityThreat, ThreatType, AppIntegrityPlatformInterface만 유지
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 4. Checkpoint - 패키지 빌드 검증
  - 패키지가 컴파일 에러 없이 빌드되는지 확인한다. 문제가 있으면 사용자에게 질문한다.

- [ ] 5. Example 앱 업데이트
  - [ ] 5.1 example/lib/main.dart를 boolean API에 맞게 수정
    - `_initChecker()`에서 `onThreatDetected` 콜백 파라미터 제거
    - `_handleThreatsDetected` 메서드 삭제
    - `SecurityAlertDialog` 관련 코드 전체 제거 (`_showAlertDemo` 메서드, 데모 버튼)
    - `_runVerification()`에서 `verify()` 반환값을 `bool`로 수신
    - `_checker.detectedThreats`를 통해 상세 위협 정보 접근
    - UI는 boolean 결과와 detectedThreats getter 기반으로 표시
    - _Requirements: 2.1, 2.2, 4.1, 4.2, 7.5_

- [ ] 6. Final Checkpoint - 전체 빌드 및 정적 검증
  - example 앱 포함 전체 프로젝트가 에러 없이 빌드되는지 확인한다.
  - `lib/src/` 내 파일에서 `material.dart`, `widgets.dart`, `cupertino.dart` import가 없는지 확인한다.
  - `lib/src/ui/` 디렉토리가 존재하지 않는지 확인한다.
  - 문제가 있으면 사용자에게 질문한다.

- [ ]* 7. 속성 기반 테스트 작성
  - [ ]* 7.1 Property 1 테스트: verify() 반환값과 상태 일관성
    - **Property 1: verify() 반환값과 상태 일관성**
    - verify() 반환값 == hasThreat == detectedThreats.isNotEmpty 항상 동일한지 검증
    - Mock 플랫폼 응답을 다양하게 생성하여 테스트
    - **Validates: Requirements 2.1, 2.2, 4.2, 5.2, 5.5**

  - [ ]* 7.2 Property 2 테스트: detectedThreats 불변성
    - **Property 2: detectedThreats 불변성**
    - detectedThreats 반환 목록에 add/remove/clear 시도 시 UnsupportedError 발생 검증
    - **Validates: Requirements 4.1**

  - [ ]* 7.3 Property 3 테스트: 연속 호출 시 상태 교체
    - **Property 3: 연속 호출 시 상태 교체**
    - verify()를 여러 번 호출한 후 detectedThreats가 마지막 호출 결과만 포함하는지 검증
    - **Validates: Requirements 4.5, 5.3**

  - [ ]* 7.4 Property 4 테스트: PlatformException 복원력
    - **Property 4: PlatformException 복원력**
    - 랜덤 검증 단계에서 PlatformException 발생 시에도 나머지 단계가 수행되고 정상 반환하는지 검증
    - **Validates: Requirements 2.5, 5.4**

## Notes

- `*` 표시된 태스크는 선택 사항이며 빠른 MVP를 위해 건너뛸 수 있습니다.
- 각 태스크는 추적 가능성을 위해 구체적인 요구사항을 참조합니다.
- Checkpoint에서 증분 검증을 수행합니다.
- 네이티브 코드(android/, ios/)는 변경 대상이 아닙니다.
- 속성 기반 테스트는 Dart PBT 라이브러리(`glados` 또는 `dart_check`)를 활용합니다.
- `AppIntegrityPlatform.instance`를 mock으로 교체하여 플랫폼 의존성 없이 테스트합니다.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["3.1", "3.2"] },
    { "id": 3, "tasks": ["5.1"] },
    { "id": 4, "tasks": ["7.1", "7.2", "7.3", "7.4"] }
  ]
}
```
