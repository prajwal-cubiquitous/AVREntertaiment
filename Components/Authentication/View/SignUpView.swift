//
//  SignUpView.swift
//  AVREntertainment
//
//  Created by Auto on 11/4/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var phoneNumber: String = ""
    @State private var businessName: String = ""
    @State private var location: String = ""
    @State private var name: String = ""
    @State private var showConfirmPassword = false
    @State private var nameError: String?
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSuccess = false
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        !password.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !nameContainsNumbers(name)
    }
    
    // Helper function to check if name contains numbers
    private func nameContainsNumbers(_ text: String) -> Bool {
        let numbers = CharacterSet.decimalDigits
        return text.unicodeScalars.contains { numbers.contains($0) }
    }
    
    // Helper function to filter numbers from name
    private func filterNumbers(from text: String) -> String {
        return text.unicodeScalars.filter { !CharacterSet.decimalDigits.contains($0) }.map(String.init).joined()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.extraLarge) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Sign up to get started")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, DesignSystem.Spacing.extraLarge)
                    
                    // Form Fields
                    VStack(spacing: DesignSystem.Spacing.medium) {
                        // Name (Required) - No numbers allowed
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            Text("Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: DesignSystem.Spacing.medium) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                TextField("Enter your full name", text: Binding(
                                    get: { name },
                                    set: { newValue in
                                        // Filter out numbers
                                        let filtered = filterNumbers(from: newValue)
                                        name = filtered
                                        
                                        // Show error if user tried to enter numbers
                                        if newValue != filtered {
                                            nameError = "Numbers are not allowed in name"
                                            // Clear error after 2 seconds
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                nameError = nil
                                            }
                                        } else {
                                            nameError = nil
                                        }
                                    }
                                ))
                                .keyboardType(.alphabet)
                                .font(.system(size: 18, weight: .medium))
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.vertical, DesignSystem.Spacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(nameError != nil ? Color.red : (name.isEmpty ? Color(.systemGray4) : Color.black), lineWidth: 2)
                                    )
                            )
                            
                            if let error = nameError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.leading, DesignSystem.Spacing.medium)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        
                        // Email (Required)
                        ModernTextField(
                            title: "Email Address",
                            text: $email,
                            placeholder: "your@email.com",
                            icon: "envelope",
                            keyboardType: .emailAddress
                        )
                        
                        // Password (Required)
                        ModernTextField(
                            title: "Password",
                            text: $password,
                            placeholder: "Enter password (min 6 characters)",
                            icon: "lock",
                            isSecure: true
                        )
                        
                        // Confirm Password (Required) - With eye icon toggle
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            Text("Confirm Password")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: DesignSystem.Spacing.medium) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                Group {
                                    if showConfirmPassword {
                                        TextField("Re-enter password", text: $confirmPassword)
                                            .font(.system(size: 18, weight: .medium))
                                    } else {
                                        SecureField("Re-enter password", text: $confirmPassword)
                                            .font(.system(size: 18, weight: .medium))
                                    }
                                }
                                
                                // Eye icon toggle button
                                Button(action: {
                                    HapticManager.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showConfirmPassword.toggle()
                                    }
                                }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.vertical, DesignSystem.Spacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(confirmPassword.isEmpty ? Color(.systemGray4) : Color.black, lineWidth: 2)
                                    )
                            )
                        }
                        
                        // Password Match Indicator
                        if !confirmPassword.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(password == confirmPassword ? .green : .red)
                                Text(password == confirmPassword ? "Passwords match" : "Passwords do not match")
                                    .font(.caption)
                                    .foregroundColor(password == confirmPassword ? .green : .red)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, DesignSystem.Spacing.medium)
                        }
                        
                        // Business Name (Required)
                        ModernTextField(
                            title: "Business Name",
                            text: $businessName,
                            placeholder: "Enter your business name",
                            icon: "building.2.fill",
                            keyboardType: .default
                        )
                        
                        // Phone Number (Optional)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            HStack {
                                Text("Phone Number")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("(Optional)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: DesignSystem.Spacing.medium) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                TextField("Enter phone number", text: $phoneNumber)
                                    .keyboardType(.phonePad)
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.vertical, DesignSystem.Spacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(phoneNumber.isEmpty ? Color(.systemGray4) : Color.black, lineWidth: 2)
                                    )
                            )
                        }
                        
                        // Location (Optional)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                            HStack {
                                Text("Location")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("(Optional)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: DesignSystem.Spacing.medium) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                TextField("Enter location", text: $location)
                                    .keyboardType(.default)
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .padding(.horizontal, DesignSystem.Spacing.medium)
                            .padding(.vertical, DesignSystem.Spacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(location.isEmpty ? Color(.systemGray4) : Color.black, lineWidth: 2)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.extraLarge)
                    
                    // Create Account Button
                    Button(action: {
                        HapticManager.impact(.medium)
                        Task {
                            await createAccount()
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.small) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isFormValid ? Color.black : Color.gray.opacity(0.5))
                        )
                    }
                    .disabled(!isFormValid || isLoading)
                    .animation(.easeInOut(duration: 0.2), value: isFormValid)
                    .padding(.horizontal, DesignSystem.Spacing.extraLarge)
                    
                    // Navigation to Login
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            HapticManager.selection()
                            dismiss()
                        }) {
                            Text("Login")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.bottom, DesignSystem.Spacing.extraLarge)
                    
                    if let error = errorMessage {
                        ErrorMessageView(message: error)
                            .padding(.horizontal, DesignSystem.Spacing.extraLarge)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Up", isPresented: $showAlert) {
                Button("OK") {
                    if showSuccess {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func createAccount() async {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields correctly"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create Firebase Auth user
            let authResult = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
            
            // Create Customer document in Firestore
            let db = Firestore.firestore()
            let customerRef = db.collection("customers").document(authResult.user.uid)
            
            let customer = Customer(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: trimmedEmail,
                phoneNumber: trimmedPhone.isEmpty ? nil : trimmedPhone,
                businessName: businessName.trimmingCharacters(in: .whitespacesAndNewlines),
                location: trimmedLocation.isEmpty ? nil : trimmedLocation
            )
            
            try await customerRef.setData(from: customer)
            
            await MainActor.run {
                isLoading = false
                showSuccess = true
                alertMessage = "Account created successfully! Please login with your credentials."
                showAlert = true
                HapticManager.notification(.success)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                HapticManager.notification(.error)
            }
        }
    }
}


// MARK: - Preview
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(FirebaseAuthService())
    }
}

