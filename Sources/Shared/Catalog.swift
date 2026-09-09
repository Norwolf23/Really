import Foundation

/// Bundle id → question pack. Only the shield configuration extension can read bundle ids.
enum Catalog {
    // ponytail: Swift literal keyed by bundle id. Move to a file when packs become a product.
    static let packs: [String: String] = [
        "com.burbn.instagram": "instagram",
        "com.zhiliaoapp.musically": "tiktok",
        "com.google.ios.youtube": "youtube",
        "com.atebits.Tweetie2": "x",
        "com.reddit.Reddit": "reddit",
        "com.toyopagroup.picaboo": "snapchat",
        "com.facebook.Facebook": "facebook",
        "com.burbn.barcelona": "threads",
    ]

    static func pack(for bundleID: String) -> String {
        packs[bundleID] ?? "generic"
    }
}
