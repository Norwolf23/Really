import SwiftUI

struct ReasonSheet: View {
    let reasons: [String]
    let choose: (String) -> Void

    @State private var other = ""
    @State private var showOther = false
    @FocusState private var otherFocused: Bool

    private var trimmed: String { other.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 14) {
            Text("Why?")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .padding(.top, 28)
            ForEach(reasons, id: \.self) { reason in
                Button {
                    choose(reason)
                } label: {
                    Text(reason).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
            if showOther {
                HStack {
                    TextField("Go on then", text: $other)
                        .textFieldStyle(.roundedBorder)
                        .focused($otherFocused)
                        .onSubmit { if !trimmed.isEmpty { choose(trimmed) } }
                    Button {
                        choose(trimmed)
                    } label: {
                        Text("Go").foregroundStyle(.black).padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .disabled(trimmed.isEmpty)
                }
            } else {
                Button("Other") {
                    showOther = true
                    otherFocused = true
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .presentationDetents([.medium])
        .presentationBackground(.black)
    }
}
