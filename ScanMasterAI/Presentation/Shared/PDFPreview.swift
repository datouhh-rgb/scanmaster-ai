import PDFKit
import SwiftUI

struct PDFPreview: UIViewRepresentable {
    let url: URL
    let version: Date?

    init(url: URL, version: Date? = nil) {
        self.url = url
        self.version = version
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(version: version)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        context.coordinator.version = version
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url || context.coordinator.version != version {
            uiView.document = PDFDocument(url: url)
            context.coordinator.version = version
        }
    }

    final class Coordinator {
        var version: Date?

        init(version: Date?) {
            self.version = version
        }
    }
}
