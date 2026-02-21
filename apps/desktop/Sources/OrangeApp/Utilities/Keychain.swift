import Foundation

struct Keychain {
    static func save(_ value: String, for key: String) {
        UserDefaults.standard.set(value, forKey: "keychain.\(key)")
    }

    static func load(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: "keychain.\(key)")
    }
}
