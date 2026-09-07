import Foundation

enum Tier: String, Codable, CaseIterable, Comparable {
    case normal, annoyed, brutal

    var label: String { rawValue.capitalized }

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rank < rhs.rank }
}

enum QuestionSource: String, Codable, CaseIterable {
    case starterPack, custom
}

enum QuestionMode: String, Codable, CaseIterable {
    case single, rotate
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

struct GatedApp: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var urlScheme: String
    var sessionMinutes: Int
    var enabled = true
    var source = QuestionSource.starterPack
    var mode = QuestionMode.rotate
    var singleQuestionID: String? = nil
    var pauseSeconds = 5
    var cooldownMinutes = 15
    var annoyedAt = 3
    var brutalAt = 6
    var customQuestions: [Question] = []
    var lastQuestionID: String? = nil
    var cooldownUntil: Date? = nil
    var lastCheckIn: Date? = nil
}

struct CheckIn: Codable, Identifiable, Equatable {
    var id = UUID()
    var appID: String
    var at: Date
    var decision: Decision
    var reason: String? = nil
}

struct Settings: Codable, Equatable {
    var hasOnboarded = false
    var meanness = Tier.normal
    var escalates = true
}
