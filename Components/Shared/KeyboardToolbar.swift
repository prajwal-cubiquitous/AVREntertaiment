//
//  KeyboardToolbar.swift
//  AVREntertainment
//
//  Created for keyboard dismissal across all screens
//

import SwiftUI

// MARK: - Keyboard Toolbar Modifier
struct KeyboardToolbar: ViewModifier {
    @FocusState.Binding var focusedField: AnyHashable?
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundColor(.blue)
                }
            }
    }
}

// MARK: - Extension for easy application
extension View {
    /// Adds a "Done" button to the keyboard toolbar
    /// - Parameter focusedField: A binding to the focused field state
    func keyboardToolbar(focusedField: FocusState<AnyHashable?>.Binding) -> some View {
        self.modifier(KeyboardToolbar(focusedField: focusedField))
    }
}

// MARK: - TextEditor with Keyboard Dismissal
struct DismissableTextEditor: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(UIColor.placeholderText))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            }
            TextEditor(text: $text)
                .focused($isFocused)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isFocused = false
                }
                .foregroundColor(.blue)
            }
        }
    }
}

