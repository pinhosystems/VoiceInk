import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @AppStorage("DefaultAppLanguageConfirmed") private var languageConfirmed: Bool = false
    @AppStorage("DefaultAppLanguage") private var defaultAppLanguage: String = "en"
    @State private var contentOpacity: CGFloat = 0
    @State private var showPermissions = false

    /// Greeting word per primary subtag. Picked off `defaultAppLanguage` so a
    /// user who selected pt-BR sees "Olá!" even though the rest of the
    /// onboarding strings stay in English (we localize the *greeting*, not
    /// the entire flow — see Block 2 spec separating language selection from
    /// the personality moment).
    private static let greetings: [String: String] = [
        "en": "Hello!",
        "pt": "Olá!",
        "es": "¡Hola!",
        "fr": "Bonjour !",
        "de": "Hallo!",
        "it": "Ciao!",
        "ja": "こんにちは!",
        "ko": "안녕하세요!",
        "zh": "你好!"
    ]

    private var greeting: String {
        let primary = defaultAppLanguage
            .lowercased()
            .split(separator: "-")
            .first
            .map(String.init)
            ?? "en"
        return Self.greetings[primary] ?? "Hello!"
    }

    var body: some View {
        ZStack {
            if !languageConfirmed {
                OnboardingLanguageView()
                    .transition(.opacity)
            } else {
                welcomeContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: languageConfirmed)
    }

    @ViewBuilder
    private var welcomeContent: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    OnboardingBackgroundView()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            VStack(spacing: 16) {
                                Text(greeting)
                                    .font(.system(size: min(geometry.size.width * 0.07, 56), weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                Text("Welcome to VoiceInk")
                                    .font(.system(size: min(geometry.size.width * 0.04, 28), weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)

                                Text("Your writing assistant, everywhere on your Mac — 100% offline and private.")
                                    .font(.system(size: min(geometry.size.width * 0.028, 18), weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, geometry.size.height * 0.18)

                            Spacer(minLength: geometry.size.height * 0.22)

                            VStack(spacing: 20) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showPermissions = true
                                    }
                                }) {
                                    Text("Get Started")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(width: min(geometry.size.width * 0.3, 200), height: 50)
                                        .background(Color.white)
                                        .cornerRadius(25)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                SkipButton(text: "Skip Tour") {
                                    hasCompletedOnboarding = true
                                }
                            }
                            .padding(.bottom, 35)
                        }
                    }
                }
            }

            if showPermissions {
                OnboardingPermissionsView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity)
            }
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Supporting Views

struct SkipButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.2))
            .onTapGesture(perform: action)
    }
}

/// Static dark backdrop shared by every onboarding screen. The animated glow
/// and orbiting particle field were dropped in favor of a plain gradient —
/// calmer, and one less always-running animation behind the first-run flow.
struct OnboardingBackgroundView: View {
    var body: some View {
        Color.black
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.85),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
