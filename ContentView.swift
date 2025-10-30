//
//  ContentView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = FirebaseAuthService()
    @State private var isLoading = true
    @EnvironmentObject var navigationManager: NavigationManager
    
    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .onAppear {
                        // Simulate loading time for smooth UX
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(DesignSystem.Animation.standardSpring) {
                                isLoading = false
                            }
                        }
                    }
            } else {
                mainContent
            }
        }
        .animation(DesignSystem.Animation.standardSpring, value: isLoading)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidLogout"))) { _ in
            authService.signOut()
        }
    }
    
    private var mainContent: some View {
        Group {
            if authService.isAuthenticated {
                // Route based on user role
                if authService.isAdmin {
                    // ADMIN: Email-based login, goes to AdminMainView
                    AdminMainView()
                        .environmentObject(authService)
                        .environmentObject(navigationManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .onAppear(){
                            print("isUser \(authService.isUser)")
                            print("isapprover \(authService.isApprover)")
                            print("isadmin \(authService.isAdmin)")
                            print("isautehnticated \(authService.isAuthenticated)")
                        }

                }else if authService.isUser || authService.isApprover{
                    // USER: OTP-based login, goes to ProjectListView
                    if let currentUser = authService.currentUser {
                        ProjectListView(phoneNumber: currentUser.phoneNumber, role: currentUser.role)
                            .environmentObject(authService)
                            .environmentObject(navigationManager)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        AuthenticationView()
                            .environmentObject(authService)
                    }
                } else {
                    // Fallback to authentication if role is unclear
                    AuthenticationView()
                        .environmentObject(authService)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                        .onAppear(){
                            print("isUser \(authService.isUser)")
                            print("isapprover \(authService.isApprover)")
                            print("isadmin \(authService.isAdmin)")
                            print("isautehnticated \(authService.isAuthenticated)")
                        }
                }
            } else {
                // Not authenticated, show login
                AuthenticationView()
                    .environmentObject(authService)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .onAppear(){
                        print("isUser \(authService.isUser)")
                        print("isapprover \(authService.isApprover)")
                        print("isadmin \(authService.isAdmin)")
                        print("isautehnticated \(authService.isAuthenticated)")
                    }
            }
        }
        .animation(DesignSystem.Animation.standardSpring, value: authService.isAuthenticated)
        .animation(DesignSystem.Animation.standardSpring, value: authService.isAdmin)
        .animation(DesignSystem.Animation.standardSpring, value: authService.isApprover)
        .animation(DesignSystem.Animation.standardSpring, value: authService.isUser)
    }
}

// MARK: - Splash View
private struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.large) {
                // App Logo
                Image("TracuraLogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("TRACURA")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .kerning(2)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.24, green: 0.53, blue: 0.98), // light blue
                                    Color(red: 0.02, green: 0.20, blue: 0.55)  // deep blue
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .mask(
                            Text("TRACURA")
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .kerning(2)
                        )
                    
                    Text("Track. Approve. Control.")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.secondary)
                }
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, DesignSystem.Spacing.large)
            }
        }
    }
}

#Preview {
    ContentView()
}
