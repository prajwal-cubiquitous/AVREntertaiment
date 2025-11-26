import Foundation
import SwiftUI

// Navigation item wrapper
struct NavItem: Identifiable, Hashable {
    let id: String
}

// Pending navigation request
struct PendingNavigationIntent {
    let screen: String
    let projectId: String?
    let chatId: String?
    let expenseId: String?
    let phaseId: String?
    let requestId: String?
    let expenseScreenType: NavigationManager.ExpenseScreenType?
}

@MainActor
class NavigationManager: ObservableObject {
    
    // Navigation destinations
    @Published var activeProjectId: NavItem?
    @Published var activeChatId: NavItem?
    @Published var activeExpenseId: NavItem?
    @Published var activePhaseId: NavItem?
    @Published var activeRequestId: NavItem?
    
    @Published var expenseScreenType: ExpenseScreenType?

    // Readiness state
    enum AppReadyState {
        case launching
        case rootLoaded
        case projectListLoaded
        case fullyReady
    }

    @Published var readyState: AppReadyState = .launching

    // Pending navigation
    private var pendingNavigationIntent: PendingNavigationIntent?

    enum ExpenseScreenType {
        case detail
        case chat
    }
    
    init() {}

    // MARK: - Reset All Navigation
    func clearNavigation() {
        activeProjectId = nil
        activeChatId = nil
        activeExpenseId = nil
        activePhaseId = nil
        activeRequestId = nil
        expenseScreenType = nil
    }

    // MARK: - Setters
    func setProjectId(_ id: String?) {
        activeProjectId = id.map { NavItem(id: $0) }
    }
    
    func setChatId(_ id: String?) {
        activeChatId = id.map { NavItem(id: $0) }
    }
    
    func setExpenseId(_ id: String?, screenType: ExpenseScreenType = .detail) {
        activeExpenseId = id.map { NavItem(id: $0) }
        expenseScreenType = id != nil ? screenType : nil
    }
    
    func setPhaseId(_ id: String?) {
        activePhaseId = id.map { NavItem(id: $0) }
    }
    
    func setRequestId(_ id: String?) {
        activeRequestId = id.map { NavItem(id: $0) }
    }

    // MARK: - Store Pending
    func storePendingNavigation(
        screen: String,
        projectId: String? = nil,
        chatId: String? = nil,
        expenseId: String? = nil,
        phaseId: String? = nil,
        requestId: String? = nil,
        expenseScreenType: ExpenseScreenType? = nil
    ) {
        pendingNavigationIntent = PendingNavigationIntent(
            screen: screen,
            projectId: projectId,
            chatId: chatId,
            expenseId: expenseId,
            phaseId: phaseId,
            requestId: requestId,
            expenseScreenType: expenseScreenType
        )
        
        print("📦 Stored pending navigation: \(screen)")
        tryProcessNavigation()
    }

    // MARK: - Mark Ready States
    func markRootLoaded() {
        readyState = .rootLoaded
        print("🌱 Root view loaded")
        tryProcessNavigation()
    }

    func markProjectListLoaded() {
        readyState = .projectListLoaded
        print("📋 ProjectListView loaded")
        tryProcessNavigation()
    }

    func markAppReady() {
        markRootLoaded()
    }

    // MARK: - Ready Logic
    private func tryProcessNavigation() {
        guard let intent = pendingNavigationIntent else { return }

        if readyState == .projectListLoaded || readyState == .fullyReady {
            readyState = .fullyReady
            print("🚀 App fully ready — processing navigation")
            processPendingNavigation(intent)
        }
    }

    // MARK: - Process Navigation
    private func processPendingNavigation(_ intent: PendingNavigationIntent) {
        print("🎯 Processing navigation: \(intent.screen)")

        switch intent.screen {

        case "project_detail", "project_detail1":
            if let id = intent.projectId { setProjectId(id) }

        case "chat_detail":
            if let projectId = intent.projectId { setProjectId(projectId) }
            if let chatId = intent.chatId { setChatId(chatId) }

        case "expense_detail":
            if let projectId = intent.projectId { setProjectId(projectId) }
            if let expenseId = intent.expenseId { setExpenseId(expenseId, screenType: .detail) }

        case "expense_chat":
            if let projectId = intent.projectId { setProjectId(projectId) }
            if let expenseId = intent.expenseId { setExpenseId(expenseId, screenType: .chat) }

        case "phase_detail":
            if let projectId = intent.projectId { setProjectId(projectId) }
            if let phaseId = intent.phaseId { setPhaseId(phaseId) }

        case "request_detail":
            if let projectId = intent.projectId { setProjectId(projectId) }
            if let requestId = intent.requestId { setRequestId(requestId) }

        case "project_creation", "project_review":
            // Navigate to project creation/review screen for rejected projects
            if let id = intent.projectId { setProjectId(id) }
            
        case "chat_screen":
            // For customer chat notifications - same as chat_detail
            if let projectId = intent.projectId { setProjectId(projectId) }
            if let chatId = intent.chatId { setChatId(chatId) }
            
        case "expense_review":
            // For admin/customer expense review - same as expense_detail
            if let projectId = intent.projectId { setProjectId(projectId) }
            if let expenseId = intent.expenseId { setExpenseId(expenseId, screenType: .detail) }

        default:
            print("⚠️ Unknown screen: \(intent.screen)")
        }

        pendingNavigationIntent = nil
    }

    // MARK: - Cleanup
    func resetReadyState() {
        readyState = .launching
        print("🔄 Ready state reset to launching")
    }
}
