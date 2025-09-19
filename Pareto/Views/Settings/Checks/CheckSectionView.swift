import SwiftUI

struct CheckSectionView: View {
    let claimTitle: String
    let installedChecks: [ParetoCheck]
    let onSelect: (ParetoCheck) -> Void

    var body: some View {
        if !installedChecks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(claimTitle)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 1) {
                    ForEach(installedChecks, id: \.UUID) { check in
                        CheckRowView(check: check) {
                            onSelect(check)
                        }

                        if check.UUID != installedChecks.last?.UUID {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
        }
    }
}
