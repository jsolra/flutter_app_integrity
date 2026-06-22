import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_integrity_platform_interface.dart';

/// An implementation of [AppIntegrityPlatform] that uses method channels.
class MethodChannelAppIntegrity extends AppIntegrityPlatform {
  /// The method channel used to interact with the native platform.
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
