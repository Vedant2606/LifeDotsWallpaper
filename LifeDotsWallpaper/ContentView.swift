import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Frosted card style

private struct CardOpacityKey: EnvironmentKey {
    static let defaultValue: Double = 0.8
}

extension EnvironmentValues {
    fileprivate var cardOpacity: Double {
        get { self[CardOpacityKey.self] }
        set { self[CardOpacityKey.self] = newValue }
    }
}

private struct FrostedCardStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        FrostedCardBody(configuration: configuration)
    }

    private struct FrostedCardBody: View {
        let configuration: GroupBoxStyleConfiguration
        @Environment(\.cardOpacity) private var opacity

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                configuration.label
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                configuration.content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(opacity * 0.16))
            )
        }
    }
}

// MARK: - Content view

@MainActor
struct ContentView: View {
    @EnvironmentObject private var settings: WallpaperSettings
    @State private var status = "Ready"
    @State private var automationInstalled = LaunchAgentService.isInstalled
    @State private var showingImageImporter = false
    @State private var selectedTab = 0
    @AppStorage("cardOpacity") private var cardOpacity: Double = 0.8

    private var currentAge: Int {
        max(0, Calendar.current.dateComponents([.year], from: settings.birthDate, to: Date()).year ?? 0)
    }

    private var lastRefreshText: String {
        guard let date = settings.lastRefreshDate else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var panelVerticalOffsetText: String {
        let percent = Int(abs(settings.panelVerticalOffset) * 100)
        if percent == 0 { return "Centered" }
        return settings.panelVerticalOffset > 0 ? "\(percent)% lower" : "\(percent)% higher"
    }

    private let colorSwatches: [(hex: String, label: String)] = [
        (hex: "08090B", label: "Near Black"),
        (hex: "000000", label: "Pure Black"),
        (hex: "1C1C1E", label: "Charcoal"),
        (hex: "0D1B2A", label: "Dark Navy"),
        (hex: "1A1035", label: "Deep Purple"),
        (hex: "2C1810", label: "Espresso"),
        (hex: "1A3A2A", label: "Forest"),
        (hex: "2A0A0A", label: "Wine"),
        (hex: "FFFFFF", label: "White"),
        (hex: "F5F0E8", label: "Cream"),
        (hex: "E5E5EA", label: "Silver"),
        (hex: "D4C5A9", label: "Sand"),
        (hex: "1E3A5F", label: "Ocean Blue"),
        (hex: "3B2D6E", label: "Violet"),
        (hex: "4A3728", label: "Walnut"),
        (hex: "3B3D42", label: "Slate"),
    ]

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text("Life Dots")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("A private progress wallpaper for your Mac.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

                // Tab bar
                HStack(spacing: 2) {
                    tabButton("Wallpaper", icon: "circle.grid.3x3.fill", tag: 0)
                    tabButton("Panel", icon: "sidebar.right", tag: 1)
                }
                .padding(5)
                .background(Color(white: 0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                Divider()

                // Tab content
                Group {
                    if selectedTab == 0 {
                        wallpaperTab
                    } else {
                        panelTab
                    }
                }

                Divider()

                // Action buttons — always visible
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button("Generate & Set Wallpaper") { generate() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        Button("Test Automation") { testAutomation() }
                            .controlSize(.large)
                    }
                    Button(automationInstalled ? "Remove Daily Automation" : "Install Daily Automation") {
                        toggleAutomation()
                    }
                    .controlSize(.large)

                    if !LaunchAgentService.isRunningFromApplications {
                        Label(
                            "Move LifeDotsWallpaper.app to Applications before installing automation.",
                            systemImage: "info.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .frame(minWidth: 400, idealWidth: 440, maxWidth: 520)
            .background(Color(white: 0.09))
            .environment(\.colorScheme, .dark)
            .environment(\.cardOpacity, cardOpacity)
            .groupBoxStyle(FrostedCardStyle())

            // Preview pane
            VStack(spacing: 18) {
                WallpaperPreview()
                HStack {
                    Text("Live preview").font(.headline)
                    Spacer()
                    Text("\(settings.layoutPreset.rawValue) · \(settings.timelineMode.rawValue) · \(settings.separatorStyle.rawValue) separators")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(34)
            .frame(minWidth: 620)
            .background(.ultraThinMaterial)
        }
        .onReceive(settings.objectWillChange.debounce(for: .milliseconds(350), scheduler: RunLoop.main)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { settings.save() }
        }
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            importBackgroundImage(result)
        }
    }

    // MARK: - Tab bar button

    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tag }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: selectedTab == tag ? .semibold : .regular))
                .foregroundStyle(selectedTab == tag ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background {
                    if selectedTab == tag {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.09))
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: selectedTab)
    }

    // MARK: - Tab: Wallpaper

    private var wallpaperTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Wallpaper background") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Mode", selection: Binding(
                            get: { settings.backgroundStyle == .image ? 1 : 0 },
                            set: { settings.backgroundStyle = $0 == 1 ? .image : .black }
                        )) {
                            Text("Color").tag(0)
                            Text("Image").tag(1)
                        }
                        .pickerStyle(.segmented)

                        if settings.backgroundStyle != .image {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8),
                                spacing: 6
                            ) {
                                ForEach(colorSwatches, id: \.hex) { swatch in
                                    let isSelected = settings.backgroundHex.uppercased() == swatch.hex.uppercased()
                                    Button {
                                        settings.backgroundHex = swatch.hex
                                        settings.backgroundStyle = .black
                                    } label: {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(Color(nsColor: NSColor(hex: swatch.hex) ?? .black))
                                            .frame(height: 34)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 0.5)
                                            }
                                            .overlay {
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .shadow(color: .black.opacity(0.5), radius: 1)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                    .help(swatch.label)
                                }
                            }
                            ColorHexField(title: "Custom hex", hex: $settings.backgroundHex)
                            Toggle("Glass card around dots", isOn: $settings.showGlassCard)
                            if settings.showGlassCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Glass blur")
                                        Spacer()
                                        Text("\(Int(settings.glassOpacity * 100))%").foregroundStyle(.secondary)
                                    }
                                    Slider(value: $settings.glassOpacity, in: 0.0...1.0)
                                }
                            }
                        } else {
                            HStack {
                                Button { showingImageImporter = true } label: {
                                    Label("Choose Image", systemImage: "photo")
                                }
                                if let path = settings.backgroundImagePath {
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                } else {
                                    Text("No image selected").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Toggle("Blur image", isOn: Binding(
                                get: { settings.imageOverlayStyle == .blurredBackground },
                                set: { settings.imageOverlayStyle = $0 ? .blurredBackground : .liquidGlass }
                            ))
                            Toggle("Glass card around dots", isOn: $settings.showGlassCard)
                            if settings.showGlassCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Glass blur")
                                        Spacer()
                                        Text("\(Int(settings.glassOpacity * 100))%").foregroundStyle(.secondary)
                                    }
                                    Slider(value: $settings.glassOpacity, in: 0.0...1.0)
                                }
                            }
                        }
                    }
                    .padding(4)
                }

                GroupBox("Dots") {
                    VStack(spacing: 14) {
                        ColorHexField(title: "Completed days", hex: $settings.passedDotHex)
                        ColorHexField(title: "Remaining days", hex: $settings.futureDotHex)
                        ColorHexField(title: "Today", hex: $settings.currentDotHex)
                        Picker("Today style", selection: $settings.currentDayStyle) {
                            ForEach(WallpaperSettings.CurrentDayStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Dot size")
                                Spacer()
                                Text("\(Int(settings.dotSize * 100))%").foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.dotSize, in: 0.74...0.98, step: 0.01)
                        }
                        Toggle("Show remaining-day dots", isOn: $settings.showFutureDots)
                    }
                    .padding(4)
                }

                GroupBox("Layout") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Layout", selection: $settings.layoutPreset) {
                            ForEach(WallpaperSettings.LayoutPreset.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Timeline", selection: $settings.timelineMode) {
                            ForEach(WallpaperSettings.TimelineMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Separators", selection: $settings.separatorStyle) {
                            ForEach(WallpaperSettings.SeparatorStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Picker("Canvas size", selection: $settings.canvasPreset) {
                            ForEach(WallpaperSettings.CanvasPreset.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                    .padding(4)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Tab: Panel

    private var panelTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Side panel & quote") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Show date and days-left panel", isOn: $settings.showDatePanel)
                        Toggle("Show motivational quote", isOn: $settings.showQuote)
                        Toggle("Rotate quote daily", isOn: $settings.useDailyQuoteRotation)
                        Toggle("Show quote inspiration", isOn: $settings.showQuoteCredit)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Vertical position")
                                Spacer()
                                Text(panelVerticalOffsetText).foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.panelVerticalOffset, in: -0.12...0.18, step: 0.01)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Text size")
                                Spacer()
                                Text("\(Int(settings.panelTextScale * 100))%").foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.panelTextScale, in: 0.82...1.18, step: 0.01)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Section order")
                                Spacer()
                                Text("Drag to reorder").font(.caption).foregroundStyle(.secondary)
                            }
                            List {
                                ForEach(settings.panelSections) { section in
                                    Label(section.rawValue, systemImage: section.systemImage)
                                }
                                .onMove(perform: movePanelSections)
                            }
                            .frame(height: 190)
                        }

                        if settings.useDailyQuoteRotation {
                            Text("Includes \(QuoteLibrary.count) concise offline motivational lines.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            TextField("Custom quote", text: $settings.quote, axis: .vertical).lineLimit(2...4)
                            TextField("Custom credit", text: $settings.customQuoteCredit)
                        }
                    }
                    .padding(4)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Used only for age and birthday countdown. Stored locally on this Mac.")
                            .font(.caption).foregroundStyle(.secondary)
                        DatePicker("DOB", selection: $settings.birthDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                        HStack(spacing: 18) {
                            Label("Age \(currentAge)", systemImage: "person.crop.circle")
                            Text(settings.birthDate.formatted(date: .long, time: .omitted)).foregroundStyle(.secondary)
                        }
                        .font(.callout)
                        Toggle("Show age on wallpaper", isOn: $settings.showAge)
                        Toggle("Show next-birthday countdown", isOn: $settings.showBirthdayCountdown)
                    }
                    .padding(4)
                } label: {
                    Label("Date of birth", systemImage: "calendar.badge.clock")
                }

                GroupBox("Markers") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Button("Mark Today") { addTodayMarker() }
                            Button("Clear Markers") { clearMarkers() }.disabled(settings.markers.isEmpty)
                        }
                        if settings.markers.isEmpty {
                            Text("No marked days yet.").font(.caption).foregroundStyle(.secondary)
                        } else {
                            ForEach(settings.markers) { marker in
                                HStack {
                                    Circle()
                                        .fill(Color(nsColor: NSColor(hex: marker.colorHex) ?? .systemYellow))
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(marker.title)
                                        Text(marker.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { removeMarker(marker) } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    .padding(4)
                }

                if settings.timelineMode == .goal {
                    GroupBox("Custom goal") {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Goal name", text: $settings.goalTitle)
                            DatePicker("Start", selection: $settings.goalStartDate, displayedComponents: .date)
                            DatePicker("Deadline", selection: $settings.goalEndDate, displayedComponents: .date)
                        }
                        .padding(4)
                    }
                }

                GroupBox("Refresh status") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Last refreshed: \(lastRefreshText)", systemImage: "clock")
                        Label(
                            settings.lastRefreshStatus,
                            systemImage: settings.lastRefreshStatus.hasPrefix("Failed") ? "xmark.circle" : "checkmark.circle"
                        )
                        .foregroundStyle(settings.lastRefreshStatus.hasPrefix("Failed") ? .red : .secondary)
                    }
                    .font(.footnote)
                    .padding(4)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    private func addTodayMarker() {
        let marker = WallpaperSettings.DayMarker(date: Date(), title: "Marked day")
        Task { @MainActor in
            await Task.yield()
            settings.markers.insert(marker, at: 0)
            settings.save()
        }
    }

    private func clearMarkers() {
        Task { @MainActor in
            await Task.yield()
            settings.markers.removeAll()
            settings.save()
        }
    }

    private func removeMarker(_ marker: WallpaperSettings.DayMarker) {
        Task { @MainActor in
            await Task.yield()
            settings.markers.removeAll { $0.id == marker.id }
            settings.save()
        }
    }

    private func movePanelSections(from source: IndexSet, to destination: Int) {
        Task { @MainActor in
            await Task.yield()
            settings.panelSections.move(fromOffsets: source, toOffset: destination)
            settings.save()
        }
    }

    private func importBackgroundImage(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            let hasAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }
            let directory = try backgroundImageDirectory()
            let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let dest = directory.appendingPathComponent("custom-background.\(ext)")
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            settings.backgroundStyle = .image
            settings.backgroundImagePath = dest.path
            settings.save()
            status = "Background image imported."
        } catch {
            status = "Image import error: \(error.localizedDescription)"
        }
    }

    private func backgroundImageDirectory() throws -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LifeDotsWallpaper", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func generate() {
        do {
            try WallpaperService.generateAndApply(settings: settings)
            status = "Wallpaper generated and applied."
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    private func testAutomation() {
        do {
            settings.save()
            try LaunchAgentService.runBackgroundGenerationNow()
            reloadRefreshStatus()
            status = "Background automation test finished."
        } catch {
            reloadRefreshStatus()
            status = "Automation test error: \(error.localizedDescription)"
        }
    }

    private func toggleAutomation() {
        do {
            if automationInstalled {
                try LaunchAgentService.uninstall()
                automationInstalled = LaunchAgentService.isInstalled
                status = "Daily automation removed."
            } else {
                settings.save()
                try LaunchAgentService.install()
                automationInstalled = LaunchAgentService.isInstalled
                status = "Installed. It checks from 6:00 AM onward and refreshes once per day."
            }
        } catch {
            automationInstalled = LaunchAgentService.isInstalled
            status = "Automation error: \(error.localizedDescription)"
        }
    }

    private func reloadRefreshStatus() {
        let latest = WallpaperSettings.load()
        settings.lastRefreshDate = latest.lastRefreshDate
        settings.lastRefreshStatus = latest.lastRefreshStatus
    }
}
