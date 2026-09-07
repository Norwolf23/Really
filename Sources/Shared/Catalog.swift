import Foundation

enum Catalog {
    struct Entry: Equatable {
        let pack: String
        let sessionMinutes: Int
    }

    // ponytail: Swift literal keyed by bundle id. Move to a file when packs become a product.
    static let entries: [String: Entry] = [
        "com.burbn.instagram": Entry(pack: "instagram", sessionMinutes: 12),
        "com.zhiliaoapp.musically": Entry(pack: "tiktok", sessionMinutes: 20),
        "com.google.ios.youtube": Entry(pack: "youtube", sessionMinutes: 18),
        "com.atebits.Tweetie2": Entry(pack: "x", sessionMinutes: 10),
        "com.reddit.Reddit": Entry(pack: "reddit", sessionMinutes: 15),
        "com.toyopagroup.picaboo": Entry(pack: "snapchat", sessionMinutes: 6),
        "com.facebook.Facebook": Entry(pack: "facebook", sessionMinutes: 10),
        "com.burbn.barcelona": Entry(pack: "threads", sessionMinutes: 10),
    ]

    static func pack(for bundleID: String) -> String {
        entries[bundleID]?.pack ?? "generic"
    }

    static func sessionMinutes(for bundleID: String) -> Int {
        entries[bundleID]?.sessionMinutes ?? 10
    }
}
