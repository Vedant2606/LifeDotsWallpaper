import AppKit
import Foundation
import SwiftUI

@MainActor
final class WallpaperSettings: ObservableObject {
    enum CurrentDayStyle: String, CaseIterable, Codable, Identifiable {
        case ring = "Ring"
        case filled = "Filled"
        var id: String { rawValue }
    }

    enum CanvasPreset: String, CaseIterable, Codable, Identifiable {
        case automatic = "Automatic (Current Display)"
        case macbookAir13 = "MacBook Air 13-inch M4 (2940 x 1912)"
        case macbook14 = "MacBook Pro 14-inch (3024 x 1964)"
        case macbook16 = "MacBook Pro 16-inch (3456 x 2234)"
        case fiveK = "5K 16:10 (5120 x 3200)"

        var id: String { rawValue }

        var size: CGSize? {
            switch self {
            case .automatic: return nil
            case .macbookAir13: return CGSize(width: 2940, height: 1912)
            case .macbook14: return CGSize(width: 3024, height: 1964)
            case .macbook16: return CGSize(width: 3456, height: 2234)
            case .fiveK: return CGSize(width: 5120, height: 3200)
            }
        }
    }

    enum LayoutPreset: String, CaseIterable, Codable, Identifiable {
        case wide = "Wide"
        case centered = "Centered"
        case minimal = "Minimal"
        case widgetLeft = "Widget Left Space"
        case noPanel = "No Panel"

        var id: String { rawValue }
    }

    enum SeparatorStyle: String, CaseIterable, Codable, Identifiable {
        case none = "None"
        case month = "Month"
        case week = "Week"

        var id: String { rawValue }
    }

    enum TimelineMode: String, CaseIterable, Codable, Identifiable {
        case year = "Year"
        case month = "Month"
        case weeks = "Weeks"
        case goal = "Goal"

        var id: String { rawValue }
    }

    enum BackgroundStyle: String, CaseIterable, Codable, Identifiable {
        case black = "Black"
        case white = "White"
        case image = "Image"

        var id: String { rawValue }
    }

    enum ImageOverlayStyle: String, CaseIterable, Codable, Identifiable {
        case liquidGlass = "Liquid Glass"
        case blurredBackground = "Blur Background"

        var id: String { rawValue }
    }

    enum PanelSection: String, CaseIterable, Codable, Identifiable {
        case date = "Date"
        case daysLeft = "Days Left"
        case progress = "Progress"
        case quote = "Quote"
        case week = "Week"
        case age = "Age"
        case birthday = "Birthday"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .date: return "calendar"
            case .daysLeft: return "number"
            case .progress: return "chart.bar.fill"
            case .quote: return "quote.bubble"
            case .week: return "calendar.badge.clock"
            case .age: return "person.crop.circle"
            case .birthday: return "gift"
            }
        }
    }

    struct DayMarker: Codable, Identifiable, Equatable {
        var id: UUID
        var date: Date
        var title: String
        var colorHex: String

        init(id: UUID = UUID(), date: Date = Date(), title: String = "Milestone", colorHex: String = "FFD166") {
            self.id = id
            self.date = date
            self.title = title
            self.colorHex = colorHex
        }
    }

    private struct StoredSettings: Codable {
        var birthDate: Date
        var backgroundHex: String
        var passedDotHex: String
        var futureDotHex: String
        var currentDotHex: String
        var currentDayStyle: CurrentDayStyle
        var dotSize: Double
        var showFutureDots: Bool
        var showQuote: Bool
        var quote: String
        var customQuoteCredit: String
        var useDailyQuoteRotation: Bool
        var showQuoteCredit: Bool
        var showDatePanel: Bool
        var showAge: Bool
        var showBirthdayCountdown: Bool
        var canvasPreset: CanvasPreset
        var layoutPreset: LayoutPreset?
        var separatorStyle: SeparatorStyle?
        var timelineMode: TimelineMode?
        var backgroundStyle: BackgroundStyle?
        var imageOverlayStyle: ImageOverlayStyle?
        var backgroundImagePath: String?
        var goalTitle: String?
        var goalStartDate: Date?
        var goalEndDate: Date?
        var markers: [DayMarker]?
        var panelVerticalOffset: Double?
        var panelTextScale: Double?
        var panelSections: [PanelSection]?
        var lastRefreshDate: Date?
        var lastRefreshStatus: String?
        var showMenuBarIcon: Bool?
        var showGlassCard: Bool?
        var glassOpacity: Double?
    }

    @Published var birthDate: Date
    @Published var backgroundHex: String
    @Published var passedDotHex: String
    @Published var futureDotHex: String
    @Published var currentDotHex: String
    @Published var currentDayStyle: CurrentDayStyle
    @Published var dotSize: Double
    @Published var showFutureDots: Bool
    @Published var showQuote: Bool
    @Published var quote: String
    @Published var customQuoteCredit: String
    @Published var useDailyQuoteRotation: Bool
    @Published var showQuoteCredit: Bool
    @Published var showDatePanel: Bool
    @Published var showAge: Bool
    @Published var showBirthdayCountdown: Bool
    @Published var canvasPreset: CanvasPreset
    @Published var layoutPreset: LayoutPreset
    @Published var separatorStyle: SeparatorStyle
    @Published var timelineMode: TimelineMode
    @Published var backgroundStyle: BackgroundStyle
    @Published var imageOverlayStyle: ImageOverlayStyle
    @Published var backgroundImagePath: String?
    @Published var goalTitle: String
    @Published var goalStartDate: Date
    @Published var goalEndDate: Date
    @Published var markers: [DayMarker]
    @Published var panelVerticalOffset: Double
    @Published var panelTextScale: Double
    @Published var panelSections: [PanelSection]
    @Published var lastRefreshDate: Date?
    @Published var lastRefreshStatus: String
    @Published var showGlassCard: Bool
    @Published var glassOpacity: Double

    init(
        birthDate: Date = Calendar.current.date(from: DateComponents(year: 1997, month: 8, day: 25)) ?? Date(),
        backgroundHex: String = "08090B",
        passedDotHex: String = "FFFFFF",
        futureDotHex: String = "3B3D42",
        currentDotHex: String = "63D68A",
        currentDayStyle: CurrentDayStyle = .ring,
        dotSize: Double = 0.88,
        showFutureDots: Bool = true,
        showQuote: Bool = true,
        quote: String = "Make this year the one you are proud of.",
        customQuoteCredit: String = "Your daily note",
        useDailyQuoteRotation: Bool = true,
        showQuoteCredit: Bool = true,
        showDatePanel: Bool = true,
        showAge: Bool = true,
        showBirthdayCountdown: Bool = true,
        canvasPreset: CanvasPreset = .automatic,
        layoutPreset: LayoutPreset = .wide,
        separatorStyle: SeparatorStyle = .month,
        timelineMode: TimelineMode = .year,
        backgroundStyle: BackgroundStyle = .black,
        imageOverlayStyle: ImageOverlayStyle = .liquidGlass,
        backgroundImagePath: String? = nil,
        goalTitle: String = "Launch",
        goalStartDate: Date = Date(),
        goalEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date(),
        markers: [DayMarker] = [],
        panelVerticalOffset: Double = 0,
        panelTextScale: Double = 1,
        panelSections: [PanelSection] = PanelSection.allCases,
        lastRefreshDate: Date? = nil,
        lastRefreshStatus: String = "Never refreshed",
        showGlassCard: Bool = false,
        glassOpacity: Double = 0.7
    ) {
        self.birthDate = birthDate
        self.backgroundHex = backgroundHex
        self.passedDotHex = passedDotHex
        self.futureDotHex = futureDotHex
        self.currentDotHex = currentDotHex
        self.currentDayStyle = currentDayStyle
        self.dotSize = dotSize
        self.showFutureDots = showFutureDots
        self.showQuote = showQuote
        self.quote = quote
        self.customQuoteCredit = customQuoteCredit
        self.useDailyQuoteRotation = useDailyQuoteRotation
        self.showQuoteCredit = showQuoteCredit
        self.showDatePanel = showDatePanel
        self.showAge = showAge
        self.showBirthdayCountdown = showBirthdayCountdown
        self.canvasPreset = canvasPreset
        self.layoutPreset = layoutPreset
        self.separatorStyle = separatorStyle
        self.timelineMode = timelineMode
        self.backgroundStyle = backgroundStyle
        self.imageOverlayStyle = imageOverlayStyle
        self.backgroundImagePath = backgroundImagePath
        self.goalTitle = goalTitle
        self.goalStartDate = goalStartDate
        self.goalEndDate = goalEndDate
        self.markers = markers
        self.panelVerticalOffset = panelVerticalOffset
        self.panelTextScale = panelTextScale
        self.panelSections = panelSections
        self.lastRefreshDate = lastRefreshDate
        self.lastRefreshStatus = lastRefreshStatus
        self.showGlassCard = showGlassCard
        self.glassOpacity = glassOpacity
    }

    private convenience init(stored: StoredSettings) {
        self.init(
            birthDate: stored.birthDate,
            backgroundHex: stored.backgroundHex,
            passedDotHex: stored.passedDotHex,
            futureDotHex: stored.futureDotHex,
            currentDotHex: stored.currentDotHex,
            currentDayStyle: stored.currentDayStyle,
            dotSize: stored.dotSize,
            showFutureDots: stored.showFutureDots,
            showQuote: stored.showQuote,
            quote: stored.quote,
            customQuoteCredit: stored.customQuoteCredit,
            useDailyQuoteRotation: stored.useDailyQuoteRotation,
            showQuoteCredit: stored.showQuoteCredit,
            showDatePanel: stored.showDatePanel,
            showAge: stored.showAge,
            showBirthdayCountdown: stored.showBirthdayCountdown,
            canvasPreset: stored.canvasPreset,
            layoutPreset: stored.layoutPreset ?? .wide,
            separatorStyle: stored.separatorStyle ?? .month,
            timelineMode: stored.timelineMode ?? .year,
            backgroundStyle: stored.backgroundStyle ?? .black,
            imageOverlayStyle: stored.imageOverlayStyle ?? .liquidGlass,
            backgroundImagePath: stored.backgroundImagePath,
            goalTitle: stored.goalTitle ?? "Launch",
            goalStartDate: stored.goalStartDate ?? Date(),
            goalEndDate: stored.goalEndDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date(),
            markers: stored.markers ?? [],
            panelVerticalOffset: stored.panelVerticalOffset ?? 0,
            panelTextScale: stored.panelTextScale ?? 1,
            panelSections: Self.validPanelSections(stored.panelSections),
            lastRefreshDate: stored.lastRefreshDate,
            lastRefreshStatus: stored.lastRefreshStatus ?? "Never refreshed",
            showGlassCard: stored.showGlassCard ?? false,
            glassOpacity: stored.glassOpacity ?? 0.7
        )
    }

    static func load() -> WallpaperSettings {
        guard let data = UserDefaults.standard.data(forKey: "LifeDotsWallpaper.nativeSettings"),
              let stored = try? JSONDecoder().decode(StoredSettings.self, from: data)
        else { return WallpaperSettings() }
        return WallpaperSettings(stored: stored)
    }

    func save() {
        let stored = StoredSettings(
            birthDate: birthDate,
            backgroundHex: backgroundHex,
            passedDotHex: passedDotHex,
            futureDotHex: futureDotHex,
            currentDotHex: currentDotHex,
            currentDayStyle: currentDayStyle,
            dotSize: dotSize,
            showFutureDots: showFutureDots,
            showQuote: showQuote,
            quote: quote,
            customQuoteCredit: customQuoteCredit,
            useDailyQuoteRotation: useDailyQuoteRotation,
            showQuoteCredit: showQuoteCredit,
            showDatePanel: showDatePanel,
            showAge: showAge,
            showBirthdayCountdown: showBirthdayCountdown,
            canvasPreset: canvasPreset,
            layoutPreset: layoutPreset,
            separatorStyle: separatorStyle,
            timelineMode: timelineMode,
            backgroundStyle: backgroundStyle,
            imageOverlayStyle: imageOverlayStyle,
            backgroundImagePath: backgroundImagePath,
            goalTitle: goalTitle,
            goalStartDate: goalStartDate,
            goalEndDate: goalEndDate,
            markers: markers,
            panelVerticalOffset: panelVerticalOffset,
            panelTextScale: panelTextScale,
            panelSections: panelSections,
            lastRefreshDate: lastRefreshDate,
            lastRefreshStatus: lastRefreshStatus,
            showGlassCard: showGlassCard,
            glassOpacity: glassOpacity
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: "LifeDotsWallpaper.nativeSettings")
    }

    private static func validPanelSections(_ stored: [PanelSection]?) -> [PanelSection] {
        var result = [PanelSection]()
        for section in stored ?? PanelSection.allCases where !result.contains(section) {
            result.append(section)
        }
        for section in PanelSection.allCases where !result.contains(section) {
            result.append(section)
        }
        return result
    }

    func recordRefresh(status: String, at date: Date = Date()) {
        lastRefreshDate = date
        lastRefreshStatus = status
        save()
    }

    func resolvedCanvasSize() -> CGSize {
        if let preset = canvasPreset.size { return preset }
        let displayID = CGMainDisplayID()
        let displayMode = CGDisplayCopyDisplayMode(displayID)
        let pixelWidth = displayMode?.pixelWidth ?? CGDisplayPixelsWide(displayID)
        let pixelHeight = displayMode?.pixelHeight ?? CGDisplayPixelsHigh(displayID)
        if pixelWidth > 0, pixelHeight > 0 {
            return CGSize(width: pixelWidth, height: pixelHeight)
        }
        return CGSize(width: 2940, height: 1912)
    }
}
