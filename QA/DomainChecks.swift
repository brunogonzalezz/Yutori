import Foundation
// Only UI/service dependencies are substituted; domain sources are copied unchanged.
enum AppLanguage { static func localized(_ key: String) -> String { key } }
final class PurchaseManager { static let shared = PurchaseManager(); var isPro = false }
var checks = 0
func check(_ value: @autoclosure () -> Bool, _ name: String) { checks += 1; if !value() { fatalError("FAIL: \(name)") }; print("PASS: \(name)") }
func rejects(_ name: String, _ action: () throws -> Void) { do { try action(); fatalError("FAIL: \(name)") } catch { checks += 1; print("PASS: \(name)") } }
let suite = "YutoriAudit.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let courses = CourseStore(defaults: defaults)
let course = StudyCourse(name: "Maths")
try courses.save(course)
check(CourseStore(defaults: defaults).courses.count == 1, "course persists")
rejects("free second course blocked") { try courses.save(StudyCourse(name: "Science",color: .green)) }
rejects("blank course blocked") { try courses.save(StudyCourse(name: " ")) }
let store = StudySessionStore(defaults: defaults)
store.resetAllData()
check(!store.hasActiveBowl, "reset requires bowl selection")
check(!store.selectNextBowl(.tofuCurry), "locked bowl blocked")
check(store.selectNextBowl(.chirashi), "unlocked bowl selectable")
check(!store.collectBowl(), "incomplete bowl cannot collect")
var session = StudySession(course:course,blockDescription:"",duration:18000,endedAt:Date.now.addingTimeInterval(-1),startingDishSeconds:0,bowlKind:.chirashi,pauseCount:0)
try store.save(session)
check(store.canCollectBowl, "five hours complete bowl")
check(store.canUnlockNextBowl && store.unlockedBowlCount == 3, "unlock requires explicit claim")
check(store.unlockNextBowl() && store.unlockedBowlCount == 4, "manual unlock")
check(!store.unlockNextBowl(), "cannot claim twice")
check(store.collectBowl() && !store.hasActiveBowl, "collect and clear selection")
check(!store.collectBowl(), "cannot collect twice")
let restored = StudySessionStore(defaults:defaults)
check(restored.collectedKinds.contains(.chirashi) && restored.unlockedBowlCount == 4, "collection and unlock persist")
check(restored.selectNextBowl(.tofuCurry) && restored.dishProgress.level == 0, "new bowl starts empty")
session.duration = 20000
try restored.save(session)
check(restored.bowlUnlockSeconds == 18000 && restored.dishProgress.level == 0, "manual time edit does not earn progress")
try restored.deleteSession(id:session.id)
check(restored.sessions.isEmpty && restored.collectedBowls.isEmpty && restored.unlockedBowlCount == 3, "deletion reconciles earned bowls and unlocks")
check(restored.grantStarterTeriyakiBowlIfNeeded(), "starter gift")
check(restored.grantStarterTeriyakiBowlIfNeeded() && restored.collectedBowls.count == 1, "starter gift idempotent")
restored.resetAllData()
check(restored.sessions.isEmpty && restored.collectedBowls.isEmpty && restored.bowlUnlockSeconds == 0, "account data reset")
var watch = StudyStopwatch(); let start = Date(timeIntervalSince1970:1000)
watch.resume(at:start); watch.resume(at:start.addingTimeInterval(10))
check(watch.elapsed(at:start.addingTimeInterval(60)) == 60, "resume idempotent")
watch.pause(at:start.addingTimeInterval(60))
check(watch.elapsed(at:start.addingTimeInterval(120)) == 60, "pause freezes timer")
watch.resume(at:start.addingTimeInterval(120))
check(watch.elapsed(at:start.addingTimeInterval(150)) == 90, "resume accumulates")
let decoded = try JSONDecoder().decode(StudyStopwatch.self,from:JSONEncoder().encode(watch))
check(decoded.elapsed(at:start.addingTimeInterval(150)) == 90,"active timer persistence")
for (seconds,level) in [(0.0,0),(3599,0),(3600,1),(17999,4),(18000,5),(30000,5)] { check(DishProgress(totalSeconds:seconds).level == level,"level boundary \(seconds)") }
check(DishProgress(totalSeconds:.nan).level == 0,"invalid progress sanitized")
var cal = Calendar(identifier:.gregorian); cal.timeZone = TimeZone(secondsFromGMT:0)!
let now=Date(timeIntervalSince1970:1790769600)
let yesterday=cal.date(byAdding:.day,value:-1,to:now)!
let before=cal.date(byAdding:.day,value:-2,to:now)!
check(StudyStreak(sessionDates:[now,now,yesterday,before],now:now,calendar:cal).count == 3,"streak deduplicates days")
check(StudyStreak(sessionDates:[yesterday,before],now:now,calendar:cal).count == 2,"streak survives until today ends")
check(StudyStreak(sessionDates:[before],now:now,calendar:cal).count == 0,"missed day resets streak")
defaults.set(Data("invalid".utf8),forKey:"studySessions.v1")
let broken=StudySessionStore(defaults:defaults)
check(broken.loadFailed,"corrupt saved data detected")
rejects("corrupt data not overwritten") { try broken.save(session) }
print("TOTAL: \(checks) checks passed")
