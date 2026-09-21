import Foundation
import Observation

@Observable
final class AppReset {
    static let shared = AppReset()
    private(set) var revision = UUID()

    func reset() {
        ActiveStudySession.shared.clear()
        // Clear this app's preferences only, including profile photos and old test data.
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        CourseStore.shared.resetAllData()
        StudySessionStore.shared.resetAllData()
        StudyTestClock.shared.enabled = false
        StudyTestClock.shared.selectedDay = .now
        // Recreate navigation and all temporary view state at Home.
        revision = UUID()
    }
}
