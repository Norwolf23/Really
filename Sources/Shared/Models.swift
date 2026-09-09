import FamilyControls
import Foundation
import ManagedSettings

enum Tier: String, Codable, CaseIterable, Comparable {
    case normal, annoyed, brutal

    var label: String { rawValue.capitalized }

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rank < rhs.rank }
}

enum Decision: String, Codable {
    case proceed = "continue"
    case no
}

struct Question: Codable, Identifiable, Hashable {
    var id: String
    var text: String
    var tier: Tier
}

/// One shield answer. `appID` is the app's opaque token, base64-encoded (see `TokenID`); the app renders it with `Label(token)`.
struct CheckIn: Codable, Identifiable, Equatable {
    var id = UUID()
    var appID: String
    var at: Date
    var decision: Decision
}

/// Bundle ids and names are readable only inside the shield configuration extension, which can't write anything.
/// The token itself is available everywhere, so it is the app id.
enum TokenID {
    static func string(_ token: ApplicationToken) -> String {
        (try? JSONEncoder().encode(token))?.base64EncodedString() ?? "unknown"
    }

    static func token(_ id: String) -> ApplicationToken? {
        Data(base64Encoded: id).flatMap { try? JSONDecoder().decode(ApplicationToken.self, from: $0) }
    }
}

/// Written by the app only.
struct Settings: Codable, Equatable {
    var hasOnboarded = false
    var meanness = Tier.normal
    var escalates = true
    var cooldownMinutes = 15 // DeviceActivity schedules can't be shorter than 15 min
    var annoyedAt = 3
    var brutalAt = 6
    /// includeEntireCategory: a ticked category expands into app tokens, so category picks shield something.
    var selection = FamilyActivitySelection(includeEntireCategory: true)

    init() {}

    /// Missing keys fall back to defaults, so adding a field never makes an old settings.json undecodable.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? hasOnboarded
        meanness = try c.decodeIfPresent(Tier.self, forKey: .meanness) ?? meanness
        escalates = try c.decodeIfPresent(Bool.self, forKey: .escalates) ?? escalates
        cooldownMinutes = try c.decodeIfPresent(Int.self, forKey: .cooldownMinutes) ?? cooldownMinutes
        annoyedAt = try c.decodeIfPresent(Int.self, forKey: .annoyedAt) ?? annoyedAt
        brutalAt = try c.decodeIfPresent(Int.self, forKey: .brutalAt) ?? brutalAt
        selection = try c.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection) ?? selection
    }
}

/// Written by the shield extensions only.
struct ShieldState: Codable, Equatable {
    var cooldowns: [String: Date] = [:]
    var lastQuestion: [String: String] = [:]
    /// Diagnostic: which button the action extension last handled.
    var lastAction: String? = nil
}
