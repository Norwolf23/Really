import Foundation

enum Packs {
    static func questions(for appID: String, bundle: Bundle = .main) -> [Question] {
        let name = fileName(for: appID, bundle: bundle)
        guard let raw = load(name, bundle: bundle) else { return [] }
        // ponytail: ids are positional ("pack-x.tier.index"). Pack lines are append-only; never reorder or delete a line, or saved single-question choices shift. Give lines explicit ids when packs become a product.
        return Tier.allCases.flatMap { tier in
            (raw[tier.rawValue] ?? []).enumerated().map { index, text in
                Question(id: "\(name).\(tier.rawValue).\(index)", text: text, tier: tier)
            }
        }
    }

    /// The app's own reasons when it has at least three, else the generic list.
    static func reasons(for appID: String, bundle: Bundle = .main) -> [String] {
        let own = load(fileName(for: appID, bundle: bundle), bundle: bundle)?["reasons"] ?? []
        if own.count >= 3 { return own }
        return load("pack-generic", bundle: bundle)?["reasons"] ?? []
    }

    private static func fileName(for appID: String, bundle: Bundle) -> String {
        let preferred = appID.hasPrefix("custom-") ? "pack-generic" : "pack-" + appID
        return bundle.url(forResource: preferred, withExtension: "json") != nil ? preferred : "pack-generic"
    }

    private static func load(_ name: String, bundle: Bundle) -> [String: [String]]? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: [String]].self, from: data)
    }
}
