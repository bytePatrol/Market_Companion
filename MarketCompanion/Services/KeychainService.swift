// KeychainService.swift
// MarketCompanion
//
// Secure storage for API keys and sensitive data via macOS Keychain.
// Supports both legacy keyed access and per-provider secret storage.

import Foundation
import Security

final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()

    private let serviceName = "com.marketcompanion.keys"
    private let providerServicePrefix = "com.marketcompanion.provider"

    // MARK: - Legacy Key Names

    enum KeyName: String, CaseIterable {
        case marketDataAPIKey = "market_data_api_key"
        case marketDataBaseURL = "market_data_base_url"
    }

    // MARK: - Generic Save/Read/Delete (private helpers)

    private func saveRaw(service: String, account: String, value: String) throws {
        let data = Data(value.utf8)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func readRaw(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteRaw(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Legacy Key-based Access

    func save(key: KeyName, value: String) throws {
        try saveRaw(service: serviceName, account: key.rawValue, value: value)
    }

    func read(key: KeyName) -> String? {
        readRaw(service: serviceName, account: key.rawValue)
    }

    func delete(key: KeyName) throws {
        try deleteRaw(service: serviceName, account: key.rawValue)
    }

    func hasKey(_ key: KeyName) -> Bool {
        read(key: key) != nil
    }

    // MARK: - Per-Provider Secret Access

    private func providerService(for providerID: ProviderID) -> String {
        "\(providerServicePrefix).\(providerID.rawValue)"
    }

    func saveProviderSecret(providerID: ProviderID, key: String, value: String) throws {
        try saveRaw(service: providerService(for: providerID), account: key, value: value)
    }

    func readProviderSecret(providerID: ProviderID, key: String) -> String? {
        readRaw(service: providerService(for: providerID), account: key)
    }

    func deleteProviderSecret(providerID: ProviderID, key: String) throws {
        try deleteRaw(service: providerService(for: providerID), account: key)
    }

    func deleteAllProviderSecrets(providerID: ProviderID) throws {
        let knownKeys = ["api_key", "api_secret", "base_url"]
        for key in knownKeys {
            try deleteRaw(service: providerService(for: providerID), account: key)
        }
    }

    func hasProviderCredentials(providerID: ProviderID) -> Bool {
        readProviderSecret(providerID: providerID, key: "api_key") != nil
    }

    // MARK: - Delete All

    func deleteAll() throws {
        for key in KeyName.allCases {
            try delete(key: key)
        }
        for id in ProviderID.allCases where id != .mock {
            try deleteAllProviderSecrets(providerID: id)
        }
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}
