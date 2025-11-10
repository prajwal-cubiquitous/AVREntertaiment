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
    @State private var hasLoadedExpenseData = false
    
    init(expense: Expense, project: Project, customerId: String?) {
        self.expense = expense
        self.project = project
        self._viewModel = StateObject(wrappedValue: AddExpenseViewModel(project: project, customerId: customerId))
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
                        
//                        HStack {
//                            Image(systemName: "building.2")
//                                .foregroundColor(.secondary)
//                            Text("AVR Entertainment")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
//                        }
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
                Section(header: Text("Receipt (Optional)")) {
                    attachmentView
                }
                
                // MARK: - Payment Proof (Required for UPI and Check)
                if viewModel.selectedPaymentMode == .upi || viewModel.selectedPaymentMode == .check {
                    Section(header: Text("Payment Proof"), footer: Text("Payment proof is required for UPI and check payments")) {
                        paymentProofView
                    }
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
            .confirmationDialog("Select Payment Proof", isPresented: $viewModel.showingPaymentProofOptions, titleVisibility: .visible) {
                Button("Camera") {
                    showingPaymentProofCamera = true
                }
                
                Button("Select from Photos") {
                    viewModel.showingPaymentProofImagePicker = true
                }
                
                Button("Select from Files") {
                    viewModel.showingPaymentProofDocumentPicker = true
                }
                
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $viewModel.showingPaymentProofImagePicker) {
                ExpenseImagePicker(selectedImage: Binding(
                    get: { nil },
                    set: { image in
                        viewModel.handlePaymentProofImageSelection(image)
                    }
                ))
            }
            .sheet(isPresented: $showingPaymentProofCamera) {
                ExpenseCameraPicker(
                    selectedImage: Binding(
                        get: { nil },
                        set: { image in
                            viewModel.handlePaymentProofImageSelection(image)
                        }
                    ),
                    onDismiss: {
                        showingPaymentProofCamera = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingPaymentProofDocumentPicker) {
                DocumentPicker(
                    allowedTypes: [.pdf, .image],
                    onDocumentPicked: viewModel.handlePaymentProofDocumentSelection
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
                    // Wait for phases to load by checking availablePhases
                    var attempts = 0
                    while viewModel.availablePhases.isEmpty && attempts < 30 {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        attempts += 1
                    }
                    // If phases are loaded, load expense data
                    if !viewModel.availablePhases.isEmpty && !hasLoadedExpenseData {
                        await MainActor.run {
                            loadExpenseData()
                            hasLoadedExpenseData = true
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.availablePhases) { newPhases in
            // When phases load, load expense data if it hasn't been loaded yet
            if !newPhases.isEmpty && !hasLoadedExpenseData {
                loadExpenseData()
                hasLoadedExpenseData = true
            }
        }
    }
    
    // MARK: - Load Expense Data
    private func loadExpenseData() {
        // Only load if phases are available
        guard !viewModel.availablePhases.isEmpty else {
            print("⚠️ Cannot load expense data: phases not loaded yet")
            return
        }
        
        print("📝 Loading expense data for editing...")
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        if let date = dateFormatter.date(from: expense.date) {
            viewModel.expenseDate = date
        }
        
        // Set amount
        viewModel.amount = String(format: "%.2f", expense.amount)
        
        // Set description
        viewModel.description = expense.description
        
        // Set phase and department
        if let phaseId = expense.phaseId, !phaseId.isEmpty {
            // Verify phase exists in available phases
            if viewModel.availablePhases.contains(where: { $0.id == phaseId }) {
                viewModel.selectedPhaseId = phaseId
                print("✅ Phase set: \(phaseId)")
            } else {
                print("⚠️ Phase ID \(phaseId) not found in available phases")
                // Try to find the phase even if it's disabled
                if let phase = viewModel.availablePhases.first(where: { $0.id == phaseId }) {
                    viewModel.selectedPhaseId = phaseId
                    print("✅ Phase found (may be disabled): \(phaseId)")
                }
            }
        }
        
        // Set department
        viewModel.selectedDepartment = expense.department
        viewModel.updateDepartmentForPhase()
        print("✅ Department set: \(expense.department)")
        
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
        print("✅ Categories set: \(viewModel.categories)")
        
        // Set payment mode
        viewModel.selectedPaymentMode = expense.modeOfPayment
        print("✅ Payment mode set: \(expense.modeOfPayment.rawValue)")
        
        // Set existing attachment info if present
        viewModel.attachmentURL = expense.attachmentURL
        viewModel.attachmentName = expense.attachmentName
        
        // Set existing payment proof info if present
        viewModel.paymentProofURL = expense.paymentProofURL
        viewModel.paymentProofName = expense.paymentProofName
        
        print("✅ Expense data loaded successfully")
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
                    Button {
                        if phase.canAddExpense {
                            viewModel.selectedPhaseId = phase.id
                            viewModel.updateDepartmentForPhase()
                        }
                    } label: {
                        TruncatedTextWithTooltip(
                            phase.name,
                            font: .body,
                            foregroundColor: .primary,
                            lineLimit: 1
                        )
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
                                TruncatedTextWithTooltip(
                                    phase.name,
                                    font: .body,
                                    foregroundColor: .primary,
                                    lineLimit: 1
                                )
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
                        TruncatedTextWithTooltip(
                            selectedPhase.name,
                            font: .body,
                            fontWeight: .medium,
                            foregroundColor: .primary,
                            lineLimit: 1
                        )
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
                        Button {
                            viewModel.selectedDepartment = department
                        } label: {
                            TruncatedTextWithTooltip(
                                department,
                                font: .body,
                                foregroundColor: .primary,
                                lineLimit: 1
                            )
                        }
                    }
                } label: {
                    HStack {
                        TruncatedTextWithTooltip(
                            viewModel.selectedDepartment.isEmpty ? "Select Department" : viewModel.selectedDepartment,
                            font: .body,
                            fontWeight: .medium,
                            foregroundColor: viewModel.selectedDepartment.isEmpty ? .secondary : .primary,
                            lineLimit: 1
                        )
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
    @State private var showingFileViewer = false
    @State private var showingPaymentProofFileViewer = false
    @State private var showingPaymentProofCamera = false
    
    private var attachmentView: some View {
        VStack(spacing: 12) {
            if let attachmentName = viewModel.attachmentName {
                // Show attached file
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: fileIcon(for: attachmentName))
                            .foregroundColor(.blue)
                        Text(attachmentName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Preview button
                    Button(action: {
                        showingFileViewer = true
                    }) {
                        Image(systemName: "eye.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Remove button
                    Button("Remove") {
                        withAnimation(.easeInOut) {
                            viewModel.removeAttachment()
                        }
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                // Add attachment button
                Button(action: {
                    viewModel.showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "paperclip")
                            .font(.title3)
                        Text("Add Receipt")
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
        .sheet(isPresented: $showingFileViewer) {
            if let urlString = viewModel.attachmentURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: viewModel.attachmentName)
            }
        }
    }
    
    // MARK: - Payment Proof Section
    private var paymentProofView: some View {
        VStack(spacing: 12) {
            if let paymentProofName = viewModel.paymentProofName {
                // Show attached file
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: fileIcon(for: paymentProofName))
                            .foregroundColor(.green)
                        Text(paymentProofName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Preview button
                    Button(action: {
                        showingPaymentProofFileViewer = true
                    }) {
                        Image(systemName: "eye.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                            .frame(width: 44, height: 44)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Remove button
                    Button(action: {
                        withAnimation(.easeInOut) {
                            viewModel.removePaymentProof()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Add payment proof button
                Button(action: {
                    viewModel.showingPaymentProofOptions = true
                }) {
                    HStack {
                        Image(systemName: "paperclip")
                            .font(.title3)
                        Text("Add Payment Proof")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundColor(.green)
                    .padding()
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Upload progress
            if viewModel.isUploadingPaymentProof {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.paymentProofUploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("Uploading... \(Int(viewModel.paymentProofUploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingPaymentProofFileViewer) {
            if let urlString = viewModel.paymentProofURL,
               let url = URL(string: urlString) {
                FileViewerSheet(fileURL: url, fileName: viewModel.paymentProofName)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func fileIcon(for fileName: String) -> String {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".pdf") {
            return "doc.fill"
        } else if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".png") {
            return "photo.fill"
        } else {
            return "doc.fill"
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

