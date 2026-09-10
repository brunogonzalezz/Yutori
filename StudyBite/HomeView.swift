
import SwiftUI

struct HomeView: View {
    
    @State var showSettings = false
    @State private var sessionStore = StudySessionStore.shared
    @State private var courseStore = CourseStore.shared
    @AppStorage("profileName") private var profileName = "Bruno Gonzalez"
    private var greeting: String { Self.sessionGreeting }

    // Pick once per app process, including when HomeView is recreated.
    private static let sessionGreeting: String = {
        let greetings = [
            "Hi!", "Welcome back!", "Good to see you!",
            "Ready to study?", "Let's get started!", "Time to focus!",
            "You've got this!", "One step at a time!", "Let's learn something new!",
            "Make today count!", "A little progress every day!", "Ready for a fresh start?",
            "Your next chapter starts here!", "Small steps, big dreams!", "Keep your curiosity alive!",
            "Let's make progress!", "Time to grow!", "One study bite at a time!",
            "Bring your ideas to life!", "Build a little momentum!"
        ]
        let defaults = UserDefaults.standard
        let lastGreeting = defaults.string(forKey: "lastHomeGreeting")
        let greeting = greetings.filter { $0 != lastGreeting }.randomElement() ?? "Hi!"
        defaults.set(greeting, forKey: "lastHomeGreeting")
        return greeting
    }()

    var body: some View {
        
        ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    showSettings = true
                } label: {
                    ProfileAvatarView(size: 50)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(profileName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(greeting) \(profileName)")
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .padding(.bottom, -25)
            
            VStack(spacing: 20) {
                
                Image("bowl")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 330, height: 330)
                
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.25))
                                .frame(height: 7)
                            
                            Capsule()
                                .fill(Color.black)
                                .frame(
                                    width: geometry.size.width * 0.65,
                                    height: 7
                                )
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black)
                                    .frame(width: 28, height: 28)
                                    .rotationEffect(.degrees(45))
                                
                                Text("4")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .frame(height: 15)
                    
                    Text("41 min remaining")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 60)
                .offset(y: -45)
            }
            .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 14) {
                
                Spacer()
                    .frame(height: 5)
                
                Text("Last sessions")
                    .font(.system(size: 24, weight: .bold))
                
                if sessionStore.loadFailed {
                    Text("Couldn't load your sessions. Please reopen the app and try again.")
                        .foregroundStyle(.secondary)
                } else if sessionStore.sessions.isEmpty {
                    Text("Your completed study sessions will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessionStore.sessions) { session in
                        let course = courseStore.courses.first { $0.id == session.course.id } ?? session.course
                        HStack(spacing: 12) {
                            CourseBadge(course: course)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.name)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(session.blockDescription)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Text(session.formattedDuration)
                                .font(.system(size: 17, weight: .medium))
                                .fixedSize()
                        }
                        .accessibilityElement(children: .combine)
                        if session.id != sessionStore.sessions.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .offset(y: -25)
        }
        .padding(.bottom, 32)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    HomeView()
}
