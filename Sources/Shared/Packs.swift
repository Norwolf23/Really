import Foundation

enum Packs {
    /// Questions for a pack name ("instagram", "generic", ...). Unknown names fall back to the generic pack.
    static func questions(for pack: String, bundle: Bundle = .main) -> [Question] {
        let name = bundle.url(forResource: "pack-" + pack, withExtension: "json") != nil ? "pack-" + pack : "pack-generic"
        guard let raw = load(name, bundle: bundle) else { return [] }
        // ponytail: ids are positional ("pack-x.tier.index"). Pack lines are append-only; never reorder or delete a line, or lastQuestion bookkeeping shifts. Give lines explicit ids when packs become a product.
        return Tier.allCases.flatMap { tier in
            (raw[tier.rawValue] ?? []).enumerated().map { index, text in
                Question(id: "\(name).\(tier.rawValue).\(index)", text: text, tier: tier)
            }
        }
    }

    private static func load(_ name: String, bundle: Bundle) -> [String: [String]]? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: [String]].self, from: data)
    }
}
