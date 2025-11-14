import SwiftUI

struct ContentView: View {
    @StateObject private var authService = FirebaseAuthService()
    @State private var isLoading = true
    @EnvironmentObject var navigationManager: NavigationManager
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .onAppear {
                        // Mark root immediately when splash appears
                        navigationManager.markRootLoaded()

                        // Simulated loading animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(DesignSystem.Animation.standardSpring) {
                                isLoading = false
                            }
                        }
                    }
            } else {
                mainContent
                    .onAppear {
                        // Mark root loaded again when main content becomes visible
                        navigationManager.markRootLoaded()
                    }
            }
        }
        .animation(DesignSystem.Animation.standardSpring, value: isLoading)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidLogout"))) { _ in
            authService.signOut()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active, !isLoading, authService.isAuthenticated {
                navigationManager.markRootLoaded()
            }
        }
    }
    
    // MAIN CONTENT ROUTER
    private var mainContent: some View {
        Group {
            if authService.isAuthenticated {
                
                if authService.isAdmin {
                    
                    AdminMainView()
                        .environmentObject(authService)
                        .environmentObject(navigationManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .onAppear {
                            navigationManager.markRootLoaded()
                        }
                    
                } else if authService.isUser || authService.isApprover {
                    
                    if let currentUser = authService.currentUser {
                        
                        ProjectListView(
                            phoneNumber: currentUser.phoneNumber,
                            role: currentUser.role,
                            customerId: authService.currentCustomerId
                        )
                        .environmentObject(authService)
                        .environmentObject(navigationManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .onAppear {
                            navigationManager.markProjectListLoaded()
                        }
                        
                    } else {
                        AuthenticationView()
                            .environmentObject(authService)
                    }
                    
                } else {
                    
                    AuthenticationView()
                        .environmentObject(authService)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                
            } else {
                
                AuthenticationView()
                    .environmentObject(authService)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
            
        }
        .animation(DesignSystem.Animation.standardSpring, value: authService.isAuthenticated)
        .animation(DesignSystem.Animation.standardSpring, value: authService.isAdmin)
        .animation(DesignSystem.Animation.standardSpring, value: authService.isApprover)
        .animation(DesignSystem.Animation.standardSpring, value: authService.isUser)
    }
}


// MARK: - Splash View (unchanged)
private struct SplashView: View {
    var body: some View {
        ZStack {
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
                Image("TracuraLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 130)
                    .shadow(radius: 8)
                
                Text("TRACURA")
                    .font(.system(size: 54, weight: .bold))
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
                
                Text("Track. Approve. Control.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            
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
