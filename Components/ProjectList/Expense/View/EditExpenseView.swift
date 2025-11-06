import SwiftUI
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore

struct EditExpenseView: View {
    let expense: Expense
    let project: Project
    @StateObject private var viewModel: AddExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customerId: String?
    
    init(expense: Expense, project: Project) {
        self.expense = expense
        self.project = project
        self._viewModel = StateObject(wrappedValue: AddExpenseViewModel(project: project, customerId: nil))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Project Header
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                            Text("AVR Entertainment")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // MARK: - Basic Information
                Section(header: Text("Expense Details")) {
                    // Date
                    DatePicker("Date", selection: $viewModel.expenseDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        TextField("0", text: $viewModel.amount)
                            .keyboardType(.decimalPad)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        TextEditor(text: $viewModel.description)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                            )
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Phase Selection
                Section(header: Text("Phase Selection")) {
                    phasePickerView
                }
                
                // MARK: - Department Selection
                Section(header: Text("Department Selection")) {
                    departmentPickerView
                }
                
                // MARK: - Categories
                Section(header: categoriesHeader, footer: categoriesFooter) {
                    categoriesView
                }
                
                // MARK: - Payment Mode
                Section(header: Text("Mode of Payment")) {
                    paymentModeView
                }
                
                // MARK: - Attachment
                Section(header: Text("Attachment (Optional)")) {
                    attachmentView
                }
                
                // MARK: - Update Button
                Section {
                    updateButton
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Status", isPresented: $viewModel.showAlert) {
                Button("OK") {
                    if viewModel.alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            .sheet(isPresented: $viewModel.showingDocumentPicker) {
                DocumentPicker(
                    allowedTypes: [.pdf, .image],
                    onDocumentPicked: viewModel.handleDocumentSelection
                )
            }
        }
        .onAppear {
            // Fetch customerId from users collection using current user UID
            Task {
                await fetchCustomerId()
                // Update customerId in ViewModel when it becomes available
                if let customerId = customerId {
                    viewModel.updateCustomerId(customerId)
                }
                // Wait for phases to load, then pre-fill the form
                // Small delay to ensure phases are loaded
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    loadExpenseData()
                }
            }
        }
        .onChange(of: viewModel.availablePhases) { _ in
            // When phases load, update the form if phaseId is set but not selected
            if let phaseId = expense.phaseId, !phaseId.isEmpty, viewModel.selectedPhaseId.isEmpty {
                loadExpenseData()
            }
        }
    }
    
    // MARK: - Load Expense Data
    private func loadExpenseData() {
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        if let date = dateFormatter.date(from: expense.date) {
            viewModel.expenseDate = date
        }
        
        // Set amount
        viewModel.amount = String(expense.amount)
        
        // Set description
        viewModel.description = expense.description
        
        // Set phase and department
        if let phaseId = expense.phaseId {
            viewModel.selectedPhaseId = phaseId
        }
        viewModel.selectedDepartment = expense.department
        viewModel.updateDepartmentForPhase()
        
        // Set categories and check for "Misc / Other" custom names
        viewModel.categories = expense.categories.isEmpty ? [""] : expense.categories
        // Initialize search texts for all categories
        for index in 0..<viewModel.categories.count {
            viewModel.categorySearchTexts[index] = ""
            // Check if any category is a custom name (not in predefined list)
            let category = viewModel.categories[index]
            if !AddExpenseViewModel.predefinedCategories.contains(category) && category != "" {
                // This is a custom category, treat it as "Misc / Other"
                viewModel.categories[index] = "Misc / Other (notes required)"
                viewModel.categoryCustomNames[index] = category
            }
        }
        
        // Set payment mode
        viewModel.selectedPaymentMode = expense.modeOfPayment
        
        // Set existing attachment info if present
        viewModel.attachmentURL = expense.attachmentURL
        viewModel.attachmentName = expense.attachmentName
    }
    
    // MARK: - Phase Picker
    private var phasePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Menu {
                // Show only phases that can accept expenses, plus the currently selected phase (for editing)
                ForEach(viewModel.availablePhases.filter { $0.canAddExpense || $0.id == viewModel.selectedPhaseId }) { phase in
                    Button(phase.name) {
                        if phase.canAddExpense {
                            viewModel.selectedPhaseId = phase.id
                            viewModel.updateDepartmentForPhase()
                        }
                    }
                }
                
                // Show disabled/out-of-timeline phases at the bottom with indicators (excluding already selected)
                let disabledPhases = viewModel.availablePhases.filter { !$0.canAddExpense && $0.id != viewModel.selectedPhaseId }
                if !disabledPhases.isEmpty {
                    Divider()
                    
                    ForEach(disabledPhases) { phase in
                        Button {
                            // Do nothing - disabled
                        } label: {
                            HStack {
                                Text(phase.name)
                                Spacer()
                                if !phase.isEnabled {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(true)
                    }
                }
            } label: {
                HStack {
                    if let selectedPhase = viewModel.selectedPhase {
                        Text(selectedPhase.name)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    } else {
                        Text("Select Phase")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(8)
            }
            
            // Show info about disabled phases if selected phase is not available for new expenses
            if let selectedPhase = viewModel.selectedPhase, !selectedPhase.canAddExpense {
                HStack(spacing: 6) {
                    Image(systemName: selectedPhase.isEnabled ? "info.circle" : "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(selectedPhase.isEnabled ? "This phase is not in the current timeline" : "This phase is disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Department Picker
    private var departmentPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Department")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if let selectedPhase = viewModel.selectedPhase {
                Menu {
                    ForEach(selectedPhase.departments.keys.sorted(), id: \.self) { department in
                        Button(department) {
                            viewModel.selectedDepartment = department
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.selectedDepartment.isEmpty ? "Select Department" : viewModel.selectedDepartment)
                            .foregroundColor(viewModel.selectedDepartment.isEmpty ? .secondary : .primary)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                }
                .disabled(!selectedPhase.canAddExpense && selectedPhase.id != viewModel.selectedPhaseId)
            } else {
                Text("Please select a phase first")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Categories Section
    private var categoriesHeader: some View {
        HStack {
            Text("Category")
            Spacer()
            Button(action: viewModel.addCategory) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
    }
    
    private var categoriesFooter: some View {
        Text("Add multiple categories by tapping the + button")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var categoriesView: some View {
        ForEach(Array(viewModel.categories.enumerated()), id: \.offset) { index, _ in
            VStack(alignment: .leading, spacing: 8) {
                // Category Dropdown
                CategorySearchableDropdown(
                    selectedCategory: Binding(
                        get: { 
                            (index >= 0 && index < viewModel.categories.count) ? viewModel.categories[index] : ""
                        },
                        set: { newValue in
                            if index < viewModel.categories.count {
                                viewModel.selectCategory(newValue, at: index)
                            }
                        }
                    ),
                    searchText: Binding(
                        get: { viewModel.categorySearchTexts[index] ?? "" },
                        set: { newValue in
                            viewModel.categorySearchTexts[index] = newValue
                        }
                    ),
                    filteredCategories: viewModel.filteredCategories(for: index),
                    index: index,
                    onSelect: { category in
                        viewModel.selectCategory(category, at: index)
                    },
                    showRemoveButton: viewModel.categories.count > 1,
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.removeCategory(at: index)
                        }
                    }
                )
                
                // Show custom name field if "Misc / Other" is selected
                if index >= 0 && index < viewModel.categories.count && viewModel.categories[index] == "Misc / Other (notes required)" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Category Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter custom category name", text: Binding(
                            get: { viewModel.categoryCustomNames[index] ?? "" },
                            set: { newValue in
                                viewModel.setCategoryCustomName(newValue, at: index)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                    }
                    .padding(.leading, 8)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Payment Mode
    private var paymentModeView: some View {
        VStack(spacing: 12) {
            ForEach(PaymentMode.allCases, id: \.self) { mode in
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectedPaymentMode = mode
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.selectedPaymentMode == mode ? "circle.inset.filled" : "circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                            
                            HStack(spacing: 8) {
                                Image(systemName: mode.icon)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                Text(mode.rawValue)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Attachment Section
    private var attachmentView: some View {
        VStack(spacing: 12) {
            if let attachmentName = viewModel.attachmentName {
                // Show attached file
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)
                    Text(attachmentName)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button("Remove") {
                        withAnimation(.easeInOut) {
                            viewModel.removeAttachment()
                        }
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                // Add attachment button
                Button(action: {
                    viewModel.showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "paperclip")
                            .font(.title3)
                        Text("Add Attachment")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Upload progress
            if viewModel.isUploading {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("Uploading... \(Int(viewModel.uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Update Button
    private var updateButton: some View {
        Button(action: {
            viewModel.updateExpense(expenseId: expense.id!)
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Update Expense")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isFormValid ? Color.orange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding(.horizontal)
    }
    
    // MARK: - Fetch Customer ID
    private func fetchCustomerId() async {
        guard let currentUserUID = Auth.auth().currentUser?.uid else {
            print("No current user UID found")
            return
        }
        
        let db = Firestore.firestore()
        do {
            // Query users collection where document ID = current user UID
            let userDoc = try await db.collection("users").document(currentUserUID).getDocument()
            
            if userDoc.exists, let userData = userDoc.data(), let ownerID = userData["ownerID"] as? String {
                await MainActor.run {
                    self.customerId = ownerID
                }
            } else {
                print("User document not found or ownerID missing")
            }
        } catch {
            print("Error fetching customerId: \(error.localizedDescription)")
        }
    }
}

