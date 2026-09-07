import FamilyControls
import Foundation

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

/// One shield answer. `appID` is the bundle id the shield extension saw; `appName` its display name.
struct CheckIn: Codable, Identifiable, Equatable {
    var id = UUID()
    var appID: String
    var appName: String
    var at: Date
    var decision: Decision
}

/// Written by the app only.
struct Settings: Codable, Equatable {
    var hasOnboarded = false
    var meanness = Tier.normal
    var escalates = true
    var cooldownMinutes = 15 // DeviceActivity schedules can't be shorter than 15 min
    var annoyedAt = 3
    var brutalAt = 6
    var selection = FamilyActivitySelection()
}

struct Shown: Codable, Equatable {
    var id: String
    var name: String
    var at = Date.now
}

/// Written by the shield extensions only.
struct ShieldState: Codable, Equatable {
    var cooldowns: [String: Date] = [:]
    var lastQuestion: [String: String] = [:]
    /// The app the configuration extension last rendered; the action extension can't read app identity itself.
    var lastShown: Shown? = nil
    /// 1 = first question, 2 = "Do you still want to go through?"
    var round = 1
}
