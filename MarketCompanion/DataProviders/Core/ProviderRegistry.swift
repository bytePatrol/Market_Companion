// ProviderRegistry.swift
// MarketCompanion
//
// Central registry of all available market data providers.

import Foundation

final class ProviderRegistry: @unchecked Sendable {
    static let shared = ProviderRegistry()

    private var providers: [ProviderID: MarketDataProvider] = [:]
    private var rateLimiters: [ProviderID: RateLimiter] = [:]

    private init() {
        registerAll()
    }

    // For testing
    init(providers: [MarketDataProvider]) {
        for provider in providers {
            self.providers[provider.providerID] = provider
            self.rateLimiters[provider.providerID] = RateLimiter(
                provider: provider.providerID,
                config: .forProvider(provider.providerID)
            )
        }
    }

    // MARK: - Registration

    private func registerAll() {
        let allProviders: [MarketDataProvider] = [
            MockMarketDataProvider(),
            FinnhubProvider(),
            AlpacaProvider(),
            AlphaVantageProvider(),
            MarketStackProvider(),
            EODHDProvider(),
            MassiveProvider(),
            DataBentoProvider(),
            ThetaDataProvider(),
        ]

        for provider in allProviders {
            providers[provider.providerID] = provider
            rateLimiters[provider.providerID] = RateLimiter(
                provider: provider.providerID,
                config: .forProvider(provider.providerID)
            )
        }
    }

    // MARK: - Access

    func provider(for id: ProviderID) -> MarketDataProvider? {
        providers[id]
    }

    func rateLimiter(for id: ProviderID) -> RateLimiter? {
        rateLimiters[id]
    }

    var allProviders: [MarketDataProvider] {
        ProviderID.allCases.compactMap { providers[$0] }
    }

    var allProviderIDs: [ProviderID] {
        ProviderID.allCases
    }

    func hasCredentials(for id: ProviderID) -> Bool {
        if id == .mock { return true }
        let keychain = KeychainService.shared
        return keychain.readProviderSecret(providerID: id, key: "api_key") != nil
    }
}
