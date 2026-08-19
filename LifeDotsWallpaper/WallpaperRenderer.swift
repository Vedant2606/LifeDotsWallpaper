import AppKit
import CoreImage
import Foundation

@MainActor
struct WallpaperRenderer {
    let settings: WallpaperSettings
    var todayPulseScale: CGFloat = 1.0

    private struct TimelineData {
        var calendar: Calendar
        var today: Date
        var start: Date
        var end: Date
        var title: String
        var footer: String
        var total: Int
        var elapsedIndex: Int
        var dayNumber: Int
        var daysLeft: Int
        var progress: Double
        var remainingRatio: Double
        var separatorIndices: Set<Int>
        var markers: [Int: [WallpaperSettings.DayMarker]]
    }

    private struct DotGeometry {
        var row: Int
        var column: Int
        var rect: NSRect
        var center: NSPoint
    }

    private struct ForegroundPalette {
        var primary: NSColor
        var secondary: NSColor
        var completedDot: NSColor
        var remainingDot: NSColor
        var accent: NSColor
        var progress: NSColor
        var divider: NSColor
        var glassFill: NSColor
        var glassStroke: NSColor
        var glassHighlight: NSColor
        var glassShadow: NSColor
    }

    func render(for date: Date = Date()) throws -> NSImage {
        let size = settings.resolvedCanvasSize()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw NSError(
                domain: "LifeDotsWallpaper",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create wallpaper bitmap."]
            )
        }

        bitmap.size = size
        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw NSError(
                domain: "LifeDotsWallpaper",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not create drawing context."]
            )
        }

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = graphicsContext
        defer { NSGraphicsContext.current = previousContext }

        let context = graphicsContext.cgContext
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)

        let canvasRect = NSRect(origin: .zero, size: size)
        let data = timelineData(for: date)
        let gridRect = gridRect(for: size)
        let panelRect = panelRect(for: size)
        let palette = foregroundPalette()

        drawBackground(in: canvasRect, context: context)
        if usesLiquidGlassCards {
            let extraX = size.width * 0.025
            let extraTop = size.height * 0.035
            let dotsCardRect = NSRect(
                x: gridRect.minX - extraX,
                y: gridRect.minY - 160,
                width: gridRect.width + extraX * 2,
                height: gridRect.height + extraTop + 160
            )
            drawLiquidGlassPanel(in: dotsCardRect, radius: size.height * 0.028, palette: palette)
        }

        drawDots(in: gridRect, data: data, palette: palette)
        if settings.layoutPreset != .minimal {
            drawLegend(below: gridRect, palette: palette)
            drawFooter(below: gridRect, canvasSize: size, data: data, palette: palette)
        }

        if settings.showDatePanel && settings.layoutPreset != .noPanel && settings.layoutPreset != .minimal {
            drawPanel(in: panelRect, data: data, date: date, palette: palette)
        }

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    private func gridRect(for size: CGSize) -> NSRect {
        switch settings.layoutPreset {
        case .wide:
            return NSRect(x: size.width * 0.18, y: size.height * 0.33, width: size.width * 0.56, height: size.height * 0.36)
        case .centered:
            return NSRect(x: size.width * 0.30, y: size.height * 0.23, width: size.width * 0.36, height: size.height * 0.56)
        case .minimal:
            return NSRect(x: size.width * 0.20, y: size.height * 0.39, width: size.width * 0.60, height: size.height * 0.22)
        case .widgetLeft:
            return NSRect(x: size.width * 0.34, y: size.height * 0.32, width: size.width * 0.43, height: size.height * 0.38)
        case .noPanel:
            return NSRect(x: size.width * 0.14, y: size.height * 0.31, width: size.width * 0.72, height: size.height * 0.40)
        }
    }

    private func panelRect(for size: CGSize) -> NSRect {
        NSRect(
            x: size.width * 0.80,
            y: size.height * 0.10,
            width: size.width * 0.15,
            height: size.height * 0.78
        )
    }

    private func columns(for data: TimelineData) -> Int {
        switch settings.timelineMode {
        case .year:
            switch settings.layoutPreset {
            case .centered: return 19
            case .widgetLeft: return 28
            case .noPanel: return 36
            case .minimal, .wide: return 31
            }
        case .month:
            return settings.layoutPreset == .centered ? 10 : 16
        case .weeks:
            return settings.layoutPreset == .centered ? 8 : 13
        case .goal:
            let wideColumns = max(12, min(34, Int(ceil(sqrt(Double(data.total)) * 2.2))))
            return settings.layoutPreset == .centered ? max(8, min(22, wideColumns - 6)) : wideColumns
        }
    }

    private func drawBackground(in rect: NSRect, context: CGContext) {
        switch settings.backgroundStyle {
        case .black:
            drawSolidBackground(in: rect, color: NSColor(hex: settings.backgroundHex) ?? NSColor(calibratedWhite: 0.025, alpha: 1), context: context)
        case .white:
            drawSolidBackground(in: rect, color: .white, context: context)
        case .image:
            guard let path = settings.backgroundImagePath,
                  drawImageBackground(path: path, in: rect, blurred: settings.imageOverlayStyle == .blurredBackground, context: context) else {
                drawSolidBackground(in: rect, color: NSColor(hex: settings.backgroundHex) ?? NSColor(calibratedWhite: 0.025, alpha: 1), context: context)
                return
            }
        }
    }

    private func drawSolidBackground(in rect: NSRect, color: NSColor, context: CGContext) {
        let base = color
        base.setFill()
        NSBezierPath(rect: rect).fill()

        guard settings.backgroundStyle != .white else { return }

        let center = CGPoint(x: rect.width * 0.72, y: rect.height * 0.50)
        let glow = NSColor.white.withAlphaComponent(0.032).cgColor
        let clear = NSColor.white.withAlphaComponent(0).cgColor
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [glow, clear] as CFArray,
            locations: [0, 1]
        ) {
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: rect.width * 0.39,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    private var usesLiquidGlassCards: Bool {
        settings.showGlassCard
    }

    private func foregroundPalette() -> ForegroundPalette {
        let isLight = backgroundIsLight()
        if isLight {
            let primary = NSColor(calibratedWhite: 0.08, alpha: 1)
            let secondary = primary.withAlphaComponent(0.58)
            return ForegroundPalette(
                primary: primary,
                secondary: secondary,
                completedDot: NSColor(calibratedWhite: 0.12, alpha: 0.94),
                remainingDot: NSColor(calibratedWhite: 0.62, alpha: 0.42),
                accent: NSColor(calibratedRed: 0.00, green: 0.48, blue: 0.19, alpha: 1),
                progress: NSColor(calibratedRed: 0.62, green: 0.41, blue: 0.00, alpha: 1),
                divider: primary.withAlphaComponent(0.14),
                glassFill: NSColor.white.withAlphaComponent(0.42),
                glassStroke: NSColor.white.withAlphaComponent(0.68),
                glassHighlight: NSColor.white.withAlphaComponent(0.82),
                glassShadow: NSColor.black.withAlphaComponent(0.16)
            )
        }

        let primary = NSColor.white
        return ForegroundPalette(
            primary: primary,
            secondary: primary.withAlphaComponent(0.58),
            completedDot: NSColor.white.withAlphaComponent(0.94),
            remainingDot: NSColor(calibratedWhite: 0.62, alpha: 0.44),
            accent: NSColor(hex: settings.currentDotHex) ?? .systemGreen,
            progress: daysLeftAccentColor(remainingRatio: 0.42),
            divider: primary.withAlphaComponent(0.14),
            glassFill: NSColor.white.withAlphaComponent(0.085),
            glassStroke: NSColor.white.withAlphaComponent(0.26),
            glassHighlight: NSColor.white.withAlphaComponent(0.58),
            glassShadow: NSColor.black.withAlphaComponent(0.34)
        )
    }

    private func backgroundIsLight() -> Bool {
        switch settings.backgroundStyle {
        case .black:
            guard let color = NSColor(hex: settings.backgroundHex),
                  let rgb = color.usingColorSpace(.deviceRGB) else { return false }
            let luminance = rgb.redComponent * 0.2126 + rgb.greenComponent * 0.7152 + rgb.blueComponent * 0.0722
            return luminance > 0.50
        case .white:
            return true
        case .image:
            guard let path = settings.backgroundImagePath,
                  let image = NSImage(contentsOfFile: path) else {
                return false
            }
            return averageLuminance(of: image) > 0.55
        }
    }

    private func averageLuminance(of image: NSImage) -> CGFloat {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }
        let width = 24
        let height = 24
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var total: CGFloat = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = CGFloat(pixels[index]) / 255
            let green = CGFloat(pixels[index + 1]) / 255
            let blue = CGFloat(pixels[index + 2]) / 255
            total += red * 0.2126 + green * 0.7152 + blue * 0.0722
        }
        return total / CGFloat(width * height)
    }

    private func drawImageBackground(path: String, in rect: NSRect, blurred: Bool, context: CGContext) -> Bool {
        let url = URL(fileURLWithPath: path)
        if blurred, let image = blurredImage(url: url, canvasSize: rect.size) {
            image.draw(in: rect)
        } else if let image = NSImage(contentsOf: url) {
            image.draw(in: rect, from: image.cropRectToFill(rect.size), operation: .sourceOver, fraction: 1)
        } else {
            return false
        }
        return true
    }

    private func blurredImage(url: URL, canvasSize: CGSize, radius: CGFloat = 28) -> NSImage? {
        guard let source = CIImage(contentsOf: url) else { return nil }

        let scale = max(canvasSize.width / source.extent.width, canvasSize.height / source.extent.height)
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        // cropRect has a non-zero origin when the image aspect ratio differs from canvas
        let cropRect = CGRect(
            x: (scaled.extent.width - canvasSize.width) / 2,
            y: (scaled.extent.height - canvasSize.height) / 2,
            width: canvasSize.width,
            height: canvasSize.height
        )
        let cropped = scaled.cropped(to: cropRect)

        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(cropped, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)

        // Re-crop at the same origin so we get the correct center region, not (0,0)
        let output = (filter.outputImage ?? cropped).cropped(to: cropRect)
        guard let cgImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: cropRect) else { return nil }
        return NSImage(cgImage: cgImage, size: canvasSize)
    }

    private func drawImageGlow(in rect: NSRect, context: CGContext) {
        let glow = NSColor.white.withAlphaComponent(0.08).cgColor
        let clear = NSColor.white.withAlphaComponent(0).cgColor
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [glow, clear] as CFArray,
            locations: [0, 1]
        ) else { return }

        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: rect.width * 0.72, y: rect.height * 0.58),
            startRadius: 0,
            endCenter: CGPoint(x: rect.width * 0.72, y: rect.height * 0.58),
            endRadius: rect.width * 0.44,
            options: [.drawsAfterEndLocation]
        )
    }

    private func drawLiquidGlassPanel(in rect: NSRect, radius: CGFloat, palette: ForegroundPalette) {
        let blurAmount = CGFloat(settings.glassOpacity)
        let panel = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        // Drop shadow — draw with shadow then restore before drawing content
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
        shadow.shadowBlurRadius = 44
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        palette.glassFill.setFill()
        panel.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Clip blurred image inside panel (frosted glass tint from background)
        if settings.backgroundStyle == .image,
           let path = settings.backgroundImagePath,
           let blurred = blurredImage(url: URL(fileURLWithPath: path), canvasSize: settings.resolvedCanvasSize(), radius: max(1, blurAmount * 30)) {
            NSGraphicsContext.saveGraphicsState()
            panel.addClip()
            blurred.draw(in: NSRect(origin: .zero, size: settings.resolvedCanvasSize()))
            NSGraphicsContext.restoreGraphicsState()
        }

        // Semi-transparent tint on top of blurred image
        palette.glassFill.withAlphaComponent(palette.glassFill.alphaComponent * blurAmount).setFill()
        panel.fill()
    }

    private func timelineData(for date: Date) -> TimelineData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: date)

        switch settings.timelineMode {
        case .year:
            let year = calendar.component(.year, from: today)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
            let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? today
            let total = max(calendar.dateComponents([.day], from: start, to: end).day ?? 365, 1)
            return timelineData(
                calendar: calendar,
                today: today,
                start: start,
                end: end,
                title: "YEAR",
                footer: "One year, \(total) opportunities.",
                total: total,
                separatorIndices: separatorIndices(calendar: calendar, start: start, end: end, total: total),
                markers: markerIndices(calendar: calendar, start: start, total: total)
            )
        case .month:
            let components = calendar.dateComponents([.year, .month], from: today)
            let start = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? today
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? today
            let total = max(calendar.dateComponents([.day], from: start, to: end).day ?? 30, 1)
            return timelineData(
                calendar: calendar,
                today: today,
                start: start,
                end: end,
                title: "MONTH",
                footer: "THIS MONTH. \(total) DAYS.",
                total: total,
                separatorIndices: separatorIndices(calendar: calendar, start: start, end: end, total: total),
                markers: markerIndices(calendar: calendar, start: start, total: total)
            )
        case .weeks:
            let year = calendar.component(.year, from: today)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
            let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? today
            let total = 52
            let elapsedDays = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
            let elapsedIndex = min(total - 1, elapsedDays / 7)
            let daysLeft = max(calendar.dateComponents([.day], from: today, to: end).day ?? 0, 0)
            let dayNumber = elapsedIndex + 1
            return TimelineData(
                calendar: calendar,
                today: today,
                start: start,
                end: end,
                title: "WEEKS",
                footer: "THIS YEAR. 52 WEEKS.",
                total: total,
                elapsedIndex: elapsedIndex,
                dayNumber: dayNumber,
                daysLeft: daysLeft,
                progress: Double(dayNumber) / Double(total),
                remainingRatio: Double(max(total - dayNumber, 0)) / Double(max(total - 1, 1)),
                separatorIndices: settings.separatorStyle == .month ? monthWeekSeparatorIndices(calendar: calendar, start: start) : [],
                markers: weekMarkerIndices(calendar: calendar, start: start)
            )
        case .goal:
            let start = calendar.startOfDay(for: min(settings.goalStartDate, settings.goalEndDate))
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(settings.goalStartDate, settings.goalEndDate))) ?? today
            let total = max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
            return timelineData(
                calendar: calendar,
                today: today,
                start: start,
                end: end,
                title: settings.goalTitle.isEmpty ? "GOAL" : settings.goalTitle.uppercased(),
                footer: "\(settings.goalTitle.isEmpty ? "GOAL" : settings.goalTitle.uppercased()). \(total) DAYS.",
                total: total,
                separatorIndices: separatorIndices(calendar: calendar, start: start, end: end, total: total),
                markers: markerIndices(calendar: calendar, start: start, total: total)
            )
        }
    }

    private func timelineData(
        calendar: Calendar,
        today: Date,
        start: Date,
        end: Date,
        title: String,
        footer: String,
        total: Int,
        separatorIndices: Set<Int>,
        markers: [Int: [WallpaperSettings.DayMarker]]
    ) -> TimelineData {
        let rawElapsed = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let elapsedIndex = min(max(rawElapsed, 0), total - 1)
        let dayNumber = min(max(rawElapsed + 1, 1), total)
        let daysLeft = max(calendar.dateComponents([.day], from: today, to: end).day ?? 0, 0)
        return TimelineData(
            calendar: calendar,
            today: today,
            start: start,
            end: end,
            title: title,
            footer: footer,
            total: total,
            elapsedIndex: elapsedIndex,
            dayNumber: dayNumber,
            daysLeft: daysLeft,
            progress: Double(dayNumber) / Double(total),
            remainingRatio: Double(max(total - dayNumber, 0)) / Double(max(total - 1, 1)),
            separatorIndices: separatorIndices,
            markers: markers
        )
    }

    private func separatorIndices(calendar: Calendar, start: Date, end: Date, total: Int) -> Set<Int> {
        switch settings.separatorStyle {
        case .none:
            return []
        case .week:
            return Set(stride(from: 7, to: total, by: 7))
        case .month:
            var indices = Set<Int>()
            var cursor = calendar.date(byAdding: .month, value: 1, to: start) ?? end
            while cursor < end {
                let index = calendar.dateComponents([.day], from: start, to: cursor).day ?? 0
                if index > 0 && index < total { indices.insert(index) }
                cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? end
            }
            return indices
        }
    }

    private func monthWeekSeparatorIndices(calendar: Calendar, start: Date) -> Set<Int> {
        var indices = Set<Int>()
        for month in 2...12 {
            guard let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: start), month: month, day: 1)) else { continue }
            let day = calendar.dateComponents([.day], from: start, to: date).day ?? 0
            let week = min(max(day / 7, 0), 51)
            indices.insert(week)
        }
        return indices
    }

    private func markerIndices(calendar: Calendar, start: Date, total: Int) -> [Int: [WallpaperSettings.DayMarker]] {
        Dictionary(grouping: settings.markers.compactMap { marker -> (Int, WallpaperSettings.DayMarker)? in
            let index = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: marker.date)).day ?? -1
            guard index >= 0 && index < total else { return nil }
            return (index, marker)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }
    }

    private func weekMarkerIndices(calendar: Calendar, start: Date) -> [Int: [WallpaperSettings.DayMarker]] {
        Dictionary(grouping: settings.markers.compactMap { marker -> (Int, WallpaperSettings.DayMarker)? in
            let day = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: marker.date)).day ?? -1
            guard day >= 0 else { return nil }
            let week = day / 7
            guard week >= 0 && week < 52 else { return nil }
            return (week, marker)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }
    }

    private func drawDots(in rect: NSRect, data: TimelineData, palette: ForegroundPalette) {
        let columns = columns(for: data)
        let rows = Int(ceil(Double(data.total) / Double(columns)))
        let unit = min(rect.width / CGFloat(columns), rect.height / CGFloat(rows))
        let diameter = unit * CGFloat(settings.dotSize)
        let gap = max(unit - diameter, diameter * 0.16)
        let usedHeight = CGFloat(rows) * diameter + CGFloat(max(rows - 1, 0)) * gap
        let originY = rect.midY - usedHeight / 2
        let ringWidth = max(4, diameter * 0.16)

        let passed = palette.completedDot
        let future = palette.remainingDot
        let current = palette.accent

        for index in 0..<data.total {
            let geometry = dotGeometry(index: index, total: data.total, columns: columns, rows: rows, rect: rect, diameter: diameter, gap: gap, originY: originY)

            let path = NSBezierPath(ovalIn: geometry.rect)
            if index < data.elapsedIndex {
                passed.setFill()
                path.fill()
            } else if index == data.elapsedIndex {
                switch settings.currentDayStyle {
                case .filled:
                    current.setFill()
                    path.fill()
                case .ring:
                    if settings.showFutureDots {
                        future.setFill()
                        path.fill()
                    }
                }
            } else if settings.showFutureDots {
                future.setFill()
                path.fill()
            }

            if let markers = data.markers[index], let marker = markers.first {
                let markerColor = NSColor(hex: marker.colorHex) ?? NSColor.systemYellow
                markerColor.setStroke()
                let markerPath = NSBezierPath(ovalIn: geometry.rect.insetBy(dx: -diameter * 0.16, dy: -diameter * 0.16))
                markerPath.lineWidth = max(3, diameter * 0.12)
                markerPath.stroke()
            }

            if index == data.elapsedIndex {
                let currentRect = geometry.rect.insetBy(
                    dx: -diameter * 0.20 * todayPulseScale,
                    dy: -diameter * 0.20 * todayPulseScale
                )
                current.setStroke()
                let currentPath = NSBezierPath(ovalIn: currentRect)
                currentPath.lineWidth = ringWidth
                currentPath.stroke()
            }
        }
    }

    private func dotGeometry(
        index: Int,
        total: Int,
        columns: Int,
        rows: Int,
        rect: NSRect,
        diameter: CGFloat,
        gap: CGFloat,
        originY: CGFloat
    ) -> DotGeometry {
        let row = index / columns
        let column = index % columns
        let dotsInRow = min(columns, total - (row * columns))
        let rowWidth = CGFloat(dotsInRow) * diameter + CGFloat(max(dotsInRow - 1, 0)) * gap
        let originX = rect.midX - rowWidth / 2
        let x = originX + CGFloat(column) * (diameter + gap)
        let y = originY + CGFloat(rows - row - 1) * (diameter + gap)
        let dotRect = NSRect(x: x, y: y, width: diameter, height: diameter)
        return DotGeometry(row: row, column: column, rect: dotRect, center: NSPoint(x: dotRect.midX, y: dotRect.midY))
    }

    private func drawLegend(below gridRect: NSRect, palette: ForegroundPalette) {
        let y = gridRect.minY - 56
        let centerX = gridRect.midX
        let itemGap = gridRect.width * 0.25
        drawLegendItem(centerX: centerX - itemGap, y: y, label: "COMPLETED", color: palette.completedDot, textColor: palette.secondary, ring: false)
        drawLegendItem(centerX: centerX, y: y, label: "TODAY", color: palette.accent, textColor: palette.secondary, ring: true)
        drawLegendItem(centerX: centerX + itemGap, y: y, label: "REMAINING", color: palette.remainingDot, textColor: palette.secondary, ring: false)
    }

    private func drawLegendItem(centerX: CGFloat, y: CGFloat, label: String, color: NSColor, textColor: NSColor, ring: Bool) {
        let marker = NSRect(x: centerX - 58, y: y - 7, width: 16, height: 16)
        let path = NSBezierPath(ovalIn: marker)
        if ring {
            color.setStroke()
            path.lineWidth = 3
            path.stroke()
        } else {
            color.setFill()
            path.fill()
        }
        drawText(label, at: NSPoint(x: centerX - 32, y: y - 7), size: 15, weight: .medium, color: textColor, kern: 1.1)
    }

    private func daysLeftAccentColor(remainingRatio: Double) -> NSColor {
        let clamped = min(max(remainingRatio, 0), 1)
        return NSColor(calibratedHue: CGFloat(0.33 * clamped), saturation: 0.68, brightness: 0.88, alpha: 1.0)
    }

    private func drawFooter(below gridRect: NSRect, canvasSize: CGSize, data: TimelineData, palette: ForegroundPalette) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: palette.secondary.withAlphaComponent(0.70),
            .kern: 1.4,
            .paragraphStyle: paragraph
        ]
        data.footer.draw(in: NSRect(x: 0, y: gridRect.minY - 132, width: canvasSize.width, height: 28), withAttributes: attrs)
    }

    private func drawPanel(in rect: NSRect, data: TimelineData, date: Date, palette: ForegroundPalette) {
        let rect = rect.offsetBy(dx: 0, dy: -rect.height * CGFloat(settings.panelVerticalOffset))
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let week = data.calendar.component(.weekOfYear, from: date)
        let accent = palette.accent
        let remainingAccent = palette.progress
        let primary = palette.primary
        let secondary = palette.secondary

        // Calculate total content height upfront (needed for card sizing and centering)
        let visibleSections = settings.panelSections.filter { shouldDrawPanelSection($0) }
        var innerHeight: CGFloat = 0
        for (i, section) in visibleSections.enumerated() {
            innerHeight += panelSectionHeight(section)
            if i < visibleSections.count - 1 { innerHeight += scaledPanelSize(30) }
        }
        innerHeight = min(innerHeight, rect.height - scaledPanelSize(32))

        var contentTopY = rect.maxY
        var contentBottomY = rect.minY

        if usesLiquidGlassCards {
            // Equal padding on both sides so card is centered; 32pt gives YEAR label comfortable room
            let padding = scaledPanelSize(32)
            let cardHeight = innerHeight + padding * 2
            // Center card vertically on rect.midY (which already has panelVerticalOffset applied)
            let cardRect = NSRect(
                x: rect.minX - scaledPanelSize(28),
                y: rect.midY - cardHeight / 2,
                width: rect.width + scaledPanelSize(56),
                height: cardHeight
            )
            drawLiquidGlassPanel(in: cardRect, radius: scaledPanelSize(28), palette: palette)
            contentTopY = cardRect.maxY - padding
            contentBottomY = cardRect.minY + padding
        }

        var y = contentTopY
        for section in settings.panelSections where shouldDrawPanelSection(section) {
            if y < contentBottomY + scaledPanelSize(36) { break }
            switch section {
            case .date:
                drawText(data.title, at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(16), weight: .semibold, color: accent, kern: 2.3)
                y -= scaledPanelSize(60)
                drawText(dayFormatter.string(from: date), at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(36), weight: .semibold, color: primary)
                y -= scaledPanelSize(46)
                drawText(dateFormatter.string(from: date), at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(23), weight: .regular, color: secondary)
                y -= scaledPanelSize(62)
            case .daysLeft:
                drawMetricLabel(settings.timelineMode == .goal ? "GOAL DAYS LEFT" : "DAYS LEFT", at: NSPoint(x: rect.minX, y: y), color: secondary)
                y -= scaledPanelSize(43)
                drawText("\(data.daysLeft)", at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(34), weight: .semibold, color: remainingAccent)
                y -= scaledPanelSize(62)
            case .progress:
                drawMetricLabel(settings.timelineMode == .goal ? "GOAL LEFT" : "YEAR LEFT", at: NSPoint(x: rect.minX, y: y), color: secondary)
                y -= scaledPanelSize(45)
                drawText("\(Int((data.remainingRatio * 100).rounded()))%", at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(36), weight: .semibold, color: remainingAccent)
                y -= scaledPanelSize(38)
                drawProgressBar(in: NSRect(x: rect.minX, y: y, width: rect.width, height: scaledPanelSize(8)), progress: data.remainingRatio, accent: remainingAccent)
                y -= scaledPanelSize(50)
            case .quote:
                let daily = settings.useDailyQuoteRotation
                    ? QuoteLibrary.quote(for: date)
                    : DailyQuote(text: settings.quote, credit: settings.customQuoteCredit)
                let quoteHeight = scaledPanelSize(165)
                drawQuote(daily, in: NSRect(x: rect.minX, y: y - quoteHeight, width: rect.width, height: quoteHeight), accent: accent, palette: palette)
                y -= quoteHeight + scaledPanelSize(40)
            case .week:
                drawMetricLabel(settings.timelineMode == .weeks ? "WEEK BLOCK" : "WEEK", at: NSPoint(x: rect.minX, y: y), color: secondary)
                y -= scaledPanelSize(38)
                drawText(settings.timelineMode == .weeks ? "Week \(data.dayNumber)" : "Week \(week)", at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(28), weight: .medium, color: primary)
                y -= scaledPanelSize(54)
            case .age:
                drawMetricLabel("AGE", at: NSPoint(x: rect.minX, y: y), color: secondary)
                y -= scaledPanelSize(34)
                drawText("\(age(on: data.today)) years", at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(24), weight: .medium, color: primary)
                y -= scaledPanelSize(54)
            case .birthday:
                drawMetricLabel("NEXT BIRTHDAY", at: NSPoint(x: rect.minX, y: y), color: secondary)
                y -= scaledPanelSize(32)
                let days = daysUntilNextBirthday(from: data.today)
                drawText(days == 0 ? "Today" : "\(days) days", at: NSPoint(x: rect.minX, y: y), size: scaledPanelSize(23), weight: .medium, color: primary)
                y -= scaledPanelSize(54)
            }
            if y > contentBottomY + scaledPanelSize(18) {
                drawDivider(y: y, rect: rect, palette: palette)
                y -= usesLiquidGlassCards ? scaledPanelSize(30) : scaledPanelSize(38)
            }
        }
    }

    private func drawQuote(_ quote: DailyQuote, in rect: NSRect, accent: NSColor, palette: ForegroundPalette) {
        drawText("\u{201C}", at: NSPoint(x: rect.minX, y: rect.maxY - scaledPanelSize(35)), size: scaledPanelSize(36), weight: .bold, color: accent)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineSpacing = scaledPanelSize(5)
        let quoteAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: scaledPanelSize(22), weight: .semibold),
            .foregroundColor: palette.primary.withAlphaComponent(0.94),
            .paragraphStyle: paragraph
        ]
        quote.text.draw(
            with: NSRect(x: rect.minX, y: rect.minY + scaledPanelSize(34), width: rect.width, height: rect.height - scaledPanelSize(60)),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: quoteAttributes
        )

        if settings.showQuoteCredit {
            let creditAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: scaledPanelSize(15), weight: .regular),
                .foregroundColor: palette.secondary.withAlphaComponent(0.82)
            ]
            ("- " + quote.credit).draw(
                with: NSRect(x: rect.minX, y: rect.minY + 4, width: rect.width, height: scaledPanelSize(28)),
                options: [.usesLineFragmentOrigin],
                attributes: creditAttributes
            )
        }
    }

    private func age(on date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.year], from: settings.birthDate, to: date).year ?? 0)
    }

    private func daysUntilNextBirthday(from today: Date) -> Int {
        let calendar = Calendar.current
        let birth = calendar.dateComponents([.month, .day], from: settings.birthDate)
        let currentYear = calendar.component(.year, from: today)
        var components = DateComponents(year: currentYear, month: birth.month, day: birth.day)
        var next = calendar.date(from: components) ?? today
        if calendar.startOfDay(for: next) < calendar.startOfDay(for: today) {
            components.year = currentYear + 1
            next = calendar.date(from: components) ?? today
        }
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: next)).day ?? 0)
    }

    private func shouldDrawPanelSection(_ section: WallpaperSettings.PanelSection) -> Bool {
        switch section {
        case .date, .daysLeft, .progress, .week:
            return true
        case .quote:
            return settings.showQuote
        case .age:
            return settings.showAge
        case .birthday:
            return settings.showBirthdayCountdown
        }
    }

    private func panelSectionHeight(_ section: WallpaperSettings.PanelSection) -> CGFloat {
        switch section {
        case .date:
            return scaledPanelSize(168)   // 60 + 46 + 62
        case .daysLeft:
            return scaledPanelSize(105)   // 43 + 62
        case .progress:
            return scaledPanelSize(133)   // 45 + 38 + 50
        case .quote:
            return scaledPanelSize(205)   // 165 + 40
        case .week:
            return scaledPanelSize(92)    // 38 + 54
        case .age:
            return scaledPanelSize(88)    // 34 + 54
        case .birthday:
            return scaledPanelSize(86)    // 32 + 54
        }
    }

    private func scaledPanelSize(_ size: CGFloat) -> CGFloat {
        size * CGFloat(settings.panelTextScale)
    }

    private func drawProgressBar(in rect: NSRect, progress: Double, accent: NSColor) {
        let background = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.white.withAlphaComponent(0.10).setFill()
        background.fill()

        let clamped = CGFloat(min(max(progress, 0), 1))
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width * clamped, height: rect.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        accent.setFill()
        fill.fill()
    }

    private func drawDivider(y: CGFloat, rect: NSRect, palette: ForegroundPalette) {
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: rect.minX, y: y))
        divider.line(to: NSPoint(x: rect.maxX, y: y))
        divider.lineWidth = 1
        palette.divider.setStroke()
        divider.stroke()
    }

    private func drawMetricLabel(_ text: String, at point: NSPoint, color: NSColor) {
        drawText(text, at: point, size: scaledPanelSize(15), weight: .medium, color: color, kern: 1.3)
    }

    private func drawText(_ text: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat = 0) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .kern: kern
        ]
        text.draw(at: point, withAttributes: attributes)
    }

    func savePNG(_ image: NSImage, to url: URL) throws {
        let bitmap = image.representations.compactMap { $0 as? NSBitmapImageRep }.first
        guard let data = bitmap?.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: "LifeDotsWallpaper",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not encode wallpaper as PNG."]
            )
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

private extension NSImage {
    func cropRectToFill(_ targetSize: CGSize) -> NSRect {
        let sourceSize = size
        guard sourceSize.width > 0, sourceSize.height > 0, targetSize.width > 0, targetSize.height > 0 else {
            return NSRect(origin: .zero, size: sourceSize)
        }

        let sourceRatio = sourceSize.width / sourceSize.height
        let targetRatio = targetSize.width / targetSize.height
        if sourceRatio > targetRatio {
            let width = sourceSize.height * targetRatio
            return NSRect(x: (sourceSize.width - width) / 2, y: 0, width: width, height: sourceSize.height)
        } else {
            let height = sourceSize.width / targetRatio
            return NSRect(x: 0, y: (sourceSize.height - height) / 2, width: sourceSize.width, height: height)
        }
    }
}
