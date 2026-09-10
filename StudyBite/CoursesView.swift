import SwiftUI

extension CourseColor {
    var tint: Color {
        switch self {
        case .blue: Color(red: 0.67, green: 0.81, blue: 0.96)
        case .teal: Color(red: 0.62, green: 0.84, blue: 0.82)
        case .green: Color(red: 0.72, green: 0.86, blue: 0.68)
        case .orange: Color(red: 0.98, green: 0.77, blue: 0.57)
        case .pink: Color(red: 0.96, green: 0.73, blue: 0.82)
        case .purple: Color(red: 0.81, green: 0.72, blue: 0.92)
        case .red: Color(red: 0.94, green: 0.67, blue: 0.67)
        case .indigo: Color(red: 0.71, green: 0.75, blue: 0.91)
        case .mint: Color(red: 0.74, green: 0.92, blue: 0.82)
        case .peach: Color(red: 0.99, green: 0.83, blue: 0.73)
        case .lemon: Color(red: 0.97, green: 0.92, blue: 0.66)
        case .lavender: Color(red: 0.88, green: 0.82, blue: 0.96)
        case .rose: Color(red: 0.93, green: 0.79, blue: 0.82)
        case .sky: Color(red: 0.75, green: 0.88, blue: 0.97)
        case .sage: Color(red: 0.77, green: 0.83, blue: 0.73)
        case .sand: Color(red: 0.9, green: 0.84, blue: 0.72)
        }
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
                    .font(.system(size: 17))
                Spacer()
                Text("\(store.courses.count)")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 24)
            .frame(minHeight: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(red: 0.95, green: 0.95, blue: 0.965), in: RoundedRectangle(cornerRadius: 38))
        .sheet(isPresented: $showCourses) {
            CoursesPage(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit \(course.name)")
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                if !store.loadFailed {
                    Button {
                        editingCourse = StudyCourse(name: "")
                    } label: {
                        Label("Create course", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("My Courses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(item: $editingCourse) { course in
                CourseEditorView(course: course, store: store)
            }
        }
        .tint(.primary)
    }
}

struct CourseBadge: View {
    let course: StudyCourse

    var body: some View {
        Image(systemName: course.icon)
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(Color(white: 0.22))
            .frame(width: 44, height: 44)
            .background(course.color.tint, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

private struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var course: StudyCourse
    let store: CourseStore
    @State private var saveFailed = false

    private let icons = [
        ("book.fill", "Book"), ("percent", "Maths"), ("atom", "Science"),
        ("globe.europe.africa.fill", "Geography"), ("clock.fill", "History"),
        ("textformat.abc", "Language"), ("paintpalette.fill", "Art"),
        ("music.note", "Music"), ("desktopcomputer", "Computing"),
        ("leaf.fill", "Biology"), ("flask.fill", "Chemistry"),
        ("function", "Calculus"), ("pencil", "Writing"),
        ("briefcase.fill", "Business"), ("brain.head.profile", "Psychology"),
        ("graduationcap.fill", "Education"), ("studentdesk", "Study"),
        ("books.vertical.fill", "Literature"), ("character.bubble.fill", "Conversation"),
        ("number", "Numbers"), ("sum", "Algebra"), ("chart.bar.fill", "Statistics"),
        ("chart.pie.fill", "Data"), ("ruler.fill", "Geometry"),
        ("testtube.2", "Laboratory"), ("bolt.fill", "Physics"),
        ("sparkles", "Astronomy"), ("moon.stars.fill", "Space"),
        ("sun.max.fill", "Weather"), ("drop.fill", "Water"),
        ("pawprint.fill", "Zoology"), ("heart.fill", "Health"),
        ("cross.case.fill", "Medicine"), ("stethoscope", "Nursing"),
        ("building.columns.fill", "Classics"), ("map.fill", "Maps"),
        ("hammer.fill", "Engineering"), ("gearshape.fill", "Mechanics"),
        ("curlybraces", "Programming"), ("network", "Networks"),
        ("camera.fill", "Photography"), ("film.fill", "Cinema"),
        ("theatermasks.fill", "Theatre"), ("scissors", "Crafts"),
        ("sportscourt.fill", "Sports"), ("figure.run", "Exercise"),
        ("fork.knife", "Nutrition"), ("dollarsign.circle.fill", "Economics"),
        ("lightbulb.fill", "Ideas"), ("puzzlepiece.fill", "Logic")
    ]

    private var validName: Bool {
        !course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && course.name.count <= 60
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CourseBadge(course: course)
                        Text(course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your course" : course.name)
                            .font(.headline)
                    }
                }
                Section("Name") {
                    TextField("Course name", text: $course.name)
                        .textInputAutocapitalization(.words)
                        .onChange(of: course.name) { _, value in
                            if value.count > 60 { course.name = String(value.prefix(60)) }
                        }
                }
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        ForEach(CourseColor.allCases, id: \.self) { color in
                            Button {
                                course.color = color
                            } label: {
                                Circle()
                                    .fill(color.tint)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if course.color == color {
                                            Image(systemName: "checkmark")
                                                .font(.body.bold())
                                                .foregroundStyle(Color(white: 0.22))
                                        }
                                    }
                                    .frame(width: 48, height: 48)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color.rawValue.capitalized)
                            .accessibilityAddTraits(course.color == color ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                        ForEach(icons, id: \.0) { icon, name in
                            Button {
                                course.icon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 23))
                                    .foregroundStyle(Color.primary)
                                    .frame(width: 48, height: 48)
                                    .background(course.icon == icon ? course.color.tint : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(course.icon == icon ? Color.primary.opacity(0.6) : .clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name)
                            .accessibilityAddTraits(course.icon == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(store.courses.contains(where: { $0.id == course.id }) ? "Edit course" : "New course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.save(course)
                            dismiss()
                        } catch {
                            saveFailed = true
                        }
                    }
                    .disabled(!validName)
                }
            }
            .alert("Couldn't save course", isPresented: $saveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please try again. Your changes haven't been saved.")
            }
        }
        .tint(.primary)
    }
}
