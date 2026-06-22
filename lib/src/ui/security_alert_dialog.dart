import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/integrity_config.dart';
import '../models/security_threat.dart';

/// 보안 경고 다이얼로그를 표시하는 유틸리티 클래스.
///
/// 무결성 검증에서 위협이 탐지되었을 때 사용자에게 경고를 표시하고
/// 앱 종료를 유도하는 기본 UI를 제공한다.
class SecurityAlertDialog {
  SecurityAlertDialog._();

  /// 보안 경고 다이얼로그를 표시한다.
  ///
  /// [context] - 다이얼로그를 표시할 BuildContext.
  /// [threats] - 탐지된 보안 위협 목록.
  /// [customDialogBuilder] - 커스텀 다이얼로그 빌더. 제공 시 기본 다이얼로그 대신 사용.
  static Future<void> showSecurityAlert(
    BuildContext context,
    List<SecurityThreat> threats, {
    CustomDialogBuilder? customDialogBuilder,
  }) {
    if (customDialogBuilder != null) {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return PopScope(
            canPop: false,
            child: customDialogBuilder(dialogContext, threats),
          );
        },
      );
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            icon: const Icon(
              Icons.warning,
              color: Colors.amber,
              size: 48,
            ),
            title: const Text('보안 경고'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: threats
                    .map(
                      (threat) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                '${threat.type.name}: ${threat.message}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SystemNavigator.pop();
                  exit(0);
                },
                child: const Text('종료'),
              ),
            ],
          ),
        );
      },
    );
  }
}
