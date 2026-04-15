//
//  KeychainStore.swift
//  Lumoria App
//
//  Thin wrapper around SecItem for storing a per-user symmetric data key.
//  Items are scoped by the Supabase user id and synced through iCloud
//  Keychain (`kSecAttrSynchronizable`) so the same user sees the same
//  ciphertext across their devices.
//

import Foundation
import Security

enum KeychainStoreError: Error {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedFormat
}

enum KeychainStore {
    static let service = "com.lumoria.datakey"

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
    }

    static func save(_ data: Data, account: String) throws {
        var add = baseQuery(account: account)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updates: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(
                baseQuery(account: account) as CFDictionary,
                updates as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.saveFailed(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainStoreError.saveFailed(status)
        }
    }

    static func read(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainStoreError.readFailed(status)
        }
        guard let data = result as? Data else {
            throw KeychainStoreError.unexpectedFormat
        }
        return data
    }

    static func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.deleteFailed(status)
        }
    }
}
