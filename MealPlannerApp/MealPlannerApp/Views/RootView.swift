import PhotosUI
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                CalendarScreen()
            }
            .tabItem {
                Label("Planner", systemImage: "calendar")
            }

            NavigationStack {
                RecipesView()
            }
            .tabItem {
                Label("Recipes", systemImage: "book.closed")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(.yellow)
        .preferredColorScheme(.dark)
        .toolbarBackground(Color.black, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .overlay(alignment: .top) {
            if let errorMessage = appModel.errorMessage {
                ErrorBanner(message: errorMessage) {
                    appModel.errorMessage = nil
                }
                .padding(.top, 8)
            }
        }
    }
}

private struct RecipesView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isShowingCreateRecipe = false

    private var lunchRecipes: [MenuItem] {
        appModel.activeMenuItems.filter(\.supportsLunch)
    }

    private var dinnerRecipes: [MenuItem] {
        appModel.activeMenuItems.filter(\.supportsDinner)
    }

    var body: some View {
        List {
            if appModel.activeMenuItems.isEmpty {
                ContentUnavailableView(
                    "No Recipes Yet",
                    systemImage: "fork.knife",
                    description: Text("Add your first recipe to start building the menu.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Lunch") {
                    if lunchRecipes.isEmpty {
                        Text("No lunch recipes yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lunchRecipes) { item in
                            recipeRow(for: item)
                        }
                    }
                }

                Section("Dinner") {
                    if dinnerRecipes.isEmpty {
                        Text("No dinner recipes yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dinnerRecipes) { item in
                            recipeRow(for: item)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Recipe") {
                    isShowingCreateRecipe = true
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .sheet(isPresented: $isShowingCreateRecipe) {
            NavigationStack {
                RecipeEditorView(initialItem: MenuItem.empty)
            }
        }
    }

    private func recipeRow(for item: MenuItem) -> some View {
        NavigationLink {
            RecipeEditorView(initialItem: item)
        } label: {
            Text(item.name)
                .font(.headline)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    _ = await appModel.delete(menuItem: item)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        List {
            Section("Connection Status") {
                LabeledContent("Supabase", value: appModel.isSupabaseConfigured ? "Connected" : "Not Configured")
            }

            Section("Project URL") {
                Text(appModel.configuredSupabaseURL)
                    .textSelection(.enabled)
                    .font(.footnote.monospaced())
            }

            Section("Notes") {
                Text("This app reads recipes and daily meal assignments from your Supabase project. The project URL is okay to view, but write access is still controlled by your Supabase keys and table policies.")
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Settings")
    }
}

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer()
            Button("Dismiss", action: dismiss)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(.red.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

private struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    @State private var id: UUID
    @State private var name: String
    @State private var supportsLunch: Bool
    @State private var supportsDinner: Bool
    @State private var ingredients: String
    @State private var instructions: String
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isSaving = false

    init(initialItem: MenuItem) {
        _id = State(initialValue: initialItem.id)
        _name = State(initialValue: initialItem.name)
        _supportsLunch = State(initialValue: initialItem.supportsLunch)
        _supportsDinner = State(initialValue: initialItem.supportsDinner)
        _ingredients = State(initialValue: initialItem.ingredients)
        _instructions = State(initialValue: initialItem.instructions)
        if let decodedData = Data(base64Encoded: initialItem.photoDataBase64), !initialItem.photoDataBase64.isEmpty {
            _photoData = State(initialValue: decodedData)
        } else {
            _photoData = State(initialValue: nil)
        }
        _selectedPhotoItem = State(initialValue: nil)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Recipe Name", text: $name)
            }

            Section("Meal Type") {
                Toggle("Lunch", isOn: $supportsLunch)
                Toggle("Dinner", isOn: $supportsDinner)
            }

            Section("Ingredients") {
                TextEditor(text: $ingredients)
                    .frame(minHeight: 140)
            }

            Section("Photo") {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    photoBox
                }
                .buttonStyle(.plain)

                if isLoadingPhoto {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading photo...")
                            .foregroundStyle(.secondary)
                    }
                }

                if photoData != nil {
                    Button("Remove Photo", role: .destructive) {
                        photoData = nil
                        selectedPhotoItem = nil
                    }
                }
            }

            Section("Instructions") {
                TextEditor(text: $instructions)
                    .frame(minHeight: 180)
            }
        }
        .navigationTitle(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Recipe" : "Edit Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        isSaving = true
                        if await appModel.save(menuItem: composeItem()) {
                            dismiss()
                        }
                        isSaving = false
                    }
                }
                .disabled(
                    isSaving ||
                    isLoadingPhoto ||
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (!supportsLunch && !supportsDinner)
                )
            }
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
    }

    private func composeItem() -> MenuItem {
        MenuItem(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            supportsLunch: supportsLunch,
            supportsDinner: supportsDinner,
            ingredients: ingredients,
            photoDataBase64: photoData?.base64EncodedString() ?? "",
            instructions: instructions,
            isArchived: false
        )
    }

    private var photoBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [6]))
                )

            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 30))
                        .foregroundStyle(.yellow)
                    Text("Choose Photo")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Pick a recipe photo from your iPhone Photos app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data),
           let normalizedData = normalizedPhotoData(from: uiImage) {
            photoData = normalizedData
        }
    }

    private func normalizedPhotoData(from image: UIImage) -> Data? {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1

        let maxDimension: CGFloat = 1400
        let sourceSize = image.size
        let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)

        let renderedImage = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return renderedImage.jpegData(compressionQuality: 0.82)
    }
}
