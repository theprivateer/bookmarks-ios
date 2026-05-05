import SwiftUI

enum ShareState {
    case loading
    case success
    case failure(String)
}

struct ShareExtensionView: View {
    let state: ShareState
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                Text("Saving…")
                    .foregroundStyle(.secondary)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                Text("Saved")
                    .font(.headline)
            case .failure(let message):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
