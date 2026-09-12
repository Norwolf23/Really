import FamilyControls
import SwiftUI

/// Name + icon for an app id from the log. iOS draws it from the opaque token; we never learn the name as text.
struct AppLabel: View {
    let id: String

    var body: some View {
        if let token = TokenID.token(id) {
            Label(token).labelStyle(.titleAndIcon)
        } else {
            Text("Some app")
        }
    }
}
