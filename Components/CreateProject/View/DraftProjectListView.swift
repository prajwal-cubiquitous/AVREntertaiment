//
//  DraftProjectListView.swift
//  AVREntertainment
//
//  Created by Auto on 1/7/25.
//

import SwiftUI

struct DraftProjectListView: View {
    @ObservedObject var viewModel: CreateProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draftToDelete: DraftProject?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.drafts.isEmpty {
                    emptyStateView
                } else {
                    draftListView
                }
            }
            .navigationTitle("Draft Projects")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Draft", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let draft = draftToDelete {
                        HapticManager.impact(.medium)
                        viewModel.deleteDraft(draft)
                        draftToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    draftToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this draft? This action cannot be undone.")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Drafts")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Save your project as a draft to continue working on it later")
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var draftListView: some View {
        List {
            ForEach(viewModel.drafts) { draft in
                DraftProjectRow(
                    draft: draft,
                    onContinue: {
                        HapticManager.selection()
                        viewModel.loadDraft(draft)
                        dismiss()
                    },
                    onDelete: {
                        HapticManager.selection()
                        draftToDelete = draft
                        showDeleteConfirmation = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .onDelete { indexSet in
                HapticManager.selection()
                for index in indexSet {
                    if index < viewModel.drafts.count {
                        let draft = viewModel.drafts[index]
                        draftToDelete = draft
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
    }
}

struct DraftProjectRow: View {
    let draft: DraftProject
    let onContinue: () -> Void
    let onDelete: () -> Void
    
    private var formState: CreateProjectFormState {
        draft.formState
    }
    
    private var projectName: String {
        let name = formState.projectName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Untitled Project" : name
    }
    
    private var lastUpdated: String {
        let date = draft.updatedAt.dateValue()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var summaryText: String {
        var components: [String] = []
        
        if !formState.client.trimmingCharacters(in: .whitespaces).isEmpty {
            components.append("Client: \(formState.client)")
        }
        
        if !formState.location.trimmingCharacters(in: .whitespaces).isEmpty {
            components.append("Location: \(formState.location)")
        }
        
        if !formState.phases.isEmpty {
            let phaseCount = formState.phases.count
            components.append("\(phaseCount) phase\(phaseCount == 1 ? "" : "s")")
        }
        
        return components.joined(separator: " • ")
    }
    
    var body: some View {
        Button(action: onContinue) {
            HStack(alignment: .top, spacing: 12) {
                // Project Icon
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Project Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(projectName)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if !summaryText.isEmpty {
                        Text(summaryText)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Updated \(lastUpdated)")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

