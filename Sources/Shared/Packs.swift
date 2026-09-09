import Foundation

enum Packs {
    private struct Line: Decodable {
        var text: String
        var yes: String?
        var no: String?
    }

    /// Questions for a pack name ("instagram", "generic", ...). Unknown names fall back to the generic pack.
    static func questions(for pack: String, bundle: Bundle = .main) -> [Question] {
        let name = bundle.url(forResource: "pack-" + pack, withExtension: "json") != nil ? "pack-" + pack : "pack-generic"
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [Line]].self, from: data) else { return [] }
        // ponytail: ids are positional ("pack-x.tier.index"); the shield rotates by open number, so order is the schedule.
        return Tier.allCases.flatMap { tier in
            (raw[tier.rawValue] ?? []).enumerated().map { index, line in
                var q = Question(id: "\(name).\(tier.rawValue).\(index)", text: line.text, tier: tier)
                if let yes = line.yes { q.yes = yes }
                if let no = line.no { q.no = no }
                return q
            }
        }
    }
}
