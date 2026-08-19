import AppKit
import Foundation

@MainActor
enum WallpaperService {
    static var wallpaperDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/LifeDotsWallpaper", isDirectory: true)
    }

    private static func uniqueWallpaperURL(for date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return wallpaperDirectory
            .appendingPathComponent("life-dots-\(formatter.string(from: date)).png")
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
            let outputURL = uniqueWallpaperURL(for: now)

            try renderer.savePNG(image, to: outputURL)
            try apply(url: outputURL)
            cleanupOldWallpapers(keeping: outputURL)
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

    private static func cleanupOldWallpapers(keeping currentURL: URL) {
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

        // Keep the current wallpaper plus the two most recent previous files.
        for oldURL in sorted.dropFirst(2) {
            try? fileManager.removeItem(at: oldURL)
        }
    }
}
