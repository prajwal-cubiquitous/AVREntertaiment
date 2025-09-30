//
//  ChatsView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 9/29/25.
//

import SwiftUI

struct ChatsView: View {
    let project: Project
    let currentUserPhone: String?
    let currentUserRole: UserRole
    
    @StateObject private var viewModel: ChatsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedParticipant: ChatParticipant?
    @State private var showingGroupChat = false
    
    init(project: Project, currentUserPhone: String? = nil, currentUserRole: UserRole) {
        self.project = project
        self.currentUserPhone = currentUserPhone
        self.currentUserRole = currentUserRole
        self._viewModel = StateObject(wrappedValue: ChatsViewModel(project: project, currentUserPhone: currentUserPhone, currentUserRole: currentUserRole))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.participants.isEmpty {
                    emptyStateView
                } else {
                    participantsListView
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingGroupChat = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 16))
                            Text("Group")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .task {
                await viewModel.loadChatParticipants()
            }
            .sheet(isPresented: $showingGroupChat) {
                GroupChatView(
                    project: project,
                    currentUserPhone: currentUserPhone,
                    role: currentUserRole
                )
                .presentationDetents([.large])
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // Project info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Project Team Chats")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusView(status: project.statusType)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading chat participants...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text("No Team Members")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("There are no other team members available for chat in this project.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Participants List View
    private var participantsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.participants) { participant in
                    NavigationLink(destination: IndividualChatView(participant: participant, project: project, role: currentUserRole, currentUserPhoneNumber: (currentUserRole != .ADMIN) ? currentUserPhone : nil)
                        .onAppear {
                            Task {
                                await viewModel.markMessagesAsRead(for: participant.phoneNumber)
                            }
                        }
                    ) {
                        ChatParticipantRow(participant: participant)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Chat Participant Row
struct ChatParticipantRow: View {
    let participant: ChatParticipant
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(participant.roleColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: participant.roleIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(participant.roleColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(participant.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if participant.isOnline {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                HStack {
                    Text(participant.role.displayName)
                        .font(.caption)
                        .foregroundColor(participant.roleColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(participant.roleColor.opacity(0.12))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if let lastMessageTime = participant.lastMessageTime {
                        Text(timeAgoString(from: lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let lastSeen = participant.lastSeen {
                        Text(timeAgoString(from: lastSeen))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Last message preview
                if let lastMessage = participant.lastMessage {
                    HStack {
                        Text(lastMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if participant.unreadCount > 0 {
                            Text("\(participant.unreadCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}


#Preview {
    ChatsView(
        project: Project.sampleData[0],
        currentUserPhone: "9876543218",
        currentUserRole: .USER
    )
}
