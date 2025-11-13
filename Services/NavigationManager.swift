//
//  NavigationManager.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/28/25.
//
import Foundation

struct ProjectNavigationItem: Identifiable, Hashable {
    let id: String
}

class NavigationManager: ObservableObject {
    @Published var activeProjectId: ProjectNavigationItem?
    @Published var activeChatId: ProjectNavigationItem?
    @Published var activeExpenseId: ProjectNavigationItem?
    @Published var activePhaseId: ProjectNavigationItem?
    @Published var activeRequestId: ProjectNavigationItem?
    @Published var expenseScreenType: ExpenseScreenType? = nil // Track if expense should show detail or chat
    
    enum ExpenseScreenType {
        case detail
        case chat
    }
    
    init(){
    }
    
    func clearNavigation() {
        activeProjectId = nil
        activeChatId = nil
        activeExpenseId = nil
        activePhaseId = nil
        activeRequestId = nil
        expenseScreenType = nil
    }
    
    func setProjectId(_ id: String?) {
        activeProjectId = id.map { ProjectNavigationItem(id: $0) }
    }
    
    func setChatId(_ id: String?) {
        activeChatId = id.map { ProjectNavigationItem(id: $0) }
    }
    
    func setExpenseId(_ id: String?, screenType: ExpenseScreenType = .detail) {
        activeExpenseId = id.map { ProjectNavigationItem(id: $0) }
        expenseScreenType = id != nil ? screenType : nil
    }
    
    func setPhaseId(_ id: String?) {
        activePhaseId = id.map { ProjectNavigationItem(id: $0) }
    }
    
    func setRequestId(_ id: String?) {
        activeRequestId = id.map { ProjectNavigationItem(id: $0) }
    }
}
