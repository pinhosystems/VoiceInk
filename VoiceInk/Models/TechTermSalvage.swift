import Foundation

/// Locale-specific "fix English tech jargon mistranscribed phonetically"
/// guidance. Non-English speakers routinely sprinkle English tech terms
/// into their dictation ("comêti", "puxe", "taipiscripti") — the STT
/// engine writes the phonetic spelling and the LLM has no signal to
/// recover the canonical English term unless we point at the patterns
/// explicitly.
///
/// The block this enum produces is injected by `AIEnhancementService`
/// at runtime, based on the user's configured STT language. Only
/// prompts in the `coding` or `dev_ai` categories receive it — non-tech
/// prompts (Chat, Email, Rewrite) don't need the verbose salvage table
/// and would just burn tokens.
///
/// To add a new locale: append a case to `block(forLanguageCode:)` and
/// hand-curate a salvage table from observed STT failures. Patterns
/// shipped by upstream Whisper / cloud STT models differ per locale —
/// don't blindly translate the pt-BR table.
enum TechTermSalvage {

    /// Returns a `<TECH_TERM_SALVAGE>` block when the locale code maps
    /// to a known table, `nil` otherwise (i.e. EN audio, "auto", or any
    /// locale we haven't curated yet — those land on the generic
    /// instruction inside the prompt itself).
    static func block(forLanguageCode raw: String?) -> String? {
        guard let normalized = normalize(raw) else { return nil }

        switch normalized {
        case "pt", "pt-br":
            return ptBrBlock
        case "es":
            return esBlock
        default:
            return nil
        }
    }

    /// Lower-cased, locale-normalized BCP-47 prefix. Returns nil for
    /// empty / "auto" / "en" / "en-*" since those don't need salvage.
    private static func normalize(_ raw: String?) -> String? {
        guard var code = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else { return nil }
        code = code.lowercased()
        if code == "auto" || code == "en" || code.hasPrefix("en-") { return nil }
        return code
    }

    // MARK: - pt-BR

    private static let ptBrBlock = """
    <TECH_TERM_SALVAGE>
    Devs em português frequentemente intercalam jargão técnico em inglês com a fala. O STT escreve a versão fonética. Quando o contexto for técnico, detecte e CORRIJA para a grafia canônica em inglês:

    | Ouvido (fonético PT) | Correto (canônico EN) |
    | --- | --- |
    | comêti, comêtchi, kometi, comêchi | commit |
    | puxe (verbo em git), puch | push |
    | pul, pulhequesti, pulrequesti, pulrequest | pull request |
    | mergi, mêrgi, merdge | merge |
    | brãnchi, brãnche, brãntche | branch |
    | rebeisi, rebeise, rebêisi | rebase |
    | repô, hepô | repo |
    | chécouti, tchécauti, tchekauti | checkout |
    | deploi (verbo/substantivo) | deploy |
    | taipiscripti, taipscripti | TypeScript |
    | djavaiscripti, javaiscripti | JavaScript |
    | enepeeme, enpeeme | npm |
    | iuseteit, iusefect | useState, useEffect |
    | ridiucs, rêducs | Redux |
    | búqui (web), hooky | hook |
    | callbéqui | callback |
    | mídiuér, mídiouér | middleware |
    | enpoint, indpointi | endpoint |
    | "ápi" (em contexto técnico) | API |
    | jeisson, jésson | JSON |
    | ésquema (em DB) | schema |
    | querê, querê pê | query |
    | builde, buildi | build |
    | runtaimi | runtime |
    | bãndoll, bãndle | bundle |
    | quontêiner | container |

    Quando o contexto for ambíguo (palavra técnica que também existe em português), prefira a interpretação técnica em inglês se as palavras vizinhas forem código, comandos, ou nomes de ferramentas.
    </TECH_TERM_SALVAGE>

    """

    // MARK: - es

    /// Light Spanish table. Patterns observed less systematically than
    /// pt-BR — expand as users report mistranscriptions.
    private static let esBlock = """
    <TECH_TERM_SALVAGE>
    Devs hispanohablantes mezclan jerga técnica en inglés. El STT escribe la versión fonética. En contexto técnico, detecta y CORRIGE a la grafía canónica en inglés:

    | Oído (fonético ES) | Correcto (canónico EN) |
    | --- | --- |
    | cómit, kométi | commit |
    | puch | push |
    | pul, pulrekuest | pull request |
    | merche, mértche | merge |
    | brantche, branch | branch |
    | rebeis | rebase |
    | déploi, deploi | deploy |
    | taipscript | TypeScript |
    | yavascript | JavaScript |
    | énepeeme | npm |
    | endpoint, endpointe | endpoint |
    | yeison | JSON |
    | api (deletrear A-P-I, no "ápi") | API |
    | builde, build | build |
    | runtaim | runtime |

    Cuando el contexto sea ambiguo, prefiere la interpretación técnica en inglés si las palabras vecinas son código, comandos o nombres de herramientas.
    </TECH_TERM_SALVAGE>

    """
}
