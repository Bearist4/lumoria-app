//
//  PurchaseService.swift
//  Lumoria App
//
//  Wraps StoreKit 2 product fetch + purchase + verification, then posts
//  the verified Transaction's productId / transactionId / expiresAt to
//  `set_premium_from_transaction` so the server profile mirrors the
//  paid state. Refreshes EntitlementStore on success so every gate
//  picks up the new tier without a manual reload.
//
//  Phase 2 trusts StoreKit's local verification of the Transaction
//  payload. Phase 5 will add server-side push verification (ASSN2)
//  to close the residual trust gap.
//

import Foundation
import StoreKit
import Supabase
import Observation

@MainActor
@Observable
final class PurchaseService {

    enum Failure: Error, Equatable {
        case notSignedIn
        case verificationFailed
        case rpcFailed(String)
        case storeKitError(String)
    }

    private(set) var products: [PaywallPlan: Product] = [:]
    private(set) var isPurchasing: Bool = false
    private(set) var lastError: Failure? = nil

    private let entitlement: EntitlementStore

    init(entitlement: EntitlementStore) {
        self.entitlement = entitlement
    }

    /// Fetch the three known products. Idempotent — call on paywall
    /// appear; cached afterwards.
    func loadProducts() async {
        do {
            let ids = PaywallPlan.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            var byPlan: [PaywallPlan: Product] = [:]
            for p in fetched {
                if let plan = PaywallPlan(rawValue: p.id) {
                    byPlan[plan] = p
                }
            }
            self.products = byPlan
        } catch {
            self.lastError = .storeKitError(error.localizedDescription)
        }
    }

    func displayPrice(for plan: PaywallPlan) -> String? {
        products[plan]?.displayPrice
    }

    /// Run a full purchase. Returns true on success.
    @discardableResult
    func purchase(_ plan: PaywallPlan) async -> Bool {
        guard let product = products[plan] else { return false }
        guard let uid = supabase.auth.currentUser?.id else {
            lastError = .notSignedIn
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase(options: [
                .appAccountToken(uid)
            ])
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                try await markPremiumOnServer(
                    transaction: transaction,
                    product: product
                )
                await transaction.finish()
                await entitlement.refresh()
                return true

            case .userCancelled, .pending:
                return false

            @unknown default:
                return false
            }
        } catch let f as Failure {
            lastError = f
            return false
        } catch {
            lastError = .storeKitError(error.localizedDescription)
            return false
        }
    }

    /// Apple-required: re-sync purchases for users who reinstall or
    /// switch devices.
    @discardableResult
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await entitlement.refresh()
            return true
        } catch {
            lastError = .storeKitError(error.localizedDescription)
            return false
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw Failure.verificationFailed
        }
    }

    private func markPremiumOnServer(
        transaction: Transaction,
        product: Product
    ) async throws {
        struct Params: Encodable {
            let p_product_id: String
            let p_transaction_id: String
            let p_expires_at: String?
        }

        let expiresAt: Date? = product.subscription != nil
            ? transaction.expirationDate
            : nil

        let params = Params(
            p_product_id: product.id,
            p_transaction_id: String(transaction.id),
            p_expires_at: expiresAt.map {
                ISO8601DateFormatter().string(from: $0)
            }
        )

        do {
            try await supabase.rpc("set_premium_from_transaction", params: params).execute()
        } catch {
            throw Failure.rpcFailed(error.localizedDescription)
        }
    }
}
