import SwiftUI
import AppKit

struct ColorHexField: View {
    let title: String
    @Binding var hex: String
    @State private var draftHex = ""
    @State private var draftColor = Color.white

    private var colorBinding: Binding<Color> {
        Binding(
            get: { draftColor },
            set: { newValue in
                draftColor = newValue
                if let nsColor = NSColor(newValue).usingColorSpace(.deviceRGB) {
                    updateDraft(nsColor.hexString)
                }
            }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { draftHex },
            set: { newValue in
                updateDraft(newValue)
            }
        )
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
            TextField("FFFFFF", text: textBinding)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
        }
        .onAppear { syncFromBinding() }
        .onChange(of: hex) { _, _ in syncFromBinding() }
    }

    private func updateDraft(_ value: String) {
        let sanitized = sanitizedHex(value)
        draftHex = sanitized
        draftColor = Color(nsColor: NSColor(hex: sanitized) ?? .white)
        commit(sanitized)
    }

    private func syncFromBinding() {
        let sanitized = sanitizedHex(hex)
        guard sanitized != draftHex else { return }
        draftHex = sanitized
        draftColor = Color(nsColor: NSColor(hex: sanitized) ?? .white)
    }

    private func commit(_ value: String) {
        Task { @MainActor in
            await Task.yield()
            if hex != value {
                hex = value
            }
        }
    }

    private func sanitizedHex(_ value: String) -> String {
        String(value.uppercased().filter { $0.isHexDigit }.prefix(6))
    }
}
