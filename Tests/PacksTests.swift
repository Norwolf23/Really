import XCTest
@testable import Really

final class PacksTests: XCTestCase {
    func testEveryCatalogAppHasAFullPack() {
        for entry in Catalog.entries {
            let questions = Packs.questions(for: entry.id, bundle: .main)
            for tier in Tier.allCases {
                XCTAssertGreaterThanOrEqual(questions.filter { $0.tier == tier }.count, 10, "\(entry.id) \(tier)")
            }
            XCTAssertEqual(questions.last?.text, "No, seriously. Really?", entry.id)
        }
    }

    func testCustomAppUsesGenericPack() {
        let generic = Packs.questions(for: "generic", bundle: .main)
        let custom = Packs.questions(for: "custom-abc", bundle: .main)
        XCTAssertFalse(generic.isEmpty)
        XCTAssertEqual(custom.map(\.text), generic.map(\.text))
    }

    func testUnknownIDFallsBackToGeneric() {
        XCTAssertEqual(Packs.questions(for: "does-not-exist", bundle: .main).count, Packs.questions(for: "generic", bundle: .main).count)
    }

    func testIDsAreStableAndUnique() {
        let a = Packs.questions(for: "instagram", bundle: .main)
        let b = Packs.questions(for: "instagram", bundle: .main)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertEqual(Set(a.map(\.id)).count, a.count)
        XCTAssertEqual(a.first?.id, "pack-instagram.normal.0")
    }

    func testNoPackLineUsesExclamationOrEmoji() {
        for entry in Catalog.entries + [CatalogEntry(id: "generic", name: "", urlScheme: "", sessionMinutes: 1)] {
            for q in Packs.questions(for: entry.id, bundle: .main) {
                XCTAssertFalse(q.text.contains("!"), q.text)
                XCTAssertTrue(q.text.unicodeScalars.allSatisfy { $0.value < 0x2500 }, q.text)
            }
        }
    }
}
