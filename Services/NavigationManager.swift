//
//  NavigationManager.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/28/25.
//
import Foundation

class NavigationManager: ObservableObject {
    @Published var activeProjectId: String?
    
    init(){
        print("activte project id \(activeProjectId)")

    }
}
