import Foundation

/// Generic French pack covering fr, fr-FR, fr-CA, fr-BE, fr-CH.
/// Metropolitan French conventions as default; universally applicable content
/// that reads correctly across all francophone regions.
///
/// Input transforms: filler-word removal, abbreviation expansion, vocabulary
/// biasing for proper nouns / institutions, and regex normalizers for phone
/// numbers, postal codes, and business identifiers (SIRET/SIREN).
///
/// Output: Whisper prompt seeds across multiple domains plus a comprehensive
/// formatting-rules block for the LLM enhancement step.
struct FrenchPack: LocalePack {
    let primarySubtag: String = "fr"
    let displayName: String = "French"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "euh",
        "ben",
        "bah",
        "enfin",
        "bon",
        "voilà",
        "quoi",
        "genre",
        "en fait",
        "du coup",
        "c'est-à-dire",
        "tu vois",
        "vous voyez",
        "hein",
        "disons",
        "bref",
        "effectivement",
        "justement",
        "forcément",
        "comment dire"
    ]

    // MARK: - Word Replacements (abbreviation expansions)

    let wordReplacements: [(original: String, replacement: String)] = [
        ("stp", "s'il te plaît"),
        ("svp", "s'il vous plaît"),
        ("bcp", "beaucoup"),
        ("tjs, tjrs", "toujours"),
        ("qd, qnd", "quand"),
        ("qq, qqn", "quelqu'un"),
        ("qqch", "quelque chose"),
        ("pb, pbm", "problème"),
        ("rdv", "rendez-vous"),
        ("aprem", "après-midi"),
        ("tel", "téléphone"),
        ("info", "information"),
        ("infos", "informations"),
        ("ordi", "ordinateur"),
        ("resto", "restaurant"),
        ("env", "environ"),
        ("dept", "département"),
        ("gouv", "gouvernement"),
        ("ds", "dans"),
        ("ns", "nous"),
        ("vs", "vous"),
        ("ms", "mais"),
        ("mtn, mnt", "maintenant"),
        ("ajd", "aujourd'hui"),
        ("càd", "c'est-à-dire"),
        ("pk, pq", "pourquoi"),
        ("pcq, pck", "parce que"),
        ("bsr", "bonsoir"),
        ("bjr", "bonjour"),
        ("slt", "salut"),
        ("mrc", "merci"),
        ("dsl", "désolé"),
        ("sms", "message"),
        ("biz", "bisous"),
        ("pr", "pour"),
        ("tt", "tout"),
        ("tps", "temps"),
        ("auj", "aujourd'hui"),
        ("ptdr", "mort de rire"),
        ("jr, jrs", "jour"),
        ("sem", "semaine"),
        ("mat", "matin"),
        ("aprem, aprèm", "après-midi")
    ]

    // MARK: - Vocabulary Terms (STT biasing)

    let vocabularyTerms: [String] = [
        // Institutions et organismes publics
        "Assemblée nationale",
        "Sénat",
        "Conseil d'État",
        "Cour de cassation",
        "Conseil constitutionnel",
        "Cour des comptes",
        "INSEE",
        "SNCF",
        "EDF",
        "RATP",
        "Élysée",
        "Matignon",
        "Quai d'Orsay",
        "Bercy",

        // Protection sociale et administration
        "Sécurité sociale",
        "Pôle emploi",
        "France Travail",
        "URSSAF",
        "CPAM",
        "CAF",
        "RSA",
        "SMIC",
        "Assurance maladie",
        "Mutuelle",
        "ANTS",
        "Préfecture",
        "Mairie",

        // Fiscalité et entreprise
        "SIRET",
        "SIREN",
        "TVA",
        "impôt sur le revenu",
        "CSG",
        "CRDS",
        "CFE",
        "CVAE",
        "auto-entrepreneur",
        "micro-entreprise",
        "SAS",
        "SARL",
        "EURL",
        "SA",
        "Kbis",
        "greffe",
        "CCI",

        // Éducation
        "baccalauréat",
        "grandes écoles",
        "Sciences Po",
        "HEC",
        "Polytechnique",
        "ENS",
        "CNRS",
        "INSERM",
        "Collège de France",
        "Sorbonne",
        "université",
        "licence",
        "master",
        "doctorat",
        "BTS",
        "DUT",
        "BUT",
        "classe préparatoire",
        "CPGE",
        "agrégation",
        "CAPES",

        // Noms propres et lieux
        "Champs-Élysées",
        "François",
        "Château",
        "Notre-Dame",
        "Montmartre",
        "Versailles",
        "Lyon",
        "Marseille",
        "Toulouse",
        "Bordeaux",
        "Strasbourg",
        "Montpellier",
        "Bruxelles",
        "Genève",
        "Lausanne",
        "Québec",
        "Montréal",

        // Médias et culture
        "RTBF",
        "RTS",
        "Radio-Canada",
        "France Télévisions",
        "France Inter",
        "France Culture",
        "Arte",
        "TF1",
        "BFM",
        "Le Monde",
        "Le Figaro",
        "Libération",

        // Santé
        "ANSM",
        "HAS",
        "ARS",
        "CHU",
        "EHPAD",
        "médecin traitant",
        "carte Vitale",
        "ordonnance",

        // Juridique
        "tribunal judiciaire",
        "cour d'appel",
        "tribunal administratif",
        "procureur",
        "avocat",
        "huissier",
        "notaire",
        "PACS",
        "Code civil",
        "Code pénal",
        "CNIL",
        "RGPD",

        // Transports et infrastructure
        "TGV",
        "RER",
        "métro",
        "Navigo",
        "péage",
        "autoroute",
        "Air France",
        "Eurostar",
        "Thalys",

        // Termes courants avec orthographe non triviale
        "Ça",
        "où",
        "là",
        "déjà",
        "à côté",
        "peut-être",
        "c'est-à-dire",
        "aujourd'hui",
        "quelqu'un",
        "jusqu'à",
        "presqu'île"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // French phone numbers: reformat 10-digit sequences into "0X XX XX XX XX"
        // Matches 10 consecutive digits starting with 0, possibly separated by
        // spaces, dots, or dashes.
        NormalizerRule(
            pattern: #"(?<!\d)0([1-9])[\s.-]?(\d{2})[\s.-]?(\d{2})[\s.-]?(\d{2})[\s.-]?(\d{2})(?!\d)"#,
            replacement: "0$1 $2 $3 $4 $5",
            description: "Format French phone number as 0X XX XX XX XX"
        ),

        // SIRET (14 digits): reformat as "XXX XXX XXX XXXXX"
        NormalizerRule(
            pattern: #"(?<!\d)(\d{3})[\s.-]?(\d{3})[\s.-]?(\d{3})[\s.-]?(\d{5})(?!\d)"#,
            replacement: "$1 $2 $3 $4",
            description: "Format SIRET as XXX XXX XXX XXXXX"
        ),

        // SIREN (9 digits): reformat as "XXX XXX XXX"
        // Only matches when NOT followed by more digits (avoids partial SIRET match).
        NormalizerRule(
            pattern: #"(?<!\d)(\d{3})[\s.-]?(\d{3})[\s.-]?(\d{3})(?!\d)"#,
            replacement: "$1 $2 $3",
            description: "Format SIREN as XXX XXX XXX"
        ),

        // French postal codes: ensure 5 consecutive digits stay together.
        // Matches a word boundary followed by 5 digits (starting with valid
        // department prefixes 01-97) not surrounded by more digits.
        NormalizerRule(
            pattern: #"(?<!\d)(0[1-9]|[1-8]\d|9[0-7])\s?(\d{3})(?!\d)"#,
            replacement: "$1$2",
            description: "Normalize French postal code to 5 digits"
        )
    ]

    let normalizationExamples: [(before: String, after: String)] = [
        ("Appelez-moi au 06.12.34.56.78", "Appelez-moi au 06 12 34 56 78"),
        ("SIRET 123 456 789 00012", "SIRET 123 456 789 00012"),
        ("Code postal 75 001", "Code postal 75001")
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": """
            Bonjour, comment allez-vous ? Aujourd'hui nous sommes le 15/05/2026 et la \
            réunion est prévue à 14h30. Le montant convenu est de 1 500,00 €, pouvant \
            atteindre 2 350,75 € avec les taxes. J'ai déjà envoyé le courriel à \
            l'équipe ; il faut confirmer avec François, Élise et Jean-Pierre avant \
            demain. N'oubliez pas de relire la proposition — j'ai mis l'accent sur les \
            points principaux : délai, périmètre et budget. À Paris, la circulation est \
            fluide, mais l'application indique des ralentissements sur le périphérique. \
            L'idée est simple : commencer par l'essentiel, puis passer à la prochaine \
            étape du projet.
            """,
        "technical": """
            Nous discutons d'architecture logicielle en français. Aujourd'hui, le \
            15/05/2026, nous allons passer en revue l'API REST du backend en Node.js, \
            le frontend en React avec TypeScript, le déploiement sur AWS via Docker et \
            Kubernetes, l'observabilité sur Grafana, la base de données PostgreSQL, le \
            cache Redis. Pull request, code review, CI/CD, async/await, callback, \
            endpoint, payload JSON, JWT, OAuth, gRPC, microservices.
            """,
        "medical": """
            Consultation médicale en français. Patient de 52 ans présentant une dyspnée \
            d'effort depuis une semaine, hypertension artérielle traitée par amlodipine \
            5 mg, diabète de type 2 sous metformine 1000 mg, cholestérol LDL à 1,52 g/L, \
            glycémie à jeun 1,26 g/L. Prescrire : NFS, ionogramme, créatininémie, BNP, \
            ECG, échocardiographie. Antécédents : appendicectomie, allergie aux \
            pénicillines. Carte Vitale, ALD, CPAM, HAS, ANSM.
            """,
        "legal": """
            Conclusions en français. Demandeur : M. Jean-Pierre Dupont, né le \
            12/03/1975, domicilié au 25 rue des Lilas, 75015 Paris. Assignation en \
            responsabilité civile sur le fondement des articles 1240 et 1241 du Code \
            civil. Défendeur : la société XYZ SAS, SIRET 123 456 789 00012, siège \
            social au 8 avenue de la République, 69003 Lyon. Tribunal judiciaire, \
            cour d'appel, Cour de cassation, procureur, CNIL, RGPD, préjudice moral, \
            dommages et intérêts.
            """,
        "corporate": """
            Réunion d'entreprise en français, le 15/05/2026 à 14h30. Ordre du jour : \
            revue du budget T2, objectif de 1 500 000 € de chiffre d'affaires, OKR de \
            l'équipe produit, recrutement de 3 ingénieurs seniors, alignement avec les \
            parties prenantes, suivi des actions de la dernière réunion, prochaines \
            étapes pour le sprint, date limite le 30/06/2026. Participants : François, \
            Élise, Jean-Pierre, Marie. ROI, NPS, CAC, LTV, KPI, MVP, EBITDA.
            """
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    fr: standard French orthography, decimal comma, non-breaking space as \
    thousands separator and before currency symbol ("1 500,00 €"), \
    dd/mm/aaaa, 24h time with "h" separator (14h30), lowercase month and \
    weekday names. French typography requires a non-breaking space before \
    the two-part punctuation marks ":", ";", "!", "?" and inside «…» quotes. \
    Use typographic apostrophe (') not ASCII ('). Elision mandatory before \
    vowels and mute h (l'homme, j'ai, c'est, d'accord, n'est-ce pas). \
    Trait d'union in compound numbers below 100 (vingt-trois, quatre-vingts). \
    Ligatures "œ" and "æ" where standard (cœur, œuvre, curriculum vitæ). \
    Metric system (km, kg, °C) with space between number and unit.
    """
}
