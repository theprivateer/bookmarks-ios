import SwiftUI

struct SettingsView: View {
    @State private var baseURL = SettingsStore.baseURL
    @State private var apiKey = SettingsStore.apiKey
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("API Configuration") {
                    TextField("Base URL", text: $baseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Button("Save") {
                        SettingsStore.baseURL = baseURL
                        SettingsStore.apiKey = apiKey
                        saved = true
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .alert("Saved", isPresented: $saved) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
}
