import Foundation
import FirebaseFirestore

@MainActor
class EditProjectViewModel: ObservableObject {
    @Published var name: String
    @Published var description: String
    @Published var budget: Double
    @Published var startDate: String
    @Published var endDate: String
    @Published var status: String
    @Published var teamMembers: [String]
    @Published var departments: [String: Double]
    
    private let projectId: String
    private let db = Firestore.firestore()
    
    init(project: Project) {
        self.projectId = project.id ?? ""
        self.name = project.name
        self.description = project.description
        self.budget = project.budget
        self.startDate = project.startDate ?? ""
        self.endDate = project.endDate ?? ""
        self.status = project.status
        self.teamMembers = project.teamMembers
        self.departments = project.departments
    }
    
    func addTeamMember(_ member: String) {
        if !member.isEmpty && !teamMembers.contains(member) {
            teamMembers.append(member)
        }
    }
    
    func removeTeamMember(_ member: String) {
        teamMembers.removeAll { $0 == member }
    }
    
    func addDepartment(_ department: String, amount: Double) {
        if !department.isEmpty && amount > 0 {
            departments[department] = amount
        }
    }
    
    func removeDepartment(_ department: String) {
        departments.removeValue(forKey: department)
    }
    
    func updateDepartmentAmount(_ department: String, amount: Double) {
        if amount > 0 {
            departments[department] = amount
        }
    }
    
    func saveChanges() async throws {
        let projectRef = db.collection("projects_ios").document(projectId)
        
        try await projectRef.updateData([
            "name": name,
            "description": description,
            "budget": budget,
            "startDate": startDate,
            "endDate": endDate,
            "status": status,
            "teamMembers": teamMembers,
            "departments": departments
        ])
    }
} 
