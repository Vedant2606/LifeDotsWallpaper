import Darwin
import Foundation

@MainActor
enum LaunchAgentService {
    static let label = "com.vedant.lifedotswallpaper.daily"
    private static let legacyWakeMarkerKey = "LifeDotsWallpaper.dailyWakeRepeatInstalled"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static var isRunningFromApplications: Bool {
        let bundlePath = Bundle.main.bundleURL.standardizedFileURL.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL.path

        return bundlePath.hasPrefix("/Applications/") || bundlePath.hasPrefix(userApplications + "/")
    }

    static func install() throws {
        guard isRunningFromApplications else {
            throw NSError(
                domain: label,
                code: 10,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Move LifeDotsWallpaper.app into the Applications folder, open that installed copy, and then install the 6:00 AM automation."
                ]
            )
        }

        guard let executableURL = Bundle.main.executableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw NSError(
                domain: label,
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "The installed app executable could not be found."]
            )
        }

        try? bootout()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let catchUpSchedule = (6...23).map { hour in
            ["Hour": hour, "Minute": 0]
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executableURL.path, "--generate-wallpaper-if-needed"],
            "StartCalendarInterval": catchUpSchedule,
            "RunAtLoad": true,
            "ProcessType": "Background",
            "LimitLoadToSessionType": "Aqua",
            "StandardOutPath": home.appendingPathComponent("Library/Logs/LifeDotsWallpaper.log").path,
            "StandardErrorPath": home.appendingPathComponent("Library/Logs/LifeDotsWallpaper-error.log").path
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: plistURL, options: .atomic)

        let domain = "gui/\(getuid())"
        let status = try runLaunchctl(["bootstrap", domain, plistURL.path])
        guard status == 0 else {
            throw NSError(
                domain: label,
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "macOS could not register the daily automation. Remove it and try installing it again."
                ]
            )
        }

        try removeLegacyDailyWakeIfInstalled()
    }

    static func uninstall() throws {
        try? bootout()
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
        try removeLegacyDailyWakeIfInstalled()
    }

    static func runBackgroundGenerationNow() throws {
        guard let executableURL = Bundle.main.executableURL,
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw NSError(
                domain: label,
                code: 13,
                userInfo: [NSLocalizedDescriptionKey: "The app executable could not be found."]
            )
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--generate-wallpaper"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: label,
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "The background wallpaper refresh failed."]
            )
        }
    }

    private static func removeLegacyDailyWakeIfInstalled() throws {
        guard UserDefaults.standard.bool(forKey: legacyWakeMarkerKey) else { return }
        try runPrivilegedPMSet(arguments: ["repeat", "cancel"])
        UserDefaults.standard.removeObject(forKey: legacyWakeMarkerKey)
    }

    private static func bootout() throws {
        let service = "gui/\(getuid())/\(label)"
        _ = try runLaunchctl(["bootout", service])
    }

    private static func runLaunchctl(_ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static func runPrivilegedPMSet(arguments: [String]) throws {
        let command = (["/usr/bin/pmset"] + arguments)
            .map(shellQuoted)
            .joined(separator: " ")
        let script = "do shell script \"\(command.replacingOccurrences(of: "\\\"", with: "\\\\\\\""))\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: label,
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "The automation was updated, but macOS did not allow the old daily wake schedule to be removed. You can remove it later with pmset repeat cancel."
                ]
            )
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
