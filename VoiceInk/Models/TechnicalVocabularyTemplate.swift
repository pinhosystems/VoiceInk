import Foundation

/// Canonical English-spelled tech vocabulary for code dictation. Mirrors the
/// purpose of `BrazilianVocabularyTemplate` but for engineering terms that any
/// dev — regardless of source language — needs the STT/LLM stack to spell
/// correctly. Surfaced via "Adicionar vocabulário técnico" in the Vocabulary
/// panel. Pairs naturally with the "Code" prompt template and the
/// `WhisperPromptDomain.technical` STT seed.
///
/// Selection criteria:
/// 1. Term has canonical EN spelling commonly mangled by phonetic STT.
/// 2. Term is high-frequency in modern engineering dictation.
/// 3. Term is unambiguous in writing (no homograph collisions with common
///    non-technical words).
enum TechnicalVocabularyTemplate {

    static let canonicalWords: [String] = [
        // Languages
        "JavaScript", "TypeScript", "Python", "Go", "Rust", "Swift", "Kotlin",
        "Java", "Ruby", "PHP", "C#", "C++", "Elixir", "Erlang", "Haskell",
        "Lua", "Dart", "Scala", "Clojure", "Bash", "Zsh", "PowerShell",

        // Web frameworks / libraries
        "React", "Next.js", "Vue", "Nuxt", "Angular", "Svelte", "SvelteKit",
        "SolidJS", "Remix", "Astro", "Qwik",
        "Express", "Fastify", "NestJS", "Hono", "Koa",
        "Django", "FastAPI", "Flask", "Starlette",
        "Rails", "Sinatra", "Phoenix", "Laravel", "Symfony",
        "Spring Boot", "ASP.NET", "Gin", "Echo", "Actix",

        // Mobile / desktop
        "SwiftUI", "UIKit", "Jetpack Compose", "React Native", "Flutter",
        "Tauri", "Electron",

        // Build / bundler / runtime
        "Vite", "Webpack", "esbuild", "Rollup", "Parcel", "Turbopack",
        "Babel", "SWC", "tsx", "ts-node", "Bun", "Deno", "Node.js",

        // Package managers
        "npm", "yarn", "pnpm", "pip", "poetry", "uv", "cargo", "go mod",
        "composer", "Gradle", "Maven", "CocoaPods", "Swift Package Manager",

        // Databases
        "PostgreSQL", "MySQL", "MariaDB", "SQLite", "MongoDB", "Redis",
        "Elasticsearch", "DynamoDB", "Cassandra", "ClickHouse", "DuckDB",
        "Snowflake", "BigQuery",

        // Cloud / infra / hosting
        "AWS", "GCP", "Azure", "Cloudflare", "Vercel", "Netlify", "Fly.io",
        "Railway", "Render", "Heroku", "Supabase", "Firebase", "PlanetScale",
        "Neon", "Turso",

        // DevOps / containers / IaC
        "Docker", "Kubernetes", "Helm", "Terraform", "Pulumi", "Ansible",
        "Nomad", "Consul", "Vault",

        // CI/CD
        "GitHub Actions", "GitLab CI", "CircleCI", "Jenkins", "Buildkite",
        "Drone CI",

        // Observability
        "Grafana", "Prometheus", "Datadog", "New Relic", "Sentry",
        "OpenTelemetry", "Jaeger", "Loki", "Tempo",

        // Protocols / specs / concepts
        "REST", "GraphQL", "gRPC", "WebSocket", "Server-Sent Events", "SSE",
        "JWT", "OAuth", "OIDC", "SAML", "mTLS", "CORS", "CSRF", "XSS",
        "SSR", "SSG", "ISR", "CSR", "RAG", "ORM", "RPC", "ABAC", "RBAC",

        // React / Vue hooks and primitives
        "useState", "useEffect", "useMemo", "useCallback", "useRef",
        "useContext", "useReducer", "useLayoutEffect", "useTransition",
        "useDeferredValue", "useSyncExternalStore",
        "ref", "computed", "watch", "watchEffect", "onMounted", "onUnmounted",

        // VCS / collaboration
        "Git", "GitHub", "GitLab", "Bitbucket", "Gitea", "Sourcetree",
        "commit", "branch", "merge", "rebase", "cherry-pick", "stash",
        "pull request", "merge request", "code review",

        // Files / configs
        "package.json", "tsconfig.json", "package-lock.json", "yarn.lock",
        "pnpm-lock.yaml", "Cargo.toml", "Cargo.lock", "go.mod", "go.sum",
        "Dockerfile", "docker-compose.yml", ".env", ".gitignore",
        "README.md", "CHANGELOG.md", "Makefile",

        // Editors / IDEs
        "VS Code", "IntelliJ IDEA", "PyCharm", "WebStorm", "GoLand",
        "Android Studio", "Xcode", "Cursor", "Zed", "Neovim", "Emacs",

        // AI / ML stack
        "Claude", "GPT", "Gemini", "Ollama", "LangChain", "LlamaIndex",
        "OpenAI", "Anthropic", "Hugging Face", "PyTorch", "TensorFlow",
        "scikit-learn", "pandas", "NumPy",

        // Networking
        "HTTP", "HTTPS", "TCP", "UDP", "DNS", "TLS", "SSL", "IP", "CDN",
        "VPC", "subnet", "load balancer",

        // API / data formats
        "JSON", "YAML", "TOML", "XML", "Protocol Buffers", "Avro",
        "OpenAPI", "Swagger", "AsyncAPI",

        // Common concepts (canonical spelling)
        "endpoint", "payload", "callback", "promise", "async", "await",
        "middleware", "decorator", "schema", "migration", "rollback",
        "deploy", "rollout", "canary", "blue-green", "feature flag",
        "webhook", "cron", "queue", "worker", "sidecar", "ingress", "egress",

        // Security tooling
        "SAST", "DAST", "SCA", "CSP", "WAF", "IAM", "KMS", "SSO", "MFA"
    ]

    static var count: Int { canonicalWords.count }
}
