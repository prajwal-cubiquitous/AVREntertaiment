import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation

struct AddExpenseView: View {
    let project: Project
    @StateObject private var viewModel: AddExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: FirebaseAuthService
    @State private var showingFileViewer = false
    @State private var showingCamera = false
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: AddExpenseViewModel(project: project, customerId: nil))
    }
    
    private var customerId: String? {
        authService.currentCustomerId
    }
    
    // MARK: - Helper Functions
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0.00"
    }
    
    private func fileIcon(for fileName: String) -> String {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".pdf") {
            return "doc.fill"
        } else if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") {
            return "photo.fill"
        } else if lowercased.hasSuffix(".png") {
            return "photo.fill"
        } else {
            return "doc.fill"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
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
                            Text("Tracura")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // MARK: - Basic Information
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expense Date")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                        
                        DatePicker("Select expense date", selection: $viewModel.expenseDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("Phase selection will be filtered based on this date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                    
                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        TextField("0", text: Binding(
                            get: { viewModel.amount },
                            set: { newValue in
                                // Format the input according to Indian numbering system
                                viewModel.amount = viewModel.formatAmountInput(newValue)
                            }
                        ))
                            .keyboardType(.decimalPad)
                            .font(.title3)
                            .fontWeight(.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.amountError != nil ? Color.red : Color.clear, lineWidth: 1)
                            )
                        
                        if let error = viewModel.amountError {
                            InlineErrorMessage(message: error)
                        }
                    }
                    .id("amount")
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
                                    .stroke(viewModel.descriptionError != nil ? Color.red : Color(UIColor.systemGray4), lineWidth: viewModel.descriptionError != nil ? 1 : 1)
                            )
                        
                        if let error = viewModel.descriptionError {
                            InlineErrorMessage(message: error)
                        }
                    }
                    .id("description")
                    .padding(.vertical, 4)
                } header: {
                    Text("Expense Details")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Phase Selection
                Section {
                    phasePickerView
                    
                    // Admin approval message
                    if let message = viewModel.adminApprovalMessage {
                        AdminApprovalMessageView(message: message)
                    }
                } header: {
                    Text("Phase Selection")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } footer: {
                    if !viewModel.availablePhases.filter({ $0.canAddExpense }).isEmpty {
                        Text("Phases are filtered based on the selected expense date")
                            .font(.caption)
                    } else {
                        Text("No phases available for the selected date. Please select a different date.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // MARK: - Department Selection
                Section {
                    departmentPickerView
                } header: {
                    Text("Department Selection")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Categories
                Section {
                    categoriesView
                } header: {
                    categoriesHeader
                }
//                footer: {
//                    categoriesFooter
//                }
                
                // MARK: - Payment Mode
                Section {
                    paymentModeView
                } header: {
                    Text("Mode of Payment")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Attachment
                Section {
                    attachmentView
                } header: {
                    Text("Attachment")
                        .textCase(.none)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Submit Button
                Section {
                    submitButton
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.firstInvalidFieldId) { fieldId in
                if let fieldId = fieldId {
                    print("🔄 Attempting to scroll to field: \(fieldId)")
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        withAnimation(.easeInOut(duration: 0.6)) {
                            proxy.scrollTo(fieldId, anchor: .top)
                        }
                    }
                }
            }
            .alert("Status", isPresented: $viewModel.showAlert) {
                Button("OK") {
                    if viewModel.shouldDismissOnAlert {
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            .confirmationDialog("Select Attachment", isPresented: $viewModel.showingAttachmentOptions, titleVisibility: .visible) {
                Button("Camera") {
                    showingCamera = true
                }
                
                Button("Select from Photos") {
                    viewModel.showingImagePicker = true
                }
                
                Button("Select from Files") {
                    viewModel.showingDocumentPicker = true
                }
                
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ExpenseImagePicker(selectedImage: Binding(
                    get: { nil },
                    set: { image in
                        viewModel.handleImageSelection(image)
                    }
                ))
            }
            .sheet(isPresented: $showingCamera) {
                ExpenseCameraPicker(
                    selectedImage: Binding(
                        get: { nil },
                        set: { image in
                            viewModel.handleImageSelection(image)
                        }
                    ),
                    onDismiss: {
                        showingCamera = false
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingDocumentPicker) {
                DocumentPicker(
                    allowedTypes: [.pdf, .image],
                    onDocumentPicked: viewModel.handleDocumentSelection
                )
            }
            .sheet(isPresented: $showingFileViewer) {
                if let urlString = viewModel.attachmentURL,
                   let url = URL(string: urlString) {
                    FileViewerSheet(fileURL: url, fileName: viewModel.attachmentName)
                }
            }
            }
        }
            .onAppear{
                UserServices.shared.currentUserPhone
                // Update customerId in ViewModel when it becomes available
                if let customerId = customerId {
                    viewModel.updateCustomerId(customerId)
                }
            }
            .onChange(of: viewModel.expenseDate) { newDate in
                // Reload phases when date changes
                viewModel.loadPhases(for: newDate)
            }
            .onChange(of: viewModel.amount) { _ in
                viewModel.checkAdminApprovalConditions()
            }
            .onChange(of: viewModel.selectedPhaseId) { _ in
                viewModel.checkAdminApprovalConditions()
            }
            .onChange(of: viewModel.selectedDepartment) { _ in
                viewModel.checkAdminApprovalConditions()
            }
    }
    
    
    // MARK: - Phase Picker
    private var phasePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase")
                .font(.subheadline)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            Menu {
                // Show only phases that can accept expenses for the selected date
                let availablePhases = viewModel.availablePhases.filter { $0.canAddExpense }
                if !availablePhases.isEmpty {
                    ForEach(availablePhases) { phase in
                        Button {
                            viewModel.selectedPhaseId = phase.id
                            viewModel.updateDepartmentForPhase()
                        } label: {
                            HStack {
                                Text(phase.name)
                                Spacer()
                                Text(formatCurrency(phase.remainingAmount))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Text("No phases available for selected date")
                        .foregroundColor(.secondary)
                        .disabled(true)
                }
                
                // Show disabled/out-of-timeline phases at the bottom with indicators
                let disabledPhases = viewModel.availablePhases.filter { !$0.canAddExpense }
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
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .disabled(true)
                    }
                }
            } label: {
                HStack {
                    if let selectedPhase = viewModel.selectedPhase {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedPhase.name)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                            Text("Remaining: \(formatCurrency(selectedPhase.remainingAmount))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select Phase")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(8)
            }
            
            // Show info about disabled phases if selected phase is not available
            if let selectedPhase = viewModel.selectedPhase, !selectedPhase.canAddExpense {
                HStack(spacing: 6) {
                    Image(systemName: selectedPhase.isEnabled ? "calendar.badge.exclamationmark" : "lock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(selectedPhase.isEnabled ? "This phase is not available for the selected expense date" : "This phase is disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            
            if let error = viewModel.phaseError {
                InlineErrorMessage(message: error)
            }
        }
        .id("phase")
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
                            viewModel.checkAdminApprovalConditions()
                        } label: {
                            HStack {
                                Text(department)
                                Spacer()
                                if let remaining = selectedPhase.departmentRemainingAmounts[department] {
                                    Text(formatCurrency(remaining))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.selectedDepartment.isEmpty {
                            Text("Select Department")
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.selectedDepartment)
                                    .foregroundColor(.primary)
                                    .fontWeight(.medium)
                                if let remaining = selectedPhase.departmentRemainingAmounts[viewModel.selectedDepartment] {
                                    Text("Remaining: \(formatCurrency(remaining))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.departmentError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                }
                .disabled(!selectedPhase.canAddExpense)
            } else {
                Text("Please select a phase first")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let error = viewModel.departmentError {
                InlineErrorMessage(message: error)
            }
        }
        .id("department")
        .padding(.vertical, 4)
    }
    
    // MARK: - Categories Section
    private var categoriesHeader: some View {
        HStack {
            Text("Category")
//            Spacer()
//            Button(action: viewModel.addCategory) {
//                Image(systemName: "plus.circle.fill")
//                    .foregroundColor(.blue)
//                    .font(.title3)
//            }
        }
    }
    
//    private var categoriesFooter: some View {
//        Text("Add multiple categories by tapping the + button")
//            .font(.caption)
//            .foregroundColor(.secondary)
//    }
    
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke((viewModel.categoryError(at: index)?.contains("Custom") ?? false) ? Color.red : Color.clear, lineWidth: 1)
                        )
                        
                        if let error = viewModel.categoryError(at: index), error.contains("Custom") {
                            InlineErrorMessage(message: error)
                        }
                    }
                    .id("category_\(index)_custom")
                    .padding(.leading, 8)
                    .padding(.top, 4)
                }
                
                if let error = viewModel.categoryError(at: index), !error.contains("Custom") {
                    InlineErrorMessage(message: error)
                }
            }
            .id("category_\(index)")
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
        VStack(alignment: .leading, spacing: 12) {
            if let attachmentName = viewModel.attachmentName {
                // Show attached file
                HStack(spacing: 12) {
                    // File info - not clickable
                    HStack {
                        Image(systemName: fileIcon(for: attachmentName))
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(attachmentName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text("Tap preview to view")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Preview button - separate icon button
                    Button(action: {
                        HapticManager.selection()
                        showingFileViewer = true
                    }) {
                        Image(systemName: "eye.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Remove button - separate action
                    Button(action: {
                        HapticManager.selection()
                        withAnimation(.easeInOut) {
                            viewModel.removeAttachment()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Add attachment button
                Button(action: {
                    viewModel.showingAttachmentOptions = true
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.attachmentError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
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
            
            // Error message
            if let error = viewModel.attachmentError {
                InlineErrorMessage(message: error)
            }
        }
        .id("attachment")
        .padding(.vertical, 4)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: {
            HapticManager.impact(.medium)
            // Validate and find first invalid field before submitting
            if let firstInvalidField = viewModel.validateAndFindFirstInvalidField() {
                viewModel.firstInvalidFieldId = firstInvalidField
                HapticManager.notification(.error)
            } else {
                // Form is valid, proceed with submission
                viewModel.submitExpense()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Submit for Approval")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isFormValid ? Color.blue : Color.blue.opacity(0.6))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isLoading)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding(.horizontal)
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onDocumentPicked: (Result<[URL], Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        // Enable access to files outside the app's sandbox
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // URLs are already accessible, no need for security-scoped resource handling here
            // The ViewModel will handle copying to a temporary location
            parent.onDocumentPicked(.success(urls))
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation if needed
        }
    }
}

// MARK: - Expense Image Picker
struct ExpenseImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ExpenseImagePicker
        
        init(_ parent: ExpenseImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error loading image: \(error.localizedDescription)")
                            return
                        }
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Expense Camera Picker
struct ExpenseCameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ExpenseCameraPicker
        
        init(_ parent: ExpenseCameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Extract image on main thread
            DispatchQueue.main.async {
                if let editedImage = info[.editedImage] as? UIImage {
                    self.parent.selectedImage = editedImage
                } else if let originalImage = info[.originalImage] as? UIImage {
                    self.parent.selectedImage = originalImage
                }
            }
            
            // Dismiss the picker first
            picker.dismiss(animated: true) {
                // After picker dismisses, dismiss the sheet
                DispatchQueue.main.async {
                    self.parent.onDismiss()
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                // After picker dismisses, dismiss the sheet
                DispatchQueue.main.async {
                    self.parent.onDismiss()
                }
            }
        }
    }
}

// MARK: - Category Searchable Dropdown
struct CategorySearchableDropdown: View {
    @Binding var selectedCategory: String
    @Binding var searchText: String
    let filteredCategories: [String]
    let index: Int
    let onSelect: (String) -> Void
    let showRemoveButton: Bool
    let onRemove: () -> Void
    @State private var showDropdown = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Search Text Field / Display
                if selectedCategory.isEmpty || showDropdown {
                    TextField("Search or select category", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onTapGesture {
                            showDropdown = true
                        }
                        .onChange(of: searchText) { _ in
                            showDropdown = !searchText.isEmpty || selectedCategory.isEmpty
                        }
                } else {
                    // Show selected category as a chip
                    HStack {
                        Text(selectedCategory)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(8)
                        .onTapGesture {
                            showDropdown = true
                            searchText = ""
                        }
                    }
                
                if showRemoveButton {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
            }
            
            // Dropdown List
            if showDropdown && !filteredCategories.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredCategories, id: \.self) { category in
                            Button(action: {
                                onSelect(category)
                                searchText = ""
                                showDropdown = false
                            }) {
                                HStack {
                                    Text(category)
                                        .foregroundColor(.primary)
                                        .font(.subheadline)
                                    Spacer()
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            if !selectedCategory.isEmpty {
                showDropdown = false
            }
        }
    }
}

// MARK: - Admin Approval Message View
struct AdminApprovalMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14, weight: .medium))
            
            Text(message)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.small)
        .padding(.top, DesignSystem.Spacing.extraSmall)
    }
}

// MARK: - Preview
#Preview {
    AddExpenseView(project: Project.sampleData[0])
} 
