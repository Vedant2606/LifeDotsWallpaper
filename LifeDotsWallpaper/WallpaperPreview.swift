import Combine
import SwiftUI

@MainActor
struct WallpaperPreview: View {
    @EnvironmentObject private var settings: WallpaperSettings
    @State private var preview: NSImage?
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
            if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ProgressView()
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .shadow(color: .black.opacity(0.25), radius: 22, y: 10)
        .task {
            scheduleRefresh()
            startPulse()
        }
        .onReceive(settings.objectWillChange.debounce(for: .milliseconds(180), scheduler: RunLoop.main)) { _ in
            scheduleRefresh(after: 0.2)
        }
        .onChange(of: pulse) { scheduleRefresh() }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulse.toggle()
        }
    }

    private func scheduleRefresh(after delay: TimeInterval = 0) {
        Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            } else {
                await Task.yield()
            }
            refresh()
        }
    }

    private func refresh() {
        let scale: CGFloat = pulse ? 1.35 : 1.0
        preview = try? WallpaperRenderer(settings: settings, todayPulseScale: scale).render()
    }
}
