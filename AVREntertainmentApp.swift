//
//  AVREntertainmentApp.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications
import FirebaseMessaging


class AppDelegate: NSObject, UIApplicationDelegate {
    let gcmMessageIDKey = "gcm.message_id"
    
    // Store FCM token and customer ID for cleanup
    private var storedFCMToken: String?
    private var storedCustomerId: String?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        Messaging.messaging().delegate = self
        
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        
        // Store app launch flag for cleanup detection
        UserDefaults.standard.set(true, forKey: "AppLaunched")
        
        return true
    }
    
    // Handle app termination - attempt to clean up FCM token
    func applicationWillTerminate(_ application: UIApplication) {
        cleanupFCMTokenOnTermination()
    }
    
    // Handle app entering background - store current state for cleanup
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Store current FCM token and customer ID for potential cleanup
        if let currentUser = Auth.auth().currentUser,
           let email = currentUser.email, !email.isEmpty {
            storedCustomerId = currentUser.uid
            Task {
                if let token = try? await Messaging.messaging().token() {
                    storedFCMToken = token
                    UserDefaults.standard.set(token, forKey: "LastFCMToken")
                    UserDefaults.standard.set(currentUser.uid, forKey: "LastCustomerId")
                }
            }
        }
    }
    
    func cleanupFCMTokenOnTermination() {
        // Try to clean up FCM token on app termination
        // Note: This may not always execute due to iOS limitations, but we try
        if let currentUser = Auth.auth().currentUser,
           let email = currentUser.email, !email.isEmpty {
            let customerId = currentUser.uid
            let token = storedFCMToken ?? UserDefaults.standard.string(forKey: "LastFCMToken")
            
            if let token = token {
                Task {
                    await FirestoreManager.shared.removeToken(token, customerId: customerId)
                }
            }
        }
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to auth
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        print("Device token received: \(deviceToken.map { String(format: "%02x", $0) }.joined())")
        
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        //        if let messageID = userInfo[gcmMessageIDKey] {sign
        //                print("Message ID: \(messageID)")
        //              }
        //
        //              print(userInfo)
        
        if Auth.auth().canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        // This notification is not auth related; it should be handled separately.
    }
    
    func application(_ application: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }else{
            return false
        }
        // URL not auth related; it should be handled separately.
    }
}

@main
struct AVREntertainmentApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var navigationManager = NavigationManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationManager)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Handle app lifecycle changes
                    if newPhase == .background {
                        // App entered background - store state for cleanup
                        delegate.applicationDidEnterBackground(UIApplication.shared)
                        // Don't reset flags - keep them so navigation works when returning
                    } else if newPhase == .inactive {
                        // App is about to terminate - attempt cleanup
                        if oldPhase == .background {
                            delegate.cleanupFCMTokenOnTermination()
                        }
                    }
                    // Note: Views will mark themselves ready when becoming active via their own onChange handlers
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateFromNotification"))) { (notification: Notification) in
                    if let userInfo = notification.userInfo,
                       let screen = userInfo["screen"] as? String {
                        
                        let projectId = userInfo["projectId"] as? String
                        let chatId = userInfo["chatId"] as? String
                        let expenseId = userInfo["expenseId"] as? String
                        let phaseId = userInfo["phaseId"] as? String
                        let requestId = userInfo["requestId"] as? String
                        let customerId = userInfo["customerId"] as? String
                        
                        // Determine expense screen type
                        let expenseScreenType: NavigationManager.ExpenseScreenType? = {
                            if screen == "expense_chat" {
                                return .chat
                            } else if screen == "expense_detail" || screen == "expert_detail" {
                                return .detail
                            }
                            return nil
                        }()
                        
                        // Check if app and views are ready
                        if navigationManager.readyState == .projectListLoaded || navigationManager.readyState == .fullyReady {
                            // Views are ready, navigate immediately
                            print("✅ Views ready, navigating immediately to: \(screen)")
                            if screen == "project_detail" || screen == "project_detail1" {
                                if let projectId = projectId {
                                    navigationManager.setProjectId(projectId)
                                }
                            } else if screen == "chat_detail" || screen == "chat_screen" {
                                // For chat notifications: Navigate to project first, then open ChatsView
                                if let projectId = projectId {
                                    // Check if we're already in the target project
                                    let currentProjectId = navigationManager.activeProjectId?.id
                                    
                                    if currentProjectId == projectId {
                                        // Already in the target project, just set chatId directly
                                        print("📍 Already in project \(projectId), setting chatId directly")
                                        if let chatId = chatId {
                                            // Small delay to ensure DashboardView is ready
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                navigationManager.setChatId(chatId)
                                            }
                                        }
                                    } else {
                                        // Need to navigate to project first
                                        navigationManager.setProjectId(projectId)
                                        // Delay chat navigation to ensure project view is loaded
                                        // DashboardView/ProjectDetailView will open ChatsView sheet, which will then navigate to specific chat
                                        if let chatId = chatId {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                navigationManager.setChatId(chatId)
                                            }
                                        }
                                    }
                                }
                            } else if screen == "expense_detail" || screen == "expert_detail" || screen == "expense_review" {
                                // For expense notifications: Navigate to project first, then to expense
                                if let projectId = projectId {
                                    navigationManager.setProjectId(projectId)
                                    if let expenseId = expenseId {
                                        // Delay expense navigation to ensure project is fully loaded
                                        // DashboardView/ProjectDetailView will handle showing expense detail
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            navigationManager.setExpenseId(expenseId, screenType: .detail)
                                        }
                                    }
                                }
                            } else if screen == "expense_chat" {
                                // For expense chat notifications: Navigate to project first, then to expense chat
                                if let projectId = projectId {
                                    navigationManager.setProjectId(projectId)
                                    if let expenseId = expenseId {
                                        // Delay expense chat navigation to ensure project is fully loaded
                                        // DashboardView/ProjectDetailView will handle showing expense chat
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            navigationManager.setExpenseId(expenseId, screenType: .chat)
                                        }
                                    }
                                }
                            } else if screen == "phase_detail" {
                                // For phase notifications: Navigate to project first, then to phase
                                if let projectId = projectId {
                                    navigationManager.setProjectId(projectId)
                                    if let phaseId = phaseId {
                                        // Delay phase navigation to ensure project is fully loaded
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            navigationManager.setPhaseId(phaseId)
                                        }
                                    }
                                }
                            } else if screen == "request_detail" {
                                // For request notifications: Navigate to project first, then to request
                                if let projectId = projectId {
                                    navigationManager.setProjectId(projectId)
                                    if let requestId = requestId {
                                        // Delay request navigation to ensure project is fully loaded
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            navigationManager.setRequestId(requestId)
                                        }
                                    }
                                }
                            } else if screen == "project_creation" || screen == "project_review" {
                                // Navigate to project creation/review screen for rejected projects
                                if let projectId = projectId {
                                    // Set projectId which will trigger navigation to CreateProjectView in ProjectListView
                                    // The ProjectListView will handle fetching the project and showing CreateProjectView
                                    navigationManager.setProjectId(projectId)
                                }
                            }
                        } else {
                            // Views not ready, store for later
                            print("⏳ Views not ready, storing navigation intent: \(screen)")
                            navigationManager.storePendingNavigation(
                                screen: screen,
                                projectId: projectId,
                                chatId: chatId,
                                expenseId: expenseId,
                                phaseId: phaseId,
                                requestId: requestId,
                                expenseScreenType: expenseScreenType
                            )
                        }
                    }
                }
        }
    }
}


extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM token received: \(fcmToken ?? "nil")")
        // Save to Firestore under current user
        if let token = fcmToken {
            // Store token for cleanup
            storedFCMToken = token
            if let currentUser = Auth.auth().currentUser,
               let email = currentUser.email, !email.isEmpty {
                storedCustomerId = currentUser.uid
                UserDefaults.standard.set(token, forKey: "LastFCMToken")
                UserDefaults.standard.set(currentUser.uid, forKey: "LastCustomerId")
            }
            
            Task {
                await FirestoreManager.shared.saveToken(token: token)
            }
        }
    }
}


@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        print(userInfo)
        
        // Save notification to NotificationManager
        Task { @MainActor in
            let title = notification.request.content.title
            let body = notification.request.content.body
            let projectId = userInfo["projectId"] as? String
            
            // Convert userInfo to [String: Any] for storage
            var data: [String: Any] = [:]
            for (key, value) in userInfo {
                if let keyString = key as? String {
                    data[keyString] = value
                }
            }
            
            NotificationManager.shared.saveNotification(
                title: title,
                body: body,
                data: data,
                projectId: projectId
            )
        }
        
        // Change this to your preferred presentation option
        completionHandler([[.banner, .badge, .sound]])
    }
    
    //    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    //
    //    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
//        print("Full Notification Payload: \(userInfo)")
        
        // Save notification to NotificationManager (when user taps notification)
        Task { @MainActor in
            let title = response.notification.request.content.title
            let body = response.notification.request.content.body
            let projectId = userInfo["projectId"] as? String
            
            // Convert userInfo to [String: Any] for storage
            var data: [String: Any] = [:]
            for (key, value) in userInfo {
                if let keyString = key as? String {
                    data[keyString] = value
                }
            }
            
            NotificationManager.shared.saveNotification(
                title: title,
                body: body,
                data: data,
                projectId: projectId
            )
            
            // Handle navigation
            NotificationManager.shared.handleNavigation(data: data)
        }
        
        // Check type field to determine if expense notification should be chat
        let notificationType = userInfo["type"] as? String
        let isExpenseChat = notificationType == "expense_chat_staff" || notificationType == "expense_chat_customer"
        
        // Determine actual screen - if type indicates expense_chat, override screen
        var actualScreen = userInfo["screen"] as? String
        if isExpenseChat && (actualScreen == "expense_detail" || actualScreen == "expense_review") {
            actualScreen = "expense_chat"
        }
        
        if let screen = actualScreen {
            switch screen {
            case "project_detail":
                if let projectId = userInfo["projectId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "projectId": projectId]
                    )
//                    print("🔗 Navigate to project with ID: \(projectId)")
                }
                
            case "chat_detail":
                if let chatId = userInfo["chatId"] as? String , let projectId = userInfo["projectId"] as? String{
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "chatId": chatId,  "projectId": projectId]
                    )
                    print("💬 Navigate to chat with ID: \(chatId)")
                }
            case "expense_detail":
                if let expenseId = userInfo["expenseId"] as? String , let projectId = userInfo["projectId"] as? String{
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "expenseId": expenseId,  "projectId": projectId]
                    )
                    print("💬 Navigate to expense: \(expenseId)")
                }
            case "project_detail1":
                if let projectId = userInfo["projectId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "projectId": projectId]
                    )
//                    print("🔗 Navigate to project with ID: \(projectId)")
                }
            case "expense_chat":
                if let expenseId = userInfo["expenseId"] as? String , let projectId = userInfo["projectId"] as? String{
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "expenseId": expenseId,  "projectId": projectId]
                    )
                }
                
            case "phase_detail":
                if let phaseId = userInfo["phaseId"] as? String, let projectId = userInfo["projectId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "phaseId": phaseId, "projectId": projectId]
                    )
                    print("📋 Navigate to phase: \(phaseId) in project: \(projectId)")
                }
                
            case "request_detail":
                if let requestId = userInfo["requestId"] as? String, let customerId = userInfo["customerId"] as? String {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "requestId": requestId, "customerId": customerId]
                    )
                    print("📝 Navigate to request: \(requestId)")
                }
                
            case "project_creation":
                // Handle project creation screen navigation (for rejected projects)
                if let projectId = userInfo["projectId"] as? String,
                   let type = userInfo["type"] as? String,
                   type == "project_declined" {
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateFromNotification"),
                        object: nil,
                        userInfo: ["screen": screen, "projectId": projectId, "type": type]
                    )
                    print("📝 Navigate to project creation (rejected): \(projectId)")
                }
                
            default:
                print("No navigation case matched for screen: \(screen)")
            }
        }
        
        completionHandler()
    }
}
