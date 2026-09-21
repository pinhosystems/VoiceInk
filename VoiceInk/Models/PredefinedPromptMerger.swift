import Foundation

/// Reconciles the persisted prompt list with the predefined prompts compiled
/// into the app. Pure and side-effect free so the launch-time migration can be
/// unit tested without a live `AIEnhancementService`.
///
/// Example:
/// ```swift
/// customPrompts = PredefinedPromptMerger.merge(
///     persisted: customPrompts,
///     templates: PredefinedPrompts.createDefaultPrompts(),
///     templateLibrary: PromptTemplates.all,
///     seedTriggerWords: false
/// )
/// ```
enum PredefinedPromptMerger {

    static func merge(
        persisted: [CustomPrompt],
        templates: [CustomPrompt],
        templateLibrary: [TemplatePrompt],
        seedTriggerWords: Bool
    ) -> [CustomPrompt] {
        var prompts = purgeOrphanPredefined(persisted, templates: templates)
        prompts = dropLegacyClones(prompts, templates: templates)
        prompts = dedupeClones(prompts)
        prompts = retagClonedCategories(prompts, templateLibrary: templateLibrary)
        return upsertPredefined(prompts, templates: templates, seedTriggerWords: seedTriggerWords)
    }

    /// True when any user-owned field of a predefined prompt diverges from the
    /// shipped template. Trigger words are excluded on purpose: editing only
    /// those keeps the prompt on the upstream text, which still gets updated.
    static func hasUserEdits(_ prompt: CustomPrompt, template: CustomPrompt) -> Bool {
        let differences: [Bool] = [
            prompt.title != template.title,
            prompt.promptText != template.promptText,
            prompt.icon != template.icon,
            prompt.description != template.description,
            prompt.useSystemInstructions != template.useSystemInstructions,
            prompt.category != template.category
        ]
        return differences.contains(true)
    }

    /// Factory reset of a predefined prompt. Everything the user touched —
    /// text, icon, trigger words — goes back to the shipped template; only the
    /// selection-relevant `isActive` flag carries over.
    static func restored(_ prompt: CustomPrompt, to template: CustomPrompt) -> CustomPrompt {
        CustomPrompt(
            id: template.id,
            title: template.title,
            promptText: template.promptText,
            isActive: prompt.isActive,
            icon: template.icon,
            description: template.description,
            isPredefined: true,
            triggerWords: template.triggerWords,
            useSystemInstructions: template.useSystemInstructions,
            vocabularyDomains: template.vocabularyDomains,
            category: template.category,
            isCustomized: false
        )
    }

    // MARK: - Stages

    /// Drops entries persisted with `isPredefined: true` whose UUID is no
    /// longer in the source list. Without this, a prompt that used to be
    /// predefined and was later removed stays stuck — the delete UI guards on
    /// `!isPredefined`, so the user can never remove it.
    private static func purgeOrphanPredefined(
        _ prompts: [CustomPrompt],
        templates: [CustomPrompt]
    ) -> [CustomPrompt] {
        let validIds = Set(templates.map { $0.id })
        return prompts.filter { !$0.isPredefined || validIds.contains($0.id) }
    }

    /// Migrates legacy clones: Task Prompt (and any other prompt) was
    /// previously a clonable template — every application of the "AI Coding
    /// Agent" Power Mode preset spawned a fresh non-predefined "Task Prompt"
    /// entry. Now that those prompts are predefined entries with stable UUIDs,
    /// drop the non-predefined siblings whose title matches a predefined one.
    private static func dropLegacyClones(
        _ prompts: [CustomPrompt],
        templates: [CustomPrompt]
    ) -> [CustomPrompt] {
        let predefinedTitles = Set(templates.map { $0.title })
        return prompts.filter { $0.isPredefined || !predefinedTitles.contains($0.title) }
    }

    /// Collapses exact (title, promptText) duplicates among non-predefined
    /// prompts — every "Add new prompt from template" click used to spawn a
    /// fresh CustomPrompt with a new UUID but identical content. Keeps the
    /// earliest occurrence so a persisted `selectedPromptId` still resolves;
    /// prompts the user actually edited are untouched.
    private static func dedupeClones(_ prompts: [CustomPrompt]) -> [CustomPrompt] {
        var seenSignatures: Set<String> = []
        return prompts.filter { prompt in
            guard !prompt.isPredefined else { return true }
            let signature = "\(prompt.title)\u{1F}\(prompt.promptText)"
            return seenSignatures.insert(signature).inserted
        }
    }

    /// Re-tags legacy template clones with the right PromptCategory. Builds
    /// shipped before the category field existed decoded old CustomPrompts with
    /// `.writing` regardless of source, so a cloned "Commit Message" never
    /// qualified for the runtime tech-term salvage injection.
    private static func retagClonedCategories(
        _ prompts: [CustomPrompt],
        templateLibrary: [TemplatePrompt]
    ) -> [CustomPrompt] {
        let templateByTitle = Dictionary(templateLibrary.map { ($0.title, $0) }) { first, _ in first }
        return prompts.map { prompt in
            guard !prompt.isPredefined,
                  let template = templateByTitle[prompt.title],
                  prompt.category != template.category else { return prompt }
            return prompt.with(category: template.category)
        }
    }

    /// Refreshes every predefined prompt from its template, appending the ones
    /// the user has never seen. Customized prompts keep their fields verbatim.
    private static func upsertPredefined(
        _ prompts: [CustomPrompt],
        templates: [CustomPrompt],
        seedTriggerWords: Bool
    ) -> [CustomPrompt] {
        var merged = prompts
        for template in templates {
            guard let index = merged.firstIndex(where: { $0.id == template.id }) else {
                merged.append(template)
                continue
            }
            merged[index] = refreshed(merged[index], from: template, seedTriggerWords: seedTriggerWords)
        }
        return merged
    }

    private static func refreshed(
        _ existing: CustomPrompt,
        from template: CustomPrompt,
        seedTriggerWords: Bool
    ) -> CustomPrompt {
        // One-time seeding of default trigger words: the upsert deliberately
        // preserves user-edited triggerWords, so entries persisted before the
        // defaults existed would stay empty forever.
        let triggers = existing.triggerWords.isEmpty && seedTriggerWords
            ? template.triggerWords
            : existing.triggerWords
        guard !existing.isCustomized else {
            return existing.with(isPredefined: true, triggerWords: triggers)
        }
        return CustomPrompt(
            id: existing.id,
            title: template.title,
            promptText: template.promptText,
            isActive: existing.isActive,
            icon: template.icon,
            description: template.description,
            isPredefined: true,
            triggerWords: triggers,
            useSystemInstructions: template.useSystemInstructions,
            vocabularyDomains: template.vocabularyDomains,
            category: template.category,
            isCustomized: false
        )
    }
}
