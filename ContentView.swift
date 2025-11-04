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
            // Background gradient (purple → blue)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.44, green: 0.37, blue: 1.0),
                    Color(red: 0.38, green: 0.82, blue: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Logo
                Image("TracuraLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 130)
                    .shadow(radius: 8)
                
                // Title
                Text("TRACURA")
                    .font(.system(size: 54, weight: .bold, design: .default))
                    .kerning(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.27, green: 0.33, blue: 0.82),
                                Color(red: 0.16, green: 0.18, blue: 0.60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Tagline
                Text("Track. Approve. Control.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.9))
                    .padding(.top, 8)
            }
            // Center vertically with spacing
            .frame(maxHeight: .infinity)
            
            // ProgressView fixed at bottom
            VStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
                    .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    SplashView()
}
