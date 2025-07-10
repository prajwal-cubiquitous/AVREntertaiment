import SwiftUI
import FirebaseFirestore

struct CreateUserView: View {
    @StateObject private var viewModel = CreateUserViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Phone Number Field
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        
                        TextField("Phone Number", text: $viewModel.phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    
                    // Name Field
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        
                        TextField("Full Name", text: $viewModel.name)
                            .textContentType(.name)
                    }
                    
                    // Role Selection
                    HStack {
                        Image(systemName: "person.badge.key.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        
                        Picker("Role", selection: $viewModel.selectedRole) {
                            ForEach([UserRole.APPROVER, UserRole.USER], id: \.self) { role in
                                Text(role.displayName).tag(role)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                } header: {
                    Text("User Information")
                } footer: {
                    if !viewModel.isFormValid {
                        Text("Please fill all fields with valid information")
                            .foregroundColor(.red)
                    }
                }
                
                // Role Description
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.selectedRole == .APPROVER ? "checkmark.shield.fill" : "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.selectedRole == .APPROVER ? .green : .blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.selectedRole.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(viewModel.selectedRole == .APPROVER ? 
                                 "Can review and approve/reject expense submissions from users" :
                                 "Can submit expenses and view project details")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Role Permissions")
                }
                
                // Success/Error Messages
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ErrorMessageView(message: errorMessage)
                    }
                }
                
                if viewModel.showSuccessMessage {
                    Section {
                        SuccessMessageView(message: "User created successfully!")
                    }
                }
            }
            .navigationTitle("Create User")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.checkAndCreateUser(authService: authService)
                            if viewModel.showSuccessMessage {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                    .fontWeight(.semibold)
                }
            }
            .disabled(viewModel.isLoading)
            .overlay(
                Group {
                    if viewModel.isLoading {
                        LoadingView()
                    }
                }
            )
            .alert("User Already Exists", isPresented: $viewModel.showDuplicateAlert) {
                Button("Cancel", role: .cancel) {
                    // Do nothing, just dismiss the alert
                }
                Button("Continue", role: .destructive) {
                    Task {
                        await viewModel.createUser(authService: authService, overwrite: true)
                        if viewModel.showSuccessMessage {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }
                    }
                }
            } message: {
                Text("A user with this phone number already exists. Do you want to overwrite their information?")
            }
        }
    }
}

// MARK: - Supporting Views
struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.callout)
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SuccessMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(message)
                .font(.callout)
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                
                Text("Creating User...")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    CreateUserView()
        .environmentObject(FirebaseAuthService())
} 