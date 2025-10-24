import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications

struct AuthenticationView: View {
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isOtpSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAuthMethod: AuthMethod = .otp
    
    // MARK: - UI Configuration
    // 🎨 EASY TO MODIFY UI VALIDATION SETTINGS 🎨
    // Change these values to customize the validation UI behavior
    struct UIConfig {
        static let showValidationMessages = true    // Show error messages below fields
        static let showCharacterCount = true        // Show character count (e.g., "5/10")
        static let enableRealTimeValidation = true  // Enable real-time border color changes
        static let showValidationIcons = false      // Show checkmark/error icons (future feature)
    }
    
    enum AuthMethod: CaseIterable {
        case email, otp
        
        var title: String {
            switch self {
            case .email: return "Admin Login"
            case .otp: return "Phone Login"
            }
        }
        
        var icon: String {
            switch self {
            case .email: return "person.badge.shield.checkmark"
            case .otp: return "phone.badge.checkmark"
            }
        }
    }
    
    // MARK: - Validation Logic
    private var isPhoneNumberValid: Bool {
        let processedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        guard processedPhone.count == AuthenticationViewModel.ValidationRules.phoneNumberLength else {
            return false
        }
        
        // Check if only numbers (if required)
        if AuthenticationViewModel.ValidationRules.allowOnlyNumbers {
            return processedPhone.allSatisfy { $0.isNumber }
        }
        
        return true
    }
    
    private var isOtpCodeValid: Bool {
        let processedOtp = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        guard processedOtp.count == AuthenticationViewModel.ValidationRules.otpCodeLength else {
            return false
        }
        
        // Check if only numbers (if required)
        if AuthenticationViewModel.ValidationRules.allowOnlyNumbers {
            return processedOtp.allSatisfy { $0.isNumber }
        }
        
        return true
    }
    
    private var isEmailFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        !password.isEmpty &&
        password.count >= AuthenticationViewModel.ValidationRules.minimumPasswordLength
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top section with method selector
                    VStack(spacing: DesignSystem.Spacing.extraLarge) {
                        Spacer()
                        
                        // Welcome text
                        Text("Welcome Back")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        // Method selector
                        authMethodSelector
                        
                        Spacer()
                    }
                    .frame(height: geometry.size.height * 0.35)
                    
                    // Authentication form section
                    authenticationSection
                        .frame(height: geometry.size.height * 0.65)
                }
            }
        }
        .alert("Authentication Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var authMethodSelector: some View {
        HStack(spacing: 0) {
            ForEach(AuthMethod.allCases, id: \.self) { method in
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedAuthMethod = method
                        resetState()
                    }
                    HapticManager.selection()
                }) {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: method.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(selectedAuthMethod == method ? .white : .primary)
                        
                        Text(method.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(selectedAuthMethod == method ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedAuthMethod == method ? Color.black : Color(.systemGray6))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
                .padding(.horizontal, DesignSystem.Spacing.medium)
        )
    }
    
    private var authenticationSection: some View {
        VStack(spacing: 0) {
            // Form container
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                if selectedAuthMethod == .email {
                    emailAuthForm
                } else {
                    otpAuthForm
                }
                
                if let error = errorMessage {
                    ErrorMessageView(message: error)
                        .transition(.scale.combined(with: .opacity))
                }
                
                if isLoading {
                    LoadingView()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.extraLarge)
            .padding(.top, DesignSystem.Spacing.extraLarge)
            
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color(.secondarySystemBackground))
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private var emailAuthForm: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Administrator Access")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Enter your admin credentials to continue")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                ModernTextField(
                    title: "Email Address",
                    text: $email,
                    placeholder: "admin@avrenterainment.com",
                    icon: "envelope",
                    keyboardType: .emailAddress
                )
                
                ModernTextField(
                    title: "Password",
                    text: $password,
                    placeholder: "Enter your password",
                    icon: "lock",
                    isSecure: true
                )
            }
            
            Button(action: {
                HapticManager.impact(.medium)
                Task {
                    await signInWithEmail()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text("Sign In")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEmailFormValid ? Color.black : Color.gray.opacity(0.5))
                )
            }
            .disabled(!isEmailFormValid || isLoading)
            .animation(.easeInOut(duration: 0.2), value: isEmailFormValid)
        }
    }
    
    private var otpAuthForm: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            if !isOtpSent {
                phoneNumberForm
            } else {
                otpVerificationForm
            }
        }
    }
    
    private var phoneNumberForm: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Phone Verification")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("We'll send a verification code to your phone")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                HStack {
                    Text("Phone Number")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Character count (if enabled)
                    if UIConfig.showCharacterCount {
                        Text("\(phoneNumber.count)/\(AuthenticationViewModel.ValidationRules.phoneNumberLength)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isPhoneNumberValid ? .green : .secondary)
                    }
                }
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    // Country Code
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Text("🇮🇳")
                            .font(.title3)
                        
                        Text("+91")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.medium)
                    .padding(.vertical, DesignSystem.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemFill))
                    )
                    
                    // Phone Number Input
                    TextField("\(AuthenticationViewModel.ValidationRules.phoneNumberLength)-digit number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .font(.system(size: 18, weight: .medium))
                        .padding(.horizontal, DesignSystem.Spacing.medium)
                        .padding(.vertical, DesignSystem.Spacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(getValidationColor(isValid: isPhoneNumberValid, hasContent: !phoneNumber.isEmpty), lineWidth: 2)
                                )
                        )
                }
            }
            
            Button(action: {
                HapticManager.impact(.medium)
                Task {
                    await sendOTP()
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.small) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text("Send Code")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isPhoneNumberValid ? Color.black : Color.gray.opacity(0.5))
                )
                .opacity(isPhoneNumberValid && !isLoading ? 1.0 : 0.6)
            }
            .disabled(!isPhoneNumberValid || isLoading)
            .animation(.easeInOut(duration: 0.2), value: isPhoneNumberValid)
            .accessibilityLabel("Send OTP code to entered phone number")
        }
    }
    
    private var otpVerificationForm: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text("Enter Code")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(spacing: DesignSystem.Spacing.small) {
                    Text("Code sent to")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("+91 \(phoneNumber)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                HStack {
                    Text("Verification Code")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Character count (if enabled)
                    if UIConfig.showCharacterCount {
                        Text("\(otpCode.count)/\(AuthenticationViewModel.ValidationRules.otpCodeLength)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isOtpCodeValid ? .green : .secondary)
                    }
                }
                
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "number")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    TextField("Enter \(AuthenticationViewModel.ValidationRules.otpCodeLength)-digit code", text: $otpCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .medium))
                }
                .padding(.horizontal, DesignSystem.Spacing.medium)
                .padding(.vertical, DesignSystem.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(getValidationColor(isValid: isOtpCodeValid, hasContent: !otpCode.isEmpty), lineWidth: 2)
                        )
                )
                

            }
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Button(action: {
                    HapticManager.impact(.medium)
                    Task {
                        await verifyOTP()
                    }
                }) {
                    HStack(spacing: DesignSystem.Spacing.small) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text("Verify")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isOtpCodeValid ? Color.black : Color.gray.opacity(0.5))
                    )
                }
                .disabled(!isOtpCodeValid || isLoading)
                .animation(.easeInOut(duration: 0.2), value: isOtpCodeValid)
                
                Button(action: {
                    HapticManager.selection()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        otpCode = ""
                        isOtpSent = false
                        errorMessage = nil
                    }
                }) {
                    Text("Change Phone Number")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func getValidationColor(isValid: Bool, hasContent: Bool) -> Color {
        if !hasContent {
            return Color(.systemGray4)
        }
        return isValid ? .green : .red
    }
    
    private func resetState() {
        email = ""
        password = ""
        phoneNumber = ""
        otpCode = ""
        isOtpSent = false
        errorMessage = nil
    }
    
    private func sendOTP() async {
        isLoading = true
        errorMessage = nil
        
        let success = await authService.sendOTP(to: phoneNumber)
        
        if success {
            isOtpSent = true
            HapticManager.notification(.success)
        } else {
            HapticManager.notification(.error)
            if let authError = authService.errorMessage {
                errorMessage = authError
            }
        }
        
        isLoading = false
    }
    
    private func verifyOTP() async {
        isLoading = true
        errorMessage = nil
        
        let success = await authService.verifyOTP(code: otpCode)
        
        if success {
            
            HapticManager.notification(.success)
        } else {
            HapticManager.notification(.error)
            if let authError = authService.errorMessage {
                errorMessage = authError
            }
        }
        
        isLoading = false
    }
    
    private func signInWithEmail() async {
        isLoading = true
        errorMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = await authService.signInWithEmail(email: trimmedEmail, password: password)
        
        if success {
            HapticManager.notification(.success)
        } else {
            HapticManager.notification(.error)
            if let authError = authService.errorMessage {
                errorMessage = authError
            }
        }
        
        isLoading = false
    }
}

// MARK: - Modern Text Field
struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 18, weight: .medium))
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(text.isEmpty ? Color(.systemGray4) : Color.black, lineWidth: 2)
                    )
            )
        }
    }
}

//// MARK: - Supporting Views
//struct ErrorMessageView: View {
//    let message: String
//    
//    var body: some View {
//        HStack(spacing: DesignSystem.Spacing.small) {
//            Image(systemName: "exclamationmark.triangle.fill")
//                .foregroundColor(.red)
//                .font(.system(size: 16, weight: .medium))
//            
//            Text(message)
//                .font(.system(size: 14, weight: .medium))
//                .foregroundColor(.red)
//                .multilineTextAlignment(.leading)
//            
//            Spacer(minLength: 0)
//        }
//        .padding(DesignSystem.Spacing.medium)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(.red.opacity(0.1))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(.red.opacity(0.3), lineWidth: 1)
//                )
//        )
//    }
//}

//struct LoadingView: View {
//    var body: some View {
//        HStack(spacing: DesignSystem.Spacing.medium) {
//            ProgressView()
//                .progressViewStyle(CircularProgressViewStyle(tint: .black))
//                .scaleEffect(0.8)
//            
//            Text("Processing...")
//                .font(.system(size: 16, weight: .medium))
//                .foregroundColor(.secondary)
//        }
//        .padding(DesignSystem.Spacing.medium)
//    }
//}

// MARK: - Preview
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
} 

//
//final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
//    
//    
//    func application(_ application: UIApplication,
//                         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
//            FirebaseApp.configure()
////            UNUserNotificationCenter.current().delegate = self
////            requestPushAuthorization()
////            Messaging.messaging().delegate = self
////            UIApplication.shared.registerForRemoteNotifications()
//            return true
//    }
//    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        // Pass device token to auth
//        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
//        print("Device token received: \(deviceToken.map { String(format: "%02x", $0) }.joined())")
//
//    }
//    
//    func application(_ application: UIApplication,
//        didReceiveRemoteNotification notification: [AnyHashable : Any],
//        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//      if Auth.auth().canHandleNotification(notification) {
//        completionHandler(.noData)
//        return
//      }
//      // This notification is not auth related; it should be handled separately.
//    }
//    
//    func application(_ application: UIApplication, open url: URL,
//        options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
//      if Auth.auth().canHandle(url) {
//        return true
//      }
//      // URL not auth related; it should be handled separately.
//    }
//}
