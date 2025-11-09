import SwiftUI
import FirebaseFirestore
import Contacts
import ContactsUI

struct CreateUserView: View {
    @StateObject private var viewModel = CreateUserViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showingContactPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Name Field - moved to top
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        
                        TextField("Full Name", text: $viewModel.name)
                            .textContentType(.name)
                    }
                    
                    // Phone Number Field - moved below name
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.accentColor)
                                .frame(width: 20)
                            
                            TextField("Phone Number", text: $viewModel.phoneNumber)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                            
                            // Contact picker button
                            Button(action: {
                                showingContactPicker = true
                            }) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Show phone number error only when validation has been attempted
                        if viewModel.hasAttemptedValidation, let phoneError = viewModel.phoneNumberError {
                            Text(phoneError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 28) // Align with text field
                        }
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
                    // Show general error message only when validation has been attempted
                    if viewModel.hasAttemptedValidation, let errorMessage = viewModel.errorMessage, viewModel.phoneNumberError == nil {
                        Text(errorMessage)
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
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.checkAndCreateUser(authService: authService)
                            if viewModel.showSuccessMessage {
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                                    dismiss()
//                                }
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
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerView(
                    onContactSelected: { contact in
                        // Extract phone number from contact
                        if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                            // Clean phone number - remove spaces, dashes, parentheses
                            let cleaned = phoneNumber.replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: "-", with: "")
                                .replacingOccurrences(of: "(", with: "")
                                .replacingOccurrences(of: ")", with: "")
                                .replacingOccurrences(of: "+91", with: "")
                            
                            viewModel.phoneNumber = cleaned
                        }
                        
                        // Extract name from contact
                        let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                        if !fullName.isEmpty {
                            viewModel.name = fullName
                        }
                    },
                    onDismiss: {
                        showingContactPicker = false
                    }
                )
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

// MARK: - Contact Picker View
struct ContactPickerView: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            // Call the completion handler on main thread
            DispatchQueue.main.async {
                self.parent.onContactSelected(contact)
                // Dismiss the picker
                picker.dismiss(animated: true) {
                    // After picker dismisses, dismiss the sheet
                    DispatchQueue.main.async {
                        self.parent.onDismiss()
                    }
                }
            }
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            picker.dismiss(animated: true) {
                // After picker dismisses, dismiss the sheet
                DispatchQueue.main.async {
                    self.parent.onDismiss()
                }
            }
        }
    }
}

#Preview {
    CreateUserView()
        .environmentObject(FirebaseAuthService())
} 
