import Foundation
import SwiftUI

struct GitHubContribution: Identifiable {
    let date: Date
    let level: Int
    var id: Date { date }
}

@MainActor
final class GitHubActivityStore: ObservableObject {
    @Published var contributions: [GitHubContribution] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var currentStreak: Int {
        let calendar = Calendar(identifier: .gregorian)
        let levels = Dictionary(uniqueKeysWithValues: contributions.map { (calendar.startOfDay(for: $0.date), $0.level) })
        var day = calendar.startOfDay(for: .now)
        if levels[day, default: 0] == 0 { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var streak = 0
        while levels[day, default: 0] > 0 {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    func load(username: String) async {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { contributions = []; errorMessage = nil; return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let year = Calendar.current.component(.year, from: .now)
            let url = URL(string: "https://github.com/users/\(encoded)/contributions?from=\(year - 1)-01-01")!
            var request = URLRequest(url: url); request.setValue("FieldNotes/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let html = String(data: data, encoding: .utf8) else { throw URLError(.badServerResponse) }
            contributions = parse(html)
            if contributions.isEmpty { errorMessage = "No public activity found" }
        } catch { errorMessage = "Activity unavailable" }
    }

    private func parse(_ html: String) -> [GitHubContribution] {
        let pattern = #"data-date="([0-9]{4}-[0-9]{2}-[0-9]{2})"[^>]*data-level="([0-4])""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let dateRange = Range(match.range(at: 1), in: html), let levelRange = Range(match.range(at: 2), in: html), let date = formatter.date(from: String(html[dateRange])), let level = Int(html[levelRange]) else { return nil }
            return GitHubContribution(date: date, level: level)
        }.sorted { $0.date < $1.date }
    }
}

struct GitHubActivityView: View {
    @ObservedObject var activity: GitHubActivityStore
    let username: String
    let accent: Color
    private let rows = Array(repeating: GridItem(.fixed(8), spacing: 3), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("GitHub", systemImage: "square.stack.3d.up.fill").font(.caption.weight(.medium))
                Spacer()
                if !activity.contributions.isEmpty { Text("\(activity.currentStreak) day streak").font(.caption2).foregroundStyle(.secondary) }
            }
            if activity.isLoading {
                RoundedRectangle(cornerRadius: 5).fill(.secondary.opacity(0.1)).frame(height: 74).overlay { ProgressView().controlSize(.small) }
            } else if let error = activity.errorMessage {
                Text(error).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            } else if username.isEmpty {
                Text("Add your username in Settings").font(.caption).foregroundStyle(.secondary).frame(minHeight: 48)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: 3) {
                        ForEach(Array(activity.contributions.suffix(112))) { contribution in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(contribution.level == 0 ? Color.secondary.opacity(0.12) : accent.opacity(0.28 + Double(contribution.level) * 0.18))
                                .frame(width: 8, height: 8)
                                .help(contribution.date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }.frame(height: 74)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .task(id: username) { await activity.load(username: username) }
    }
}
