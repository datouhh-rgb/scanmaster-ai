import Foundation
import SwiftUI
import UIKit

struct LocalImageView: View {
    let data: Data?
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Color(uiColor: .tertiarySystemFill)
                    Image(systemName: "doc.text.image")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
    }
}
