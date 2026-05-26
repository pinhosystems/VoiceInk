import Foundation
import AppKit
import os

enum BrowserType {
    case safari
    case arc
    case chrome
    case edge
    case firefox
    case brave
    case opera
    case vivaldi
    case orion
    case zen
    case yandex
    
    var scriptName: String {
        switch self {
        case .safari: return "safariURL"
        case .arc: return "arcURL"
        case .chrome: return "chromeURL"
        case .edge: return "edgeURL"
        case .firefox: return "firefoxURL"
        case .brave: return "braveURL"
        case .opera: return "operaURL"
        case .vivaldi: return "vivaldiURL"
        case .orion: return "orionURL"
        case .zen: return "zenURL"
        case .yandex: return "yandexURL"
        }
    }
    
    var bundleIdentifier: String {
        switch self {
        case .safari: return "com.apple.Safari"
        case .arc: return "company.thebrowser.Browser"
        case .chrome: return "com.google.Chrome"
        case .edge: return "com.microsoft.edgemac"
        case .firefox: return "org.mozilla.firefox"
        case .brave: return "com.brave.Browser"
        case .opera: return "com.operasoftware.Opera"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .orion: return "com.kagi.kagimacOS"
        case .zen: return "app.zen-browser.zen"
        case .yandex: return "ru.yandex.desktop.yandex-browser"
        }
    }
    
    var displayName: String {
        switch self {
        case .safari: return "Safari"
        case .arc: return "Arc"
        case .chrome: return "Google Chrome"
        case .edge: return "Microsoft Edge"
        case .firefox: return "Firefox"
        case .brave: return "Brave"
        case .opera: return "Opera"
        case .vivaldi: return "Vivaldi"
        case .orion: return "Orion"
        case .zen: return "Zen Browser"
        case .yandex: return "Yandex Browser"
        }
    }
    
    static var allCases: [BrowserType] {
        [.safari, .arc, .chrome, .edge, .brave, .opera, .vivaldi, .orion, .yandex]
    }
    
    static var installedBrowsers: [BrowserType] {
        allCases.filter { browser in
            let workspace = NSWorkspace.shared
            return workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) != nil
        }
    }
}

enum BrowserURLError: Error {
    case scriptNotFound
    case executionFailed
    case browserNotRunning
    case noActiveWindow
    case noActiveTab
}

class BrowserURLService {
    static let shared = BrowserURLService()

    /// Hard timeout for AppleScript URL extraction. Browsers occasionally hang
    /// (e.g., during heavy startup or when blocked on a system prompt), and
    /// `task.waitUntilExit()` will sit forever. 3 seconds is plenty for a
    /// well-behaved browser to return its active tab URL and short enough that
    /// a stall does not freeze Power Mode application.
    private static let appleScriptTimeoutSeconds: TimeInterval = 3.0

    private let logger = Logger(
        subsystem: "agabo.dev.voiceink",
        category: "browser.applescript"
    )

    private init() {}

    func getCurrentURL(from browser: BrowserType) async throws -> String {
        guard let scriptURL = Bundle.main.url(forResource: browser.scriptName, withExtension: "scpt") else {
            logger.error("❌ AppleScript file not found: \(browser.scriptName, privacy: .public).scpt")
            throw BrowserURLError.scriptNotFound
        }

        logger.debug("🔍 Attempting to execute AppleScript for \(browser.displayName, privacy: .public)")

        if !isRunning(browser) {
            logger.error("❌ Browser not running: \(browser.displayName, privacy: .public)")
            throw BrowserURLError.browserNotRunning
        }

        let output = try await runAppleScriptWithTimeout(at: scriptURL, label: browser.displayName)

        if output.isEmpty {
            logger.error("❌ Empty output from AppleScript for \(browser.displayName, privacy: .public)")
            throw BrowserURLError.noActiveTab
        }
        if output.lowercased().contains("error") {
            logger.error("❌ AppleScript error for \(browser.displayName, privacy: .public): \(output, privacy: .public)")
            throw BrowserURLError.executionFailed
        }
        logger.debug("✅ Successfully retrieved URL from \(browser.displayName, privacy: .public): \(output, privacy: .public)")
        return output
    }

    /// Runs `osascript <scriptURL>` off the calling cooperative thread with a
    /// bounded wait. Times out and terminates the subprocess after
    /// `appleScriptTimeoutSeconds` so a hung browser cannot stall Power Mode
    /// application indefinitely.
    private func runAppleScriptWithTimeout(at scriptURL: URL, label: String) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [logger] in
                let task = Process()
                task.launchPath = "/usr/bin/osascript"
                task.arguments = [scriptURL.path]

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe

                let semaphore = DispatchSemaphore(value: 0)
                task.terminationHandler = { _ in semaphore.signal() }

                do {
                    try task.run()
                } catch {
                    logger.error("❌ AppleScript spawn failed for \(label, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: BrowserURLError.executionFailed)
                    return
                }

                let waitResult = semaphore.wait(timeout: .now() + Self.appleScriptTimeoutSeconds)
                if waitResult == .timedOut {
                    if task.isRunning {
                        task.terminate()
                        _ = semaphore.wait(timeout: .now() + 1)
                    }
                    logger.error("❌ AppleScript timed out after \(Self.appleScriptTimeoutSeconds, privacy: .public)s for \(label, privacy: .public)")
                    continuation.resume(throwing: BrowserURLError.executionFailed)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let raw = String(data: data, encoding: .utf8) else {
                    logger.error("❌ Failed to decode AppleScript output for \(label, privacy: .public)")
                    continuation.resume(throwing: BrowserURLError.executionFailed)
                    return
                }
                continuation.resume(returning: raw.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
    
    func isRunning(_ browser: BrowserType) -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let isRunning = runningApps.contains { $0.bundleIdentifier == browser.bundleIdentifier }
        logger.debug("\(browser.displayName, privacy: .public) running status: \(isRunning, privacy: .public)")
        return isRunning
    }
} 
