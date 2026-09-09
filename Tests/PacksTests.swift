import XCTest
@testable import Really

final class PacksTests: XCTestCase {
    let packs = Set(Catalog.packs.values)

    func testEveryCatalogAppHasAFullPack() {
        XCTAssertEqual(packs.count, 8)
        for pack in packs {
            let questions = Packs.questions(for: pack, bundle: .main)
            for tier in Tier.allCases {
                XCTAssertGreaterThanOrEqual(questions.filter { $0.tier == tier }.count, 10, "\(pack) \(tier)")
            }
            XCTAssertEqual(questions.last?.text, "No, seriously. Really?", pack)
        }
    }

    func testUnknownPackFallsBackToGeneric() {
        let generic = Packs.questions(for: "generic", bundle: .main)
        XCTAssertFalse(generic.isEmpty)
        XCTAssertEqual(Packs.questions(for: "does-not-exist", bundle: .main).map(\.text), generic.map(\.text))
    }

    func testIDsAreStableAndUnique() {
        let a = Packs.questions(for: "instagram", bundle: .main)
        let b = Packs.questions(for: "instagram", bundle: .main)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertEqual(Set(a.map(\.id)).count, a.count)
        XCTAssertEqual(a.first?.id, "pack-instagram.normal.0")
    }

    func testNoPackLineUsesExclamationOrEmoji() {
        for pack in packs.union(["generic"]) {
            for q in Packs.questions(for: pack, bundle: .main) {
                XCTAssertFalse(q.text.contains("!"), q.text)
                XCTAssertTrue(q.text.unicodeScalars.allSatisfy { $0.value < 0x2500 }, q.text)
            }
        }
    }

    func testReasonsKeyDoesNotLeakIntoQuestions() {
        XCTAssertEqual(Packs.questions(for: "instagram", bundle: .main).count, 30)
    }
}
