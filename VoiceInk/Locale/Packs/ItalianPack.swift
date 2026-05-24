import Foundation

/// Curated Italian pack covering it, it-IT, it-CH. Provides filler words,
/// abbreviation expansions, vocabulary biasing for Italian institutions and
/// companies, normalization for codice fiscale / phone / CAP formats, Whisper
/// prompt seeds across multiple domains, and LLM formatting conventions tuned
/// to standard Italian usage.
struct ItalianPack: LocalePack {
    let primarySubtag: String = "it"
    let displayName: String = "Italian"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "ehm", "cioè", "allora", "praticamente", "diciamo",
        "insomma", "ecco", "tipo", "niente", "vabbè",
        "comunque", "magari", "boh", "mah", "senti",
        "guarda", "in pratica", "fondamentalmente"
    ]

    // MARK: - Word Replacements

    let wordReplacements: [(original: String, replacement: String)] = [
        ("cmq", "comunque"),
        ("xché, xke", "perché"),
        ("nn", "non"),
        ("qnd, qndo", "quando"),
        ("qlc, qlcs", "qualcosa"),
        ("msg", "messaggio"),
        ("tel", "telefono"),
        ("info", "informazione"),
        ("dott", "dottore"),
        ("ing", "ingegnere"),
        ("avv", "avvocato"),
        ("sig", "signore"),
        ("sig.ra", "signora"),
        ("rif", "riferimento")
    ]

    // MARK: - Vocabulary Terms

    let vocabularyTerms: [String] = [
        // Istituzioni
        "Quirinale", "Palazzo Chigi",
        "Camera dei Deputati", "Senato della Repubblica",
        "Corte Costituzionale", "Consiglio di Stato",
        "Corte dei Conti", "Consiglio Superiore della Magistratura",
        "INPS", "INAIL", "Agenzia delle Entrate",
        "Guardia di Finanza", "Carabinieri",
        "Ministero dell'Economia", "Ministero della Giustizia",

        // Aziende e marchi
        "Eni", "Enel", "Telecom Italia", "TIM",
        "Ferrovie dello Stato", "Trenitalia", "Italo",
        "Poste Italiane", "Fiat", "Ferrari", "Lamborghini",
        "Maserati", "Alfa Romeo", "Stellantis",
        "Intesa Sanpaolo", "UniCredit", "Mediobanca",
        "Generali", "Luxottica", "Barilla", "Lavazza",

        // Geografia
        "Firenze", "Napoli", "Venezia", "Torino", "Milano",
        "Roma", "Bologna", "Genova", "Palermo", "Catania",
        "Bari", "Verona", "Padova", "Trieste",

        // Educazione
        "Università Bocconi", "Politecnico di Milano",
        "Politecnico di Torino", "La Sapienza",
        "Università di Bologna", "Scuola Normale Superiore",
        "LUISS", "Cattolica",

        // Documenti e identificatori
        "codice fiscale", "partita IVA", "IBAN",
        "tessera sanitaria", "carta d'identità",
        "SPID", "PEC", "CIE", "patente di guida",
        "visura camerale", "DURC",

        // Tributi e previdenza
        "IRPEF", "IRES", "IVA", "IMU", "TARI", "IRAP",
        "modello 730", "modello Unico", "F24",
        "contributi INPS", "TFR", "CUD", "busta paga"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Codice fiscale: 16 alphanumeric chars (e.g. RSSMRA85M01H501Z)
        NormalizerRule(
            pattern: #"(?<![A-Za-z0-9])([A-Z]{6}\d{2}[A-EHLMPR-T]\d{2}[A-Z]\d{3}[A-Z])(?![A-Za-z0-9])"#,
            options: [.caseInsensitive],
            replacement: "$1",
            description: "Format codice fiscale (uppercase)"
        ),

        // Italian phone: +39 prefix with area code and number
        // Matches sequences like +39 02 1234 5678 or +39 333 123 4567
        NormalizerRule(
            pattern: #"(?<!\d)\+?\s*39\s*(\d{2,3})\s*(\d{3,4})\s*(\d{4})(?!\d)"#,
            options: [],
            replacement: "+39 $1 $2 $3",
            description: "Normalize Italian phone number with +39 prefix"
        ),

        // CAP (Codice di Avviamento Postale): 5 digits
        NormalizerRule(
            pattern: #"(?i)(?:CAP|c\.a\.p\.)\s*[:\s]*(\d{5})\b"#,
            options: [],
            replacement: "CAP $1",
            description: "Normalize CAP (Italian postal code) format"
        )
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": """
            Buongiorno, come va? Oggi è il 15/05/2026 e la riunione è fissata per le 14:30. \
            L'importo concordato è di 1.500,00 €, potrebbe arrivare a 2.350,75 € con l'IVA. \
            Ho già inviato l'e-mail al team; dobbiamo confermare con Anna, Marco e Giulia entro domani. \
            Non dimenticare di rivedere la proposta — ho messo in evidenza i punti principali: \
            scadenza, ambito e budget. A Milano il traffico è scorrevole, ma l'app segnala \
            rallentamenti sulla tangenziale est. L'idea è semplice: partire dall'essenziale, \
            poi passare alla prossima fase del progetto.
            """,
        "technical": """
            Stiamo discutendo di architettura software in italiano. Oggi è il 15/05/2026 \
            e revisioniamo l'API REST del backend in Node.js, il frontend in React con \
            TypeScript, deploy su AWS tramite Docker e Kubernetes, osservabilità su Grafana, \
            database PostgreSQL, cache Redis. Pull request, code review, CI/CD, async/await, \
            callback, endpoint, payload JSON, JWT, OAuth, gRPC, microservizi.
            """,
        "medical": """
            Questa è una visita clinica in italiano. Paziente di 52 anni, lamenta dispnea \
            da 4 giorni, ipertensione arteriosa in terapia con ramipril 5mg, diabete mellito \
            tipo 2 con metformina 1000mg, colesterolo LDL 160, glicemia a digiuno 130. \
            Richiedere emocromo, GOT, GPT, creatinina, azotemia, ecocardiogramma. \
            Codice ICD-10 I10. SSN, ASL, tessera sanitaria, codice fiscale RSSMRA85M01H501Z.
            """,
        "legal": """
            Si tratta di atto di citazione in italiano. Attore: Mario Rossi, codice fiscale \
            RSSMRA85M01H501Z, residente in Via Roma 15, 20121 Milano (MI). Il ricorrente \
            chiede il risarcimento del danno ex art. 2043 c.c. Convenuto: Società Alfa S.r.l., \
            partita IVA 12345678901. Tribunale di Milano, Corte d'Appello, Cassazione, \
            Corte Costituzionale, PEC, avvocato, procura alle liti, udienza.
            """
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
        it: standard Italian orthography, decimal comma, period as thousands \
        separator ("1.500,00 €"), dd/mm/aaaa, 24h time with colon (14:30), \
        lowercase month and weekday names. Italian uses « » or " " for quotation \
        marks; apostrophes are common in contractions ("l'utente", "dell'API").
        """

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        ("Codice fiscale rssmra85m01h501z", "Codice fiscale RSSMRA85M01H501Z"),
        ("Chiamami al +39 02 1234 5678.", "Chiamami al +39 02 1234 5678."),
        ("Il CAP è 20121.", "CAP 20121")
    ]
}
