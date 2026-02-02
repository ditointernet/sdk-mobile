import SwiftUI

struct CardView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    VStack(spacing: 16) {
        CardView(title: "Example Card") {
            VStack(alignment: .leading, spacing: 8) {
                Text("This is a card component")
                Button("Action") { }
            }
        }

        CardView(title: "Another Card") {
            Text("SwiftUI makes UI easy!")
        }
    }
    .padding()
}
