import XCTest
@testable import Really

@MainActor
final class StoreTests: XCTestCase {
    var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("really-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testStartsEmpty() {
        let store = Store(directory: dir)
        XCTAssertTrue(store.apps.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
    }

    func testUpdateInsertsThenReplaces() {
        let store = Store(directory: dir)
        var app = Catalog.gatedApp(Catalog.entries[0])
        store.update(app)
        XCTAssertEqual(store.apps.count, 1)
        app.pauseSeconds = 9
        store.update(app)
        XCTAssertEqual(store.apps.count, 1)
        XCTAssertEqual(store.app("instagram")?.pauseSeconds, 9)
    }

    func testRemove() {
        let store = Store(directory: dir)
        store.update(Catalog.gatedApp(Catalog.entries[0]))
        store.remove("instagram")
        XCTAssertNil(store.app("instagram"))
    }

    func testPersistsAcrossInstances() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        do {
            let store = Store(directory: dir)
            store.update(Catalog.gatedApp(Catalog.entries[0]))
            store.record(.no, for: "instagram", questionID: "q1", now: now)
        }
        let reloaded = Store(directory: dir)
        XCTAssertEqual(reloaded.apps.map(\.id), ["instagram"])
        XCTAssertEqual(reloaded.events.count, 1)
        XCTAssertEqual(reloaded.events[0].decision, .no)
        XCTAssertEqual(reloaded.events[0].at.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(reloaded.app("instagram")?.lastQuestionID, "q1")
    }

    func testRecordProceedStartsCooldown() {
        let store = Store(directory: dir)
        var app = Catalog.gatedApp(Catalog.entries[0]); app.cooldownMinutes = 15
        store.update(app)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        store.record(.proceed, for: "instagram", questionID: nil, now: now)
        XCTAssertEqual(store.app("instagram")?.cooldownUntil, now.addingTimeInterval(15 * 60))
        XCTAssertEqual(store.events.last?.decision, .proceed)
    }

    func testRecordNoDoesNotStartCooldown() {
        let store = Store(directory: dir)
        store.update(Catalog.gatedApp(Catalog.entries[0]))
        store.record(.no, for: "instagram", questionID: nil)
        XCTAssertNil(store.app("instagram")?.cooldownUntil)
    }

    func testRecordForUnknownAppIsIgnored() {
        let store = Store(directory: dir)
        store.record(.no, for: "nope", questionID: nil)
        XCTAssertTrue(store.events.isEmpty)
    }

    func testMarkCheckIn() {
        let store = Store(directory: dir)
        store.update(Catalog.gatedApp(Catalog.entries[0]))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        store.markCheckIn("instagram", now: now)
        XCTAssertEqual(store.app("instagram")?.lastCheckIn, now)
    }
}
