import SwiftUI
import UniformTypeIdentifiers

struct AddExpenseView: View {
    let project: Project
    @StateObject private var viewModel: AddExpenseViewModel
    @Environment(\.compatibleDismiss) private var dismiss
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: AddExpenseViewModel(project: project))
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
                
                // MARK: - Department Selection
                Section(header: Text("Assignment")) {
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
    }
    
    // MARK: - Department Picker
    private var departmentPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Department")
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(viewModel.availableDepartments, id: \.self) { department in
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
        ForEach(Array(viewModel.categories.enumerated()), id: \.offset) { index, category in
            HStack {
                TextField("Enter category name", text: $viewModel.categories[index])
                    .textFieldStyle(.roundedBorder)
                
                if viewModel.categories.count > 1 {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.removeCategory(at: index)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
            }
            .padding(.vertical, 2)
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
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: viewModel.submitExpense) {
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
            .background(viewModel.isFormValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding(.horizontal)
    }
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [Any]
    let onDocumentPicked: (Result<[URL], Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
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
            parent.onDocumentPicked(.success(urls))
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation if needed
        }
    }
}

// MARK: - Preview
#Preview {
    AddExpenseView(project: Project.sampleData[0])
} 