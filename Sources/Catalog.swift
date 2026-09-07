import Foundation

struct CatalogEntry: Identifiable {
    let id: String
    let name: String
    let urlScheme: String
    let sessionMinutes: Int
}

enum Catalog {
    // ponytail: Swift literal, not JSON. Move to a file when packs become a product.
    static let entries: [CatalogEntry] = [
        CatalogEntry(id: "instagram", name: "Instagram", urlScheme: "instagram://", sessionMinutes: 12),
        CatalogEntry(id: "tiktok", name: "TikTok", urlScheme: "tiktok://", sessionMinutes: 20),
        CatalogEntry(id: "youtube", name: "YouTube", urlScheme: "youtube://", sessionMinutes: 18),
        CatalogEntry(id: "x", name: "X", urlScheme: "twitter://", sessionMinutes: 10),
        CatalogEntry(id: "reddit", name: "Reddit", urlScheme: "reddit://", sessionMinutes: 15),
        CatalogEntry(id: "snapchat", name: "Snapchat", urlScheme: "snapchat://", sessionMinutes: 6),
        CatalogEntry(id: "facebook", name: "Facebook", urlScheme: "fb://", sessionMinutes: 10),
        CatalogEntry(id: "threads", name: "Threads", urlScheme: "barcelona://", sessionMinutes: 10),
    ]

    static func gatedApp(_ entry: CatalogEntry) -> GatedApp {
        GatedApp(id: entry.id, name: entry.name, urlScheme: entry.urlScheme, sessionMinutes: entry.sessionMinutes)
    }

    static func custom(name: String, urlScheme: String) -> GatedApp {
        GatedApp(id: "custom-" + UUID().uuidString.lowercased(), name: name, urlScheme: urlScheme, sessionMinutes: 10)
    }
}
