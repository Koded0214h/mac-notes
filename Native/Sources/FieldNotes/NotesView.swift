import AppKit
import SwiftUI

struct NotesView: View {
    @ObservedObject var store: NoteStore
    let dismiss: () -> Void
    @StateObject private var githubActivity = GitHubActivityStore()
    @State private var query = ""
    @State private var preview = false
    @State private var showPreferences = false
    @FocusState private var titleFocused: Bool

    @AppStorage("fieldNotes.appearance") private var appearance = AppearanceMode.system.rawValue
    @AppStorage("fieldNotes.typeface") private var typeface = EditorTypeface.sans.rawValue
    @AppStorage("fieldNotes.fontSize") private var fontSize = 16.0
    @AppStorage("fieldNotes.lineSpacing") private var lineSpacing = 4.0
    @AppStorage("fieldNotes.accent") private var accentName = AccentTheme.moss.rawValue
    @AppStorage("fieldNotes.githubUsername") private var githubUsername = "Koded0214h"

    private var accent: AccentTheme { AccentTheme(rawValue: accentName) ?? .moss }
    private var editorTypeface: EditorTypeface { EditorTypeface(rawValue: typeface) ?? .sans }
    private var colorScheme: ColorScheme? { (AppearanceMode(rawValue: appearance) ?? .system).colorScheme }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            editor
        }
        .frame(width: 760, height: 590)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(colorScheme)
        .tint(accent.color)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "note.text").foregroundStyle(accent.color)
                Text("Field Notes").font(.headline)
                Spacer()
                Button { showPreferences.toggle() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).help("Editor settings")
                    .popover(isPresented: $showPreferences, arrowEdge: .top) { PreferencesView() }
            }.padding(.bottom, 16)

            Button { store.createNote(); titleFocused = true } label: {
                HStack { Image(systemName: "plus"); Text("New note"); Spacer(); Text("⌘N").font(.caption2).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.borderedProminent).controlSize(.small)

            TextField("Search notes", text: $query).textFieldStyle(.roundedBorder).padding(.vertical, 12)

            List(store.search(query), selection: $store.activeID) { note in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(note.title.isEmpty ? "Untitled note" : note.title).font(.subheadline.weight(.medium)).lineLimit(1); Spacer(); if note.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(accent.color) } }
                    Text(note.content.replacingOccurrences(of: "\n", with: " ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(note.updatedAt.formatted(.relative(presentation: .named))).font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 3)
                .tag(note.id)
                .contextMenu {
                    Button(note.pinned ? "Unpin" : "Pin") { store.togglePin(note) }
                    Divider()
                    Button("Delete", role: .destructive) { store.delete(note) }
                }
            }
            .listStyle(.sidebar)
            .frame(minHeight: 180)

            GitHubActivityView(activity: githubActivity, username: githubUsername, accent: accent.color)
                .padding(.top, 10)

            HStack(spacing: 5) { Image(systemName: "lock.fill"); Text("Saved as Markdown on this Mac") }
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 10)
        }
        .padding(16)
        .frame(width: 270)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.65))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Label(store.saveState, systemImage: store.saveState == "Saved locally" ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(preview ? "Edit" : "Preview") { preview.toggle() }.buttonStyle(.plain).font(.caption)
                Button { if let note = store.activeNote { store.togglePin(note) } } label: {
                    Image(systemName: store.activeNote?.pinned == true ? "pin.fill" : "pin")
                }.buttonStyle(.plain).help(store.activeNote?.pinned == true ? "Unpin note" : "Pin note")
            }.padding(.bottom, 18)

            if let note = store.activeNote {
                TextField("Untitled note", text: Binding(get: { store.activeNote?.title ?? note.title }, set: { store.updateActive(title: $0) }))
                    .font(.system(size: 25, weight: .semibold))
                    .textFieldStyle(.plain)
                    .focused($titleFocused)

                Divider().padding(.vertical, 12)

                if preview {
                    ScrollView {
                        Text(note.content.isEmpty ? "Nothing to preview yet." : note.content)
                            .font(.system(size: fontSize))
                            .lineSpacing(lineSpacing)
                            .foregroundStyle(note.content.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.vertical, 14)
                    }
                } else {
                    MarkdownTextView(
                        text: Binding(get: { store.activeNote?.content ?? note.content }, set: { store.updateActive(content: $0) }),
                        documentID: note.id,
                        font: editorTypeface.font(size: fontSize),
                        lineSpacing: lineSpacing
                    )
                }

                Divider().padding(.top, 8)
                HStack {
                    Text("\(wordCount(note.content)) words")
                    Text("\(note.content.count) characters")
                    Spacer()
                    Text(editorTypeface.rawValue)
                    Text("\(Int(fontSize)) pt")
                }.font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
            } else {
                VStack(spacing: 9) {
                    Image(systemName: "note.text").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("No note selected").font(.headline)
                    Text("Create a note to start writing.").font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wordCount(_ text: String) -> Int { text.split(whereSeparator: { $0.isWhitespace }).count }
}
