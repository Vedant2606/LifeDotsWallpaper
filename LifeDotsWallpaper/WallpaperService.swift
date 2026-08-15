import AppKit
import Foundation

@MainActor
enum WallpaperService {
    static var wallpaperDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/LifeDotsWallpaper", isDirectory: true)
    }

    private static func uniqueWallpaperURL(for date: Date = Date(), screenIndex: Int = 0) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let suffix = NSScreen.screens.count > 1 ? "-screen\(screenIndex + 1)" : ""
        return wallpaperDirectory
            .appendingPathComponent("life-dots-\(formatter.string(from: date))\(suffix).png")
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
            let screens = NSScreen.screens
            var lastOutputURL: URL?

            for (index, screen) in screens.enumerated() {
                var renderer = WallpaperRenderer(settings: settings)
                // Render at this screen's native pixel resolution
                renderer.overrideCanvasSize = settings.resolvedCanvasSize(for: screen)

                let image = try renderer.render(for: now)
                let outputURL = uniqueWallpaperURL(for: now, screenIndex: index)

                try renderer.savePNG(image, to: outputURL)
                try NSWorkspace.shared.setDesktopImageURL(
                    outputURL,
                    for: screen,
                    options: [
                        NSWorkspace.DesktopImageOptionKey.imageScaling:
                            NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                        NSWorkspace.DesktopImageOptionKey.allowClipping: false
                    ]
                )
                lastOutputURL = outputURL
            }

            if let lastOutputURL {
                cleanupOldWallpapers(keeping: lastOutputURL, screenCount: screens.count)
            }
            settings.recordRefresh(status: "Succeeded", at: now)
        } catch {
            settings.recordRefresh(status: "Failed: \(error.localizedDescription)")
            throw error
        }
    }

    // Kept for external callers that need to re-apply an existing URL to all screens
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

    private static func cleanupOldWallpapers(keeping currentURL: URL, screenCount: Int = 1) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: wallpaperDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let pngFiles = files.filter {
            $0.pathExtension.lowercased() == "png" && $0 != currentURL
        }

        let sorted = pngFiles.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return leftDate > rightDate
        }

        // Keep current generation plus two previous generations (×screenCount files each).
        for oldURL in sorted.dropFirst(screenCount * 2) {
            try? fileManager.removeItem(at: oldURL)
        }
    }
}
