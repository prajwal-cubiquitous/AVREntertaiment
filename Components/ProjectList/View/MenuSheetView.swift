//import SwiftUI
//import FirebaseAuth
//
//struct MenuSheetView: View {
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var authService: FirebaseAuthService
//    
//    var body: some View {
//        VStack(spacing: DesignSystem.Spacing.medium) {
//            // Sheet Handle
//            RoundedRectangle(cornerRadius: 2.5)
//                .fill(Color.secondary.opacity(0.3))
//                .frame(width: 36, height: 5)
//                .padding(.top, DesignSystem.Spacing.medium)
//            
//            // Menu Title
//            Text("Menu")
//                .font(DesignSystem.Typography.title2)
//                .fontWeight(.bold)
//                .padding(.vertical, DesignSystem.Spacing.medium)
//            
//            // Menu Items
//            VStack(spacing: DesignSystem.Spacing.small) {
//                // Sign Out Button
//                Button(action: {
//                    HapticManager.impact(.medium)
//                    Task {
//                        do {
//                            try await authService.signOut()
//                        } catch {
//                            print("Error signing out: \(error)")
//                        }
//                    }
//                    dismiss()
//                }) {
//                    HStack {
//                        Image(systemName: "rectangle.portrait.and.arrow.right")
//                            .foregroundColor(.red)
//                        Text("Sign Out")
//                            .foregroundColor(.red)
//                        Spacer()
//                    }
//                    .padding()
//                    .background(Color(UIColor.secondarySystemGroupedBackground))
//                    .cornerRadius(10)
//                }
//            }
//            .padding(.horizontal, DesignSystem.Spacing.medium)
//            
//            Spacer()
//        }
//        .background(Color(UIColor.systemGroupedBackground))
//    }
//} 
