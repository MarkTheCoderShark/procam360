import SwiftUI

extension View {
    func fvAccessibilityLabel(_ label: String) -> some View {
        self.accessibilityLabel(label)
    }

    func fvAccessibilityHint(_ hint: String) -> some View {
        self.accessibilityHint(hint)
    }

    func fvAccessibilityAction(_ name: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: name, action)
    }

    func fvAccessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View {
        self.accessibilityElement(children: children)
    }

    func fvAccessibilityHidden(_ hidden: Bool = true) -> some View {
        self.accessibilityHidden(hidden)
    }

    func fvAccessibilityIdentifier(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }
}

struct FVAccessibilityLabels {
    static let camera = "Open camera"
    static let takePhoto = "Take photo"
    static let recordVideo = "Record video"
    static let switchCamera = "Switch between front and back camera"
    static let flashToggle = "Toggle flash"
    static let voiceNote = "Record voice note"

    static let projectList = "List of projects"
    static let createProject = "Create new project"
    static let projectSettings = "Project settings"
    static let shareProject = "Share project"
    static let deleteProject = "Delete project"

    static let photoGrid = "Photo gallery"
    static let photoDetail = "Full screen photo view"
    static let downloadPhoto = "Download photo"
    static let addComment = "Add comment to photo"

    static let timeline = "Photos sorted by date"
    static let mapView = "Photos shown on map"
    static let folderView = "Photos organized in folders"

    static let syncStatus = "Sync status"
    static let syncInProgress = "Syncing in progress"
    static let syncComplete = "All changes synced"
    static let syncPending = "Changes pending sync"

    static func photoAt(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Photo taken on \(formatter.string(from: date))"
    }

    static func projectWith(name: String, photoCount: Int) -> String {
        "\(name) project with \(photoCount) photos"
    }

    static func folderWith(name: String, photoCount: Int) -> String {
        "\(name) folder containing \(photoCount) photos"
    }
}

struct AccessibilityAnnouncementModifier: ViewModifier {
    let announcement: String
    @Binding var trigger: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                    trigger = false
                }
            }
    }
}

extension View {
    func fvAnnounce(_ message: String, when trigger: Binding<Bool>) -> some View {
        self.modifier(AccessibilityAnnouncementModifier(announcement: message, trigger: trigger))
    }
}

struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation
    let reducedAnimation: Animation

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: UUID())
    }
}

extension View {
    func fvAnimation(_ animation: Animation, reduced: Animation = .linear(duration: 0)) -> some View {
        self.modifier(ReduceMotionModifier(animation: animation, reducedAnimation: reduced))
    }
}
