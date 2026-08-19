import AppKit
import Foundation

@MainActor
enum WallpaperService {
    static var wallpaperDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LifeDotsWallpaper", isDirectory: true)
    }

    // Fixed filename so macOS always updates the same thumbnail in System Settings
    // rather than accumulating a new thumbnail entry for every generation.
    private static var wallpaperURL: URL {
        wallpaperDirectory.appendingPathComponent("life-dots.png")
    }

    static func generateAndApply(settings: WallpaperSettings) throws {
        try generateAndApply(settings: settings, force: true)
    }

    static func generateAndApplyIfNeeded(settings: WallpaperSettings) throws {
        try generateAndApply(settings: settings, force: false)
    }

    private static func generateAndApply(settings: WallpaperSettings, force: Bool) throws {
        settings.save()

        let now = Date()
        if !force, let lastRefreshDate = settings.lastRefreshDate,
           Calendar.current.isDate(lastRefreshDate, inSameDayAs: now) {
            return
        }

        do {
            let renderer = WallpaperRenderer(settings: settings)
            let image = try renderer.render(for: now)

            try renderer.savePNG(image, to: wallpaperURL)
            try apply(url: wallpaperURL)
            settings.recordRefresh(status: "Succeeded", at: now)
        } catch {
            settings.recordRefresh(status: "Failed: \(error.localizedDescription)")
            throw error
        }
    }

    static func apply(url: URL) throws {
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(
                url,
                for: screen,
                options: [
                    NSWorkspace.DesktopImageOptionKey.imageScaling:
                        NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    NSWorkspace.DesktopImageOptionKey.allowClipping: false
                ]
            )
        }
    }
}
