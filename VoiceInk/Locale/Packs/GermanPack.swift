import Foundation

/// Generic German pack covering de, de-DE, de-AT, de-CH, de-LI.
///
/// Targets standard German (Hochdeutsch) conventions shared across the DACH
/// region. Swiss German specifics (apostrophe thousands separator "1'500.00",
/// no scharfes S) can ship as a dedicated de-CH pack later.
///
/// Provides: filler-word removal, abbreviation expansion, STT vocabulary
/// biasing, IBAN/phone/PLZ normalization, Whisper prompt seeds (default,
/// technical, medical, legal), and LLM format rules.
struct GermanPack: LocalePack {
    let primarySubtag: String = "de"
    let displayName: String = "German"

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // IBAN: 22-digit DE IBAN → grouped in fours (DE89 3704 0044 0532 0130 00)
        NormalizerRule(
            pattern: #"(?<![A-Z0-9])([Dd][Ee]\s*\d{2})\s*(\d{4})\s*(\d{4})\s*(\d{4})\s*(\d{4})\s*(\d{2})(?![0-9])"#,
            options: [],
            replacement: "$1 $2 $3 $4 $5 $6",
            description: "Format German IBAN into standard groups of four"
        ),
        // Phone: +49 prefix, area code + subscriber number (spaces inserted)
        // Matches +49 followed by 10-11 digits possibly with spaces/dashes
        NormalizerRule(
            pattern: #"(?<!\d)\+?\s*49[\s./-]*(\d{2,5})[\s./-]*(\d{3,8})[\s./-]*(\d{0,5})(?!\d)"#,
            options: [],
            replacement: "+49 $1 $2$3",
            description: "Normalize German phone numbers to +49 area subscriber format"
        ),
        // PLZ: exactly 5 consecutive digits preceded by "PLZ" or context indicating a postal code
        NormalizerRule(
            pattern: #"(?i)\b(PLZ|Postleitzahl)\s*[:\s]*(\d{5})\b"#,
            options: [.caseInsensitive],
            replacement: "$1 $2",
            description: "Ensure German postal codes (PLZ) are formatted as 5-digit blocks"
        )
    ]

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        ("IBAN DE89370400440532013000", "IBAN DE89 3704 0044 0532 0130 00"),
        ("Ruf mich an unter +4930123456789", "Ruf mich an unter +49 30 123456789"),
        ("PLZ:80331", "PLZ 80331")
    ]

    // MARK: - Word Replacements (abbreviation expansions)

    let wordReplacements: [(original: String, replacement: String)] = [
        ("bzw", "beziehungsweise"),
        ("usw", "und so weiter"),
        ("dh", "das heißt"),
        ("d.h.", "das heißt"),
        ("zB", "zum Beispiel"),
        ("z.B.", "zum Beispiel"),
        ("uU", "unter Umständen"),
        ("u.U.", "unter Umständen"),
        ("mfg", "mit freundlichen Grüßen"),
        ("MfG", "mit freundlichen Grüßen"),
        ("vlg", "vielleicht"),
        ("evtl", "eventuell"),
        ("ca", "circa"),
        ("Tel", "Telefon"),
        ("Nr", "Nummer"),
        ("Str", "Straße"),
        ("Hbf", "Hauptbahnhof"),
        ("inkl", "inklusive"),
        ("exkl", "exklusive"),
        ("ggf", "gegebenenfalls"),
        ("iHv", "in Höhe von"),
        ("mE", "meines Erachtens")
    ]

    // MARK: - Vocabulary Terms (STT biasing)

    let vocabularyTerms: [String] = [
        // Institutions and government bodies
        "Bundestag", "Bundesrat", "Bundesverfassungsgericht",
        "Bundesgerichtshof", "Bundesministerium", "Bundeskanzler",
        "Bundespräsident", "Bundesregierung", "Bundeswehr",
        "Finanzamt", "Arbeitsagentur", "Bundesagentur für Arbeit",
        "Sozialversicherung", "Krankenkasse", "Rentenversicherung",
        "Techniker Krankenkasse", "AOK", "Barmer",

        // Legal entities
        "GmbH", "AG", "e.V.", "KG", "OHG", "UG", "SE", "GbR",
        "Einzelunternehmen", "Kommanditgesellschaft",

        // Companies and brands
        "Deutsche Bahn", "Telekom", "Deutsche Telekom",
        "Siemens", "Volkswagen", "Allianz", "SAP",
        "BMW", "Mercedes-Benz", "Daimler", "Porsche", "Audi",
        "BASF", "Bayer", "Bosch", "Continental", "ThyssenKrupp",
        "Lufthansa", "Deutsche Bank", "Commerzbank",
        "Adidas", "Henkel", "Fresenius", "Zalando", "Delivery Hero",

        // Education
        "Universität", "Gymnasium", "Abitur", "Fachhochschule",
        "TU München", "TU Berlin", "TU Dresden",
        "ETH Zürich", "Universität Wien",
        "Ludwig-Maximilians-Universität", "Humboldt-Universität",
        "Ruprecht-Karls-Universität", "Heidelberg",
        "Fraunhofer", "Max-Planck-Institut", "Helmholtz",
        "Leibniz-Gemeinschaft", "DFG",

        // DACH geography
        "München", "Zürich", "Wien", "Düsseldorf", "Nürnberg", "Köln",
        "Frankfurt", "Stuttgart", "Hamburg", "Berlin",
        "Österreich", "Schweiz", "Liechtenstein",
        "Nordrhein-Westfalen", "Baden-Württemberg", "Bayern",
        "Niedersachsen", "Hessen", "Sachsen", "Thüringen",
        "Rheinland-Pfalz", "Schleswig-Holstein", "Brandenburg",
        "Mecklenburg-Vorpommern", "Saarland", "Sachsen-Anhalt",
        "Salzburg", "Innsbruck", "Graz", "Linz",
        "Bern", "Basel", "Genf", "Lausanne",

        // Legal and administrative terms
        "Grundgesetz", "Steuernummer", "Sozialversicherungsnummer",
        "IBAN", "BIC", "Handelsregister",
        "Personalausweis", "Reisepass", "Aufenthaltstitel",
        "Steuererklärung", "Einkommensteuerbescheid",
        "Umsatzsteuer", "Mehrwertsteuer", "Gewerbesteuer",
        "Grundbuch", "Katasteramt", "Notar",
        "Arbeitsvertrag", "Kündigungsschutz", "Betriebsrat",
        "Datenschutz-Grundverordnung", "DSGVO",
        "Bürgerliches Gesetzbuch", "BGB",
        "Handelsgesetzbuch", "HGB",
        "Strafgesetzbuch", "StGB",
        "Zivilprozessordnung", "ZPO"
    ]

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "äh", "ähm",
        "also", "halt",
        "sozusagen", "quasi",
        "irgendwie", "genau",
        "na ja", "tja",
        "sag mal", "weißt du",
        "gell", "oder",
        "ne", "ja",
        "eben", "eigentlich",
        "gewissermaßen", "im Prinzip",
        "sagen wir mal", "praktisch"
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": """
            Hallo, wie geht es Ihnen? Heute ist der 15.05.2026 und unsere Besprechung \
            beginnt um 14:30 Uhr. Der vereinbarte Betrag liegt bei 1.500,00 €, mit \
            Mehrwertsteuer können es bis zu 2.350,75 € werden. Ich habe die E-Mail \
            bereits an das Team geschickt; wir müssen bis morgen die Rückmeldung von \
            Herrn Müller, Frau Schmidt und Dr. Weber abwarten. Vergessen Sie nicht, \
            den Entwurf zu überprüfen — ich habe die Schwerpunkte hervorgehoben: \
            Zeitplan, Umfang und Budget. In München zeigt die App keinen Stau auf \
            der A9, aber die S-Bahn hat Verspätung. Die Idee ist einfach: zuerst das \
            Wesentliche erledigen, dann zur nächsten Phase des Projekts übergehen.
            """,
        "technical": """
            Wir besprechen die Softwarearchitektur auf Deutsch. Heute ist der 15.05.2026 \
            und wir überprüfen die REST-API des Backends in Node.js, das Frontend in \
            React mit TypeScript, das Deployment auf AWS über Docker und Kubernetes, \
            Observability mit Grafana und Prometheus, die PostgreSQL-Datenbank, den \
            Redis-Cache. Pull Request, Code Review, CI/CD-Pipeline, async/await, \
            Callback, Endpoint, JSON-Payload, JWT, OAuth 2.0, gRPC, GraphQL, \
            Microservices, Load Balancer, Terraform, Infrastructure as Code.
            """,
        "medical": """
            Dies ist eine klinische Besprechung auf Deutsch. Patient, 52 Jahre, \
            klagt über Dyspnoe seit 4 Tagen, bekannte arterielle Hypertonie unter \
            Ramipril 5 mg, Diabetes mellitus Typ 2 unter Metformin 1000 mg, \
            LDL-Cholesterin 158 mg/dl, Nüchternblutzucker 134 mg/dl. Anordnung: \
            großes Blutbild, GOT, GPT, Kreatinin, Harnstoff, Echokardiographie, \
            BNT-pro-BNP. ICD-10 I10. Überweisung an die Kardiologie. \
            Gesetzliche Krankenversicherung, Kassenärztliche Vereinigung, Ärztekammer.
            """,
        "legal": """
            Es handelt sich um eine Klageschrift auf Deutsch. Kläger: Max Mustermann, \
            Steuer-ID 12 345 678 901, wohnhaft Musterstraße 15, 80331 München. \
            Der Kläger macht Schadensersatz gemäß § 823 BGB geltend. Beklagte: \
            Beispiel GmbH, HRB 12345, Amtsgericht München. Aktenzeichen 5 O 123/26, \
            Landgericht München I. Grundgesetz Art. 14, Zivilprozessordnung, \
            Bundesgerichtshof, Bundesverfassungsgericht, Rechtsanwaltskammer.
            """
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    de: standard German orthography (post-1996 reform), decimal comma, period \
    as thousands separator ("1.500,00 €"), dd.mm.jjjj date format, 24h time \
    with colon (14:30), capitalised nouns, scharfes S "ß" where applicable \
    (Switzerland substitutes "ss"). Numbers below 13 typically spelled out \
    in formal prose. Use German quotation style: „opening" and "closing".
    """
}
