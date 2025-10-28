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
    @Published var activeChatId: String?
    
    init(){
        print("active project id \(activeProjectId?.id ?? "nil")")
        print("active chat id \(activeChatId ?? "nil")")
    }
    
    func clearNavigation() {
        activeProjectId = nil
        activeChatId = nil
    }
    
    func setProjectId(_ id: String?) {
        activeProjectId = id.map { ProjectNavigationItem(id: $0) }
    }
}
