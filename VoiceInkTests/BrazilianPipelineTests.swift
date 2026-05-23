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
//   - BrazilianTextNormalizer rewrites the common Brazilian formatting cases
//     without corrupting unrelated text.
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

    // MARK: - BrazilianTextNormalizer

    @Test("isEnabled is true by default when language is pt")
    func normalizerEnabledByDefault() {
        withDefault("BrazilianNormalizationEnabled", value: nil) {
            #expect(BrazilianTextNormalizer.isEnabled(for: "pt"))
            #expect(BrazilianTextNormalizer.isEnabled(for: "pt-BR"))
            #expect(!BrazilianTextNormalizer.isEnabled(for: "en"))
        }
    }

    @Test("normalizer formats CPF (11 digits)")
    func normalizesCPF() {
        let input = "Meu CPF é 12345678900 e o RG é 123."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("123.456.789-00"))
    }

    @Test("normalizer formats CNPJ (14 digits)")
    func normalizesCNPJ() {
        let input = "A empresa tem CNPJ 12345678000190 ativo."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("12.345.678/0001-90"))
    }

    @Test("normalizer formats CEP (8 digits)")
    func normalizesCEP() {
        let input = "Mando para o CEP 05435010 na Vila Madalena."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("05435-010"))
    }

    @Test("normalizer rewrites 'duas horas e meia' as '2h30'")
    func normalizesHoursAndHalf() {
        let input = "A reunião é amanhã às duas horas e meia."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("2h30"))
    }

    @Test("normalizer converts 'duas da tarde' to '14h'")
    func normalizesAfternoonHours() {
        let input = "Te vejo às duas da tarde."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("14h"))
    }

    @Test("normalizer converts 'cinquenta por cento' to '50%'")
    func normalizesPercent() {
        let input = "Crescemos cinquenta por cento no trimestre."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("50%"))
    }

    @Test("normalizer converts 'três ponto cinco' to '3,5'")
    func normalizesDecimal() {
        let input = "O índice está em três ponto cinco hoje."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("3,5"))
    }

    @Test("normalizer formats reais with thousands separator")
    func normalizesCurrency() {
        let input = "O orçamento ficou em 1500 reais e 50 centavos."
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output.contains("R$ 1.500,50"))
    }

    @Test("normalizer leaves non-pt-BR text untouched when isEnabled is false")
    func normalizerNoOpForEnglish() {
        // No CPF-like patterns; verifies the pipeline early-exits cleanly.
        let input = "Meeting at 2:30pm with the team."
        #expect(!BrazilianTextNormalizer.isEnabled(for: "en"))
        // Even if called directly, regex paths don't match this.
        let output = BrazilianTextNormalizer.normalize(input)
        #expect(output == input)
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
