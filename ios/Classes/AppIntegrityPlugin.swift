import Flutter
import UIKit
import MachO

public class AppIntegrityPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_integrity", binaryMessenger: registrar.messenger())
        let instance = AppIntegrityPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

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

    private func checkCodeSigning() -> [String: Any] {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let codeSignatureExists = checkCodeSignatureDirectoryExists()
        let executableExists = checkExecutableExists()
        let isDebugBuild = checkIsDebugBuild()
        let isSimulator = checkIsSimulator()
        let isEncrypted: Bool

        // In debug build or simulator, always treat encryption as passed
        if isDebugBuild || isSimulator {
            isEncrypted = true
        } else {
            isEncrypted = checkIsEncrypted()
        }

        return [
            "bundleId": bundleId,
            "codeSignatureExists": codeSignatureExists,
            "executableExists": executableExists,
            "isEncrypted": isEncrypted,
            "isDebugBuild": isDebugBuild,
            "isSimulator": isSimulator,
        ]
    }

    /// Determine install source based on App Store receipt file
    private func getInstallSource() -> String {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return "sideloaded"
        }

        if receiptURL.path.contains("sandboxReceipt") {
            return "testflight"
        }

        if FileManager.default.fileExists(atPath: receiptURL.path) {
            return "appstore"
        }

        return "sideloaded"
    }

    /// Check if _CodeSignature directory exists in app bundle
    private func checkCodeSignatureDirectoryExists() -> Bool {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            return false
        }
        let codeSignaturePath = (bundlePath as NSString).appendingPathComponent("_CodeSignature")
        return FileManager.default.fileExists(atPath: codeSignaturePath)
    }

    /// Check if executable file exists in app bundle
    private func checkExecutableExists() -> Bool {
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }
        return FileManager.default.fileExists(atPath: executablePath)
    }

    /// Check Mach-O binary encryption status via LC_ENCRYPTION_INFO/LC_ENCRYPTION_INFO_64
    private func checkIsEncrypted() -> Bool {
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }

        guard let fileData = FileManager.default.contents(atPath: executablePath) else {
            return false
        }

        return fileData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Bool in
            guard let baseAddress = bytes.baseAddress else {
                return false
            }

            // Read Mach-O magic number
            let magic = baseAddress.load(as: UInt32.self)

            let is64Bit: Bool
            var headerSize: Int

            switch magic {
            case MH_MAGIC:
                is64Bit = false
                headerSize = MemoryLayout<mach_header>.size
            case MH_MAGIC_64:
                is64Bit = true
                headerSize = MemoryLayout<mach_header_64>.size
            default:
                return false
            }

            // Get number of load commands
            let ncmds: UInt32
            if is64Bit {
                let header = baseAddress.load(as: mach_header_64.self)
                ncmds = header.ncmds
            } else {
                let header = baseAddress.load(as: mach_header.self)
                ncmds = header.ncmds
            }

            // Iterate through load commands to find LC_ENCRYPTION_INFO or LC_ENCRYPTION_INFO_64
            var offset = headerSize
            for _ in 0..<ncmds {
                guard offset + MemoryLayout<load_command>.size <= bytes.count else {
                    return false
                }

                let cmd = baseAddress.advanced(by: offset).load(as: load_command.self)

                if cmd.cmd == LC_ENCRYPTION_INFO {
                    let encryptionCmd = baseAddress.advanced(by: offset).load(as: encryption_info_command.self)
                    return encryptionCmd.cryptid != 0
                } else if cmd.cmd == LC_ENCRYPTION_INFO_64 {
                    let encryptionCmd = baseAddress.advanced(by: offset).load(as: encryption_info_command_64.self)
                    return encryptionCmd.cryptid != 0
                }

                offset += Int(cmd.cmdsize)
            }

            // No encryption load command found
            return false
        }
    }

    /// Check if running a debug build
    private func checkIsDebugBuild() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Check if running on simulator
    private func checkIsSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #endif
    }
}
