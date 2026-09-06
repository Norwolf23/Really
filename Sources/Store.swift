import Foundation

/// All app state. Two JSON files, rewritten whole on every change.
/// ponytail: fine for a few events a day; move to SwiftData if events.json passes a few MB.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var apps: [GatedApp] { didSet { save() } }
    @Published var events: [CheckIn] { didSet { save() } }

    private let appsURL: URL
    private let eventsURL: URL

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Really", isDirectory: true)
    }

    init(directory: URL = Store.defaultDirectory) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        appsURL = directory.appendingPathComponent("apps.json")
        eventsURL = directory.appendingPathComponent("events.json")
        apps = Store.load([GatedApp].self, from: appsURL) ?? []
        events = Store.load([CheckIn].self, from: eventsURL) ?? []
    }

    func app(_ id: String) -> GatedApp? {
        apps.first { $0.id == id }
    }

    func update(_ app: GatedApp) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index] = app
        } else {
            apps.append(app)
        }
    }

    func remove(_ id: String) {
        apps.removeAll { $0.id == id }
    }

    func record(_ decision: Decision, for appID: String, questionID: String?, now: Date = .now) {
        guard var app = app(appID) else { return }
        app.lastQuestionID = questionID
        if decision == .proceed {
            app.cooldownUntil = now.addingTimeInterval(TimeInterval(app.cooldownMinutes * 60))
        }
        update(app)
        events.append(CheckIn(appID: appID, at: now, decision: decision))
    }

    func markCheckIn(_ appID: String, now: Date = .now) {
        guard var app = app(appID) else { return }
        app.lastCheckIn = now
        update(app)
    }

    private func save() {
        try? Store.write(apps, to: appsURL)
        try? Store.write(events, to: eventsURL)
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
