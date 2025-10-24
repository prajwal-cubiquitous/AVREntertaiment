import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class FirebaseAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isAdmin = false
    @Published var isApprover = false
    @Published var isUser = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    @Published var verificationID: String?
    
    init() {
        // Check if user is already authenticated
        if let firebaseUser = auth.currentUser {
            Task {
                await loadCurrentUser(firebaseUser: firebaseUser)
            }
        }
        
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.loadCurrentUser(firebaseUser: user)
                } else {
                    self?.resetAuthState()
                }
            }
        }
    }
    
    private func resetAuthState() {
        currentUser = nil
        isAuthenticated = false
        isAdmin = false
        isApprover = false
        isUser = false
        errorMessage = nil
    }
    
    private func loadCurrentUser(firebaseUser: FirebaseAuth.User) async {
        isLoading = true
        errorMessage = nil
        
        // Check if this is an admin user (email-based)
        if let email = firebaseUser.email, !email.isEmpty {
            // This is an admin user
            let adminUser = User.adminUser(email: email, name: firebaseUser.displayName ?? "Admin")
            updateUserState(user: adminUser)
        } else {
            // This is an OTP-based user (APPROVER or USER)
            if let phoneNumber = firebaseUser.phoneNumber {
                await loadOTPUser(phoneNumber: phoneNumber)
            } else {
                errorMessage = "Unable to determine user type"
                isLoading = false
            }
        }
        
        isLoading = false
    }
    
    public func loadOTPUser(phoneNumber: String) async {
        do {
            let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let document = try await db.collection(FirebaseCollections.users).document(cleanPhoneNumber).getDocument()
            
            if document.exists, let userData = try? document.data(as: User.self) {
                updateUserState(user: userData)
            } else {
                errorMessage = "User not found. Please contact admin for access."
                resetAuthState()
            }
        } catch {
            errorMessage = "Failed to load user: \(error.localizedDescription)"
            resetAuthState()
        }
    }
    
    private func updateUserState(user: User) {
        currentUser = user
        print("User state updated: \(String(describing: user))")
        isAuthenticated = true
        
        // Set role flags
        isAdmin = (user.role == .ADMIN)
        isApprover = (user.role == .APPROVER)
        isUser = (user.role == .USER)
    }
    
    // MARK: - Email Authentication (Admin only)
    func signInWithEmail(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            // Admin user will be loaded automatically through auth state listener
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - OTP Authentication (APPROVER and USER)
    func sendOTP(to phoneNumber: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // Clean phone number and add country code
        let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate phone number format
        guard cleanPhoneNumber.count == 10, cleanPhoneNumber.allSatisfy({ $0.isNumber }) else {
            errorMessage = "Please enter a valid 10-digit phone number"
            isLoading = false
            return false
        }
        
        let fullPhoneNumber = "+91\(cleanPhoneNumber)"
        print("📱 Sending OTP to: \(fullPhoneNumber)")
        
        // First check if user exists in Firestore
        do {
            let document = try await db.collection(FirebaseCollections.users).document(cleanPhoneNumber).getDocument()
            if !document.exists {
                errorMessage = "Mobile Number not registered, please contact admin"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Failed to verify user: \(error.localizedDescription)"
            isLoading = false
            return false
        }
        
        do{
//            Auth.auth().settings.isAppVerificationDisabledForTesting = true
            PhoneAuthProvider.provider()
              .verifyPhoneNumber(fullPhoneNumber, uiDelegate: nil) { verificationID, error in
                            if let error = error {
                                self.errorMessage = "Error: \(error.localizedDescription)"
                                return
                            }
                            self.verificationID = verificationID
                            self.isLoading = false
                            self.errorMessage = nil
                        }
            return true
        } catch {
            print("❌ OTP Send Error: \(error.localizedDescription)")
            errorMessage = "Failed to send OTP: \(error.localizedDescription)"
            isLoading = false
            return false
        }

    }
    
    func verifyOTP(code: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let verificationID = verificationID ?? UserDefaults.standard.string(forKey: "authVerificationID") else {
            errorMessage = "Verification ID not found. Please request a new OTP."
            isLoading = false
            return false
        }
        
        do {
            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
            let result = try await auth.signIn(with: credential)
            // User will be loaded automatically through auth state listener
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - User Management (Admin only)
    func createUser(phoneNumber: String, name: String, role: UserRole, overwrite: Bool = false) async -> Bool {
        guard isAdmin else {
            errorMessage = "Only admin users can create new users"
            return false
        }
        
        do {
            // Clean phone number of any potential prefixes
            let cleanPhoneNumber = phoneNumber.replacingOccurrences(of: "+91", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Use phone number as document ID
            let userRef = db.collection(FirebaseCollections.users).document(cleanPhoneNumber)
            
            // Check if user exists
            if !overwrite {
                let doc = try await userRef.getDocument()
                if doc.exists {
                    errorMessage = "User already exists with this phone number"
                    return false
                }
            }
            
            let newUser = User(
                phoneNumber: cleanPhoneNumber,
                name: name,
                role: role
            )
            
            try await userRef.setData(from: newUser, merge: overwrite)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func getAllUsers() async -> [User] {
        guard isAdmin else { return [] }
        
        do {
            let snapshot = try await db.collection(FirebaseCollections.users)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            return snapshot.documents.compactMap { document in
                try? document.data(as: User.self)
            }
        } catch {
            errorMessage = "Failed to fetch users: \(error.localizedDescription)"
            return []
        }
    }
    
    func getApprovers() async -> [User] {
        guard isAdmin else { return [] }
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("role", isEqualTo: UserRole.APPROVER.rawValue)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? document.data(as: User.self)
            }
        } catch {
            errorMessage = "Failed to fetch approvers: \(error.localizedDescription)"
            return []
        }
    }
    
    func getUsers() async -> [User] {
        guard isAdmin else { return [] }
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("role", isEqualTo: UserRole.USER.rawValue)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                try? document.data(as: User.self)
            }
        } catch {
            errorMessage = "Failed to fetch users: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try auth.signOut()
            resetAuthState()
            verificationID = nil
            UserDefaults.standard.removeObject(forKey: "authVerificationID")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
