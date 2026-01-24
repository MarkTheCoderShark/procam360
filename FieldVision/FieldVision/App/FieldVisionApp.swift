import SwiftUI
import SwiftData
import UserNotifications
import RevenueCat

@main
struct FieldVisionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer

    @StateObject private var appState = AppState()
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var purchaseService = PurchaseService.shared

    init() {
        PurchaseService.shared.configure()
        
        do {
            let schema = Schema([
                User.self,
                Project.self,
                Folder.self,
                Photo.self,
                Comment.self,
                ProjectShareLink.self,
                SyncQueueItem.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to configure SwiftData: \(error)")
        }

        let authVM = AuthViewModel()
        _authViewModel = StateObject(wrappedValue: authVM)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(notificationService)
                .environmentObject(purchaseService)
                .task {
                    await notificationService.checkAuthorizationStatus()
                }
        }
        .modelContainer(container)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationService.shared.handleDeviceTokenError(error)
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthFlowView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab: Tab = .projects

    enum Tab: Hashable {
        case projects
        case activity
        case map
        case settings
    }

    init() {
        // Configure UITabBar appearance for proper colors
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        // Selected tab item color
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)]

        // Unselected tab item color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ProjectListView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(Tab.projects)

            ActivityDashboardView()
                .tabItem {
                    Label("Activity", systemImage: "chart.bar.fill")
                }
                .tag(Tab.activity)

            ProjectMapTab()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.map)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Color(red: 0, green: 0.478, blue: 1))
    }
}
