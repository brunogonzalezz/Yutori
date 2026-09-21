import AppIntents

struct ToggleStudySessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or resume session"
    static var openAppWhenRun = false
    @Parameter(title: "Session") var sessionID: String
    init() {}
    init(sessionID: String) { self.sessionID = sessionID }
    @MainActor func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let session = ActiveStudySession.shared
        guard session.id?.uuidString == sessionID, session.finishedAt == nil else { return .result() }
        session.toggle()
        await session.syncActivity()
        #endif
        return .result()
    }
}

struct FinishStudySessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finish session"
    static var openAppWhenRun = true
    @Parameter(title: "Session") var sessionID: String
    init() {}
    init(sessionID: String) { self.sessionID = sessionID }
    @MainActor func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let session = ActiveStudySession.shared
        guard session.id?.uuidString == sessionID else { return .result() }
        session.finish(at: .now)
        await session.syncActivity()
        #endif
        return .result()
    }
}
