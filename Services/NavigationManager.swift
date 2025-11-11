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
    
    init(){
    }
    
    func clearNavigation() {
        activeProjectId = nil
        activeChatId = nil
        activeExpenseId = nil
    }
    
    func setProjectId(_ id: String?) {
        activeProjectId = id.map { ProjectNavigationItem(id: $0) }
    }
    
    func setChatId(_ id: String?) {
        activeChatId = id.map { ProjectNavigationItem(id: $0) }
    }
    
    func setExpenseId(_ id: String?) {
        activeExpenseId = id.map { ProjectNavigationItem(id: $0) }
    }
}
