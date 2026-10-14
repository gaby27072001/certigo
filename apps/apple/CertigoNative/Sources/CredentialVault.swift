import Foundation
import Security

enum CredentialVaultError: Error {
    case status(OSStatus)
    case invalidItem
}
struct CredentialVault: DeveloperConnectionVault {
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.certigo.native.dev.session",
            kSecAttrAccount as String: "developer-connection",
        ]
    }

    func read() throws -> DeveloperConnection? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialVaultError.status(status) }
        guard let data = value as? Data else { throw CredentialVaultError.invalidItem }
        return try JSONDecoder().decode(DeveloperConnection.self, from: data)
    }

    func save(_ connection: DeveloperConnection) throws {
        let data = try JSONEncoder().encode(connection)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw CredentialVaultError.status(updated) }
        let inserted = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard inserted == errSecSuccess else { throw CredentialVaultError.status(inserted) }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialVaultError.status(status)
        }
    }
}
