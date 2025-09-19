import SwiftUI

struct TeamEnforcementHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Checks marked with ✴ are enforced by your team and cannot be disabled.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 10)
        }
    }
}
