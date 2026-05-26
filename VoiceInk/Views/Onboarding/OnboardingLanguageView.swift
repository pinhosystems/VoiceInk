import SwiftUI

/// Mandatory onboarding step. Before the user sees the welcome greeting they
/// must explicitly confirm the global default language. The choice propagates
/// to every per-context language picker (STT, LLM output) through
/// `LanguageDefaultPropagator.apply` so the rest of the onboarding (and the
/// app) reads from a single source of truth.
///
/// The view stays purely about language selection — the welcome greeting and
/// the rest of the onboarding tour live in their own views. This separation
/// is the explicit user constraint: utility step before personality step.
struct OnboardingLanguageView: View {
    @AppStorage("DefaultAppLanguage") private var defaultAppLanguage: String = "en"
    @AppStorage("DefaultAppLanguageConfirmed") private var confirmed: Bool = false

    /// Curated profile list — mirrors Settings → Language but trimmed to the
    /// most common entries so the onboarding does not overwhelm. Regional
    /// variants the user actually picks resolve via the fallback chain in
    /// LanguageFallbackResolver, so a user who later wants `pt-PT` does not
    /// have to ship with that exact option here.
    private static let options: [(code: String, label: String, native: String)] = [
        ("auto", "Auto-detect", "Auto"),
        ("en", "English", "English"),
        ("en-US", "English (United States)", "English"),
        ("en-GB", "English (United Kingdom)", "English"),
        ("pt", "Portuguese", "Português"),
        ("pt-BR", "Portuguese (Brazil)", "Português"),
        ("pt-PT", "Portuguese (Portugal)", "Português"),
        ("es", "Spanish", "Español"),
        ("fr", "French", "Français"),
        ("de", "German", "Deutsch"),
        ("it", "Italian", "Italiano"),
        ("ja", "Japanese", "日本語"),
        ("ko", "Korean", "한국어"),
        ("zh", "Chinese (Simplified)", "中文"),
        ("zh-TW", "Chinese (Traditional)", "中文")
    ]

    @State private var stagedChoice: String = "en"

    var body: some View {
        ZStack {
            OnboardingBackgroundView()

            GeometryReader { geometry in
                VStack(spacing: 40) {
                    Spacer().frame(height: max(geometry.size.height * 0.12, 40))

                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                            .symbolRenderingMode(.hierarchical)

                        Text("Pick your default language")
                            .font(.system(size: min(geometry.size.width * 0.045, 32), weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("VoiceInk uses this as the source of truth for every language picker — transcription, LLM enhancement, Power Mode profiles. Regional variants fall back to the closest available match automatically.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 520)
                            .padding(.horizontal, 24)
                    }

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Self.options, id: \.code) { option in
                                languageRow(option: option)
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: 560, maxHeight: geometry.size.height * 0.45)

                    Button {
                        confirmSelection()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 200, height: 48)
                            .background(Color.white)
                            .cornerRadius(24)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            stagedChoice = defaultAppLanguage
        }
    }

    private func languageRow(option: (code: String, label: String, native: String)) -> some View {
        let isSelected = stagedChoice == option.code

        return Button {
            stagedChoice = option.code
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.white)
                    if option.native != option.label && option.code != "auto" {
                        Text(option.native)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func confirmSelection() {
        defaultAppLanguage = stagedChoice
        Task { @MainActor in
            LanguageDefaultPropagator.apply(stagedChoice)
            confirmed = true
        }
    }
}

#Preview {
    OnboardingLanguageView()
}
