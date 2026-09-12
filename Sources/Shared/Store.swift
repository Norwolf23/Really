import Foundation
import os

/// All state. Three JSON files in the App Group, each rewritten whole by its own writer:
/// settings.json and custom.json (app), events.json and state.json (shield extensions). The app reloads on foreground.
/// ponytail: fine for a few events a day; move to SwiftData if events.json passes a few MB.
final class Store: ObservableObject {
    static let shared = Store()
    static let group = "group.studio.nickson.really"
    static let maxEvents = 5000
    private static let log = Logger(subsystem: "studio.nickson.really", category: "store")

    @Published var events: [CheckIn] { didSet { save(events, to: eventsURL) } }
    @Published var settings: Settings { didSet { save(settings, to: settingsURL) } }
    @Published var state: ShieldState { didSet { save(state, to: stateURL) } }
    @Published var custom: [String: CustomPack] { didSet { save(custom, to: customURL) } }

    private let eventsURL: URL
    private let settingsURL: URL
    private let stateURL: URL
    private let customURL: URL
    /// Files that exist but didn't decode (most likely a torn read of another process's write). Never overwritten.
    private(set) var unreadable: Set<URL> = []
    private var loading = false
    /// The shield extensions' sandbox denies the unlink an atomic write needs; the app keeps atomic writes.
    private let atomic = Bundle.main.bundleURL.pathExtension != "appex"

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
        customURL = directory.appendingPathComponent("custom.json")
        events = []
        settings = Settings()
        state = ShieldState()
        custom = [:]
        reload(settingsToo: true)
    }

    /// Pick up what the extensions wrote while the app was in the background. Reads only; never writes back.
    func reload(settingsToo: Bool = false) {
        loading = true
        defer { loading = false }
        events = load([CheckIn].self, from: eventsURL) ?? []
        state = load(ShieldState.self, from: stateURL) ?? ShieldState()
        if settingsToo {
            settings = load(Settings.self, from: settingsURL) ?? Settings()
            custom = load([String: CustomPack].self, from: customURL) ?? [:]
        }
    }

    func record(_ decision: Decision, app id: String, now: Date = .now) {
        guard !unreadable.contains(eventsURL) else { return } // don't write one event over a log we couldn't read
        events.append(CheckIn(appID: id, at: now, decision: decision))
        if events.count > Store.maxEvents { events.removeFirst(events.count - Store.maxEvents) }
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard !loading, !unreadable.contains(url) else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: url, options: atomic ? .atomic : [])
        } catch {
            Store.log.error("save \(url.lastPathComponent, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let value = try decoder.decode(T.self, from: data)
            unreadable.remove(url)
            return value
        } catch {
            // ponytail: a permanently corrupt file stays read-only forever; delete it by hand if that ever happens.
            Store.log.error("load \(url.lastPathComponent, privacy: .public) failed, leaving it untouched: \(error.localizedDescription, privacy: .public)")
            unreadable.insert(url)
            return nil
        }
    }
}
