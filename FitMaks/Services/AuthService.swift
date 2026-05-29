import AuthenticationServices
import Security
import UIKit

@Observable
final class AuthService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AuthService()

    private(set) var isSignedIn = false
    private(set) var isChecking = true
    private(set) var lastError: String?

    private let userIDKey = "com.fitmaks.appleUserID"
    private var signInCompletion: (() -> Void)?

    override init() {
        super.init()
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

    func startSignIn(completion: (() -> Void)? = nil) {
        lastError = nil
        signInCompletion = completion

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
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
        signInCompletion?()
        signInCompletion = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let code = (error as? ASAuthorizationError)?.code
        if code == .canceled {
            signInCompletion = nil
            return
        }
        lastError = error.localizedDescription
        print("[AuthService] Sign in failed: \(error)")
        signInCompletion = nil
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
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            print("[AuthService] Keychain save failed for \(key): \(status)")
        }
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
