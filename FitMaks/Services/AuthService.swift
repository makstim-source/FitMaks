import AuthenticationServices
import Security

@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var isSignedIn = false
    private(set) var isChecking = true
    private(set) var lastError: String?

    private let userIDKey = "com.fitmaks.appleUserID"

    init() {
        checkExistingCredential()
    }

    func checkExistingCredential() {
        guard let userID = keychainRead(key: userIDKey) else {
            isSignedIn = false
            isChecking = false
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                self?.isSignedIn = (state == .authorized)
                self?.isChecking = false
            }
        }
    }

    func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        lastError = nil

        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                lastError = "Unexpected credential type"
                return
            }
            keychainSave(key: userIDKey, value: credential.user)

            if let fullName = credential.fullName {
                let name = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !name.isEmpty {
                    UserDefaults.standard.set(name, forKey: "appleUserName")
                }
            }

            if let email = credential.email {
                UserDefaults.standard.set(email, forKey: "appleUserEmail")
            }

            isSignedIn = true
            ICloudSettingsSync.pushToICloud()

        case .failure(let error):
            let code = (error as? ASAuthorizationError)?.code
            if code == .canceled { return }
            lastError = error.localizedDescription
            print("[AuthService] Sign in failed: \(error)")
        }
    }

    func signOut() {
        keychainDelete(key: userIDKey)
        isSignedIn = false
    }

    var displayName: String? {
        UserDefaults.standard.string(forKey: "appleUserName")
    }

    var email: String? {
        UserDefaults.standard.string(forKey: "appleUserEmail")
    }

    // MARK: - Keychain

    private func keychainSave(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private func keychainRead(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
