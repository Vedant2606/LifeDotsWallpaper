import Foundation

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
