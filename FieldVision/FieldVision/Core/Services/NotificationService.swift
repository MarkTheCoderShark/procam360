import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published private(set) var isAuthorized = false
    @Published private(set) var deviceToken: String?
    
    private let apiClient = APIClient.shared
    
    override private init() {
        super.init()
    }
    
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        
        Task {
            await registerDeviceToken(token)
        }
    }
    
    func handleDeviceTokenError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    private func registerDeviceToken(_ token: String) async {
        do {
            try await apiClient.registerDeviceToken(token: token, platform: "ios")
        } catch {
            print("Failed to register device token with server: \(error)")
        }
    }
    
    func unregisterDeviceToken() async {
        guard let token = deviceToken else { return }
        
        do {
            try await apiClient.unregisterDeviceToken(token: token)
            deviceToken = nil
        } catch {
            print("Failed to unregister device token: \(error)")
        }
    }
    
    func handleNotification(_ userInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
        guard let notificationType = userInfo["type"] as? String else {
            completionHandler()
            return
        }
        
        switch notificationType {
        case "new_photo":
            handleNewPhotoNotification(userInfo)
        case "new_comment":
            handleNewCommentNotification(userInfo)
        case "project_invite":
            handleProjectInviteNotification(userInfo)
        case "sync_complete":
            handleSyncCompleteNotification(userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleNewPhotoNotification(_ userInfo: [AnyHashable: Any]) {
        guard let projectId = userInfo["projectId"] as? String,
              let photoId = userInfo["photoId"] as? String else { return }
        
        NotificationCenter.default.post(
            name: .didReceiveNewPhoto,
            object: nil,
            userInfo: ["projectId": projectId, "photoId": photoId]
        )
    }
    
    private func handleNewCommentNotification(_ userInfo: [AnyHashable: Any]) {
        guard let photoId = userInfo["photoId"] as? String,
              let commentId = userInfo["commentId"] as? String else { return }
        
        NotificationCenter.default.post(
            name: .didReceiveNewComment,
            object: nil,
            userInfo: ["photoId": photoId, "commentId": commentId]
        )
    }
    
    private func handleProjectInviteNotification(_ userInfo: [AnyHashable: Any]) {
        guard let projectId = userInfo["projectId"] as? String else { return }
        
        NotificationCenter.default.post(
            name: .didReceiveProjectInvite,
            object: nil,
            userInfo: ["projectId": projectId]
        )
    }
    
    private func handleSyncCompleteNotification(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .didCompleteSyncFromServer,
            object: nil,
            userInfo: userInfo
        )
    }
    
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String,
        userInfo: [AnyHashable: Any] = [:],
        delay: TimeInterval = 0
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        let trigger: UNNotificationTrigger?
        if delay > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        } else {
            trigger = nil
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func removeScheduledNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func updateBadgeCount(_ count: Int) {
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        Task { @MainActor in
            NotificationService.shared.handleNotification(userInfo, completionHandler: completionHandler)
        }
    }
}

extension Notification.Name {
    static let didReceiveNewPhoto = Notification.Name("didReceiveNewPhoto")
    static let didReceiveNewComment = Notification.Name("didReceiveNewComment")
    static let didReceiveProjectInvite = Notification.Name("didReceiveProjectInvite")
    static let didCompleteSyncFromServer = Notification.Name("didCompleteSyncFromServer")
}
