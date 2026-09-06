import Foundation
import os

/// All app state. Two JSON files, rewritten whole on every change.
/// ponytail: fine for a few events a day; move to SwiftData if events.json passes a few MB.
@MainActor
final class Store: ObservableObject {
    // Intents run in the app process and share this instance. If they ever move to an extension, two Store instances will overwrite each other's JSON.
    static var shared = Store()
    private static let log = Logger(subsystem: "studio.nickson.really", category: "store")

    @Published var apps: [GatedApp] { didSet { save() } }
    @Published var events: [CheckIn] { didSet { save() } }

    private let appsURL: URL
    private let eventsURL: URL

    nonisolated static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Really", isDirectory: true)
    }

    init(directory: URL = Store.defaultDirectory) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Store.log.error("create directory failed: \(error.localizedDescription, privacy: .public)")
        }
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
        do {
            try Store.write(apps, to: appsURL)
        } catch {
            Store.log.error("save apps.json failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            try Store.write(events, to: eventsURL)
        } catch {
            Store.log.error("save events.json failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(T.self, from: data)
        } catch {
            Store.log.error("load \(url.lastPathComponent, privacy: .public) failed, moving aside as .bak: \(error.localizedDescription, privacy: .public)")
            try? fileManager.removeItem(at: url.appendingPathExtension("bak"))
            try? fileManager.moveItem(at: url, to: url.appendingPathExtension("bak"))
            return nil
        }
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
