import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate = Date()
    @State private var activeMealSlot: MealSlot?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleRow
                Color.clear.frame(height: 10)

                if !appModel.isSupabaseConfigured {
                    missingConfigCard
                }

                monthHeader
                weekdayHeader

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(monthDates, id: \.self) { date in
                        CalendarDayButton(
                            date: date,
                            isInDisplayedMonth: Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            assignment: appModel.assignment(for: date)
                        ) {
                            selectedDate = date
                        }
                    }
                }

                selectedDayPanel
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeMealSlot) { slot in
            NavigationStack {
                MealPickerSheet(date: selectedDate, slot: slot)
            }
        }
    }

    private var titleRow: some View {
        Text("GVCS-B Meal Planner")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var missingConfigCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supabase Setup Needed")
                .font(.headline)
                .foregroundStyle(.black)
            Text("Add your real Supabase URL and anon key in Secrets.xcconfig. The app will show your calendar data after that connection is in place.")
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.65))
        }
        .padding()
        .background(Color.yellow.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.yellow)
            }

            Spacer()

            Text(DateFormatting.monthTitle.string(from: displayedMonth))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.yellow)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdayLabel(for: index))
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(weekdayColor(for: index))
            }
        }
    }

    private var monthDates: [Date] {
        Calendar.current.calendarGridDates(for: displayedMonth)
    }

    private var selectedDayPanel: some View {
        let assignment = appModel.assignment(for: selectedDate)
        let lunchItem = appModel.menuItem(id: assignment?.lunchMenuItemID)
        let dinnerItem = appModel.menuItem(id: assignment?.dinnerMenuItemID)
        return HStack(spacing: 12) {
            mealSummaryCard(title: "Lunch", color: .yellow, item: lunchItem) {
                activeMealSlot = .lunch
            }
            mealSummaryCard(title: "Dinner", color: .orange, item: dinnerItem) {
                activeMealSlot = .dinner
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func mealSummaryCard(title: String, color: Color, item: MenuItem?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(color)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.gray)
                }

                Text(item?.name ?? "None")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                if let item,
                   let photoData = Data(base64Encoded: item.photoDataBase64),
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 96)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundStyle(.gray)
                        }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
            .padding(12)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func weekdayLabel(for index: Int) -> String {
        switch index {
        case 0: return "SU"
        case 1: return "MO"
        case 2: return "TU"
        case 3: return "WE"
        case 4: return "TH"
        case 5: return "FR"
        default: return "SA"
        }
    }

    private func weekdayColor(for index: Int) -> Color {
        switch index {
        case 0: return .red
        case 6: return .orange
        default: return .white.opacity(0.9)
        }
    }
}

private struct CalendarDayButton: View {
    let date: Date
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let assignment: DailyMenuAssignment?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(dayNumberColor)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    if assignment?.lunchMenuItemID != nil {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 5, height: 5)
                    }
                    if assignment?.dinnerMenuItemID != nil {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var dayNumberColor: Color {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1:
            return isInDisplayedMonth ? .red : .red.opacity(0.35)
        case 7:
            return isInDisplayedMonth ? .orange : .orange.opacity(0.35)
        default:
            return isInDisplayedMonth ? .white : .white.opacity(0.35)
        }
    }
}

private struct CalendarAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let date: Date

    @State private var selectedLunchID: UUID?
    @State private var selectedDinnerID: UUID?
    @State private var isWorking = false

    var body: some View {
        Form {
            Section("Selected Date") {
                Text(DateFormatting.longDate.string(from: date))
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
                        isWorking = true
                        if await appModel.saveAssignment(for: date, lunchID: selectedLunchID, dinnerID: selectedDinnerID) {
                            dismiss()
                        }
                        isWorking = false
                    }
                } label: {
                    if isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Menus for This Day")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isWorking)
            }
        }
        .navigationTitle("Daily Menus")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear {
            let assignment = appModel.assignment(for: date)
            selectedLunchID = assignment?.lunchMenuItemID
            selectedDinnerID = assignment?.dinnerMenuItemID
        }
    }
}

private enum MealSlot: String, Identifiable {
    case lunch
    case dinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        }
    }
}

private struct MealPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel

    let date: Date
    let slot: MealSlot

    @State private var isSaving = false

    var body: some View {
        List {
            Section(DateFormatting.longDate.string(from: date)) {
                selectionRow(title: "None", id: nil)

                ForEach(availableItems) { item in
                    selectionRow(title: item.name, id: item.id)
                }
            }
        }
        .navigationTitle("Pick \(slot.title)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var availableItems: [MenuItem] {
        switch slot {
        case .lunch:
            return appModel.activeMenuItems.filter(\.supportsLunch)
        case .dinner:
            return appModel.activeMenuItems.filter(\.supportsDinner)
        }
    }

    @ViewBuilder
    private func selectionRow(title: String, id: UUID?) -> some View {
        Button {
            Task {
                await saveSelection(id)
            }
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if currentSelectionID == id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.yellow)
                }
                if isSaving, currentSelectionID == id {
                    ProgressView()
                }
            }
        }
        .disabled(isSaving)
    }

    private var currentSelectionID: UUID? {
        let assignment = appModel.assignment(for: date)
        switch slot {
        case .lunch:
            return assignment?.lunchMenuItemID
        case .dinner:
            return assignment?.dinnerMenuItemID
        }
    }

    private func saveSelection(_ chosenID: UUID?) async {
        let assignment = appModel.assignment(for: date)
        let lunchID = slot == .lunch ? chosenID : assignment?.lunchMenuItemID
        let dinnerID = slot == .dinner ? chosenID : assignment?.dinnerMenuItemID

        isSaving = true
        if await appModel.saveAssignment(for: date, lunchID: lunchID, dinnerID: dinnerID) {
            dismiss()
        }
        isSaving = false
    }
}

private extension Calendar {
    func startOfMonth(for inputDate: Date) -> Date {
        date(from: dateComponents([.year, .month], from: inputDate)) ?? inputDate
    }

    func calendarGridDates(for month: Date) -> [Date] {
        guard
            let monthInterval = dateInterval(of: .month, for: month),
            let firstWeek = dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else {
            return []
        }

        var dates: [Date] = []
        var current = firstWeek.start
        while current < lastWeek.end {
            dates.append(current)
            current = date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86_400)
        }
        return dates
    }
}

private extension String {
    var previewText: String {
        let cleaned = trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Ingredients coming soon." : cleaned
    }
}
