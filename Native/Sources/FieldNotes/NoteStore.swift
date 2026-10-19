import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var activeID: UUID?
    @Published private(set) var saveState = "Saved locally"
    private var saveTask: Task<Void, Never>?

    private let fileManager = FileManager.default
    private lazy var rootURL: URL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Field Notes", isDirectory: true)
    private var notesURL: URL { rootURL.appendingPathComponent("Notes", isDirectory: true) }
    private var metadataURL: URL { rootURL.appendingPathComponent("metadata.json") }

    init() { load() }

    var activeNote: Note? { notes.first { $0.id == activeID } }

    func createNote() {
        let note = Note()
        notes.insert(note, at: 0); activeID = note.id; persistImmediately()
    }

    func updateActive(title: String? = nil, content: String? = nil) {
        guard let activeID, let index = notes.firstIndex(where: { $0.id == activeID }) else { return }
        if let title { notes[index].title = title.isEmpty ? "Untitled note" : title }
        if let content { notes[index].content = content }
        notes[index].updatedAt = .now
        scheduleSave()
    }

    func togglePin(_ note: Note) { guard let index = notes.firstIndex(of: note) else { return }; notes[index].pinned.toggle(); scheduleSave() }

    func delete(_ note: Note) {
        guard notes.count > 1, let index = notes.firstIndex(of: note) else { return }
        removeFile(for: note); notes.remove(at: index); activeID = notes[min(index, notes.count - 1)].id; persistImmediately()
    }

    func search(_ query: String) -> [Note] {
        let sorted = notes.sorted { ($0.pinned ? 1 : 0, $0.updatedAt) > ($1.pinned ? 1 : 0, $1.updatedAt) }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.content.localizedCaseInsensitiveContains(query) }
    }

    func saveNow() { saveTask?.cancel(); writeFiles() }

    private func load() {
        do {
            try fileManager.createDirectory(at: notesURL, withIntermediateDirectories: true)
            let files = try fileManager.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: nil).filter { $0.pathExtension == "md" }
            notes = try files.compactMap { url in
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { return nil }
                let content = try String(contentsOf: url, encoding: .utf8)
                return Note(id: id, title: titleFrom(content, fallback: url.deletingPathExtension().lastPathComponent), content: content, updatedAt: fileManager.modificationDate(for: url) ?? .now)
            }
            if notes.isEmpty { notes = [Note(title: "The shape of a good day", content: "A good day has room around the edges.\n\nIt starts slowly, with a small useful thing.")]; writeFiles() }
            activeID = notes.first?.id
        } catch { notes = [Note()]; activeID = notes.first?.id }
    }

    private func scheduleSave() {
        saveState = "Saving…"; saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500)); guard !Task.isCancelled else { return }
            await self?.writeFiles()
        }
    }

    private func persistImmediately() { saveTask?.cancel(); writeFiles() }
    private func writeFiles() {
        do {
            try fileManager.createDirectory(at: notesURL, withIntermediateDirectories: true)
            let current = Set(notes.map(\.id))
            let existing = try fileManager.contentsOfDirectory(at: notesURL, includingPropertiesForKeys: nil).filter { $0.pathExtension == "md" }
            for file in existing where UUID(uuidString: file.deletingPathExtension().lastPathComponent).map({ !current.contains($0) }) == true { try fileManager.removeItem(at: file) }
            for note in notes { let url = notesURL.appendingPathComponent("\(note.id.uuidString).md"); try note.content.write(to: url, atomically: true, encoding: .utf8) }
            let metadata = try JSONEncoder().encode(notes.map { ["id": $0.id.uuidString, "title": $0.title, "pinned": String($0.pinned)] })
            try metadata.write(to: metadataURL, options: .atomic); saveState = "Saved locally"
        } catch { saveState = "Could not save" }
    }

    private func removeFile(for note: Note) { try? fileManager.removeItem(at: notesURL.appendingPathComponent("\(note.id.uuidString).md")) }
    private func titleFrom(_ content: String, fallback: String) -> String { content.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60).description ?? fallback }
}

private extension FileManager {
    func modificationDate(for url: URL) -> Date? { (try? attributesOfItem(atPath: url.path)[.modificationDate]) as? Date }
}
