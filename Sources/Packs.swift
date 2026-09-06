import Foundation

enum Packs {
    static func questions(for appID: String, bundle: Bundle = .main) -> [Question] {
        let preferred = appID.hasPrefix("custom-") ? "pack-generic" : "pack-" + appID
        let name = bundle.url(forResource: preferred, withExtension: "json") != nil ? preferred : "pack-generic"
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [] }
        return Tier.allCases.flatMap { tier in
            (raw[tier.rawValue] ?? []).enumerated().map { index, text in
                Question(id: "\(name).\(tier.rawValue).\(index)", text: text, tier: tier)
            }
        }
    }
}
