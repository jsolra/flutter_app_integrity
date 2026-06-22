package com.example.app_integrity

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Base64
import java.security.MessageDigest

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** AppIntegrityPlugin */
class AppIntegrityPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app_integrity")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getSigningHash" -> result.success(getSigningHash())
            "getInstallSource" -> result.success(getInstallSource())
            else -> result.notImplemented()
        }
    }

    private fun getSigningHash(): String? {
        return try {
            val packageName = context.packageName
            val packageManager = context.packageManager

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // API 28+: use GET_SIGNING_CERTIFICATES
                val packageInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                // API < 28: use GET_SIGNATURES (deprecated but needed for compatibility)
                @Suppress("DEPRECATION")
                val packageInfo = packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures == null || signatures.isEmpty()) {
                return null
            }

            // Hash the first signing certificate with SHA-256
            val cert = signatures[0].toByteArray()
            val md = MessageDigest.getInstance("SHA-256")
            val hash = md.digest(cert)

            // Encode with Base64 NO_WRAP
            Base64.encodeToString(hash, Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }

    private fun getInstallSource(): String? {
        return try {
            val packageName = context.packageName
            val packageManager = context.packageManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // API 30+: use getInstallSourceInfo
                val installSourceInfo = packageManager.getInstallSourceInfo(packageName)
                installSourceInfo.installingPackageName
            } else {
                // API < 30: use getInstallerPackageName (deprecated but needed for compatibility)
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
        } catch (e: Exception) {
            null
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
