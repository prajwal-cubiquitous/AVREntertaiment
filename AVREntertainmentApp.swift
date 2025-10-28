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
        return true
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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationManager)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateFromNotification"))) { notification in
                    if let userInfo = notification.userInfo,
                       let screen = userInfo["screen"] as? String {
                        
                        if screen == "project_detail",
                           let projectId = userInfo["projectId"] as? String {
                            navigationManager.setProjectId(projectId)
                        } else if screen == "chat_detail",
                                  let chatId = userInfo["chatId"] as? String , let projectId = userInfo["projectId"] as? String{
                            // Ensure project is set first so chat destination can resolve it
                            navigationManager.setProjectId(projectId)
                            navigationManager.setChatId(chatId)
                        } else if (screen == "expert_detail" || screen == "expense_detail"),
                                  let expenseId = userInfo["expenseId"] as? String,
                                  let projectId = userInfo["projectId"] as? String {
                            // Ensure project is set first so expense destination can resolve it
                            navigationManager.setProjectId(projectId)
                            navigationManager.setExpenseId(expenseId)
                        }else if screen == "project_detail1",
                                 let projectId = userInfo["projectId"] as? String {
                                  navigationManager.setProjectId(projectId)
                        }else if screen == "expense_chat",let expenseId = userInfo["expenseId"] as? String,
                                 let projectId = userInfo["projectId"] as? String {
                            navigationManager.setProjectId(projectId)
                            navigationManager.setExpenseId(expenseId)
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
            Task{
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
        
        if let screen = userInfo["screen"] as? String {
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
                    print("💬 Navigate to expense: \(expenseId)")
                }
                
            default:
                print("No navigation case matched for screen: \(screen)")
            }
        }
        
        completionHandler()
    }

    
}
