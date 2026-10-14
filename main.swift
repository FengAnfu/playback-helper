// Target player continuous playback helper for macOS. Run: bash run.sh
// Uses macOS accessibility controls, without screen coordinates or third-party libraries.
import AppKit
import ApplicationServices
import Darwin

let bundleID = "CONFIGURE_BUNDLE_ID"
let pageLabel = "CONFIGURE_PAGE_LABEL"
let playerLabel = "CONFIGURE_PLAYER_LABEL"
let detailsLabel = "CONFIGURE_DETAILS_LABEL"
let playLabel = "CONFIGURE_PLAY_LABEL"
let pauseLabel = "CONFIGURE_PAUSE_LABEL"
let replayLabel = "CONFIGURE_REPLAY_LABEL"
let nextLabel = "CONFIGURE_NEXT_LABEL"
let inspectOnly = CommandLine.arguments.contains("--inspect")
let maxMinutes: Double = 120             // Maximum runtime in minutes, including pauses and waiting.
let maxNextCount = 50                     // Maximum number of automatic chapter transitions.
let pollSeconds: Double = 2              // Polling interval in seconds.

func log(_ message: String) {
    print("[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(message)")
    fflush(stdout)
}

// Read an accessibility attribute; return nil when unavailable.
func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func string(_ element: AXUIElement, _ name: String) -> String {
    (attribute(element, name) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
}

struct Node {
    let element: AXUIElement
    let role: String
    let labels: [String]
    func named(_ name: String) -> Bool { labels.contains(name) }
}

func node(_ element: AXUIElement) -> Node {
    Node(element: element, role: string(element, kAXRoleAttribute),
         labels: [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute]
            .map { string(element, $0) }.filter { !$0.isEmpty })
}


enum ReadError: Error { case incomplete }
func walk(_ root: AXUIElement, limit: Int = 6000) throws -> [Node] {
    var result: [Node] = []
    let deadline = Date().addingTimeInterval(10)
    func visit(_ element: AXUIElement, _ depth: Int) throws {
        guard depth < 80, result.count < limit, Date() < deadline else { throw ReadError.incomplete }
        result.append(node(element))
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard status == .success || status == .attributeUnsupported || status == .noValue else {
            throw ReadError.incomplete
        }
        for child in value as? [AXUIElement] ?? [] { try visit(child, depth + 1) }
    }
    try visit(root, 0)
    return result
}

// Fresh foreground check. A stored NSRunningApplication keeps its isActive value until a
// run loop turns, which never happens here, so it must be looked up again before each click.
func targetIsFrontmost() -> Bool {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.isActive ?? false
}

// Invoke AXPress on the control; leave failures for manual handling.
func press(_ target: Node) -> Bool {
    if let enabled = attribute(target.element, kAXEnabledAttribute) as? Bool, !enabled { return false }
    return AXUIElementPerformAction(target.element, kAXPressAction as CFString) == .success
}

// Read terminal commands: p/r/q followed by Enter, or Ctrl+C to exit.
func command() -> String? {
    var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    guard poll(&descriptor, 1, 0) > 0, descriptor.revents & Int16(POLLIN) != 0 else { return nil }
    return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

if CommandLine.arguments.contains("--help") {
    print("Usage: bash run.sh [--inspect]\n--inspect: print learning-page controls without clicking.\np + Enter: pause automation; r + Enter: resume; q + Enter: quit.")
    exit(0)
}

// Permission must be granted by the user in System Settings; this check changes nothing.
let targetConfiguration = [bundleID, pageLabel, playerLabel, detailsLabel, playLabel, pauseLabel, replayLabel, nextLabel]
if targetConfiguration.contains(where: { $0.hasPrefix("CONFIGURE_") }) {
    print("No target is configured. Set the bundle identifier and accessibility labels in the source, then rebuild. No controls were inspected or clicked.")
    exit(2)
}

guard AXIsProcessTrusted() else {
    print("Accessibility access is required. In System Settings > Privacy & Security > Device Control and Data Access (Accessibility on older versions), enable the VS Code or terminal app running this script, then run it again.")
    exit(1)
}

log("Open the desired video chapter in Target player and keep Target player in the foreground.")
log("p + Enter pauses automation; r + Enter resumes; q + Enter quits. Ctrl+C stops the script.")
var paused = false
var lastMessage = ""
func status(_ message: String) {
    if message != lastMessage { log(message); lastMessage = message }
}
func hold(_ reason: String) {
    paused = true
    log(reason + ". After resolving this, enter r in the terminal, then return to Target player.")
}

let started = Date()
var nextCount = 0
var waitingForChapter: String? = nil
var nextClickedAt = Date.distantPast
var lastPlayAt = Date.distantPast
var unknownSince: Date? = nil
var endedSince: Date? = nil
var lastChapter = ""

while Date().timeIntervalSince(started) < maxMinutes * 60 {
    if let input = command() {
        if input == "q" { break }
        if input == "p" { paused = true; log("Automation paused. Any currently playing video continues playing.") }
        if input == "r" {
            paused = false; unknownSince = nil; endedSince = nil
            log("Automation resumed. Return to Target player.")
        }
    }
    if paused { Thread.sleep(forTimeInterval: 0.3); continue }
    guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
        status("Waiting for Target player to start..."); Thread.sleep(forTimeInterval: pollSeconds); continue
    }
    // Stop clicking while another application is active.
    guard running.isActive || inspectOnly else {
        status("Waiting for Target player to return to the foreground..."); Thread.sleep(forTimeInterval: 0.5); continue
    }
    let app = AXUIElementCreateApplication(running.processIdentifier)
    AXUIElementSetMessagingTimeout(app, 1)
    do {
        let all = try walk(app)
        let pages = all.filter { $0.role == "AXWebArea" && $0.named(pageLabel) }
        guard pages.count == 1 else {
            status("Open exactly one student learning page; detected \(pages.count).")
            Thread.sleep(forTimeInterval: pollSeconds); continue
        }
        let page = try walk(pages[0].element)
        if inspectOnly {
            for item in page where !item.labels.isEmpty {
                print("\(item.role): \(Array(Set(item.labels)).sorted().joined(separator: " | "))")
            }
            exit(0)
        }
        // Chinese control labels were observed in version 1.4.2. Check updates with --inspect.
        let players = page.filter { $0.named(playerLabel) }
        let headings = page.filter { $0.role == kAXStaticTextRole }.flatMap { $0.labels.prefix(1) }
        let chapter: String
        if let index = headings.firstIndex(of: detailsLabel), headings.indices.contains(index + 1) {
            chapter = headings[index + 1]
        } else {
            // The page may still be loading after a transition; hold only if this persists.
            if unknownSince == nil { unknownSince = Date() }
            if Date().timeIntervalSince(unknownSince!) > 20 { hold("Cannot identify the chapter title") }
            Thread.sleep(forTimeInterval: pollSeconds); continue
        }
        if chapter != lastChapter {
            log("Current chapter: \(chapter)")
            lastChapter = chapter; endedSince = nil; unknownSince = nil
            lastPlayAt = .distantPast
        }
        // Confirm the chapter title changed after clicking Next, then wait for the player.
        if let previous = waitingForChapter {
            if chapter != previous {
                waitingForChapter = nil
                Thread.sleep(forTimeInterval: 3)
            } else if Date().timeIntervalSince(nextClickedAt) > 20 {
                hold("The chapter did not change or the course has ended; check manually")
                waitingForChapter = nil
            } else { Thread.sleep(forTimeInterval: pollSeconds) }
            continue
        }
        // Multiple videos, text pages, and quizzes require manual selection.
        guard players.count == 1 else {
            if unknownSince == nil { unknownSince = Date() }
            if Date().timeIntervalSince(unknownSince!) > 20 {
                hold("This chapter has no unique recognized player; open a video chapter manually")
            }
            Thread.sleep(forTimeInterval: pollSeconds); continue
        }
        let controls = try walk(players[0].element)
        let buttons = controls.filter { $0.role == kAXButtonRole }
        let replay = buttons.filter { $0.named(replayLabel) }
        let play = buttons.filter { $0.named(playLabel) }
        let pause = buttons.filter { $0.named(pauseLabel) }
        // A Replay control signals playback ended; observe it for 4 seconds before advancing.
        if replay.count == 1 && pause.isEmpty && play.isEmpty {
            unknownSince = nil
            if endedSince == nil { endedSince = Date() }
            if Date().timeIntervalSince(endedSince!) >= 4 {
                guard nextCount < maxNextCount else { log("Chapter transition limit reached. Exiting."); break }
                let next = page.filter { $0.role == kAXButtonRole && $0.named(nextLabel) }
                guard targetIsFrontmost() else { continue }  // Left the foreground; wait for it.
                guard next.count == 1 else { hold("Cannot identify a unique Next Chapter button"); continue }
                // Record the attempt before clicking to avoid duplicate transitions after an API timeout.
                waitingForChapter = chapter; nextClickedAt = Date(); endedSince = nil
                if press(next[0]) {
                    nextCount += 1; log("Video ended. Moving to the next chapter (transition \(nextCount)).")
                } else { hold("The Next Chapter click result is uncertain; inspect the interface") }
            }
        } else if pause.count == 1 {
            unknownSince = nil; endedSince = nil
            status("Playing: \(chapter)")
        } else if play.count == 1 && replay.isEmpty {
            endedSince = nil; unknownSince = nil
            // Start each chapter once; later pauses may require user interaction.
            if lastPlayAt == .distantPast {
                guard targetIsFrontmost() else { continue }  // Left the foreground; wait for it.
                lastPlayAt = Date()
                if press(play[0]) { log("Clicked Play.") }
                else { hold("Could not click Play") }
            } else if Date().timeIntervalSince(lastPlayAt) > 15 {
                hold("Video did not start or was paused; check the player and any dialogs")
            }
        } else {
            endedSince = nil
            if unknownSince == nil { unknownSince = Date() }
            if Date().timeIntervalSince(unknownSince!) > 20 { hold("Cannot recognize the player state") }
        }
    } catch {
        hold("Interface reading was incomplete or timed out")
    }
    Thread.sleep(forTimeInterval: pollSeconds)
}
log("Script stopped. Target player and the current video remain in their existing state.")
