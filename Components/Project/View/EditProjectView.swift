import SwiftUI
import FirebaseFirestore

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditProjectViewModel
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingAddTeamMember = false
    @State private var showingAddDepartment = false
    @State private var newTeamMember = ""
    @State private var newDepartment = ""
    @State private var departmentAmount: Double = 0
    
    let project: Project
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: EditProjectViewModel(project: project))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Project Name", text: $viewModel.name)
                    TextField("Description", text: $viewModel.description)
                    TextField("Budget", value: $viewModel.budget, format: .currency(code: "INR"))
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Timeline")) {
                    TextField("Start Date", text: $viewModel.startDate)
                    TextField("End Date", text: $viewModel.endDate)
                }
                
                Section(header: Text("Status")) {
                    TextField("Status", text: $viewModel.status)
                }
                
                Section(header: Text("Team Members")) {
                    ForEach(viewModel.teamMembers, id: \.self) { member in
                        Text(member)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.removeTeamMember(member)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    
                    Button("Add Team Member") {
                        showingAddTeamMember = true
                    }
                }
                
                Section(header: Text("Departments")) {
                    ForEach(Array(viewModel.departments.keys.sorted()), id: \.self) { department in
                        if let amount = viewModel.departments[department] {
                            HStack {
                                Text(department)
                                Spacer()
                                Text(String(format: "₹%.2f", amount))
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.removeDepartment(department)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                    Button("Add Department") {
                        showingAddDepartment = true
                    }
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            do {
                                try await viewModel.saveChanges()
                                dismiss()
                            } catch {
                                alertMessage = error.localizedDescription
                                showingAlert = true
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .alert("Add Team Member", isPresented: $showingAddTeamMember) {
                TextField("Member Name", text: $newTeamMember)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    if !newTeamMember.isEmpty {
                        viewModel.addTeamMember(newTeamMember)
                        newTeamMember = ""
                    }
                }
            }
            .alert("Add Department", isPresented: $showingAddDepartment) {
                TextField("Department Name", text: $newDepartment)
                TextField("Budget Amount", value: $departmentAmount, format: .currency(code: "INR"))
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    if !newDepartment.isEmpty {
                        viewModel.addDepartment(newDepartment, amount: departmentAmount)
                        newDepartment = ""
                        departmentAmount = 0
                    }
                }
            }
        }
    }
} 