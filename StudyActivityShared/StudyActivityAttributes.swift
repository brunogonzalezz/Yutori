import ActivityKit
import Foundation

struct StudyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var accumulated: TimeInterval
        var runningSince: Date?
        var imageName: String
        var level: Int
    }
    var sessionID: String
    var courseName: String
    var courseIcon: String? = nil
    var courseColorHex: UInt32? = nil
}
