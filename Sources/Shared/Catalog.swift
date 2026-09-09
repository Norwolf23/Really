import Foundation

/// The apps we suggest in onboarding. Bundle ids are readable only inside the shield configuration extension
/// (to pick a pack); names and URL schemes drive the suggestion tiles and the "Open X" button.
enum Catalog {
    struct Entry: Identifiable, Equatable {
        let bundleID: String
        let name: String
        let scheme: String
        let pack: String
        var id: String { bundleID }
    }

    // ponytail: Swift literal. Move to a file when packs become a product.
    static let entries: [Entry] = [
        Entry(bundleID: "com.burbn.instagram", name: "Instagram", scheme: "instagram://", pack: "instagram"),
        Entry(bundleID: "com.zhiliaoapp.musically", name: "TikTok", scheme: "tiktok://", pack: "tiktok"),
        Entry(bundleID: "com.toyopagroup.picaboo", name: "Snapchat", scheme: "snapchat://", pack: "snapchat"),
        Entry(bundleID: "com.google.ios.youtube", name: "YouTube", scheme: "youtube://", pack: "youtube"),
        Entry(bundleID: "com.atebits.Tweetie2", name: "X", scheme: "twitter://", pack: "generic"),
        Entry(bundleID: "com.reddit.Reddit", name: "Reddit", scheme: "reddit://", pack: "generic"),
        Entry(bundleID: "com.facebook.Facebook", name: "Facebook", scheme: "fb://", pack: "generic"),
        Entry(bundleID: "com.burbn.barcelona", name: "Threads", scheme: "barcelona://", pack: "generic"),
    ]

    static func pack(for bundleID: String) -> String {
        entries.first { $0.bundleID == bundleID }?.pack ?? "generic"
    }
}
