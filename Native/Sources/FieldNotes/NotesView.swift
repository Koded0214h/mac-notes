import SwiftUI

struct NotesView: View {
    @ObservedObject var store: NoteStore
    let dismiss: () -> Void
    @State private var query = ""
    @State private var preview = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            editor
        }
        .frame(width: 720, height: 560)
        .background(.regularMaterial)
        .preferredColorScheme(nil)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Label("Field Notes", systemImage: "note.text").font(.headline); Spacer(); Button(action: {}) { Image(systemName: "gearshape") }.buttonStyle(.plain) }
                .padding(.bottom, 18)
            Button { store.createNote() } label: { Label("New note", systemImage: "plus") }.buttonStyle(.borderedProminent).tint(.green).controlSize(.small)
            TextField("Search notes", text: $query).textFieldStyle(.roundedBorder).padding(.vertical, 14)
            Text("YOUR NOTES").font(.caption2).foregroundStyle(.secondary).tracking(1)
            List(store.search(query), selection: $store.activeID) { note in
                HStack(alignment: .top) { VStack(alignment: .leading, spacing: 3) { Text(note.title).font(.subheadline.weight(.medium)).lineLimit(1); Text(note.content.replacingOccurrences(of: "\n", with: " ")).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); if note.pinned { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.green) } }
                    .tag(note.id)
                    .contextMenu { Button("Delete", role: .destructive) { store.delete(note) }; Button(note.pinned ? "Unpin" : "Pin") { store.togglePin(note) } }
            }.listStyle(.sidebar)
            HStack { Image(systemName: "lock.fill"); Text("Stored on this Mac") }.font(.caption2).foregroundStyle(.secondary).padding(.top, 12)
        }.padding(18).frame(width: 245)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(store.saveState).font(.caption2).foregroundStyle(.secondary); Spacer(); Button { preview.toggle() } label: { Text(preview ? "Edit" : "Preview") }.buttonStyle(.plain); Button { if let note = store.activeNote { store.togglePin(note) } } label: { Image(systemName: store.activeNote?.pinned == true ? "star.fill" : "star") }.buttonStyle(.plain) }.padding(.bottom, 18)
            if let note = store.activeNote {
                TextField("Untitled note", text: Binding(get: { note.title }, set: { store.updateActive(title: $0) })).font(.system(size: 26, design: .serif)).textFieldStyle(.plain)
                Divider().padding(.vertical, 12)
                if preview { ScrollView { Text(note.content).font(.system(size: 16, design: .serif)).frame(maxWidth: .infinity, alignment: .leading) } }
                else { TextEditor(text: Binding(get: { note.content }, set: { store.updateActive(content: $0) })).font(.system(size: 16, design: .serif)).scrollContentBackground(.hidden) }
                HStack { Text("\(note.content.split { $0 == " " || $0 == "\n" }.count) words"); Spacer(); Text("Markdown") }.font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
            }
        }.padding(26).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
