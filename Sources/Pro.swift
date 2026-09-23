import StoreKit
import SwiftUI

enum ProOffer {
    case secondApp
    case fullBlock
    case lines
}

/// StoreKit is the source of truth. `Settings.isPro` is the copy the shield can read.
@MainActor
final class ProStore: ObservableObject {
    static let yearlyID = "studio.nickson.really.pro.yearly"
    static let monthlyID = "studio.nickson.really.pro.monthly"
    static let ids = [yearlyID, monthlyID]

    @Published private(set) var products: [Product] = []
    @Published var offer: ProOffer?
    @Published var purchaseError: String?

    private var store: Store?
    private var updates: Task<Void, Never>?

    func start(_ store: Store) async {
        self.store = store
        updates?.cancel()
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self, case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self.refresh()
            }
        }
        products = (try? await Product.products(for: Self.ids)) ?? []
        products.sort { Self.rank($0) < Self.rank($1) }
        await refresh()
    }

    func refresh() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.ids.contains(transaction.productID), transaction.revocationDate == nil else { continue }
            unlocked = true
        }
        guard let store else { return }
        let was = store.settings.isPro
        if was != unlocked { store.settings.isPro = unlocked }
        if was && !unlocked {
            let lapse = Logic.proLapse(fullBlockEnabled: store.settings.fullBlockEnabled, offAt: store.settings.fullBlockOffAt, now: .now)
            store.settings.fullBlockEnabled = lapse.enabled
            store.settings.fullBlockOffAt = lapse.offAt
        }
        Shield.apply(store)
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "The App Store could not verify that purchase."
                    return
                }
                await transaction.finish()
                let turningOnBlock = offer == .fullBlock
                await refresh()
                if turningOnBlock, store?.settings.isPro == true {
                    store?.settings.fullBlockEnabled = true
                    store?.settings.fullBlockOffAt = nil
                    if let store { Shield.apply(store) }
                }
                offer = nil
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private static func rank(_ product: Product) -> Int {
        product.id == yearlyID ? 0 : 1
    }
}

struct PaywallView: View {
    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("REALLY PRO")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(.white.opacity(0.45))
            Text("One app stays free.")
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            if pro.products.isEmpty {
                Text("Subscriptions are unavailable right now.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ForEach(pro.products) { product in
                    Button { Task { await pro.purchase(product) } } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.id == ProStore.yearlyID ? "Yearly" : "Monthly")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            Text(priceLine(product))
                                .font(.system(size: 13, design: .monospaced))
                        }
                        .foregroundStyle(product.id == ProStore.yearlyID ? .black : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(product.id == ProStore.yearlyID ? Color.white : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.16), lineWidth: 1))
                    }
                }
            }
            if let purchaseError = pro.purchaseError {
                Text(purchaseError)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.orange)
            }
            Button("Not now") { dismiss() }
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.03, green: 0.035, blue: 0.04).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var detail: String {
        switch pro.offer {
        case .fullBlock:
            "Pro is the lock you cannot undo until tomorrow, every other app, custom lines, and the log of why you went in."
        case .lines:
            "Custom lines are part of Pro, with every other app and Full Block."
        case .secondApp, nil:
            "Pro is every other app, Full Block, custom lines, and the log of why you went in."
        }
    }

    private func priceLine(_ product: Product) -> String {
        let period = product.id == ProStore.yearlyID ? "year" : "month"
        guard let intro = product.subscription?.introductoryOffer, intro.paymentMode == .freeTrial else {
            return "\(product.displayPrice) a \(period)"
        }
        return "\(trialLength(intro.period)) free, then \(product.displayPrice) a \(period)"
    }

    private func trialLength(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: "\(period.value) days"
        case .week: "\(period.value * 7) days"
        case .month: "\(period.value) months"
        case .year: "\(period.value) years"
        @unknown default: "\(period.value) days"
        }
    }
}
