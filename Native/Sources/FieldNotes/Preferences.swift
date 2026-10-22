import AppKit
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var colorScheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}

enum EditorTypeface: String, CaseIterable, Identifiable {
    case sans = "Sans", serif = "Serif", mono = "Mono"
    var id: String { rawValue }
    func font(size: CGFloat) -> NSFont {
        switch self {
        case .sans: return .systemFont(ofSize: size)
        case .serif: return NSFont(name: "New York", size: size) ?? .systemFont(ofSize: size)
        case .mono: return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }
}

enum AccentTheme: String, CaseIterable, Identifiable {
    case moss = "Moss", blue = "Blue", plum = "Plum"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .moss: return Color(red: 0.31, green: 0.52, blue: 0.42)
        case .blue: return Color(red: 0.25, green: 0.47, blue: 0.77)
        case .plum: return Color(red: 0.55, green: 0.34, blue: 0.62)
        }
    }
}

struct PreferencesView: View {
    @AppStorage("fieldNotes.appearance") private var appearance = AppearanceMode.system.rawValue
    @AppStorage("fieldNotes.typeface") private var typeface = EditorTypeface.sans.rawValue
    @AppStorage("fieldNotes.fontSize") private var fontSize = 16.0
    @AppStorage("fieldNotes.lineSpacing") private var lineSpacing = 4.0
    @AppStorage("fieldNotes.accent") private var accent = AccentTheme.moss.rawValue
    @AppStorage("fieldNotes.githubUsername") private var githubUsername = "Koded0214h"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Editor settings").font(.headline)
            setting("Appearance") { Picker("Appearance", selection: $appearance) { ForEach(AppearanceMode.allCases) { Text($0.rawValue).tag($0.rawValue) } }.labelsHidden().pickerStyle(.segmented) }
            setting("Accent") { Picker("Accent", selection: $accent) { ForEach(AccentTheme.allCases) { Text($0.rawValue).tag($0.rawValue) } }.labelsHidden().pickerStyle(.segmented) }
            setting("Typeface") { Picker("Typeface", selection: $typeface) { ForEach(EditorTypeface.allCases) { Text($0.rawValue).tag($0.rawValue) } }.labelsHidden().pickerStyle(.segmented) }
            setting("Text size") { HStack { Slider(value: $fontSize, in: 13...22, step: 1); Text("\(Int(fontSize)) pt").monospacedDigit().frame(width: 38, alignment: .trailing) } }
            setting("Line spacing") { HStack { Slider(value: $lineSpacing, in: 1...9, step: 1); Text("\(Int(lineSpacing)) pt").monospacedDigit().frame(width: 38, alignment: .trailing) } }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("GitHub activity").font(.subheadline.weight(.medium))
                TextField("GitHub username", text: $githubUsername).textFieldStyle(.roundedBorder)
                Text("Shows public contributions in the sidebar. No token is stored.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 330)
    }

    private func setting<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(label).font(.caption).foregroundStyle(.secondary); content() }
    }
}
