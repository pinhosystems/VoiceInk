import Foundation

/// Coarse-grained grouping for prompt templates and CustomPrompts.
/// Used by the prompt picker to render a sectioned list instead of a flat
/// menu, and by Power Mode presets to link a preset to the right prompt.
///
/// Adding a new case is a non-breaking change: legacy JSON without the
/// `category` field decodes to `.writing` (the lowest-friction default),
/// and the UI groups unknown cases under "Other" via a fallback.
enum PromptCategory: String, Codable, CaseIterable, Identifiable {
    /// General writing / cleanup / rewriting — the default bucket.
    case writing

    /// Code-adjacent dictation: comments, commit messages, PR
    /// descriptions, review feedback. Output stays inside an editor.
    case coding

    /// Instructions intended to be *consumed* by an AI coding agent
    /// (Claude Code, Cursor, Copilot Chat). The LLM rewrites speech
    /// into a clean task brief — it does not generate code itself.
    case dev_ai

    /// Conversational surfaces — Slack, Teams, Messages, iMessage, etc.
    case chat

    var id: String { rawValue }

    /// Short label shown in pickers and section headers.
    var displayName: String {
        switch self {
        case .writing: return "Writing"
        case .coding:  return "Coding"
        case .dev_ai:  return "AI Coding Agent"
        case .chat:    return "Chat"
        }
    }

    /// SF Symbol hint used by the picker section header.
    var iconHint: String {
        switch self {
        case .writing: return "pencil.line"
        case .coding:  return "curlybraces"
        case .dev_ai:  return "brain.head.profile"
        case .chat:    return "bubble.left.and.bubble.right.fill"
        }
    }

    /// Stable display order in pickers, top → bottom.
    static var orderedCases: [PromptCategory] {
        [.writing, .coding, .dev_ai, .chat]
    }
}
