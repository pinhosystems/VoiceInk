//
//  BrazilianPipelineTests.swift
//  VoiceInkTests
//
//  Covers the pt-BR-specific behaviors layered on top of VoiceInk:
//   - Filler word selection switches to the pt-BR superset when SelectedLanguage
//     begins with "pt".
//   - The output filter strips pt-BR Whisper hallucinations between brackets
//     while preserving legitimate parentheticals.
//   - Language fallback maps "pt" → "pt-BR" for Apple Native and "pt-BR" → "pt"
//     for Whisper/cloud, respecting Locale.current when relevant.
//   - The pt-BR LocalePack (via LocaleNormalizer.apply) rewrites the common
//     Brazilian formatting cases without corrupting unrelated text.
//

import Testing
import Foundation
@testable import VoiceInk

@MainActor
struct BrazilianPipelineTests {

    // MARK: - Test scaffolding

    /// Sets `SelectedLanguage` for the duration of a single test. We restore the
    /// previous value on teardown so the suite stays isolated even if a test
    /// throws midway.
    private func withSelectedLanguage<R>(_ value: String, _ body: () throws -> R) rethrows -> R {
        let previous = UserDefaults.standard.string(forKey: "SelectedLanguage")
        UserDefaults.standard.set(value, forKey: "SelectedLanguage")
        defer { UserDefaults.standard.set(previous, forKey: "SelectedLanguage") }
        return try body()
    }

    private func withDefault<R>(_ key: String, value: Any?, _ body: () throws -> R) rethrows -> R {
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(value, forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        return try body()
    }

    // MARK: - FillerWordManager

    @Test("effectiveFillerWords adds pt-BR set when SelectedLanguage starts with pt")
    func fillerWordsExpandForPortuguese() {
        withSelectedLanguage("pt") {
            let words = FillerWordManager.shared.effectiveFillerWords
            #expect(words.contains("né"))
            #expect(words.contains("tipo assim"))
            #expect(words.contains("sei lá"))
            // Original English fillers are still included.
            #expect(words.contains("um"))
        }
    }

    @Test("effectiveFillerWords stays english-only for non-pt languages")
    func fillerWordsNarrowForEnglish() {
        withSelectedLanguage("en") {
            let words = FillerWordManager.shared.effectiveFillerWords
            #expect(!words.contains("né"))
            #expect(!words.contains("tipo assim"))
            #expect(words.contains("um"))
        }
    }

    // MARK: - TranscriptionOutputFilter

    @Test("filter removes pt-BR Whisper hallucinations between brackets")
    func filterStripsBrazilianHallucinations() {
        let input = "A reunião começa às 14h. [música ao fundo] Vamos discutir o orçamento. (indistinto)"
        let output = TranscriptionOutputFilter.filter(input)
        #expect(!output.contains("[música ao fundo]"))
        #expect(!output.contains("(indistinto)"))
        #expect(output.contains("A reunião começa às 14h."))
        #expect(output.contains("Vamos discutir o orçamento."))
    }

    @Test("filter preserves legitimate parentheticals in pt-BR")
    func filterPreservesLegitimateParens() {
        let input = "O gerente novo (Pedro Henrique) chega na segunda. [ver depois]"
        let output = TranscriptionOutputFilter.filter(input)
        #expect(output.contains("(Pedro Henrique)"))
        #expect(output.contains("[ver depois]"))
    }

    @Test("filter removes pt-BR fillers with longest-first ordering")
    func filterRemovesMultiWordFillersFirst() {
        withSelectedLanguage("pt") {
            withDefault("RemoveFillerWords", value: true) {
                let input = "Então, tipo assim, a gente precisa, né, conversar."
                let output = TranscriptionOutputFilter.filter(input)
                // "tipo assim" should be removed as a whole, not leaving an orphan "assim".
                #expect(!output.contains("tipo assim"))
                #expect(!output.contains("assim"))
                // "né" should also be removed.
                #expect(!output.lowercased().contains(" né"))
            }
        }
    }

    // MARK: - LanguageDictionary fallback

    @Test("validLanguageOrFallback maps pt to pt-BR for Apple Native")
    func appleNativeMapsPtToPtBR() {
        // Build a tiny mock model that reports Apple Native + Apple Native languages.
        let model = MockAppleNativeModel()
        let resolved = TranscriptionLanguageSupport.validLanguageOrFallback("pt", for: model)
        #expect(resolved == "pt-BR")
    }

    @Test("validLanguageOrFallback strips region for cloud models")
    func cloudStripsRegionTag() {
        let model = MockWhisperModel()
        let resolved = TranscriptionLanguageSupport.validLanguageOrFallback("pt-BR", for: model)
        #expect(resolved == "pt")
    }

    // MARK: - LocaleNormalizer with pt-BR pack

    /// Convenience: applies the pt-BR pack's normalization the same way the
    /// transcription pipeline does at runtime.
    private func normalizePtBR(_ text: String) -> String {
        LocaleNormalizer.apply(text, pack: BrazilianPortuguesePack())
    }

    @Test("Registry routing for Portuguese variants")
    func registryRoutesPortugueseVariants() {
        // Exact pt-BR → BrazilianPortuguesePack (with normalization).
        let ptBR = LocalePackRegistry.pack(for: "pt-BR")
        #expect(ptBR != nil)
        #expect(ptBR?.customNormalize != nil)

        // Bare "pt" in this fork intentionally resolves to BrazilianPortuguesePack
        // because SelectedLanguage defaults to "pt" for Portuguese users.
        let ptBare = LocalePackRegistry.pack(for: "pt")
        #expect(ptBare?.bcp47 == "pt-BR")

        // Region-tagged pt-PT / pt-AO falls back to the generic PortuguesePack
        // (output-only, no BR-specific transforms or fillers).
        let ptPT = LocalePackRegistry.pack(for: "pt-PT")
        #expect(ptPT != nil)
        #expect(ptPT?.bcp47 == nil)
        #expect(ptPT?.customNormalize == nil)
        #expect(ptPT?.normalizerRules.isEmpty == true)

        let ptAO = LocalePackRegistry.pack(for: "pt-AO")
        #expect(ptAO?.bcp47 == nil)
        #expect(ptAO?.primarySubtag == "pt")

        // English is intentionally nil — see Section 7.1 of MULTILINGUAL_PLAN.md.
        #expect(LocalePackRegistry.pack(for: "en") == nil)
        #expect(LocalePackRegistry.pack(for: "auto") == nil)
    }

    @Test("normalizationEnabled is true by default")
    func normalizationEnabledByDefault() {
        withDefault(LocalePackRegistry.normalizationEnabledKey, value: nil) {
            withDefault(LocalePackRegistry.legacyNormalizationEnabledKey, value: nil) {
                #expect(LocalePackRegistry.normalizationEnabled)
            }
        }
    }

    @Test("pt-BR pack formats CPF (11 digits)")
    func normalizesCPF() {
        let output = normalizePtBR("Meu CPF é 12345678900 e o RG é 123.")
        #expect(output.contains("123.456.789-00"))
    }

    @Test("pt-BR pack formats CNPJ (14 digits)")
    func normalizesCNPJ() {
        let output = normalizePtBR("A empresa tem CNPJ 12345678000190 ativo.")
        #expect(output.contains("12.345.678/0001-90"))
    }

    @Test("pt-BR pack formats CEP (8 digits)")
    func normalizesCEP() {
        let output = normalizePtBR("Mando para o CEP 05435010 na Vila Madalena.")
        #expect(output.contains("05435-010"))
    }

    @Test("pt-BR pack rewrites 'duas horas e meia' as '2h30'")
    func normalizesHoursAndHalf() {
        let output = normalizePtBR("A reunião é amanhã às duas horas e meia.")
        #expect(output.contains("2h30"))
    }

    @Test("pt-BR pack converts 'duas da tarde' to '14h'")
    func normalizesAfternoonHours() {
        let output = normalizePtBR("Te vejo às duas da tarde.")
        #expect(output.contains("14h"))
    }

    @Test("pt-BR pack converts 'cinquenta por cento' to '50%'")
    func normalizesPercent() {
        let output = normalizePtBR("Crescemos cinquenta por cento no trimestre.")
        #expect(output.contains("50%"))
    }

    @Test("pt-BR pack converts 'três ponto cinco' to '3,5'")
    func normalizesDecimal() {
        let output = normalizePtBR("O índice está em três ponto cinco hoje.")
        #expect(output.contains("3,5"))
    }

    @Test("pt-BR pack formats reais with thousands separator")
    func normalizesCurrency() {
        let output = normalizePtBR("O orçamento ficou em 1500 reais e 50 centavos.")
        #expect(output.contains("R$ 1.500,50"))
    }

    @Test("pt-BR pack leaves unrelated English text untouched")
    func normalizerNoOpForEnglish() {
        let input = "Meeting at 2:30pm with the team."
        let output = normalizePtBR(input)
        #expect(output == input)
    }

    @Test("pt-BR pack ships at least one normalization example for the UI")
    func packShipsExamples() {
        let pack = BrazilianPortuguesePack()
        #expect(!pack.normalizationExamples.isEmpty)
    }
}

// MARK: - Test doubles

/// Minimal model stub that reports Apple Native semantics. Uses the real
/// `LanguageDictionary.appleNative` so the fallback logic sees the actual locale set.
private struct MockAppleNativeModel: TranscriptionModel {
    let id = UUID()
    let name = "mock-apple-native"
    let displayName = "Mock Apple Native"
    let description = "Test stub"
    let provider: ModelProvider = .nativeApple
    let isMultilingualModel = true
    let supportsStreaming = false
    let supportedLanguages: [String: String] = LanguageDictionary.appleNative
}

private struct MockWhisperModel: TranscriptionModel {
    let id = UUID()
    let name = "mock-whisper"
    let displayName = "Mock Whisper"
    let description = "Test stub"
    let provider: ModelProvider = .whisper
    let isMultilingualModel = true
    let supportsStreaming = false
    let supportedLanguages: [String: String] = LanguageDictionary.all
}
