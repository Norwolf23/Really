import Foundation
import os

/// All state. Three JSON files in the App Group, each rewritten whole by its own writer:
/// settings.json (app), events.json and state.json (shield extensions). The app reloads on foreground.
/// ponytail: fine for a few events a day; move to SwiftData if events.json passes a few MB.
final class Store: ObservableObject {
    static let shared = Store()
    static let group = "group.studio.nickson.really"
    private static let log = Logger(subsystem: "studio.nickson.really", category: "store")

    @Published var events: [CheckIn] { didSet { save(events, to: eventsURL) } }
    @Published var settings: Settings { didSet { save(settings, to: settingsURL) } }
    @Published var state: ShieldState { didSet { save(state, to: stateURL) } }

    private let eventsURL: URL
    private let settingsURL: URL
    private let stateURL: URL

    static var defaultDirectory: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Really", isDirectory: true)
    }

    init(directory: URL = Store.defaultDirectory) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Store.log.error("create directory failed: \(error.localizedDescription, privacy: .public)")
        }
        eventsURL = directory.appendingPathComponent("events.json")
        settingsURL = directory.appendingPathComponent("settings.json")
        stateURL = directory.appendingPathComponent("state.json")
        events = Store.load([CheckIn].self, from: eventsURL) ?? []
        settings = Store.load(Settings.self, from: settingsURL) ?? Settings()
        state = Store.load(ShieldState.self, from: stateURL) ?? ShieldState()
    }

    /// Pick up what the extensions wrote while the app was in the background.
    func reload() {
        events = Store.load([CheckIn].self, from: eventsURL) ?? []
        state = Store.load(ShieldState.self, from: stateURL) ?? ShieldState()
    }

    func record(_ decision: Decision, app id: String, now: Date = .now) {
        events.append(CheckIn(appID: id, at: now, decision: decision))
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            // Not atomic: the shield extensions' sandbox denies the unlink an atomic write needs inside the App Group.
            // Files are a few KB and one process writes at a time, so a torn read is theoretical.
            try encoder.encode(value).write(to: url)
        } catch {
            Store.log.error("save \(url.lastPathComponent, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
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
}
