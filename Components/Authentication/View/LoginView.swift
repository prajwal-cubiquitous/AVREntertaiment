//
//  LoginView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 6/25/25.
//


import SwiftUI

struct LoginView: View {
    
    @StateObject private var viewModel = TestingLoginViewModel()
    @State private var showAlert = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.extraLarge) {
                        Spacer(minLength: geometry.size.height * 0.1)
                        
                        headerView
                        
                        authenticationCard
                        
                        Spacer(minLength: DesignSystem.Spacing.large)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .onAppear {
            viewModel.setAuthService(authService)
        }
        .fullScreenCover(isPresented: $viewModel.isAuthenticated) {
            NavigationStack {
                ProjectListView(phoneNumber: viewModel.phoneNumber.replacingOccurrences(of: "+91", with: ""))
            }
        }
    }
    
    private var authenticationCard: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            if !viewModel.isOtpSent {
                phoneNumberView
            } else {
                otpInputView
            }
            
            if let error = viewModel.errorMessage {
                ErrorMessageView(message: error)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if viewModel.isLoading {
                LoadingView()
            }
        }
        .padding(DesignSystem.Spacing.extraLarge)
        .cardStyle(shadow: DesignSystem.Shadow.large)
        .padding(.horizontal, DesignSystem.Spacing.large)
        .animation(DesignSystem.Animation.standardSpring, value: viewModel.isOtpSent)
    }
    
    private var headerView: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            // App logo/icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.gradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: .accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "message.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: DesignSystem.Spacing.small) {
                Text("Welcome Back")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(.primary)
                
                Text("AVR Entertainment")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.accentColor)
                    .fontWeight(.medium)
                
                Text("Enter your phone number to continue")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(DesignSystem.Animation.standardSpring, value: viewModel.isOtpSent)
    }
    
    private var phoneNumberView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Phone Number")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: DesignSystem.Spacing.small) {
                    // Country code
                    HStack(spacing: DesignSystem.Spacing.extraSmall) {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.secondary)
                            .font(DesignSystem.Typography.footnote)
                        
                        Text("+91")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, DesignSystem.Spacing.small)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    
                    // Phone number input
                    TextField("10-digit phone number", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)
                        .font(DesignSystem.Typography.body)
                        .fieldStyle()
                }
                
                Text("We'll send a verification code to this number")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                HapticManager.impact(.medium)
                viewModel.sendOTP()
            }) {
                Text("Send Verification Code")
            }
            .primaryButton()
            .disabled(viewModel.phoneNumber.count != 10)
            .animation(DesignSystem.Animation.standardSpring, value: viewModel.phoneNumber.count == 10)
        }
    }
    
    private var otpInputView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            VStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: "message.badge.filled.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                    .symbolRenderingMode(.hierarchical)
                
                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Verification Code Sent")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Enter the 6-digit code sent to")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.phoneNumber)
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Verification Code")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                TextField("Enter 6-digit code", text: $viewModel.otpCode)
                    .keyboardType(.numberPad)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .fieldStyle()
                
                // Test OTP Display
                if let testOtp = viewModel.PhoneOtp[viewModel.phoneNumber.replacingOccurrences(of: "+91", with: "")] {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Test Mode - OTP: ")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(.secondary)
                        Text(testOtp)
                            .font(DesignSystem.Typography.footnote.monospaced())
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.small)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Button {
                    HapticManager.impact(.medium)
                    if viewModel.verifyOTP() {
                        HapticManager.notification(.success)
                        withAnimation {
                            viewModel.isAuthenticated = true
                        }
                    } else {
                        HapticManager.notification(.error)
                        showAlert = true
                    }
                } label: {
                    Text("Verify & Continue")
                }
                .primaryButton()
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Verification Failed"),
                        message: Text("Please check your code and try again."),
                        dismissButton: .default(Text("OK"))
                    )
                }
                
                Button {
                    HapticManager.selection()
                    withAnimation(DesignSystem.Animation.standardSpring) {
                        viewModel.reset()
                    }
                } label: {
                    Text("Change Number")
                }
                .secondaryButton()
            }
        }
    }
}



// MARK: - Supporting Views
// Note: ErrorMessageView and LoadingView are now defined in AuthenticationView.swift

#Preview {
    LoginView()
}
