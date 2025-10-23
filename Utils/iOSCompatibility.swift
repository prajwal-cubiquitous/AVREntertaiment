//
//  iOSCompatibility.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 7/10/25.
//

import SwiftUI
import Foundation

// MARK: - iOS Version Compatibility
struct iOSCompatibility {
    static var isIOS14OrLater: Bool {
        if #available(iOS 14.0, *) {
            return true
        } else {
            return false
        }
    }
    
    static var isIOS15OrLater: Bool {
        if #available(iOS 15.0, *) {
            return true
        } else {
            return false
        }
    }
    
    static var isIOS16OrLater: Bool {
        if #available(iOS 16.0, *) {
            return true
        } else {
            return false
        }
    }
    
    static var isIOS17OrLater: Bool {
        if #available(iOS 17.0, *) {
            return true
        } else {
            return false
        }
    }
}

// MARK: - @MainActor Compatibility
extension iOSCompatibility {
    static func runOnMainActor<T>(_ action: @escaping () -> T) -> T {
        if Thread.isMainThread {
            return action()
        } else {
            return DispatchQueue.main.sync {
                action()
            }
        }
    }
    
    static func runOnMainActorAsync(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }
}

// MARK: - Async/Await Compatibility
// Note: withCheckedContinuation is available in iOS 13+, so we don't need a compatibility wrapper

// MARK: - Number Formatting Compatibility
extension Int {
    func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - SwiftUI View Modifiers Compatibility
extension View {
    @ViewBuilder
    func compatibleRefreshable(action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.refreshable {
                await action()
            }
        } else {
            self
        }
    }
    
    @ViewBuilder
    func compatibleTask(priority: TaskPriority = .userInitiated, _ action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.task(priority: priority, action)
        } else {
            self.onAppear {
                Task {
                    await action()
                }
            }
        }
    }
    
    @ViewBuilder
    func compatibleSearchable(text: Binding<String>, prompt: String? = nil) -> some View {
        if #available(iOS 15.0, *) {
            self.searchable(text: text, prompt: prompt ?? "")
        } else {
            self
        }
    }
    
    @ViewBuilder
    func compatibleNavigationTitle(_ title: String, displayMode: NavigationBarItem.TitleDisplayMode = .automatic) -> some View {
        if #available(iOS 14.0, *) {
            self.navigationTitle(title)
                .navigationBarTitleDisplayMode(displayMode)
        } else {
            self.navigationBarTitle(title)
        }
    }
    
    @ViewBuilder
    @available(iOS 14.0, *)
    func compatibleToolbar<Content: ToolbarContent>(@ToolbarContentBuilder content: () -> Content) -> some View {
        self.toolbar(content: content)
    }
    
    @ViewBuilder
    @available(iOS 15.0, *)
    func compatibleConfirmationDialog<A: View>(
        _ title: Text,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: () -> A
    ) -> some View {
        self.confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
    }
}

// MARK: - StateObject Compatibility
// Note: @StateObject is available in iOS 13+ and works perfectly fine

// MARK: - Dismiss Environment Compatibility
struct CompatibleDismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var compatibleDismiss: () -> Void {
        get { self[CompatibleDismissKey.self] }
        set { self[CompatibleDismissKey.self] = newValue }
    }
}

extension View {
    func compatibleDismiss() -> some View {
        if #available(iOS 15.0, *) {
            return self.environment(\.compatibleDismiss, {})
        } else {
            return self.environment(\.compatibleDismiss, {})
        }
    }
}

// MARK: - Color Compatibility
extension Color {
    static var compatibleAccentColor: Color {
        if #available(iOS 14.0, *) {
            return .accentColor
        } else {
            return .blue
        }
    }
    
    static var compatibleSystemBackground: Color {
        if #available(iOS 14.0, *) {
            return Color(.systemBackground)
        } else {
            return Color(.systemBackground)
        }
    }
    
    static var compatibleSecondarySystemGroupedBackground: Color {
        if #available(iOS 13.0, *) {
            return Color(.secondarySystemGroupedBackground)
        } else {
            return Color(.systemGray6)
        }
    }
    
    static var compatibleTertiarySystemGroupedBackground: Color {
        if #available(iOS 13.0, *) {
            return Color(.tertiarySystemGroupedBackground)
        } else {
            return Color(.systemGray5)
        }
    }
}

// MARK: - Font Compatibility
extension Font {
    static var compatibleLargeTitle: Font {
        if #available(iOS 14.0, *) {
            return .largeTitle
        } else {
            return .system(size: 34, weight: .bold)
        }
    }
    
    static var compatibleTitle: Font {
        if #available(iOS 14.0, *) {
            return .title
        } else {
            return .system(size: 28, weight: .bold)
        }
    }
    
    static var compatibleTitle2: Font {
        if #available(iOS 14.0, *) {
            return .title2
        } else {
            return .system(size: 22, weight: .bold)
        }
    }
    
    static var compatibleTitle3: Font {
        if #available(iOS 14.0, *) {
            return .title3
        } else {
            return .system(size: 20, weight: .semibold)
        }
    }
    
    static var compatibleHeadline: Font {
        if #available(iOS 14.0, *) {
            return .headline
        } else {
            return .system(size: 17, weight: .semibold)
        }
    }
    
    static var compatibleCallout: Font {
        if #available(iOS 14.0, *) {
            return .callout
        } else {
            return .system(size: 16, weight: .regular)
        }
    }
    
    static var compatibleSubheadline: Font {
        if #available(iOS 14.0, *) {
            return .subheadline
        } else {
            return .system(size: 15, weight: .regular)
        }
    }
    
    static var compatibleFootnote: Font {
        if #available(iOS 14.0, *) {
            return .footnote
        } else {
            return .system(size: 13, weight: .regular)
        }
    }
    
    static var compatibleCaption: Font {
        if #available(iOS 14.0, *) {
            return .caption
        } else {
            return .system(size: 12, weight: .regular)
        }
    }
    
    static var compatibleCaption2: Font {
        if #available(iOS 14.0, *) {
            return .caption2
        } else {
            return .system(size: 11, weight: .regular)
        }
    }
}

// MARK: - Animation Compatibility
extension Animation {
    static var compatibleSpring: Animation {
        if #available(iOS 15.0, *) {
            return .spring()
        } else {
            return .easeInOut(duration: 0.3)
        }
    }
    
    static func compatibleSpring(duration: Double) -> Animation {
        if #available(iOS 15.0, *) {
            return .spring(duration: duration)
        } else {
            return .easeInOut(duration: duration)
        }
    }
}

// MARK: - ProgressView Compatibility
struct CompatibleProgressView: View {
    var body: some View {
        if #available(iOS 14.0, *) {
            ProgressView()
        } else {
            ActivityIndicator(isAnimating: .constant(true), style: .medium)
        }
    }
}

struct ActivityIndicator: UIViewRepresentable {
    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style

    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}

// MARK: - Symbol Rendering Mode Compatibility
extension Image {
    @ViewBuilder
    @available(iOS 15.0, *)
    func compatibleSymbolRenderingMode(_ mode: SymbolRenderingMode) -> some View {
        self.symbolRenderingMode(mode)
    }
}

extension View {
    @ViewBuilder
    @available(iOS 15.0, *)
    func compatibleSymbolRenderingMode(_ mode: SymbolRenderingMode) -> some View {
        self.symbolRenderingMode(mode)
    }
}

// MARK: - Safe Area Compatibility
extension View {
    @ViewBuilder
    func compatibleIgnoresSafeArea(_ edges: Edge.Set = .all) -> some View {
        if #available(iOS 14.0, *) {
            self.edgesIgnoringSafeArea(edges)
        } else {
            self.edgesIgnoringSafeArea(edges)
        }
    }
}

// MARK: - TabView Style Compatibility
extension View {
    @ViewBuilder
    var compatibleTabViewStyle: some View {
        if #available(iOS 14.0, *) {
            self.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        } else {
            self
        }
    }
}

// MARK: - Button Style Compatibility
extension View {
    @ViewBuilder
    var compatibleButtonStyle: some View {
        if #available(iOS 15.0, *) {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(DefaultButtonStyle())
        }
    }
}
