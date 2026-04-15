import SwiftUI

struct MenuDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let menuItem: MenuItem
    @State private var isShowingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            if let photoData = Data(base64Encoded: menuItem.photoDataBase64),
               let uiImage = UIImage(data: photoData) {
                Section("Photo") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            Section("Ingredients") {
                Text(menuItem.ingredients.blankFallback("No ingredients entered yet."))
                    .textSelection(.enabled)
            }

            Section("Instructions") {
                Text(menuItem.instructions.blankFallback("No cooking instructions entered yet."))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(menuItem.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(isDeleting)
            }
        }
        .confirmationDialog(
            "Delete this recipe?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Recipe", role: .destructive) {
                Task {
                    isDeleting = true
                    if await appModel.delete(menuItem: menuItem) {
                        dismiss()
                    }
                    isDeleting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(menuItem.name) from your recipe list.")
        }
    }
}

private extension String {
    func blankFallback(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
