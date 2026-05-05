import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var state: ShareState = .loading {
        didSet { hostingController?.rootView = makeView() }
    }
    private var hostingController: UIHostingController<ShareExtensionView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        embed(UIHostingController(rootView: makeView()))
        Task { await run() }
    }

    private func makeView() -> ShareExtensionView {
        ShareExtensionView(state: state) { [weak self] in self?.finish() }
    }

    private func embed(_ hc: UIHostingController<ShareExtensionView>) {
        addChild(hc)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hc.view)
        hc.didMove(toParent: self)
        hostingController = hc
    }

    private func run() async {
        guard let url = await extractURL() else {
            state = .failure("Could not read the shared URL.")
            return
        }
        do {
            try await BookmarkAPIClient.createBookmark(url: url)
            state = .success
            try? await Task.sleep(for: .seconds(1))
            finish()
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    private func extractURL() async -> URL? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: {
                  $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
              }) else { return nil }
        return try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
