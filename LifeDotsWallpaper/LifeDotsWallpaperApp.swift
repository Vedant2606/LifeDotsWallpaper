import AppKit
import SwiftUI

@main
@MainActor
enum LifeDotsWallpaperMain {
    static func main() {
        do {
            if CommandLine.arguments.contains("--generate-wallpaper") {
                try WallpaperService.generateAndApply(settings: WallpaperSettings.load())
                return
            }

            if CommandLine.arguments.contains("--generate-wallpaper-if-needed") {
                try WallpaperService.generateAndApplyIfNeeded(settings: WallpaperSettings.load())
                return
            }

            LifeDotsWallpaperApp.main()
        } catch {
            fputs("LifeDotsWallpaper: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@MainActor
struct LifeDotsWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = WallpaperSettings.load()

    var body: some Scene {
        WindowGroup("Life Dots", id: "main") {
            ContentView()
                .environmentObject(settings)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 790)
    }
}
