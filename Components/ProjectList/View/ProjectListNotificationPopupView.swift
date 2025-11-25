//
//  ProjectListNotificationPopupView.swift
//  AVREntertainment
//
//  Created for ProjectListView notification popup
//

import SwiftUI

struct ProjectListNotificationPopupView: View {
    @ObservedObject var viewModel: ProjectListViewModel
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.showingFullNotifications = false
                    }
                }
            
            // Popup content - centered
            if viewModel.pendingExpenses.isEmpty {
                // Empty state - matches screenshot
                emptyStateView
            } else {
                // Show notifications list
                notificationsListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Bell icon
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
                .symbolRenderingMode(.hierarchical)
            
            // Title
            Text("No Notifications")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Message
            Text("You're all caught up!")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            // Close button
            Button {
                HapticManager.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showingFullNotifications = false
                }
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 320)
        .scaleEffect(viewModel.showingFullNotifications ? 1.0 : 0.9)
        .opacity(viewModel.showingFullNotifications ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showingFullNotifications)
    }
    
    private var notificationsListView: some View {
        VStack(spacing: 0) {
            // Header
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
            
            // Notifications list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.projects) { project in
                        let projectExpenses = viewModel.pendingExpenses.filter { $0.projectId == project.id }
                        if !projectExpenses.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(project.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                
                                ForEach(projectExpenses) { expense in
                                    NotificationItemView(expense: expense)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            // Close button
            Button {
                HapticManager.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showingFullNotifications = false
                }
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 340, maxHeight: 500)
        .scaleEffect(viewModel.showingFullNotifications ? 1.0 : 0.9)
        .opacity(viewModel.showingFullNotifications ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showingFullNotifications)
    }
}

