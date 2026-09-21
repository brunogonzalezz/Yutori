import SwiftUI
import UIKit

extension CourseColor {
    static let selectable: [CourseColor] = [.red, .orange, .lemon, .moss, .green, .teal, .pink, .indigo, .purple, .blue, .sky, .sand]

    var chartTint: Color { tint }
    var iconTint: Color { .white }

    var tint: Color {
        Color(red: Double((rgbHex >> 16) & 0xff) / 255,
              green: Double((rgbHex >> 8) & 0xff) / 255,
              blue: Double(rgbHex & 0xff) / 255)
    }
}

struct CoursesSettingsSection: View {
    @State private var store = CourseStore.shared
    @State private var showCourses = false

    var body: some View {
        Button {
            showCourses = true
        } label: {
            HStack {
                Text("My Courses")
                    .font(.system(size: 17, design: .rounded))
                Spacer()
                Text("\(store.courses.count)")
                    .foregroundStyle(AppTheme.paper.opacity(0.7))
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(AppTheme.paper)
            .padding(.horizontal, 24)
            .frame(minHeight: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            ZStack {
                AppTheme.darkSurface
                CourseIconsMosaic()
            }
            .clipShape(RoundedRectangle(cornerRadius: 38))
        }
        .sheet(isPresented: $showCourses) {
            Group {
            CoursesPage(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)

            }.presentationBackground(AppTheme.paper)
        }
    }
}

struct CoursesPage: View {
    @Environment(\.dismiss) private var dismiss
    let store: CourseStore
    @State private var editingCourse: StudyCourse?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if store.loadFailed {
                        ContentUnavailableView("Couldn't load courses", systemImage: "exclamationmark.triangle", description: Text("Please reopen the app and try again."))
                    } else {
                        if store.courses.isEmpty {
                            ContentUnavailableView("No courses yet", systemImage: "books.vertical", description: Text("Create your first course to get started."))
                        }
                        ForEach(store.courses) { course in
                            Button {
                                editingCourse = course
                            } label: {
                                HStack(spacing: 12) {
                                    CourseBadge(course: course)
                                    Text(course.name)
                                        .font(.body.weight(.medium))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 8)
                                    Image(systemName: "pencil")
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit \(course.name)")
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.paper)
            .safeAreaInset(edge: .bottom) {
                if !store.loadFailed {
                    Button {
                        editingCourse = StudyCourse(name: "")
                    } label: {
                        Label("Create course", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppTheme.paper)
                }
            }
            .navigationTitle("My Courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { editingCourse != nil },
                set: { if !$0 { editingCourse = nil } }
            )) {
                if let course = editingCourse {
                    CourseEditorView(course: course, store: store) {
                        editingCourse = nil
                    }
                }
            }
        }
        .tint(AppTheme.ink)
    }
}

struct CourseBadge: View {
    let course: StudyCourse

    var body: some View {
        Image(systemName: course.icon)
            .font(.system(size: 21, weight: .semibold, design: .rounded))
            .foregroundStyle(course.color.iconTint)
            .frame(width: 44, height: 44)
            .background(course.color.tint, in: Circle())
            .accessibilityHidden(true)
    }
}

struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var course: StudyCourse
    let store: CourseStore
    var onSaved: ((StudyCourse) -> Void)? = nil
    let onDeleted: () -> Void
    private enum EditorAlert: String, Identifiable {
        case confirmDelete, deleteFailed, saveFailed
        var id: String { rawValue }
    }
    @State private var activeAlert: EditorAlert?
    @State private var preparedColor = false
    @State private var nameExample = "Maths"
    @FocusState private var nameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var animatesNameExample: Bool {
        course.name.isEmpty && !nameFocused && !reduceMotion && scenePhase == .active
    }

    private func animateNameExamples() async {
        guard animatesNameExample else { return }
        let examples = ["Maths", "Science", "History", "Biology", "Art", "Physics", "English"]
        do {
            while !Task.isCancelled {
                for example in examples {
                    nameExample = ""
                    for letter in example {
                        try Task.checkCancellation()
                        nameExample.append(letter)
                        try await Task.sleep(for: .milliseconds(110))
                    }
                    try await Task.sleep(for: .seconds(1.8))
                    while !nameExample.isEmpty {
                        try Task.checkCancellation()
                        nameExample.removeLast()
                        try await Task.sleep(for: .milliseconds(55))
                    }
                    try await Task.sleep(for: .milliseconds(250))
                }
            }
        } catch {
            nameExample = "Maths"
        }
    }


    // Eight complete rows, grouped by subject.
    private let icons = CourseIconCatalog.icons

    private var validName: Bool {
        !course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && course.name.count <= 60
    }

    var body: some View {
        Group {
            VStack(spacing: 0) {
            Form {
                Section("Course name") {
                    HStack(spacing: 14) {
                        CourseBadge(course: course)
                        TextField("Course name", text: $course.name,
                                  prompt: Text(nameExample))
                            .focused($nameFocused)
                            .task(id: animatesNameExample) { await animateNameExamples() }
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .tint(AppTheme.ink)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .accessibilityLabel("Course name")
                            .onChange(of: course.name) { _, value in
                                if value.count > 60 { course.name = String(value.prefix(60)) }
                            }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppTheme.surface)
                Section("Choose a color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 6), spacing: 12) {
                        ForEach(CourseColor.selectable, id: \.self) { color in
                            let available = store.isColorAvailable(color, for: course.id)
                            Button {
                                course.color = color
                            } label: {
                                Circle()
                                    .fill(color.tint)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if !available {
                                            Image(systemName: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryInk)
                                        } else if course.color.paletteColor == color.paletteColor {
                                            Image(systemName: "checkmark")
                                                .font(.body.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.plain)
                            .disabled(!available)
                            .opacity(available ? 1 : 0.4)
                            .accessibilityLabel(color.displayName)
                            .accessibilityHint(available ? "Available" : "Used by another course")
                            .accessibilityAddTraits(course.color.paletteColor == color.paletteColor ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    if !store.isColorAvailable(course.color, for: course.id) {
                        Text(CourseColor.selectable.contains { store.isColorAvailable($0, for: course.id) }
                             ? "Choose an unused color. Each course has its own color."
                             : "All colors are in use. Free a color by deleting a course first.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                .listRowBackground(AppTheme.surface)
                Section("Choose an icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 6), spacing: 12) {
                        ForEach(icons, id: \.0) { icon, name in
                            Button {
                                course.icon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 23, design: .rounded))
                                    .foregroundStyle(course.icon == icon ? Color.white : AppTheme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(course.icon == icon ? course.color.tint : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(course.icon == icon ? AppTheme.ink.opacity(0.6) : .clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name)
                            .accessibilityAddTraits(course.icon == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.surface)
                if store.courses.contains(where: { $0.id == course.id }) {
                    Section {
                    Button(role: .destructive) {
                        activeAlert = .confirmDelete
                    } label: {
                        Label("Delete course", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tint(.red)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    }
                .listRowBackground(AppTheme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.paper)
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .confirmDelete:
                    return Alert(
                        title: Text("Delete this course?"),
                        message: Text("Your completed study sessions will be kept."),
                        primaryButton: .destructive(Text("Delete course")) {
                            do {
                                try store.delete(course)
                                onDeleted()
                            } catch {
                                activeAlert = .deleteFailed
                            }
                        },
                        secondaryButton: .cancel()
                    )
                case .deleteFailed:
                    return Alert(title: Text("Couldn't delete course"), message: Text("Please try again. Your course hasn't been deleted."))
                case .saveFailed:
                    return Alert(title: Text("Couldn't save course"), message: Text("Please try again. Your changes haven't been saved."))
                }
            }
            .navigationTitle(store.courses.contains(where: { $0.id == course.id }) ? "Edit course" : "New course")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .onAppear {
                guard !preparedColor else { return }
                preparedColor = true
                if !store.courses.contains(where: { $0.id == course.id }),
                   let available = CourseColor.selectable.first(where: { store.isColorAvailable($0, for: course.id) }) {
                    course.color = available
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                do {
                    try store.save(course)
                    onSaved?(course)
                    dismiss()
                } catch {
                    activeAlert = .saveFailed
                }
            } label: {
                Text(store.courses.contains(where: { $0.id == course.id }) ? "Save changes" : "Create course")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppTheme.ink, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!validName || !store.isColorAvailable(course.color, for: course.id))
            .opacity(validName && store.isColorAvailable(course.color, for: course.id) ? 1 : 0.4)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.paper)
        }
        .tint(AppTheme.ink)
    }
}
