import Foundation
import os

/// Curated, generic Spanish pack covering all es-* variants (es-ES, es-MX,
/// es-AR, es-CL, es-CO, es-PE, etc.).
///
/// Content prioritises universality across both peninsular Spanish and Latin
/// American varieties. When conventions diverge (voseo, currency, document
/// IDs), Latin American conventions take precedence given the larger market,
/// but the pack avoids region-specific transforms that would break another
/// variant. Region-specific packs (es-MX, es-AR, es-ES) can ship later with
/// an explicit bcp47 override.
///
/// Holds: text normalization (phone, DNI/NIE, decimal comma), chat-abbreviation
/// expansions, high-frequency vocabulary for STT biasing, spoken fillers,
/// Whisper prompt seeds (general + domain-specific), and the es
/// `<LOCALE_RULES>` block.
struct SpanishPack: LocalePack {
    let primarySubtag: String = "es"
    let displayName: String = "Spanish"

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Spanish phone (Spain): "+34 612 345 678" or "612 345 678"
        NormalizerRule(
            pattern: #"(?<!\d)(\+?34[\s.-]?)?([6-9]\d{2})[\s.-]?(\d{3})[\s.-]?(\d{3})(?!\d)"#,
            options: [],
            replacement: "$1$2 $3 $4",
            description: "Format Spanish mobile/landline: 612 345 678"
        ),
        // DNI (Spain): 8 digits + letter -> "12.345.678-Z"
        NormalizerRule(
            pattern: #"(?i)\b(\d{2})\.?(\d{3})\.?(\d{3})[\s-]?([A-Z])\b"#,
            options: [.caseInsensitive],
            replacement: "$1.$2.$3-$4",
            description: "Format DNI: 12.345.678-Z"
        ),
        // NIE (Spain): X/Y/Z + 7 digits + letter -> "X-1234567-Z"
        NormalizerRule(
            pattern: #"(?i)\b([XYZ])[\s-]?(\d{7})[\s-]?([A-Z])\b"#,
            options: [.caseInsensitive],
            replacement: "$1-$2-$3",
            description: "Format NIE: X-1234567-Z"
        ),
        // Thousands separator for 4+ digit numbers followed by currency-like
        // context (not already formatted). E.g. "1500 euros" stays as-is for now
        // since the LLM handles currency formatting via aiPromptFormatRules.

        // Decimal comma spoken as "coma": "3 coma 5" -> "3,5"
        NormalizerRule(
            pattern: #"\b(\d+)\s+coma\s+(\d+)\b"#,
            options: [.caseInsensitive],
            replacement: "$1,$2",
            description: "Decimal comma: '3 coma 5' -> '3,5'"
        ),
        // Percentage spoken: "50 por ciento" -> "50%"
        NormalizerRule(
            pattern: #"\b(\d+)\s+por\s+ciento\b"#,
            options: [.caseInsensitive],
            replacement: "$1%",
            description: "Percent: '50 por ciento' -> '50%'"
        )
    ]

    // MARK: - Word Replacements (chat/SMS abbreviations)

    let wordReplacements: [(original: String, replacement: String)] = [
        // Conjunctions / prepositions
        ("xq, pq, xk, pk", "porque"),
        ("xfa, porfa", "por favor"),
        ("q", "que"),
        ("x", "por"),
        ("d", "de"),
        ("tb, tmb", "también"),
        ("dnd", "donde"),
        ("xa", "para"),
        ("cm", "como"),
        ("cn", "con"),
        ("bn, bnn", "bien"),
        ("pdo", "puedo"),

        // Nouns / common words
        ("msj, msg", "mensaje"),
        ("tel", "teléfono"),
        ("info", "información"),
        ("depto, dpto", "departamento"),
        ("aprox", "aproximadamente"),
        ("gral", "general"),
        ("atte", "atentamente"),
        ("ppal", "principal"),
        ("gob", "gobierno"),
        ("admin", "administración"),
        ("dir", "dirección"),
        ("doc, docs", "documento"),
        ("fav", "favorito"),
        ("cel", "celular"),
        ("compu", "computadora"),
        ("app", "aplicación"),
        ("lab", "laboratorio"),
        ("prof", "profesor"),
        ("univ", "universidad"),
        ("secu", "secundaria"),
        ("prepa", "preparatoria"),

        // Pronouns / formality
        ("Ud", "usted"),
        ("Uds", "ustedes"),

        // Adjectives / adverbs
        ("tbien", "también"),
        ("tmpc, tpc", "tampoco"),
        ("mcho, mxo", "mucho"),
        ("pco", "poco"),
        ("bno", "bueno"),
        ("mlo", "malo"),

        // Greetings / closings
        ("hla", "hola"),
        ("bs, bss", "besos"),
        ("slds", "saludos"),
        ("grax, grcs", "gracias"),

        // Days / time
        ("hr, hrs", "hora"),
        ("min", "minuto"),
        ("seg", "segundo"),
        ("lun", "lunes"),
        ("mar", "martes"),
        ("mie, mier", "miércoles"),
        ("jue", "jueves"),
        ("vie", "viernes"),
        ("sab", "sábado"),
        ("dom", "domingo")
    ]

    // MARK: - Vocabulary Terms (STT biasing)

    let vocabularyTerms: [String] = [
        // --- Spanish institutions (Spain) ---
        "RAE", "Real Academia Española",
        "RTVE", "Radio Televisión Española",
        "Instituto Cervantes", "Cervantes",
        "Tribunal Supremo", "Tribunal Constitucional",
        "Cortes Generales", "Congreso de los Diputados", "Senado",
        "Audiencia Nacional", "Consejo General del Poder Judicial", "CGPJ",
        "Guardia Civil", "Policía Nacional", "Mossos d'Esquadra",
        "Banco de España", "CNMV",
        "Agencia Tributaria", "Hacienda",
        "Seguridad Social", "SEPE",

        // --- Latin American shared institutions ---
        "OEA", "Organización de Estados Americanos",
        "CEPAL", "Comisión Económica para América Latina",
        "Mercosur", "MERCOSUR",
        "BID", "Banco Interamericano de Desarrollo",
        "CELAC", "Alianza del Pacífico",
        "OPS", "Organización Panamericana de la Salud",

        // --- Mexico ---
        "SAT", "Servicio de Administración Tributaria",
        "IMSS", "Instituto Mexicano del Seguro Social",
        "ISSSTE", "Pemex", "UNAM", "IPN",
        "Banxico", "Banco de México",
        "INE", "Instituto Nacional Electoral",
        "CURP", "RFC",
        "Secretaría de Hacienda", "SHCP",
        "Telmex", "Televisa", "TV Azteca",
        "América Móvil", "FEMSA", "Grupo Bimbo",

        // --- Argentina ---
        "AFIP", "CUIT", "CUIL", "DNI",
        "ANSES", "BCRA", "Banco Central de la República Argentina",
        "Mercado Libre", "YPF", "Aerolíneas Argentinas",

        // --- Colombia ---
        "DIAN", "NIT", "EPS",
        "Registraduría Nacional",
        "Bancolombia", "Ecopetrol", "Avianca",

        // --- Chile ---
        "SII", "Servicio de Impuestos Internos",
        "RUT", "RUN", "AFP",
        "Isapre", "Fonasa",
        "BancoEstado", "LATAM Airlines",
        "Codelco",

        // --- Peru ---
        "SUNAT", "RUC", "DNI",
        "Banco de la Nación",

        // --- Proper nouns STT struggles with ---
        "México", "García", "González", "Rodríguez",
        "Hernández", "López", "Martínez", "Pérez",
        "Sánchez", "Ramírez", "Fernández", "Díaz",
        "Álvarez", "Gutiérrez", "Jiménez", "Núñez",
        "Buenos Aires", "Ciudad de México", "CDMX",
        "Bogotá", "Santiago", "Lima", "Caracas",
        "Montevideo", "Quito", "La Paz",
        "Guadalajara", "Monterrey", "Medellín", "Barranquilla",
        "Córdoba", "Rosario", "Valparaíso", "Cartagena",

        // --- Currency / document codes ---
        "EUR", "USD", "MXN", "ARS", "CLP", "COP", "PEN", "UYU",
        "DNI", "NIE", "NIF", "RFC", "CURP", "CUIT", "RUT", "NIT", "RUC",

        // --- Tech terms in Spanish context ---
        "aplicación", "contraseña", "servidor", "almacenamiento",
        "base de datos", "inteligencia artificial",
        "aprendizaje automático", "nube",
        "ciberseguridad", "cortafuegos",
        "enlace", "descarga", "actualización",
        "sistema operativo", "navegador",
        "red neuronal", "algoritmo",
        "WiFi", "Bluetooth", "USB",
        "iPhone", "Android", "WhatsApp", "Telegram",
        "Google", "Microsoft", "Amazon", "Apple",
        "ChatGPT", "OpenAI", "Anthropic",
        "PostgreSQL", "MongoDB", "Kubernetes", "Docker",

        // --- Legal terminology ---
        "amparo", "recurso de casación",
        "habeas corpus", "habeas data",
        "tutela", "acción popular",
        "código civil", "código penal",
        "ley orgánica", "decreto supremo",
        "escritura pública", "poder notarial",
        "sociedad anónima", "S.A.", "S.L.", "S.R.L.",
        "S.A.S.", "S.A. de C.V.",

        // --- Medical terminology ---
        "hipertensión", "diabetes mellitus",
        "insuficiencia cardíaca", "infarto",
        "electrocardiograma", "ECG",
        "resonancia magnética", "tomografía",
        "hemoglobina", "glucemia", "colesterol",
        "ibuprofeno", "paracetamol", "omeprazol",
        "CIE-10", "OMS"
    ]

    // MARK: - Filler Words

    let fillerWords: [String] = [
        // Universal Spanish fillers
        "este", "eh", "em", "ah", "uhm",
        "o sea", "bueno", "pues",
        "digamos", "a ver", "mira",
        "sabes", "entonces",
        "es decir", "básicamente", "obviamente",
        "la verdad", "tipo", "como que",
        "¿no?", "¿verdad?", "¿me entiendes?",
        "nada", "digo", "vaya",
        "hombre", "mujer", "tío", "tía",
        "dale", "vale", "oye",
        "fíjate", "imagínate", "literal",
        "en plan", "o algo así",
        "cómo te digo", "cómo te explico",
        "es que", "la cosa es que",
        "al final", "de hecho",
        "prácticamente", "sinceramente",
        "la neta", "güey", "wey",
        "onda", "rollo"
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": """
            Hola, ¿cómo estás? Hoy es 15/05/2026 y la reunión está programada para las 14:30. \
            El presupuesto aprobado fue de $1.500.000 y podría llegar a €2.350,75 con impuestos. \
            Ya envié el correo al equipo; necesitamos confirmar con María, José y Alejandro antes del viernes. \
            No olvides revisar la propuesta — puse énfasis en los puntos principales: plazo, alcance y presupuesto. \
            En Ciudad de México el tráfico está complicado, pero la aplicación muestra ruta alterna por Periférico. \
            La idea es sencilla: empezar por lo esencial y después avanzar a la siguiente fase del proyecto.
            """,
        "technical": """
            Estamos discutiendo arquitectura de software en español. Hoy es 15/05/2026 \
            y vamos a revisar la API REST del backend en Node.js, el frontend en React \
            con TypeScript, despliegue en AWS mediante Docker y Kubernetes, observabilidad \
            en Grafana, base de datos PostgreSQL, caché Redis. Pull request, code review, \
            CI/CD, async/await, callback, endpoint, payload JSON, JWT, OAuth, gRPC, \
            microservicios, balanceador de carga, certificado SSL, DNS, CDN.
            """,
        "medical": """
            Consulta clínica en español. Paciente masculino de 52 años con antecedentes de \
            hipertensión arterial controlada con losartán 50 mg, diabetes mellitus tipo 2 \
            en tratamiento con metformina 850 mg. Motivo de consulta: dolor torácico de 2 días \
            de evolución, disnea de esfuerzo. Signos vitales: TA 140/90, FC 88, FR 20, \
            SatO2 94%. Solicitar electrocardiograma, troponinas, BNP, hemograma, perfil \
            lipídico, glucemia, creatinina. Diagnóstico presuntivo: síndrome coronario agudo. \
            CIE-10 I20.9. Referir a cardiología. IMSS, EPS, Fonasa.
            """,
        "legal": """
            Escrito de demanda en español. Actor: María García López, DNI 12.345.678-Z, \
            con domicilio en Calle Gran Vía 45, 3.º B, Madrid, C.P. 28013. Demandado: \
            Empresa Constructora XYZ S.A., NIF A-12345678. Se interpone recurso de amparo \
            por vulneración de derechos fundamentales, artículo 24 de la Constitución. \
            Cuantía: €75.000,00. Juzgado de Primera Instancia n.º 5. Poder notarial, \
            escritura pública, sociedad anónima, habeas corpus, recurso de casación, \
            Tribunal Supremo, Audiencia Nacional, código civil, OAB, SAT, DIAN.
            """,
        "corporate": """
            Reunión corporativa en español, 15/05/2026 a las 14:30. Agenda: revisión del \
            presupuesto Q2, meta de $1.500.000 en ingresos, OKRs del equipo de producto, \
            contratación de 3 ingenieros senior, alineación con stakeholders, seguimiento \
            de las acciones de la reunión anterior, próximos pasos para el sprint, fecha \
            límite 30/06/2026. Participantes: Ana, Carlos, Sofía, Diego. ROI, NPS, CAC, \
            LTV, KPI, MVP, EBITDA, P&L, forecast, pipeline, churn rate.
            """
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    es: standard Spanish orthography (RAE), decimal comma, thousands dot \
    ("1.500,00"), € or $ depending on regional currency, dd/mm/aaaa, 24h \
    time ("14:30"), inverted opening punctuation (¿, ¡), lowercase month \
    and weekday names. Use Real Academia Española conventions: no space \
    before colon, em-dash with spaces for parenthetical clauses, angular \
    quotation marks («...») for outer quotes and double quotes ("...") for \
    inner. Ordinals abbreviated with superscript: 1.º, 2.ª. Percentages: \
    "50 %" (with space before % per RAE). Addresses: "C/ Gran Vía, 45, \
    3.º B, 28013 Madrid". DNI format: "12.345.678-Z".
    """

    // MARK: - Custom Normalize

    var customNormalize: ((String) -> String)? {
        { SpanishNormalizer.normalize($0) }
    }

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        ("Mi DNI es 12345678Z.", "Mi DNI es 12.345.678-Z."),
        ("El NIE es X1234567Z.", "El NIE es X-1234567-Z."),
        ("Llámame al 612345678.", "Llámame al 612 345 678."),
        ("Son 3 coma 5 litros.", "Son 3,5 litros."),
        ("Creció 50 por ciento.", "Creció 50%.")
    ]
}

// MARK: - File-private normalization implementation

/// Spanish-specific text normalization applied AFTER raw STT and word
/// replacements, but BEFORE the AI enhancement step. Runs via
/// `SpanishPack.customNormalize` when `LocalePackRegistry` resolves
/// the es pack and `LocaleNormalizationEnabled` is on.
///
/// Rules are conservative: a regex that matches confidently or not at all.
/// The goal is to handle high-frequency cases (DNI, NIE, phone numbers,
/// spoken decimals, percentages) without ever risking silent corruption
/// of legitimate text.
private enum SpanishNormalizer {
    private static let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink",
        category: "SpanishNormalizer"
    )

    /// Maps Spanish number words (0..29) to their numeric values. Used for
    /// time normalization ("las dos y media" -> "14:30") and currency.
    private static let basicNumberWords: [String: Int] = [
        "cero": 0,
        "una": 1, "uno": 1, "un": 1,
        "dos": 2,
        "tres": 3,
        "cuatro": 4,
        "cinco": 5,
        "seis": 6,
        "siete": 7,
        "ocho": 8,
        "nueve": 9,
        "diez": 10,
        "once": 11,
        "doce": 12,
        "trece": 13,
        "catorce": 14,
        "quince": 15,
        "dieciséis": 16, "dieciseis": 16,
        "diecisiete": 17,
        "dieciocho": 18,
        "diecinueve": 19,
        "veinte": 20,
        "veintiuno": 21, "veintiuna": 21,
        "veintidós": 22, "veintidos": 22,
        "veintitrés": 23, "veintitres": 23,
        "veinticuatro": 24,
        "veinticinco": 25,
        "veintiséis": 26, "veintiseis": 26,
        "veintisiete": 27,
        "veintiocho": 28,
        "veintinueve": 29
    ]

    /// Larger round numbers for percent and currency contexts.
    private static let largerNumberWords: [String: Int] = [
        "treinta": 30, "cuarenta": 40, "cincuenta": 50,
        "sesenta": 60, "setenta": 70, "ochenta": 80, "noventa": 90,
        "cien": 100, "ciento": 100, "doscientos": 200, "trescientos": 300,
        "cuatrocientos": 400, "quinientos": 500, "seiscientos": 600,
        "setecientos": 700, "ochocientos": 800, "novecientos": 900, "mil": 1000
    ]

    static func normalize(_ text: String) -> String {
        var result = text
        result = normalizeHoursAndHalf(result)
        result = normalizeHoursWithPartOfDay(result)
        result = normalizeSpokenPercent(result)
        result = normalizeSpokenDecimal(result)
        result = normalizeSpokenCurrency(result)
        return result
    }

    // MARK: - Hours

    /// "las dos y media" -> "las 2:30"; "las tres y cuarto" -> "las 3:15";
    /// "las diez en punto" -> "las 10:00".
    private static func normalizeHoursAndHalf(_ text: String) -> String {
        let numberAlternation = orderedAlternation(basicNumberWords.keys)
        // "las <number> y media/cuarto/quince/treinta/cuarenta y cinco"
        let pattern = #"(?i)\blas?\s+(\#(numberAlternation))(?:\s+horas?)?\s+y\s+(media|cuarto|quince|treinta|cuarenta\s+y\s+cinco|\d{1,2})\b"#
        var result = rewriteRegex(text, pattern: pattern) { groups in
            guard let hourWord = groups[1]?.lowercased(),
                  let minuteRaw = groups[2]?.lowercased(),
                  let hour = basicNumberWords[hourWord]
            else { return nil }
            let minute = minuteFromPhrase(minuteRaw)
            guard let minute else { return nil }
            let prefix = groups[0]?.hasPrefix("L") == true ? "Las" : "las"
            return String(format: "%@ %d:%02d", prefix, hour, minute)
        }
        // "las <number> en punto"
        let enPuntoPattern = #"(?i)\blas?\s+(\#(numberAlternation))(?:\s+horas?)?\s+en\s+punto\b"#
        result = rewriteRegex(result, pattern: enPuntoPattern) { groups in
            guard let hourWord = groups[1]?.lowercased(),
                  let hour = basicNumberWords[hourWord]
            else { return nil }
            let prefix = groups[0]?.hasPrefix("L") == true ? "Las" : "las"
            return String(format: "%@ %d:00", prefix, hour)
        }
        return result
    }

    /// "las dos de la tarde" -> "las 14:00"; "las ocho de la mañana" -> "las 8:00".
    private static func normalizeHoursWithPartOfDay(_ text: String) -> String {
        let numberAlternation = orderedAlternation(basicNumberWords.keys)
        let pattern = #"(?i)\blas?\s+(\#(numberAlternation))(?:\s+horas?)?\s+(?:de\s+la\s+)(mañana|manana|tarde|noche|madrugada)\b"#
        return rewriteRegex(text, pattern: pattern) { groups in
            guard let hourWord = groups[1]?.lowercased(),
                  let partOfDay = groups[2]?.lowercased(),
                  let raw = basicNumberWords[hourWord]
            else { return nil }
            let hour: Int
            switch partOfDay {
            case "mañana", "manana", "madrugada":
                hour = raw == 12 ? 0 : raw
            case "tarde":
                hour = raw < 12 ? raw + 12 : raw
            case "noche":
                if raw == 12 { hour = 0 }
                else if raw <= 5 { hour = raw }
                else if raw < 12 { hour = raw + 12 }
                else { hour = raw }
            default:
                hour = raw
            }
            let prefix = groups[0]?.hasPrefix("L") == true ? "Las" : "las"
            return String(format: "%@ %d:00", prefix, hour)
        }
    }

    private static func minuteFromPhrase(_ phrase: String) -> Int? {
        switch phrase {
        case "media": return 30
        case "cuarto": return 15
        case "quince": return 15
        case "treinta": return 30
        case "cuarenta y cinco": return 45
        default:
            if let n = Int(phrase), n >= 0, n < 60 { return n }
            return nil
        }
    }

    // MARK: - Percent

    /// "cincuenta por ciento" -> "50%"; "diez por ciento" -> "10%".
    private static func normalizeSpokenPercent(_ text: String) -> String {
        let combined = basicNumberWords.merging(largerNumberWords) { a, _ in a }
        let alternation = orderedAlternation(combined.keys)
        let wordPattern = #"(?i)\b(\#(alternation))\s+por\s+ciento\b"#
        return rewriteRegex(text, pattern: wordPattern) { groups in
            guard let word = groups[1]?.lowercased(),
                  let value = combined[word]
            else { return nil }
            return "\(value)%"
        }
    }

    // MARK: - Decimal "X coma Y"

    /// "tres coma cinco" -> "3,5"; "veinte coma siete" -> "20,7".
    private static func normalizeSpokenDecimal(_ text: String) -> String {
        let alternation = orderedAlternation(basicNumberWords.keys)
        let wordPattern = #"(?i)\b(\#(alternation))\s+coma\s+(\#(alternation)|\d{1,4})\b"#
        return rewriteRegex(text, pattern: wordPattern) { groups in
            guard let leftWord = groups[1]?.lowercased(),
                  let left = basicNumberWords[leftWord]
            else { return nil }
            let rightRaw = groups[2]?.lowercased() ?? ""
            let right: String
            if let n = basicNumberWords[rightRaw] { right = String(n) }
            else { right = rightRaw }
            return "\(left),\(right)"
        }
    }

    // MARK: - Currency

    /// "mil quinientos pesos" -> "$1.500"; "cien euros" -> "€100";
    /// "doscientos dólares" -> "US$200".
    private static func normalizeSpokenCurrency(_ text: String) -> String {
        let combined = basicNumberWords.merging(largerNumberWords) { a, _ in a }
        let alternation = orderedAlternation(combined.keys)

        // "<number> pesos"
        let pesosPattern = #"(?i)\b(\#(alternation))\s+pesos\b"#
        var result = rewriteRegex(text, pattern: pesosPattern) { groups in
            guard let word = groups[1]?.lowercased(),
                  let value = combined[word]
            else { return nil }
            return "$\(insertThousandsSeparator(String(value)))"
        }

        // "<number> euros"
        let eurosPattern = #"(?i)\b(\#(alternation))\s+euros\b"#
        result = rewriteRegex(result, pattern: eurosPattern) { groups in
            guard let word = groups[1]?.lowercased(),
                  let value = combined[word]
            else { return nil }
            return "€\(insertThousandsSeparator(String(value)))"
        }

        // "<number> dólares"
        let dolaresPattern = #"(?i)\b(\#(alternation))\s+d[oó]lares\b"#
        result = rewriteRegex(result, pattern: dolaresPattern) { groups in
            guard let word = groups[1]?.lowercased(),
                  let value = combined[word]
            else { return nil }
            return "US$\(insertThousandsSeparator(String(value)))"
        }

        // Numeric: "1500 pesos" -> "$1.500"
        let numPesosPattern = #"(?i)\b(\d{1,9})\s+pesos(?:\s+(?:con|y)\s+(\d{1,2})\s+centavos)?\b"#
        result = rewriteRegex(result, pattern: numPesosPattern) { groups in
            guard let inteiros = groups[1] else { return nil }
            let withDots = insertThousandsSeparator(inteiros)
            if let cents = groups[2], let n = Int(cents), n > 0 {
                return "$\(withDots),\(String(format: "%02d", n))"
            }
            return "$\(withDots)"
        }

        return result
    }

    private static func insertThousandsSeparator(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        let chars = Array(digits.reversed())
        var out = ""
        for (i, c) in chars.enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(c)
        }
        return String(out.reversed())
    }

    // MARK: - Regex helpers

    /// Alternation pattern with longest entries first so "veinticinco"
    /// matches before "veinti".
    private static func orderedAlternation<S: Sequence>(_ words: S) -> String where S.Element == String {
        words
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
    }

    /// Applies a regex with capture groups exposed as a dictionary.
    private static func rewriteRegex(
        _ text: String,
        pattern: String,
        transform: ([Int: String]) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .useUnicodeWordBoundaries]
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        var output = ""
        var cursor = text.startIndex
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let matchRange = Range(match.range, in: text) else { return }
            output.append(contentsOf: text[cursor..<matchRange.lowerBound])
            var groups: [Int: String] = [:]
            for i in 0..<match.numberOfRanges {
                if let r = Range(match.range(at: i), in: text) {
                    groups[i] = String(text[r])
                }
            }
            let original = String(text[matchRange])
            output.append(transform(groups) ?? original)
            cursor = matchRange.upperBound
        }
        output.append(contentsOf: text[cursor..<text.endIndex])
        return output
    }
}
