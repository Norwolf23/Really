import XCTest
@testable import Really

final class PacksTests: XCTestCase {
    let packs = Set(Catalog.entries.map(\.pack)).union(["generic"])

    func testEveryPackHasThreeLinesPerTierWithReplies() {
        XCTAssertEqual(packs, ["instagram", "tiktok", "snapchat", "youtube", "generic"])
        for pack in packs {
            let questions = Packs.questions(for: pack, bundle: .main)
            for tier in Tier.allCases {
                XCTAssertEqual(questions.filter { $0.tier == tier }.count, 3, "\(pack) \(tier)")
            }
            for q in questions {
                XCTAssertFalse(q.yes.isEmpty, q.id)
                XCTAssertFalse(q.no.isEmpty, q.id)
                XCTAssertNotEqual(q.yes, q.no, q.id)
                XCTAssertFalse(q.text.contains("!"), q.text)
                XCTAssertTrue(q.text.hasSuffix("?"), q.text)
            }
        }
    }

    func testRepliesVary() {
        let instagram = Packs.questions(for: "instagram", bundle: .main)
        XCTAssertGreaterThan(Set(instagram.map(\.yes)).count, 3)
    }

    func testUnknownPackFallsBackToGeneric() {
        let generic = Packs.questions(for: "generic", bundle: .main)
        XCTAssertEqual(generic.count, 9)
        XCTAssertEqual(Packs.questions(for: "does-not-exist", bundle: .main).map(\.text), generic.map(\.text))
    }

    func testIDsAreStableAndUnique() {
        let a = Packs.questions(for: "instagram", bundle: .main)
        XCTAssertEqual(Set(a.map(\.id)).count, a.count)
        XCTAssertEqual(a.first?.id, "pack-instagram.normal.0")
        XCTAssertEqual(a.first?.text, "Are you avoiding something again?")
    }
}
