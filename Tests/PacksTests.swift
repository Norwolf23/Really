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

    func testEveryCatalogAppHasThreeToFourReasons() {
        for entry in Catalog.entries {
            let reasons = Packs.reasons(for: entry.id, bundle: .main)
            XCTAssertTrue((3...4).contains(reasons.count), "\(entry.id): \(reasons.count)")
            for reason in reasons { XCTAssertFalse(reason.contains("!"), reason) }
        }
    }

    func testGenericReasonsAndFallback() {
        let generic = Packs.reasons(for: "generic", bundle: .main)
        XCTAssertEqual(generic, ["Checking one thing", "Bored", "Avoiding something", "No reason"])
        XCTAssertEqual(Packs.reasons(for: "custom-abc", bundle: .main), generic)
        XCTAssertEqual(Packs.reasons(for: "does-not-exist", bundle: .main), generic)
    }

    func testReasonsKeyDoesNotLeakIntoQuestions() {
        let questions = Packs.questions(for: "instagram", bundle: .main)
        XCTAssertEqual(questions.count, 30)
    }
}
