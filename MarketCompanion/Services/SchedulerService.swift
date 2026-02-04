// SchedulerService.swift
// MarketCompanion
//
// In-app scheduler for automated report generation.
// Checks time-of-day and triggers morning/close reports on schedule.
// Also manages LaunchAgent installation for background scheduling.

import Foundation

@MainActor
final class SchedulerService: ObservableObject {
    @Published var isMorningScheduled = true
    @Published var isCloseScheduled = true
    @Published var morningTime = Calendar.current.date(from: DateComponents(hour: 6, minute: 30)) ?? Date()
    @Published var closeTime = Calendar.current.date(from: DateComponents(hour: 13, minute: 0)) ?? Date()
    @Published var isLaunchAgentInstalled = false
    @Published var lastScheduledRun: Date?

    private var checkTimer: Timer?
    private var lastMorningDate: Date?
    private var lastCloseDate: Date?

    init() {
        checkLaunchAgentStatus()
    }

    // MARK: - In-App Scheduling

    func startScheduler(morningAction: @escaping () async -> Void, closeAction: @escaping () async -> Void) {
        // Check every 60 seconds if it's time to run
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkSchedule(morningAction: morningAction, closeAction: closeAction)
            }
        }
        print("[Scheduler] In-app scheduler started")
    }

    func stopScheduler() {
        checkTimer?.invalidate()
        checkTimer = nil
        print("[Scheduler] In-app scheduler stopped")
    }

    private func checkSchedule(morningAction: @escaping () async -> Void, closeAction: @escaping () async -> Void) async {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        let morningHour = calendar.component(.hour, from: morningTime)
        let morningMinute = calendar.component(.minute, from: morningTime)
        let closeHour = calendar.component(.hour, from: closeTime)
        let closeMinute = calendar.component(.minute, from: closeTime)

        // Check if it's a weekday
        let weekday = calendar.component(.weekday, from: now)
        guard weekday >= 2 && weekday <= 6 else { return } // Mon-Fri only

        // Morning report
        if isMorningScheduled && currentHour == morningHour && currentMinute == morningMinute {
            if lastMorningDate == nil || !calendar.isDate(lastMorningDate!, inSameDayAs: now) {
                lastMorningDate = now
                lastScheduledRun = now
                print("[Scheduler] Triggering morning report")
                await morningAction()
            }
        }

        // Close report
        if isCloseScheduled && currentHour == closeHour && currentMinute == closeMinute {
            if lastCloseDate == nil || !calendar.isDate(lastCloseDate!, inSameDayAs: now) {
                lastCloseDate = now
                lastScheduledRun = now
                print("[Scheduler] Triggering close report")
                await closeAction()
            }
        }
    }

    // MARK: - LaunchAgent Management

    private var launchAgentPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents/com.marketcompanion.scheduler.plist"
    }

    func checkLaunchAgentStatus() {
        isLaunchAgentInstalled = FileManager.default.fileExists(atPath: launchAgentPath)
    }

    func installLaunchAgent() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Find the app path
        let appPath: String
        if let bundlePath = Bundle.main.bundlePath as String? {
            appPath = bundlePath
        } else {
            appPath = "/Applications/Market Companion.app"
        }

        let morningHour = Calendar.current.component(.hour, from: morningTime)
        let morningMinute = Calendar.current.component(.minute, from: morningTime)
        let closeHour = Calendar.current.component(.hour, from: closeTime)
        let closeMinute = Calendar.current.component(.minute, from: closeTime)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.marketcompanion.scheduler</string>

            <key>ProgramArguments</key>
            <array>
                <string>open</string>
                <string>-a</string>
                <string>\(appPath)</string>
                <string>--args</string>
                <string>--generate-report</string>
            </array>

            <key>StartCalendarInterval</key>
            <array>
                <dict>
                    <key>Hour</key>
                    <integer>\(morningHour)</integer>
                    <key>Minute</key>
                    <integer>\(morningMinute)</integer>
                </dict>
                <dict>
                    <key>Hour</key>
                    <integer>\(closeHour)</integer>
                    <key>Minute</key>
                    <integer>\(closeMinute)</integer>
                </dict>
            </array>

            <key>StandardOutPath</key>
            <string>\(home)/Library/Logs/MarketCompanion/scheduler.log</string>

            <key>StandardErrorPath</key>
            <string>\(home)/Library/Logs/MarketCompanion/scheduler-error.log</string>

            <key>RunAtLoad</key>
            <false/>

            <key>EnvironmentVariables</key>
            <dict>
                <key>TZ</key>
                <string>America/Los_Angeles</string>
            </dict>
        </dict>
        </plist>
        """

        // Create log directory
        let logDir = "\(home)/Library/Logs/MarketCompanion"
        try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)

        // Create LaunchAgents directory if needed
        let launchAgentsDir = "\(home)/Library/LaunchAgents"
        try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)

        // Write plist
        try plist.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)

        // Load via launchctl
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", launchAgentPath]
        try process.run()
        process.waitUntilExit()

        isLaunchAgentInstalled = true
        print("[Scheduler] LaunchAgent installed at \(launchAgentPath)")
    }

    func uninstallLaunchAgent() throws {
        guard FileManager.default.fileExists(atPath: launchAgentPath) else { return }

        // Unload via launchctl
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", launchAgentPath]
        try process.run()
        process.waitUntilExit()

        try FileManager.default.removeItem(atPath: launchAgentPath)
        isLaunchAgentInstalled = false
        print("[Scheduler] LaunchAgent uninstalled")
    }
}
