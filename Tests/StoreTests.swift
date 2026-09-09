import XCTest
@testable import Really

final class StoreTests: XCTestCase {
    var dir: URL!
    let ig = "com.burbn.instagram"

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("really-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testStartsEmpty() {
        let store = Store(directory: dir)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.settings, Settings())
        XCTAssertEqual(store.state, ShieldState())
    }

    func testRecordAppendsEvent() {
        let store = Store(directory: dir)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        store.record(.proceed, app: ig, now: now)
        store.record(.no, app: ig)
        XCTAssertEqual(store.events.map(\.decision), [.proceed, .no])
        XCTAssertEqual(store.events[0].at, now)
    }

    func testEverythingPersistsAcrossInstances() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        do {
            let store = Store(directory: dir)
            store.record(.no, app: ig, now: now)
            store.settings.meanness = .annoyed
            store.settings.escalates = false
            store.settings.hasOnboarded = true
            store.settings.cooldownMinutes = 45
            store.state.cooldowns[ig] = now
        }
        let reloaded = Store(directory: dir)
        XCTAssertEqual(reloaded.events.count, 1)
        XCTAssertEqual(reloaded.events[0].decision, .no)
        XCTAssertEqual(reloaded.events[0].at.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(reloaded.settings.meanness, .annoyed)
        XCTAssertFalse(reloaded.settings.escalates)
        XCTAssertTrue(reloaded.settings.hasOnboarded)
        XCTAssertEqual(reloaded.settings.cooldownMinutes, 45)
        XCTAssertEqual(reloaded.state.cooldowns[ig]?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 1)
    }

    /// The extensions write events.json and state.json while the app is backgrounded; reload() picks them up.
    func testReloadPicksUpWritesFromAnotherInstance() {
        let app = Store(directory: dir)
        app.settings.hasOnboarded = true
        let ext = Store(directory: dir)
        ext.record(.proceed, app: ig)
        ext.state.cooldowns[ig] = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(app.events.isEmpty)
        app.reload()
        XCTAssertEqual(app.events.count, 1)
        XCTAssertEqual(app.state.cooldowns.count, 1)
        XCTAssertTrue(app.settings.hasOnboarded)
    }

    /// A torn read of another process's write must never turn into an overwrite.
    func testUnreadableFileIsNeverOverwritten() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("events.json")
        try Data("not json".utf8).write(to: url)
        let store = Store(directory: dir)
        XCTAssertTrue(store.events.isEmpty)
        store.record(.no, app: ig)
        store.events = []
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "not json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path + ".bak"))
    }

    func testReloadDoesNotWriteBack() throws {
        let app = Store(directory: dir)
        app.record(.no, app: ig)
        let url = dir.appendingPathComponent("events.json")
        let before = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        Thread.sleep(forTimeInterval: 0.05)
        app.reload()
        let after = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertEqual(before, after)
    }

    func testEventsAreCapped() {
        let store = Store(directory: dir)
        store.events = (0..<Store.maxEvents).map { _ in CheckIn(appID: ig, at: .now, decision: .no) }
        store.record(.no, app: ig)
        XCTAssertEqual(store.events.count, Store.maxEvents)
        XCTAssertEqual(store.events.last?.decision, .no)
    }
}
