import Foundation

enum SettingsStore {
    static let appGroupID = "group.com.philstephens.Bookmarks"
    private static let baseURLKey = "apiBaseURL"
    private static let apiKeyKey = "apiKey"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var baseURL: String {
        get { defaults?.string(forKey: baseURLKey) ?? "" }
        set { defaults?.set(newValue, forKey: baseURLKey) }
    }

    static var apiKey: String {
        get { defaults?.string(forKey: apiKeyKey) ?? "" }
        set { defaults?.set(newValue, forKey: apiKeyKey) }
    }
}
