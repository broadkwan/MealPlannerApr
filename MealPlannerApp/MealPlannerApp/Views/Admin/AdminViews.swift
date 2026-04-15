import SwiftUI

struct AdminGateView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if appModel.session == nil {
                AdminSignInView()
            } else {
                AdminDashboardView()
            }
        }
        .navigationTitle("Admin")
    }
}

private struct AdminSignInView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        Form {
            Section("Sign In") {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            }

            Section {
                Button {
                    Task {
                        isSubmitting = true
                        _ = await appModel.signIn(email: email, password: password)
                        isSubmitting = false
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting || email.isEmpty || password.isEmpty)
            }

            Section("Setup") {
                Text("Use a Supabase authenticated user account here. Public browsing stays available without signing in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AdminDashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var draft = MenuItem.empty
    @State private var isShowingCreate = false

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Signed in as", value: appModel.session?.email ?? "")
                Button("Sign Out", role: .destructive) {
                    appModel.signOut()
                }
            }

            Section("Tools") {
                NavigationLink("Edit Calendar Assignments") {
                    AssignmentEditorView()
                }
            }

            Section("Menu Items") {
                ForEach(appModel.activeMenuItems) { item in
                    NavigationLink {
                        MenuEditView(initialItem: item, mode: .edit)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                            Text(item.ingredients.previewLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draft = MenuItem.empty
                    isShowingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingCreate) {
            NavigationStack {
                MenuEditView(initialItem: draft, mode: .create)
            }
        }
    }
}

private struct MenuEditView: View {
    enum Mode: Equatable {
        case create
        case edit

        var title: String {
            switch self {
            case .create: return "New Menu Item"
            case .edit: return "Edit Menu Item"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let mode: Mode

    @State private var id: UUID
    @State private var name: String
    @State private var supportsLunch: Bool
    @State private var supportsDinner: Bool
    @State private var ingredients: String
    @State private var instructions: String
    @State private var isArchived: Bool
    @State private var isSaving = false

    init(initialItem: MenuItem, mode: Mode) {
        self.mode = mode
        _id = State(initialValue: initialItem.id)
        _name = State(initialValue: initialItem.name)
        _supportsLunch = State(initialValue: initialItem.supportsLunch)
        _supportsDinner = State(initialValue: initialItem.supportsDinner)
        _ingredients = State(initialValue: initialItem.ingredients)
        _instructions = State(initialValue: initialItem.instructions)
        _isArchived = State(initialValue: initialItem.isArchived)
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $name)
                Toggle("Supports lunch", isOn: $supportsLunch)
                Toggle("Supports dinner", isOn: $supportsDinner)
                Toggle("Archived", isOn: $isArchived)
            }

            Section("Ingredients") {
                TextEditor(text: $ingredients)
                    .frame(minHeight: 140)
            }

            Section("Instructions") {
                TextEditor(text: $instructions)
                    .frame(minHeight: 180)
            }
            if mode == .edit {
                Section {
                    Button("Archive Item", role: .destructive) {
                        Task {
                            isSaving = true
                            let draft = composeItem(archived: true)
                            if await appModel.archive(menuItem: draft) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    }
                }
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        isSaving = true
                        if await appModel.save(menuItem: composeItem(archived: isArchived)) {
                            dismiss()
                        }
                        isSaving = false
                    }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func composeItem(archived: Bool) -> MenuItem {
        MenuItem(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            supportsLunch: supportsLunch,
            supportsDinner: supportsDinner,
            ingredients: ingredients,
            photoDataBase64: "",
            instructions: instructions,
            isArchived: archived
        )
    }
}

private struct AssignmentEditorView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedDate = Date()
    @State private var selectedLunchID: UUID?
    @State private var selectedDinnerID: UUID?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Service Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .onChange(of: selectedDate, initial: true) { _, newValue in
                        let assignment = appModel.assignment(for: newValue)
                        selectedLunchID = assignment?.lunchMenuItemID
                        selectedDinnerID = assignment?.dinnerMenuItemID
                    }
            }

            Section("Lunch") {
                Picker("Lunch Menu", selection: $selectedLunchID) {
                    Text("None").tag(UUID?.none)
                    ForEach(appModel.activeMenuItems.filter(\.supportsLunch)) { item in
                        Text(item.name).tag(UUID?.some(item.id))
                    }
                }
            }

            Section("Dinner") {
                Picker("Dinner Menu", selection: $selectedDinnerID) {
                    Text("None").tag(UUID?.none)
                    ForEach(appModel.activeMenuItems.filter(\.supportsDinner)) { item in
                        Text(item.name).tag(UUID?.some(item.id))
                    }
                }
            }

            Section {
                Button {
                    Task {
                        isSaving = true
                        _ = await appModel.saveAssignment(
                            for: selectedDate,
                            lunchID: selectedLunchID,
                            dinnerID: selectedDinnerID
                        )
                        isSaving = false
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Assignment")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Assignments")
    }
}

private extension String {
    var previewLine: String {
        let compact = replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? "No ingredients yet" : compact
    }
}
