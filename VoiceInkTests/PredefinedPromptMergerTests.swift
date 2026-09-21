//
//  PredefinedPromptMergerTests.swift
//  VoiceInkTests
//
//  Covers the launch-time reconciliation between the persisted prompt list and
//  the predefined prompts compiled into the app:
//   - a built-in prompt the user edited keeps its text across launches;
//   - an untouched built-in prompt still tracks the shipped text;
//   - restore puts the shipped version back and re-enables tracking;
//   - trigger-word-only edits do not count as customization.
//

import Testing
import Foundation
@testable import VoiceInk

struct PredefinedPromptMergerTests {

    private static let templateId = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!

    private func makeTemplate(
        id: UUID = PredefinedPromptMergerTests.templateId,
        title: String = "Default",
        promptText: String = "shipped text",
        triggerWords: [String] = ["default"]
    ) -> CustomPrompt {
        CustomPrompt(
            id: id,
            title: title,
            promptText: promptText,
            icon: "checkmark.seal.fill",
            description: "shipped description",
            isPredefined: true,
            triggerWords: triggerWords,
            useSystemInstructions: true,
            category: .writing
        )
    }

    private func merge(_ persisted: [CustomPrompt], templates: [CustomPrompt], seedTriggerWords: Bool = false) -> [CustomPrompt] {
        PredefinedPromptMerger.merge(
            persisted: persisted,
            templates: templates,
            templateLibrary: [],
            seedTriggerWords: seedTriggerWords
        )
    }

    // MARK: - Customized prompts

    @Test func customizedPredefinedPromptSurvivesMerge() {
        let template = makeTemplate()
        let edited = template.with(isCustomized: true).replacingText("my own rules")

        let merged = merge([edited], templates: [template])

        #expect(merged.count == 1)
        #expect(merged[0].promptText == "my own rules")
        #expect(merged[0].isPredefined)
        #expect(merged[0].isCustomized)
    }

    @Test func untouchedPredefinedPromptTracksShippedText() {
        let template = makeTemplate()
        let stale = template.replacingText("text from an older build")

        let merged = merge([stale], templates: [template])

        #expect(merged[0].promptText == "shipped text")
        #expect(!merged[0].isCustomized)
    }

    @Test func customizedPromptKeepsEditedTriggerWords() {
        let template = makeTemplate()
        let edited = template.with(triggerWords: ["mine"], isCustomized: true)

        let merged = merge([edited], templates: [template], seedTriggerWords: true)

        #expect(merged[0].triggerWords == ["mine"])
    }

    @Test func missingPredefinedPromptIsAppended() {
        let template = makeTemplate()

        let merged = merge([], templates: [template])

        #expect(merged.count == 1)
        #expect(merged[0].id == template.id)
    }

    @Test func orphanPredefinedPromptIsPurged() {
        let template = makeTemplate()
        let orphan = makeTemplate(id: UUID(), title: "Removed Prompt").with(isCustomized: true)

        let merged = merge([orphan, template], templates: [template])

        #expect(merged.map(\.id) == [template.id])
    }

    // MARK: - Edit detection

    @Test func triggerWordOnlyEditIsNotCustomization() {
        let template = makeTemplate()
        let edited = template.with(triggerWords: ["novo gatilho"])

        #expect(!PredefinedPromptMerger.hasUserEdits(edited, template: template))
    }

    @Test func textEditIsCustomization() {
        let template = makeTemplate()
        let edited = template.replacingText("rewritten")

        #expect(PredefinedPromptMerger.hasUserEdits(edited, template: template))
    }

    // MARK: - Restore

    @Test func restoreReturnsShippedFieldsAndKeepsSelection() {
        let template = makeTemplate()
        var edited = template.with(triggerWords: ["mine"], isCustomized: true).replacingText("my own rules")
        edited.isActive = true

        let restored = PredefinedPromptMerger.restored(edited, to: template)

        #expect(restored.promptText == template.promptText)
        #expect(restored.triggerWords == template.triggerWords)
        #expect(!restored.isCustomized)
        #expect(restored.isActive)
    }

    @Test func restoredPromptTracksShippedTextAgain() {
        let template = makeTemplate()
        let edited = template.with(isCustomized: true).replacingText("my own rules")
        let restored = PredefinedPromptMerger.restored(edited, to: template)

        let merged = merge([restored], templates: [makeTemplate(promptText: "new shipped text")])

        #expect(merged[0].promptText == "new shipped text")
    }
}

private extension CustomPrompt {
    /// Test-only copy-with for the one field the production `with` omits.
    func replacingText(_ text: String) -> CustomPrompt {
        CustomPrompt(
            id: id,
            title: title,
            promptText: text,
            isActive: isActive,
            icon: icon,
            description: description,
            isPredefined: isPredefined,
            triggerWords: triggerWords,
            useSystemInstructions: useSystemInstructions,
            vocabularyDomains: vocabularyDomains,
            category: category,
            isCustomized: isCustomized
        )
    }
}
