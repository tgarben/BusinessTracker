import SwiftUI

struct PlaceholderView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
        }
    }
}
